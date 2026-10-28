//! The VR-09 plugin: the CLAP callbacks, and the glue between the host's
//! events, the engine, the audio loop and the user interface.
//!
//! The host calls these functions on three kinds of threads. The audio
//! thread runs `process`; everything it touches is an atomic, a queue, or
//! memory only it uses. The main thread runs the rest, and REAPER's timer
//! (also the main thread) drives the interface. Nothing on the audio thread
//! allocates or waits.
const std = @import("std");
const build_options = @import("build_options");
const Reaper = @import("reaper").reaper;
const clap = @import("clap.zig");
const c = clap.c;
const roland = @import("roland.zig");
const dump = @import("dump.zig");
const catalog = @import("catalog.zig");
const engine = @import("engine.zig");
const audio = @import("audio.zig");
const state = @import("state.zig");
const glue = @import("reaper_glue.zig");
const outbuf = @import("outbuf.zig");
const ui = @import("ui.zig");
/// The scripting API (`VR09_Command`) is built only for development: see `build.zig`.
const debug_api = if (build_options.debug_api) @import("debug_api.zig") else @import("debug_api_off.zig");
const dispatch = @import("dispatch.zig");
const actions = @import("actions.zig");
const split = @import("split.zig");
const registrations = @import("registrations.zig");
const scenes = @import("scenes.zig");
const strings_mod = @import("strings.zig");
const library = @import("library.zig");
const fileio = @import("fileio.zig");

const log = std.log.scoped(.plugin);

pub const plugin_id = "com.perken.vr09";
const P = [*c]const c.clap_plugin_t;

pub const allocator = std.heap.c_allocator;

/// The std.Io that the plugin does its file work with. Because the host loads the plugin as a library, there
/// is no main() to receive one from, so the plugin owns it here. The CLAP entry's init replaces this
/// single-threaded default with host_io.create(); tests keep the default.
pub var io_threaded: std.Io.Threaded = .init_single_threaded;

pub fn hostIo() std.Io {
    return io_threaded.io();
}

/// Parameters of the plugin itself, after the keyboard's.
pub const Extra = struct {
    id: []const u8,
    name: []const u8,
    module: []const u8,
    min: f64,
    max: f64,
    default: f64,
    stepped: bool,
};

pub const extras = [_]Extra{
    .{ .id = "audio-loop-on", .name = "Audio loop", .module = "Audio", .min = 0, .max = 1, .default = 0, .stepped = true },
    .{ .id = "audio-send-db", .name = "Send level", .module = "Audio", .min = -60, .max = 12, .default = 0, .stepped = false },
    .{ .id = "audio-return-db", .name = "Return level", .module = "Audio", .min = -60, .max = 12, .default = 0, .stepped = false },
    // 0 is no scene, n selects the session's scene n (see scenes.zig). Because the range is fixed, adding a
    // scene never rescales the points of a lane that refers to the scenes by position.
    .{ .id = "scene", .name = "Scene", .module = "Scenes", .min = 0, .max = scenes.max_scenes, .default = 0, .stepped = true },
    .{ .id = "split", .name = "Split at middle C", .module = "Patches", .min = 0, .max = 1, .default = 0, .stepped = true },
};

const extra_scene = 3;
const extra_split = 4;

pub const total_params = engine.param_count + extras.len;

/// Where the Scene parameter sits in the host's list of parameters: after the keyboard's, in the order of
/// `extras`. REAPER numbers the parameters in that order.
pub fn sceneParamIndex() usize {
    return engine.param_count + extra_scene;
}

fn extraId(index: usize) u32 {
    return engine.hashId(extras[index].id);
}

fn extraIndexOfId(id: u32) ?usize {
    inline for (extras, 0..) |e, i| {
        if (engine.hashId(e.id) == id) return i;
    }
    return null;
}

/// The window sizes for the host's embedded view. The real interface is a
/// ReaImGui window, so the embedded view is only a placeholder.
pub const embedded_width = 360;
pub const embedded_height = 64;

pub const max_instances = 64;

/// All live instances. Only the main thread touches this list.
pub var instances: [max_instances]?*Plugin = @splat(null);
pub var shared_bridge: ?*audio.Bridge = null;
var timer_registered: bool = false;

pub const SaveState = enum { idle, reading, done, failed };

/// A save of the keyboard as a preset. The keyboard is read first, which takes a moment, so the save has
/// two parts: `startSave` asks for the read, and `advanceSave` writes the file once the read has ended.
/// Only the main thread touches it.
pub const SaveJob = struct {
    state: SaveState = .idle,
    /// How many saves have begun. The panel tells the result of a save once, by this number.
    serial: u32 = 0,
    /// The name to save under. Like the file and the message, it is null-terminated, so the length is not kept.
    name: [96:0]u8 = @splat(0),
    /// The number of finished captures when the save began, so that the end of this one is told apart.
    baseline: u32 = 0,
    started_ms: i64 = 0,
    file: [128:0]u8 = @splat(0),
    known: usize = 0,
    message: [96:0]u8 = @splat(0),

    /// The name to save under.
    pub fn savedName(self: *const SaveJob) [:0]const u8 {
        return std.mem.sliceTo(&self.name, 0);
    }

    /// The file that was written.
    pub fn fileName(self: *const SaveJob) [:0]const u8 {
        return std.mem.sliceTo(&self.file, 0);
    }

    pub fn failure(self: *const SaveJob) [:0]const u8 {
        return std.mem.sliceTo(&self.message, 0);
    }

    pub fn fail(self: *SaveJob, text: []const u8) void {
        const n = @min(text.len, self.message.len);
        @memcpy(self.message[0..n], text[0..n]);
        self.message[n] = 0;
        self.state = .failed;
    }
};

/// A read that has not ended in this long is given up, whatever the keyboard does.
const save_timeout_ms: i64 = 120_000;

pub const Plugin = struct {
    clap: c.clap_plugin_t,
    host: [*c]const c.clap_host_t,
    shared: *engine.Shared,
    eng: *engine.Engine,
    settings: state.Settings,

    sample_rate: f64,
    active: bool,
    processing: bool,

    // The audio loop.
    slot: ?*audio.Slot,
    loop: ?*audio.Loop,
    /// What the audio thread tells the interface about the latency ping.
    ping_state: std.atomic.Value(u8),
    loop_state: std.atomic.Value(u8),
    latency_dirty: std.atomic.Value(bool),

    // The host's extensions, looked up once.
    host_params: [*c]const c.clap_host_params_t,
    host_latency: [*c]const c.clap_host_latency_t,

    // REAPER.
    track: Reaper.MediaTrack,
    ticks: u32,
    traces_logged_in: bool,
    traces_logged_out: bool,
    midi_logged: u32,
    loop_state_logged: u8,

    // The block's output.
    engine_events: outbuf.List(512),
    forward_events: outbuf.List(4096),
    router: split.Router,
    arena: outbuf.Arena(16384),

    // The session's scenes, which only the main thread touches, and the Scene parameter. `scene` is the
    // position in force (0 for none) and `pending_scene` is one that automation asked for and that the
    // main thread has not loaded yet.
    scene_list: *scenes.List,
    /// The strings of the panel and of the actions: the patches' names, the file names, the names that the
    /// player types. They are stored once each, and freed with the plugin.
    strings: strings_mod.Strings,
    /// The rows of the patch table: the registrations, the tones and the presets, read when they are first needed.
    library: library.Library,
    save: SaveJob,
    scene: std.atomic.Value(u8),
    /// The last scene that the main thread loaded, or 0. Only the main thread reads and writes it.
    scene_confirmed: u8,
    /// Set when the loop setting changed and the track's flag has not followed yet.
    loop_flag_dirty: std.atomic.Value(bool),
    pending_scene: std.atomic.Value(u8),

    ui: ui.Window,

    // ---- construction ----

    pub fn create(host: [*c]const c.clap_host_t) ?*Plugin {
        const self = allocator.create(Plugin) catch return null;
        const shared = allocator.create(engine.Shared) catch {
            allocator.destroy(self);
            return null;
        };
        shared.* = .{};
        const eng = allocator.create(engine.Engine) catch {
            allocator.destroy(shared);
            allocator.destroy(self);
            return null;
        };
        eng.* = engine.Engine.init(shared, 48000);
        const scene_list = allocator.create(scenes.List) catch {
            allocator.destroy(eng);
            allocator.destroy(shared);
            allocator.destroy(self);
            return null;
        };
        scene_list.* = .{};

        self.clap = .{
            .desc = &descriptor,
            .plugin_data = self,
            .init = pluginInit,
            .destroy = pluginDestroy,
            .activate = pluginActivate,
            .deactivate = pluginDeactivate,
            .start_processing = pluginStartProcessing,
            .stop_processing = pluginStopProcessing,
            .reset = pluginReset,
            .process = pluginProcess,
            .get_extension = pluginGetExtension,
            .on_main_thread = pluginOnMainThread,
        };
        self.host = host;
        self.shared = shared;
        self.eng = eng;
        self.settings = .{};
        self.sample_rate = 48000;
        self.active = false;
        self.processing = false;
        self.slot = null;
        self.loop = null;
        self.ping_state = std.atomic.Value(u8).init(@backingInt(audio.PingState.idle));
        self.loop_state = std.atomic.Value(u8).init(@backingInt(audio.LoopState.off));
        self.latency_dirty = std.atomic.Value(bool).init(false);
        self.host_params = null;
        self.host_latency = null;
        self.track = null;
        self.ticks = 0;
        self.traces_logged_in = false;
        self.traces_logged_out = false;
        self.midi_logged = 0;
        self.router = .{};
        self.scene_list = scene_list;
        self.strings = strings_mod.Strings.init(allocator);
        self.library = .{};
        self.save = .{};
        self.scene = std.atomic.Value(u8).init(0);
        self.scene_confirmed = 0;
        self.loop_flag_dirty = std.atomic.Value(bool).init(false);
        self.pending_scene = std.atomic.Value(u8).init(0);
        self.loop_state_logged = @backingInt(audio.LoopState.off);
        self.engine_events = .{};
        self.forward_events = .{};
        self.arena = .{};
        self.ui = .{};
        return self;
    }

    pub fn from(p: P) *Plugin {
        return @ptrCast(@alignCast(p.*.plugin_data.?));
    }

    // ---- the engine's output ----

    pub fn sink(self: *Plugin) engine.Sink {
        return .{ .ctx = self, .sysex = sinkSysex, .midi = sinkMidi, .param = sinkParam };
    }

    pub fn sinkSysex(ctx: *anyopaque, time: u32, bytes: []const u8) bool {
        const self: *Plugin = @ptrCast(@alignCast(ctx));
        const data = if (self.settings.sysex_bare.load(.monotonic)) roland.stripFraming(bytes) else bytes;
        const copy = self.arena.copy(data) orelse return false;
        return self.engine_events.push(.{ .time = time, .kind = .sysex, .sysex_ptr = copy.ptr, .sysex_len = @intCast(copy.len) });
    }

    pub fn sinkMidi(ctx: *anyopaque, time: u32, status: u8, d1: u8, d2: u8) bool {
        const self: *Plugin = @ptrCast(@alignCast(ctx));
        return self.engine_events.push(.{ .time = time, .kind = .midi, .midi = .{ status, d1, d2 } });
    }

    pub fn sinkParam(ctx: *anyopaque, time: u32, index: u32, value: u8, gesture: bool) void {
        const self: *Plugin = @ptrCast(@alignCast(ctx));
        if (gesture) _ = self.engine_events.push(.{ .time = time, .kind = .gesture_begin, .param_index = index });
        _ = self.engine_events.push(.{ .time = time, .kind = .param_value, .param_index = index, .value = @floatFromInt(value) });
        if (gesture) _ = self.engine_events.push(.{ .time = time, .kind = .gesture_end, .param_index = index });
    }

    // ---- the audio loop's settings ----

    /// Copies the loop's settings to the slot the audio device's hook reads.
    pub fn applyLoopSettings(self: *Plugin) void {
        const slot = self.slot orelse return;
        slot.out_channel.store(self.settings.out_channel.load(.monotonic), .monotonic);
        slot.in_channel.store(self.settings.in_channel.load(.monotonic), .monotonic);
    }

    /// The latency the plugin reports: the measured round trip while the loop
    /// is on, and none otherwise or after the sample rate changed.
    pub fn latencyFrames(self: *const Plugin) u32 {
        if (!self.settings.loop_enabled.load(.monotonic)) return 0;
        const rate = self.settings.latency_rate.load(.monotonic);
        if (rate == 0 or @as(f64, @floatFromInt(rate)) != self.sample_rate) return 0;
        return self.settings.latency_frames.load(.monotonic);
    }

    /// Tells the host to ask for the latency again. The host may only apply a
    /// new value while the plugin is deactivated, so it is asked to restart.
    pub fn requestLatencyUpdate(self: *Plugin) void {
        self.latency_dirty.store(true, .release);
        if (self.host.*.request_callback) |f| f(self.host);
    }

    /// Turns the audio loop on or off. Any thread may call it, the audio thread for one, when automation moves the
    /// parameter: it stores the setting and asks the host for the new latency, and leaves REAPER's track API to
    /// `syncLoopFlag`, which the main thread runs.
    pub fn setLoopEnabled(self: *Plugin, enabled: bool) void {
        if (self.settings.loop_enabled.swap(enabled, .monotonic) == enabled) return;
        self.loop_flag_dirty.store(true, .release);
        self.requestLatencyUpdate();
    }

    /// Sets the track's "no anticipative FX" flag to the loop's setting, when the setting has changed. Only the
    /// main thread calls it, because REAPER's track API is not for the audio thread.
    pub fn syncLoopFlag(self: *Plugin) void {
        if (!self.loop_flag_dirty.swap(false, .acq_rel)) return;
        if (self.track != null) glue.setNoAnticipativeFx(self.track, self.settings.loop_enabled.load(.monotonic));
    }

    pub fn startPing(self: *Plugin) void {
        if (self.loop) |loop| {
            loop.startPing();
            self.ping_state.store(@backingInt(audio.PingState.listening_noise), .release);
        }
    }

    // ---- presets ----

    /// Replaces the scene with a dump and has the engine recall it.
    pub fn loadScene(self: *Plugin, io: std.Io, scene: *const dump.Dump, name: []const u8, split_key: []const u8) void {
        self.shared.loadDesired(scene);
        self.settings.setPresetName(name);
        self.settings.setSplitKey(split_key);
        self.settings.split.store(patchSplits(io, split_key), .monotonic);
        _ = self.shared.scene_gen.fetchAdd(1, .release);
    }

    /// Loads a patch that is not one of the session's scenes (a registration, a preset, a tone of the library).
    /// Because the keyboard then plays something that no scene stands for, the Scene parameter goes to none, and the
    /// host is told, with the Split parameter, which the patch may have changed.
    pub fn loadPatch(self: *Plugin, io: std.Io, patch: *const dump.Dump, name: []const u8) void {
        self.loadScene(io, patch, name, name);
        self.setScene(0);
        self.rescanParamValues();
    }

    /// Writes the bytes that a dump knows (a tone's three, for one) and has the engine recall them, without
    /// touching the rest of the patch, its name or its split.
    pub fn mergeScene(self: *Plugin, scene: *const dump.Dump) void {
        self.shared.mergeDesired(scene);
        _ = self.shared.scene_gen.fetchAdd(1, .release);
    }

    /// Loads a registration's dump and writes it to the keyboard.
    pub fn loadRegistration(self: *Plugin, io: std.Io, file_name: []const u8) !void {
        const parsed = registrations.parseFileName(file_name) orelse return error.BadFileName;
        var folder_buf: [fileio.max_path]u8 = undefined;
        const folder = try state.registrationFolder(&folder_buf, glue.resourcePath());
        var path_buf: [fileio.max_path]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ folder, std.fs.path.sep, file_name });
        var name_buf: [96]u8 = undefined;
        try self.loadPresetFile(io, path, registrations.patchName(&name_buf, parsed));
        self.rescanParamValues();
    }

    /// Makes a position the current scene. Only the main thread calls it, so `scene_confirmed` is always a
    /// scene that exists, which `applyPendingScene` goes back to when the audio thread asked for one that does not.
    pub fn setScene(self: *Plugin, position: u8) void {
        self.scene.store(position, .monotonic);
        self.scene_confirmed = position;
    }

    /// Called from the audio thread, when automation asks for a scene: the loading is left to the main
    /// thread, which owns the list.
    pub fn requestScene(self: *Plugin, position: u8) void {
        self.scene.store(position, .monotonic);
        self.pending_scene.store(position, .release);
    }

    pub fn applyPendingScene(self: *Plugin, io: std.Io) void {
        const pending = self.pending_scene.swap(0, .acq_rel);
        if (pending == 0) return;
        self.selectScene(io, pending) catch |err| {
            log.warn("scene {d} could not be loaded: {s}", .{ pending, @errorName(err) });
            // Because `requestScene` showed the number before the list was asked, the number goes back to the
            // scene that is really loaded, and the same value can be asked for again once the scene exists.
            self.scene.store(self.scene_confirmed, .monotonic);
            self.rescanParamValues();
            return;
        };
        log.info("scene {d} loaded", .{pending});
    }

    /// Makes a scene the current one and has the engine recall its patch. Main thread only.
    pub fn selectScene(self: *Plugin, io: std.Io, position: u8) error{NoSuchScene}!void {
        const scene = self.scene_list.get(position) orelse return error.NoSuchScene;
        self.setScene(position);
        // A scene of the library remembers its split under the name of its patch, which is its label. The name is the
        // player's, and may have been changed.
        const key = if (scene.label().len > 0) scene.label() else scene.name();
        self.loadScene(io, &scene.patch, scene.name(), key);
        self.rescanParamValues();
    }

    pub const SaveError = error{ Busy, EmptyName, NameTooLong, NotConnected, QueueFull };

    /// Begins saving the keyboard as a preset: it reads the keyboard first, so that the preset holds the
    /// keyboard as it is and not what the plugin last knew. The file is written by `advanceSave`.
    pub fn startSave(self: *Plugin, io: std.Io, raw_name: []const u8) SaveError!void {
        if (self.save.state == .reading) return error.Busy;
        const trimmed = std.mem.trim(u8, raw_name, " ");
        if (trimmed.len > self.save.name.len) return error.NameTooLong;
        var clean: [96]u8 = undefined;
        if (state.sanitizeName(&clean, trimmed).len == 0) return error.EmptyName;
        if (!self.shared.connected.load(.acquire)) return error.NotConnected;
        const baseline = self.shared.captures_done.load(.acquire);
        if (!self.shared.sendCommand(.capture_keyboard)) return error.QueueFull;
        @memcpy(self.save.name[0..trimmed.len], trimmed);
        self.save.name[trimmed.len] = 0;
        self.save.baseline = baseline;
        self.save.started_ms = std.Io.Timestamp.now(io, .real).toMilliseconds();
        self.save.serial +%= 1;
        self.save.state = .reading;
    }

    /// Writes the preset once the read has ended. Called once per tick, on the main thread.
    pub fn advanceSave(self: *Plugin, io: std.Io) void {
        if (self.save.state != .reading) return;
        if (self.shared.captures_done.load(.acquire) == self.save.baseline) {
            if (std.Io.Timestamp.now(io, .real).toMilliseconds() - self.save.started_ms > save_timeout_ms) self.save.fail("the keyboard took too long to be read");
            return;
        }
        if (!self.shared.capture_answered.load(.monotonic)) return self.save.fail("the keyboard did not answer");
        if (!glue.ready) return self.save.fail("REAPER's API is not available");
        var folder_buf: [fileio.max_path]u8 = undefined;
        const folder = state.presetFolder(&folder_buf, glue.resourcePath()) catch return self.save.fail("the folder is too long");
        self.finishSave(io, folder);
    }

    /// Writes what the keyboard read gave, as the preset of the save, in `folder`.
    pub fn finishSave(self: *Plugin, io: std.Io, folder: []const u8) void {
        const patch = allocator.create(dump.Dump) catch return self.save.fail("out of memory");
        defer allocator.destroy(patch);
        self.shared.desiredSnapshot(patch);
        _ = dispatch.storePreset(io, self, folder, self.save.savedName(), patch, &self.save.file) catch |err| return self.save.fail(@errorName(err));
        self.save.known = patch.knownCount();
        self.save.state = .done;
    }

    /// Moves a scene, and the current scene with it. Fills `map` for the lane's points.
    pub fn moveScene(self: *Plugin, old_position: u8, new_position: u8, map: *scenes.Mapping) bool {
        const count = self.scene_list.count;
        if (!self.scene_list.move(old_position, new_position)) return false;
        scenes.moveMapping(count, old_position, new_position, map);
        self.followMapping(count, map);
        return true;
    }

    /// Removes a scene; the current scene follows it, or becomes none if it was the removed one.
    pub fn removeScene(self: *Plugin, position: u8, map: *scenes.Mapping) bool {
        const count = self.scene_list.count;
        if (!self.scene_list.remove(position)) return false;
        scenes.removeMapping(count, position, map);
        self.followMapping(count, map);
        return true;
    }

    pub fn followMapping(self: *Plugin, count: usize, map: *const scenes.Mapping) void {
        const current = self.scene.load(.monotonic);
        if (current >= 1 and current <= count) self.setScene(map[current - 1]);
        self.rescanParamValues();
    }

    /// Tells the host that the Scene and Split parameters changed
    /// without automation. Main thread only.
    pub fn rescanParamValues(self: *Plugin) void {
        if (self.host_params == null) return;
        if (self.host_params.*.rescan) |rescan| rescan(self.host, c.CLAP_PARAM_RESCAN_VALUES);
    }

    pub fn loadPresetFile(self: *Plugin, io: std.Io, path: []const u8, name: []const u8) !void {
        const scene = try allocator.create(dump.Dump);
        defer allocator.destroy(scene);
        scene.* = .{};
        try state.loadPresetFile(allocator, io, path, scene);
        self.loadPatch(io, scene, name);
    }

    // ---- once per timer tick, on the main thread ----

    pub fn tickMain(self: *Plugin, io: std.Io) void {
        self.ticks +%= 1;
        self.applyPendingScene(io);
        self.syncLoopFlag();
        self.advanceSave(io);
        self.logTraces();
        self.logLoopState();
        self.findTrack();
        self.connectKeyboard();
    }

    /// Writes a line when the audio loop changes state.
    pub fn logLoopState(self: *Plugin) void {
        if (self.slot) |slot| {
            if (self.ticks % 300 == 0 and self.loop_state.load(.monotonic) == @backingInt(audio.LoopState.running)) {
                const ticks = if (shared_bridge) |b| b.ticks.load(.monotonic) else 0;
                log.info("audio loop: {d} device callbacks, send underruns {d}, return overruns {d}", .{ ticks, slot.out_underruns.load(.monotonic), slot.in_overruns.load(.monotonic) });
            }
        }
        const current = self.loop_state.load(.monotonic);
        if (current == self.loop_state_logged) return;
        self.loop_state_logged = current;
        const state_value: audio.LoopState = @fromBackingInt(@intCast(current));
        log.info("audio loop: {s}", .{@tagName(state_value)});
    }

    /// Writes the first SysEx message each way to the log, once, because the
    /// audio thread must not log itself.
    pub fn logTraces(self: *Plugin) void {
        // The first few MIDI events, to learn how the host labels them.
        while (self.midi_logged < 24 and self.midi_logged < self.shared.midi_log_count.load(.acquire)) : (self.midi_logged += 1) {
            const r = self.shared.midiRecord(self.midi_logged) orelse continue;
            log.info("MIDI event {d}: flags {x} port {d} data {x:0>2} {x:0>2} {x:0>2} time {d}", .{ self.midi_logged, r.flags, r.port, r.status, r.d1, r.d2, r.time });
        }
        if (!self.traces_logged_in and self.shared.trace_in.length.load(.acquire) != 0) {
            self.traces_logged_in = true;
            var buf: [128]u8 = undefined;
            log.info("first SysEx from the host: {s}", .{self.shared.trace_in.format(&buf)});
        }
        if (!self.traces_logged_out and self.shared.trace_out.length.load(.acquire) != 0) {
            self.traces_logged_out = true;
            var buf: [128]u8 = undefined;
            log.info("first SysEx accepted by the host: {s}", .{self.shared.trace_out.format(&buf)});
        }
    }

    /// REAPER attaches the plugin to its track after creating it, so the track
    /// is not known in `init`; it is looked up from the timer until it is.
    pub fn findTrack(self: *Plugin) void {
        if (self.track != null or !glue.ready or self.ticks % 15 != 1) return;
        self.track = glue.trackOf(self.host);
        if (self.track != null) {
            log.info("found the track after {d} ticks", .{self.ticks});
            if (self.settings.loop_enabled.load(.monotonic)) glue.setNoAnticipativeFx(self.track, true);
        }
    }

    /// Chooses the keyboard as the track's MIDI hardware output, once, when
    /// the track has none, and arms the track so that the keyboard's replies
    /// reach the plugin. Because the project may still be loading the
    /// track's routing in the first moments, it waits about a second, and it
    /// never overrides an output the user (or the project) already set.
    pub fn connectKeyboard(self: *Plugin) void {
        if (self.track == null or !glue.ready) return;
        if (self.settings.autoconnect_done.load(.monotonic)) return;
        if (self.ticks < 30 or self.ticks % 60 != 0) return;
        if (glue.trackMidiOutput(self.track) != null) {
            self.settings.autoconnect_done.store(true, .monotonic);
            return;
        }
        if (glue.findKeyboard(.output)) |dev| {
            glue.setTrackMidiOutput(self.track, dev);
            self.settings.autoconnect_done.store(true, .monotonic);
            log.info("MIDI output set to device {d}", .{dev});
            // REAPER only hands the keyboard's replies to the plugin while the
            // track is armed and monitors its input. The plugin drops the
            // notes by default, so this cannot make the keyboard sound them
            // twice.
            if (!glue.trackArmed(self.track)) {
                glue.setTrackArmed(self.track, true);
                log.info("the track is armed", .{});
            }
            if (glue.trackMonitoring(self.track) == 0) {
                glue.setTrackMonitoring(self.track, 1);
                log.info("input monitoring turned on for the track", .{});
            }
        }
    }
};

pub const descriptor = blk: {
    const features = [_:null]?[*:0]const u8{
        c.CLAP_PLUGIN_FEATURE_AUDIO_EFFECT,
        c.CLAP_PLUGIN_FEATURE_UTILITY,
        c.CLAP_PLUGIN_FEATURE_STEREO,
        null,
    };
    break :blk c.clap_plugin_descriptor_t{
        .clap_version = .{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
        .id = plugin_id,
        .name = "VR-09",
        .vendor = "Perken",
        .url = "",
        .manual_url = "",
        .support_url = "",
        .version = build_options.version.ptr,
        .description = "Control, patch manager and audio insert for the Roland VR-09",
        .features = &features,
    };
};

// ---- the plugin callbacks ----

fn pluginInit(p: P) callconv(.c) bool {
    const self = Plugin.from(p);
    const in_reaper = glue.init(self.host);
    self.track = glue.trackOf(self.host);
    log.info("version {s} created: REAPER API {s}, track {s}", .{ build_options.version, if (in_reaper) "ready" else "not available", if (self.track != null) "found" else "not found" });
    if (self.host.*.get_extension) |get_ext| {
        self.host_params = @ptrCast(@alignCast(get_ext(self.host, &c.CLAP_EXT_PARAMS)));
        self.host_latency = @ptrCast(@alignCast(get_ext(self.host, &c.CLAP_EXT_LATENCY)));
    }
    for (&instances) |*slot| {
        if (slot.* == null) {
            slot.* = self;
            break;
        }
    }
    if (!timer_registered and glue.ready) {
        glue.registerTimer(onTimer);
        timer_registered = true;
    }
    debug_api.register();
    actions.register();
    return true;
}

fn pluginDestroy(p: P) callconv(.c) void {
    const self = Plugin.from(p);
    ui.close(self);
    for (&instances) |*slot| {
        if (slot.* == self) slot.* = null;
    }
    if (self.slot) |slot| {
        if (shared_bridge) |b| b.release(slot);
    }
    if (self.loop) |l| allocator.destroy(l);
    self.library.deinit(allocator);
    self.strings.deinit();
    allocator.destroy(self.scene_list);
    allocator.destroy(self.eng);
    allocator.destroy(self.shared);
    allocator.destroy(self);
}

fn pluginActivate(p: P, sample_rate: f64, min_frames: u32, max_frames: u32) callconv(.c) bool {
    _ = min_frames;
    _ = max_frames;
    const self = Plugin.from(p);
    self.sample_rate = sample_rate;
    self.eng.setSampleRate(sample_rate);
    if (glue.ready and self.slot == null) {
        if (shared_bridge == null) shared_bridge = audio.Bridge.create(allocator) catch null;
        if (shared_bridge) |b| {
            self.slot = b.claim();
            if (self.slot) |slot| {
                self.loop = allocator.create(audio.Loop) catch null;
                if (self.loop) |l| l.* = audio.Loop.init(b, slot);
                glue.registerHook(b);
            }
        }
    }
    self.applyLoopSettings();
    self.active = true;
    log.info("activated at {d} Hz, audio loop slot {s}", .{ sample_rate, if (self.slot != null) "claimed" else "not available" });
    return true;
}

fn pluginDeactivate(p: P) callconv(.c) void {
    const self = Plugin.from(p);
    self.active = false;
    if (self.slot) |slot| {
        slot.active.store(false, .release);
        if (shared_bridge) |b| b.release(slot);
        self.slot = null;
    }
    if (self.loop) |l| {
        allocator.destroy(l);
        self.loop = null;
    }
}

fn pluginStartProcessing(p: P) callconv(.c) bool {
    Plugin.from(p).processing = true;
    log.info("start processing", .{});
    return true;
}

fn pluginStopProcessing(p: P) callconv(.c) void {
    Plugin.from(p).processing = false;
}

fn pluginReset(p: P) callconv(.c) void {
    _ = p;
}

fn pluginOnMainThread(p: P) callconv(.c) void {
    const self = Plugin.from(p);
    if (!self.latency_dirty.swap(false, .acq_rel)) return;
    if (self.host_latency != null) {
        if (self.host_latency.*.changed) |changed| changed(self.host);
    }
    if (self.active) {
        if (self.host.*.request_restart) |restart| restart(self.host);
    }
}

fn isKeyboardMessage(bytes: []const u8) bool {
    const body = roland.stripFraming(bytes);
    if (body.len < 2) return false;
    if (body[0] == roland.roland_id) return true;
    // A universal non-realtime message has its sub-ID in the third byte, so a shorter one cannot be the reply.
    return body.len >= 3 and body[0] == 0x7E and body[2] == 0x06;
}

fn pluginProcess(p: P, proc: [*c]const c.clap_process_t) callconv(.c) c.clap_process_status {
    const self = Plugin.from(p);
    const frames = proc.*.frames_count;
    self.engine_events.clear();
    self.forward_events.clear();
    self.arena.reset();
    const sink = self.sink();

    const in_events = proc.*.in_events;
    const count = in_events.*.size.?(in_events);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const ev_header = in_events.*.get.?(in_events, i);
        handleInput(self, ev_header, sink);
    }

    self.eng.run(frames, sink);
    processAudio(self, proc);
    emitEvents(self, proc.*.out_events);
    return c.CLAP_PROCESS_CONTINUE;
}

fn handleInput(self: *Plugin, ev_header: [*c]const c.clap_event_header_t, sink: engine.Sink) void {
    if (ev_header.*.space_id != c.CLAP_CORE_EVENT_SPACE_ID) return;
    const time = ev_header.*.time;
    switch (ev_header.*.type) {
        c.CLAP_EVENT_PARAM_VALUE => {
            const ev: *const c.clap_event_param_value_t = @ptrCast(@alignCast(ev_header));
            if (engine.paramIndexOfId(ev.param_id)) |index| {
                self.eng.onHostParam(index, ev.value, sink, time);
            } else if (extraIndexOfId(ev.param_id)) |extra| {
                applyExtra(self, extra, ev.value);
            }
        },
        c.CLAP_EVENT_MIDI_SYSEX => {
            const ev: *const c.clap_event_midi_sysex_t = @ptrCast(@alignCast(ev_header));
            if (ev.buffer == null or ev.size == 0) return;
            const bytes = ev.buffer[0..ev.size];
            _ = self.shared.host_sysex_in.fetchAdd(1, .monotonic);
            self.shared.trace_in.capture(bytes);
            if (isKeyboardMessage(bytes)) {
                self.eng.onSysex(bytes);
            } else if (self.settings.pass_midi.load(.monotonic)) {
                _ = self.forward_events.push(.{ .time = time, .kind = .sysex, .sysex_ptr = ev.buffer, .sysex_len = ev.size });
            }
        },
        c.CLAP_EVENT_MIDI => {
            const ev: *const c.clap_event_midi_t = @ptrCast(@alignCast(ev_header));
            self.shared.recordMidi(.{ .flags = @truncate(ev_header.*.flags), .port = ev.port_index, .status = ev.data[0], .d1 = ev.data[1], .d2 = ev.data[2], .time = @truncate(time) });
            // Realtime messages (clock, active sensing) are not for the
            // keyboard's input; the unit sends them constantly.
            if (ev.data[0] >= 0xF8) return;
            // The host does not mark live input (its events carry no flags),
            // so the notes cannot be told from the track's own playback.
            // They pass only when the user asked for it.
            if (!self.settings.pass_midi.load(.monotonic)) {
                _ = self.shared.midi_dropped.fetchAdd(1, .monotonic);
                return;
            }
            var out: [2][3]u8 = undefined;
            const n = self.router.route(self.settings.split.load(.monotonic), .{ ev.data[0], ev.data[1], ev.data[2] }, &out);
            for (out[0..n]) |m| _ = self.forward_events.push(.{ .time = time, .kind = .midi, .midi = m });
        },
        else => {},
    }
}

/// Whether the patch is in the list of split patches.
pub fn patchSplits(io: std.Io, name: []const u8) bool {
    if (!glue.ready) return false;
    var buf: [1024]u8 = undefined;
    const path = state.splitsPath(&buf, glue.resourcePath()) catch return false;
    return split.isSplit(allocator, io, path, name);
}

/// Sets the current patch's split and remembers it for that patch.
pub fn setPatchSplit(self: *Plugin, io: std.Io, on: bool) void {
    self.settings.split.store(on, .monotonic);
    self.rescanParamValues();
    if (!glue.ready) return;
    var buf: [1024]u8 = undefined;
    const path = state.splitsPath(&buf, glue.resourcePath()) catch return;
    split.setSplit(allocator, io, path, self.settings.splitKey(), on) catch |err| log.warn("could not save the split list: {s}", .{@errorName(err)});
}

/// A parameter of the plugin itself changed, from automation.
pub fn applyExtra(self: *Plugin, extra: usize, value: f64) void {
    switch (extra) {
        0 => self.setLoopEnabled(value >= 0.5),
        1 => self.settings.setSendDb(@floatCast(value)),
        2 => self.settings.setReturnDb(@floatCast(value)),
        // Automation sends its value again while it holds still; only a new
        // value loads a scene.
        extra_scene => {
            const v: u8 = @intFromFloat(std.math.clamp(@round(value), 0, scenes.max_scenes));
            if (v != 0 and v != self.scene.load(.monotonic)) self.requestScene(v);
        },
        // Automation overrides the split for the moment; only the Patches
        // tab remembers it for the patch.
        extra_split => self.settings.split.store(value >= 0.5, .monotonic),
        else => {},
    }
}

fn processAudio(self: *Plugin, proc: [*c]const c.clap_process_t) void {
    if (proc.*.audio_inputs_count < 1 or proc.*.audio_outputs_count < 1) return;
    const in_buf = &proc.*.audio_inputs[0];
    const out_buf = &proc.*.audio_outputs[0];
    const frames = proc.*.frames_count;
    if (in_buf.channel_count < 2 or out_buf.channel_count < 2) return;
    const in32 = in_buf.data32 orelse return;
    const out32 = out_buf.data32 orelse return;
    const in_l = in32[0][0..frames];
    const in_r = in32[1][0..frames];
    const out_l = out32[0][0..frames];
    const out_r = out32[1][0..frames];

    const loop = self.loop orelse {
        if (out_l.ptr != in_l.ptr) @memcpy(out_l, in_l);
        if (out_r.ptr != in_r.ptr) @memcpy(out_r, in_r);
        return;
    };
    loop.send_gain = state.dbToGain(self.settings.sendDb());
    loop.return_gain = state.dbToGain(self.settings.returnDb());
    loop.process(self.settings.loop_enabled.load(.monotonic), in_l, in_r, out_l, out_r);
    self.loop_state.store(@backingInt(loop.state), .monotonic);

    const previous = self.ping_state.load(.acquire);
    const current = @backingInt(loop.ping.state);
    if (current != previous) {
        self.ping_state.store(current, .release);
        if (loop.ping.state == .done) {
            self.settings.latency_frames.store(loop.ping.latency, .monotonic);
            self.settings.latency_rate.store(@intFromFloat(self.sample_rate), .monotonic);
            self.requestLatencyUpdate();
        }
    }
}

fn emitEvents(self: *Plugin, out: [*c]const c.clap_output_events_t) void {
    const push = out.*.try_push orelse return;
    var merge = outbuf.Merge{ .a = self.forward_events.slice(), .b = self.engine_events.slice() };
    while (merge.next()) |e| {
        switch (e.kind) {
            .midi => {
                var ev = c.clap_event_midi_t{
                    .header = eventHeader(@sizeOf(c.clap_event_midi_t), e.time, c.CLAP_EVENT_MIDI),
                    .port_index = 0,
                    .data = e.midi,
                };
                _ = push(out, &ev.header);
            },
            .sysex => {
                var ev = c.clap_event_midi_sysex_t{
                    .header = eventHeader(@sizeOf(c.clap_event_midi_sysex_t), e.time, c.CLAP_EVENT_MIDI_SYSEX),
                    .port_index = 0,
                    .buffer = e.sysex_ptr,
                    .size = e.sysex_len,
                };
                if (push(out, &ev.header)) {
                    _ = self.shared.host_sysex_out.fetchAdd(1, .monotonic);
                    self.shared.trace_out.capture(e.sysex_ptr.?[0..e.sysex_len]);
                } else {
                    _ = self.shared.host_sysex_refused.fetchAdd(1, .monotonic);
                }
            },
            .param_value => {
                var ev = c.clap_event_param_value_t{
                    .header = eventHeader(@sizeOf(c.clap_event_param_value_t), e.time, c.CLAP_EVENT_PARAM_VALUE),
                    .param_id = engine.param_ids[e.param_index],
                    .cookie = null,
                    .note_id = -1,
                    .port_index = -1,
                    .channel = -1,
                    .key = -1,
                    .value = e.value,
                };
                _ = push(out, &ev.header);
            },
            .gesture_begin, .gesture_end => {
                var ev = c.clap_event_param_gesture_t{
                    .header = eventHeader(@sizeOf(c.clap_event_param_gesture_t), e.time, if (e.kind == .gesture_begin) c.CLAP_EVENT_PARAM_GESTURE_BEGIN else c.CLAP_EVENT_PARAM_GESTURE_END),
                    .param_id = engine.param_ids[e.param_index],
                };
                _ = push(out, &ev.header);
            },
        }
    }
}

fn eventHeader(size: usize, time: u32, event_type: u16) c.clap_event_header_t {
    return .{
        .size = @intCast(size),
        .time = time,
        .space_id = c.CLAP_CORE_EVENT_SPACE_ID,
        .type = event_type,
        .flags = 0,
    };
}

// ---- extensions ----

const audio_ports_ext = c.clap_plugin_audio_ports_t{ .count = audioPortsCount, .get = audioPortsGet };
const note_ports_ext = c.clap_plugin_note_ports_t{ .count = notePortsCount, .get = notePortsGet };
const params_ext = c.clap_plugin_params_t{
    .count = paramsCount,
    .get_info = paramsGetInfo,
    .get_value = paramsGetValue,
    .value_to_text = paramsValueToText,
    .text_to_value = paramsTextToValue,
    .flush = paramsFlush,
};
const latency_ext = c.clap_plugin_latency_t{ .get = latencyGet };
const state_ext = c.clap_plugin_state_t{ .save = stateSave, .load = stateLoad };
const preset_load_ext = c.clap_plugin_preset_load_t{ .from_location = presetFromLocation };
const gui_ext = c.clap_plugin_gui_t{
    .is_api_supported = guiIsApiSupported,
    .get_preferred_api = guiGetPreferredApi,
    .create = guiCreate,
    .destroy = guiDestroy,
    .set_scale = guiSetScale,
    .get_size = guiGetSize,
    .can_resize = guiCanResize,
    .get_resize_hints = guiGetResizeHints,
    .adjust_size = guiAdjustSize,
    .set_size = guiSetSize,
    .set_parent = guiSetParent,
    .set_transient = guiSetTransient,
    .suggest_title = guiSuggestTitle,
    .show = guiShow,
    .hide = guiHide,
};

fn pluginGetExtension(p: P, id: [*c]const u8) callconv(.c) ?*const anyopaque {
    _ = p;
    const name = std.mem.span(id);
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_AUDIO_PORTS))) return &audio_ports_ext;
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_NOTE_PORTS))) return &note_ports_ext;
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_PARAMS))) return &params_ext;
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_LATENCY))) return &latency_ext;
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_STATE))) return &state_ext;
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_GUI))) return &gui_ext;
    if (std.mem.eql(u8, name, clap.s(c.CLAP_EXT_PRESET_LOAD)) or std.mem.eql(u8, name, clap.s(c.CLAP_EXT_PRESET_LOAD_COMPAT))) return &preset_load_ext;
    return null;
}

fn audioPortsCount(p: P, is_input: bool) callconv(.c) u32 {
    _ = p;
    _ = is_input;
    return 1;
}

fn audioPortsGet(p: P, index: u32, is_input: bool, info: [*c]c.clap_audio_port_info_t) callconv(.c) bool {
    _ = p;
    _ = is_input;
    if (index != 0) return false;
    info.*.id = 0;
    clap.copyInto(&info.*.name, "Audio");
    info.*.flags = c.CLAP_AUDIO_PORT_IS_MAIN;
    info.*.channel_count = 2;
    info.*.port_type = &c.CLAP_PORT_STEREO;
    info.*.in_place_pair = c.CLAP_INVALID_ID;
    return true;
}

fn notePortsCount(p: P, is_input: bool) callconv(.c) u32 {
    _ = p;
    _ = is_input;
    return 1;
}

fn notePortsGet(p: P, index: u32, is_input: bool, info: [*c]c.clap_note_port_info_t) callconv(.c) bool {
    _ = p;
    if (index != 0) return false;
    info.*.id = 0;
    info.*.supported_dialects = c.CLAP_NOTE_DIALECT_MIDI;
    info.*.preferred_dialect = c.CLAP_NOTE_DIALECT_MIDI;
    clap.copyInto(&info.*.name, if (is_input) "Keyboard in" else "Keyboard out");
    return true;
}

fn paramsCount(p: P) callconv(.c) u32 {
    _ = p;
    return total_params;
}

fn paramsGetInfo(p: P, index: u32, info: [*c]c.clap_param_info_t) callconv(.c) bool {
    _ = p;
    if (index >= total_params) return false;
    info.*.cookie = null;
    if (index < engine.param_count) {
        const param = catalog.params[index];
        info.*.id = engine.param_ids[index];
        info.*.flags = c.CLAP_PARAM_IS_STEPPED | c.CLAP_PARAM_IS_AUTOMATABLE;
        clap.copyInto(&info.*.name, param.label);
        clap.copyInto(&info.*.module, param.group);
        info.*.min_value = @floatFromInt(param.low);
        info.*.max_value = @floatFromInt(param.high);
        info.*.default_value = @floatFromInt(param.low);
        return true;
    }
    const extra = extras[index - engine.param_count];
    info.*.id = extraId(index - engine.param_count);
    info.*.flags = @as(u32, @intCast(c.CLAP_PARAM_IS_AUTOMATABLE)) | (if (extra.stepped) @as(u32, @intCast(c.CLAP_PARAM_IS_STEPPED)) else 0);
    clap.copyInto(&info.*.name, extra.name);
    clap.copyInto(&info.*.module, extra.module);
    info.*.min_value = extra.min;
    info.*.max_value = extra.max;
    info.*.default_value = extra.default;
    return true;
}

fn paramsGetValue(p: P, id: c.clap_id, out: [*c]f64) callconv(.c) bool {
    const self = Plugin.from(p);
    if (engine.paramIndexOfId(id)) |index| {
        out.* = @floatFromInt(self.shared.paramValue(index));
        return true;
    }
    if (extraIndexOfId(id)) |extra| {
        out.* = switch (extra) {
            0 => if (self.settings.loop_enabled.load(.monotonic)) 1 else 0,
            1 => self.settings.sendDb(),
            2 => self.settings.returnDb(),
            extra_scene => @floatFromInt(self.scene.load(.monotonic)),
            else => if (self.settings.split.load(.monotonic)) 1 else 0,
        };
        return true;
    }
    return false;
}

fn paramsValueToText(p: P, id: c.clap_id, value: f64, out: [*c]u8, capacity: u32) callconv(.c) bool {
    const self = Plugin.from(p);
    const buf = out[0..capacity];
    if (engine.paramIndexOfId(id)) |index| {
        const text = engine.valueText(buf, catalog.params[index], value) orelse return false;
        _ = text;
        return true;
    }
    if (extraIndexOfId(id)) |extra| {
        switch (extra) {
            0, extra_split => _ = std.mem.printSentinel(buf, "{s}", .{if (value >= 0.5) "On" else "Off"}, 0) catch return false,
            extra_scene => {
                const v: u8 = @intFromFloat(std.math.clamp(@round(value), 0, scenes.max_scenes));
                if (v == 0) {
                    _ = std.mem.printSentinel(buf, "None", .{}, 0) catch return false;
                } else if (self.scene_list.get(v)) |scene| {
                    _ = std.mem.printSentinel(buf, "{d} {s}", .{ v, scene.name() }, 0) catch return false;
                } else {
                    _ = std.mem.printSentinel(buf, "{d} (empty)", .{v}, 0) catch return false;
                }
            },
            else => _ = std.mem.printSentinel(buf, "{d:.1} dB", .{value}, 0) catch return false,
        }
        return true;
    }
    return false;
}

fn paramsTextToValue(p: P, id: c.clap_id, text: [*c]const u8, out: [*c]f64) callconv(.c) bool {
    _ = p;
    _ = id;
    const s = std.mem.trim(u8, std.mem.span(text), " ");
    if (std.ascii.eqlIgnoreCase(s, "on")) {
        out.* = 1;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(s, "off")) {
        out.* = 0;
        return true;
    }
    var end: usize = 0;
    while (end < s.len and (std.ascii.isDigit(s[end]) or s[end] == '.' or s[end] == '-')) end += 1;
    out.* = std.fmt.parseFloat(f64, s[0..end]) catch return false;
    return true;
}

/// Parameter changes that arrive while the plugin is not processing: they are
/// stored, and a recall is queued for when processing resumes.
fn paramsFlush(p: P, in_events: [*c]const c.clap_input_events_t, out_events: [*c]const c.clap_output_events_t) callconv(.c) void {
    _ = out_events;
    const self = Plugin.from(p);
    if (self.processing) return;
    const count = in_events.*.size.?(in_events);
    var i: u32 = 0;
    var changed = false;
    while (i < count) : (i += 1) {
        const header_ptr = in_events.*.get.?(in_events, i);
        if (header_ptr.*.space_id != c.CLAP_CORE_EVENT_SPACE_ID or header_ptr.*.type != c.CLAP_EVENT_PARAM_VALUE) continue;
        const ev: *const c.clap_event_param_value_t = @ptrCast(@alignCast(header_ptr));
        if (engine.paramIndexOfId(ev.param_id)) |index| {
            const param = catalog.params[index];
            const value = engine.clampValue(param, ev.value);
            switch (param.kind) {
                .dt1 => _ = self.shared.setDesired(.kb, param.address, value),
                .cc => self.shared.cc_values[index].store(value, .monotonic),
            }
            changed = true;
        } else if (extraIndexOfId(ev.param_id)) |extra| {
            applyExtra(self, extra, ev.value);
        }
    }
    if (changed) _ = self.shared.scene_gen.fetchAdd(1, .release);
}

fn latencyGet(p: P) callconv(.c) u32 {
    return Plugin.from(p).latencyFrames();
}

fn stateSave(p: P, stream: [*c]const c.clap_ostream_t) callconv(.c) bool {
    const self = Plugin.from(p);
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    state.write(&buf.writer, self.shared, &self.settings, self.scene_list) catch return false;
    const write = stream.*.write orelse return false;
    var done: usize = 0;
    while (done < buf.written().len) {
        const n = write(stream, buf.written()[done..].ptr, buf.written().len - done);
        if (n <= 0) return false;
        done += @intCast(n);
    }
    return true;
}

fn stateLoad(p: P, stream: [*c]const c.clap_istream_t) callconv(.c) bool {
    const self = Plugin.from(p);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    const read = stream.*.read orelse return false;
    var chunk: [4096]u8 = undefined;
    while (true) {
        const n = read(stream, &chunk, chunk.len);
        if (n < 0) return false;
        if (n == 0) break;
        buf.appendSlice(allocator, chunk[0..@intCast(n)]) catch return false;
    }
    var reader: std.Io.Reader = .fixed(buf.items);
    state.read(&reader, self.shared, &self.settings, self.scene_list) catch |err| {
        log.warn("the saved state could not be read: {s}", .{@errorName(err)});
        return false;
    };
    self.applyLoopSettings();
    // Because the scenes that were read replace the list, the Scene parameter that pointed into the old one
    // goes to none.
    self.setScene(0);
    self.rescanParamValues();
    return true;
}

fn presetFromLocation(p: P, kind: u32, location: [*c]const u8, load_key: [*c]const u8) callconv(.c) bool {
    const io = hostIo();
    _ = load_key;
    if (kind != c.CLAP_PRESET_DISCOVERY_LOCATION_FILE) return false;
    const self = Plugin.from(p);
    const path = std.mem.span(location);
    const base = std.fs.path.basename(path);
    self.loadPresetFile(io, path, state.displayName(base)) catch |err| {
        log.warn("preset {s} could not be loaded: {s}", .{ path, @errorName(err) });
        return false;
    };
    return true;
}

fn guiIsApiSupported(p: P, api: [*c]const u8, is_floating: bool) callconv(.c) bool {
    _ = p;
    log.info("gui api asked: {s}, floating {}", .{ std.mem.span(api), is_floating });
    return std.mem.eql(u8, std.mem.span(api), platformApi());
}

fn platformApi() []const u8 {
    return switch (@import("builtin").os.tag) {
        .macos => clap.s(c.CLAP_WINDOW_API_COCOA),
        .windows => clap.s(c.CLAP_WINDOW_API_WIN32),
        else => clap.s(c.CLAP_WINDOW_API_X11),
    };
}

fn guiGetPreferredApi(p: P, api: [*c][*c]const u8, is_floating: [*c]bool) callconv(.c) bool {
    _ = p;
    api.* = switch (@import("builtin").os.tag) {
        .macos => &c.CLAP_WINDOW_API_COCOA,
        .windows => &c.CLAP_WINDOW_API_WIN32,
        else => &c.CLAP_WINDOW_API_X11,
    };
    is_floating.* = true;
    return true;
}

fn guiCreate(p: P, api: [*c]const u8, is_floating: bool) callconv(.c) bool {
    _ = p;
    log.info("gui create: api {s}, floating {}", .{ std.mem.span(api), is_floating });
    return std.mem.eql(u8, std.mem.span(api), platformApi());
}

fn guiDestroy(p: P) callconv(.c) void {
    const self = Plugin.from(p);
    log.info("gui destroy (tick {d}, panel open {})", .{ self.ticks, self.ui.open });
    ui.close(self);
}

fn guiSetScale(p: P, scale: f64) callconv(.c) bool {
    _ = p;
    _ = scale;
    return false;
}

fn guiGetSize(p: P, width: [*c]u32, height: [*c]u32) callconv(.c) bool {
    _ = p;
    width.* = embedded_width;
    height.* = embedded_height;
    return true;
}

fn guiCanResize(p: P) callconv(.c) bool {
    _ = p;
    return false;
}

fn guiGetResizeHints(p: P, hints: [*c]c.clap_gui_resize_hints_t) callconv(.c) bool {
    _ = p;
    _ = hints;
    return false;
}

fn guiAdjustSize(p: P, width: [*c]u32, height: [*c]u32) callconv(.c) bool {
    _ = p;
    width.* = embedded_width;
    height.* = embedded_height;
    return true;
}

fn guiSetSize(p: P, width: u32, height: u32) callconv(.c) bool {
    _ = p;
    _ = width;
    _ = height;
    return true;
}

fn guiSetParent(p: P, window: [*c]const c.clap_window_t) callconv(.c) bool {
    _ = window;
    log.info("gui set_parent (tick {d})", .{Plugin.from(p).ticks});
    return true;
}

fn guiSetTransient(p: P, window: [*c]const c.clap_window_t) callconv(.c) bool {
    _ = p;
    _ = window;
    return true;
}

fn guiSuggestTitle(p: P, title: [*c]const u8) callconv(.c) void {
    _ = p;
    _ = title;
}

fn guiShow(p: P) callconv(.c) bool {
    const self = Plugin.from(p);
    log.info("gui show (tick {d}, panel open {})", .{ self.ticks, self.ui.open });
    ui.open(self);
    return true;
}

fn guiHide(p: P) callconv(.c) bool {
    const self = Plugin.from(p);
    log.info("gui hide (tick {d}, panel open {})", .{ self.ticks, self.ui.open });
    ui.close(self);
    return true;
}

// ---- REAPER's timer ----

/// Runs on REAPER's main thread about thirty times a second.
pub fn onTimer() callconv(.c) void {
    const io = hostIo();
    for (instances) |maybe| {
        const self = maybe orelse continue;
        self.tickMain(io);
    }
    ui.drawAll(io);
}

/// Called when the library unloads.
pub fn shutdown() void {
    if (timer_registered) {
        glue.unregisterTimer(onTimer);
        timer_registered = false;
    }
    glue.unregisterHook();
    debug_api.unregister();
    actions.unregister();
    ui.shutdown();
    if (shared_bridge) |b| {
        allocator.destroy(b);
        shared_bridge = null;
    }
}

test "a short universal message is not taken for the keyboard's reply" {
    try std.testing.expect(!isKeyboardMessage(&.{ 0xF0, 0x7E, 0x7F, 0xF7 }));
    try std.testing.expect(!isKeyboardMessage(&.{ 0xF0, 0x7E, 0xF7 }));
    try std.testing.expect(isKeyboardMessage(&.{ 0xF0, 0x7E, 0x7F, 0x06, 0x02, 0xF7 }));
    try std.testing.expect(isKeyboardMessage(&.{ 0xF0, 0x41, 0x10, 0xF7 }));
}
