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
const debug_api = @import("debug_api.zig");
const split = @import("split.zig");
const registrations = @import("registrations.zig");
const fileio = @import("fileio.zig");

const log = std.log.scoped(.plugin);

pub const plugin_id = "com.perken.vr09";
const P = [*c]const c.clap_plugin_t;

pub const allocator = std.heap.c_allocator;

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
    // 0 is no registration, n is program n - 1 (see registrations.programOf).
    .{ .id = "patch", .name = "Registration", .module = "Patches", .min = 0, .max = 128, .default = 0, .stepped = true },
    .{ .id = "split", .name = "Split at middle C", .module = "Patches", .min = 0, .max = 1, .default = 0, .stepped = true },
};

const extra_patch = 3;
const extra_split = 4;

/// A Program Change on this channel (16, the keyboard's control channel in
/// MIDI IN Mode 2, where the keyboard ignores it) selects a registration; it
/// is not passed on.
pub const program_channel: u8 = 15;

pub const total_params = engine.param_count + extras.len;

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
pub var instances: [max_instances]?*Plugin = [_]?*Plugin{null} ** max_instances;
pub var shared_bridge: ?*audio.Bridge = null;
var timer_registered: bool = false;

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

    // Registrations selected by Program Change or automation. Both hold a
    // program number plus one, zero meaning none.
    program: std.atomic.Value(u8),
    pending_program: std.atomic.Value(u8),
    /// Whether each program's registration splits, so that the audio thread
    /// routes the notes after a Program Change at once, before the main
    /// thread loads the registration.
    program_splits: [128]std.atomic.Value(bool),
    programs_scanned: bool,

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
        self.ping_state = std.atomic.Value(u8).init(@intFromEnum(audio.PingState.idle));
        self.loop_state = std.atomic.Value(u8).init(@intFromEnum(audio.LoopState.off));
        self.latency_dirty = std.atomic.Value(bool).init(false);
        self.host_params = null;
        self.host_latency = null;
        self.track = null;
        self.ticks = 0;
        self.traces_logged_in = false;
        self.traces_logged_out = false;
        self.midi_logged = 0;
        self.router = .{};
        self.program = std.atomic.Value(u8).init(0);
        self.pending_program = std.atomic.Value(u8).init(0);
        self.program_splits = [_]std.atomic.Value(bool){std.atomic.Value(bool).init(false)} ** 128;
        self.programs_scanned = false;
        self.loop_state_logged = @intFromEnum(audio.LoopState.off);
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

    pub fn setLoopEnabled(self: *Plugin, enabled: bool) void {
        if (self.settings.loop_enabled.swap(enabled, .monotonic) == enabled) return;
        if (self.track != null) glue.setNoAnticipativeFx(self.track, enabled);
        self.requestLatencyUpdate();
    }

    pub fn startPing(self: *Plugin) void {
        if (self.loop) |loop| {
            loop.startPing();
            self.ping_state.store(@intFromEnum(audio.PingState.listening_noise), .release);
        }
    }

    // ---- presets ----

    /// Replaces the scene with a dump and has the engine recall it.
    pub fn loadScene(self: *Plugin, scene: *const dump.Dump, name: []const u8) void {
        self.shared.loadDesired(scene);
        self.settings.setPresetName(name);
        self.settings.split.store(patchSplits(name), .monotonic);
        self.program.store(0, .monotonic);
        _ = self.shared.scene_gen.fetchAdd(1, .release);
    }

    /// Loads a registration's dump and writes it to the keyboard.
    pub fn loadRegistration(self: *Plugin, entry: registrations.Entry) !void {
        var folder_buf: [fileio.max_path]u8 = undefined;
        const folder = try state.registrationFolder(&folder_buf, glue.resourcePath());
        var path_buf: [fileio.max_path]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ folder, std.fs.path.sep, entry.file_name });
        var name_buf: [96]u8 = undefined;
        try self.loadPresetFile(path, registrations.patchName(&name_buf, entry));
        const program = registrations.programOf(entry.bank, entry.slot);
        self.program.store(if (program) |n| @as(u8, n) + 1 else 0, .monotonic);
        self.rescanParamValues();
    }

    /// Loads the registration a program number selects.
    pub fn loadProgram(self: *Plugin, program: u7) !void {
        var folder_buf: [fileio.max_path]u8 = undefined;
        const folder = try state.registrationFolder(&folder_buf, glue.resourcePath());
        var lib = try registrations.scan(allocator, folder);
        defer lib.deinit(allocator);
        const entry = registrations.findProgram(&lib, program) orelse return error.NoSuchRegistration;
        try self.loadRegistration(entry);
    }

    /// Called from the audio thread: routes the following notes with the
    /// registration's split at once, and leaves the loading to the main
    /// thread, because it reads files.
    pub fn requestProgram(self: *Plugin, program: u7) void {
        self.program.store(@as(u8, program) + 1, .monotonic);
        self.settings.split.store(self.program_splits[program].load(.monotonic), .monotonic);
        self.pending_program.store(@as(u8, program) + 1, .release);
    }

    fn applyPendingProgram(self: *Plugin) void {
        const pending = self.pending_program.swap(0, .acq_rel);
        if (pending == 0 or !glue.ready) return;
        const program: u7 = @intCast(pending - 1);
        self.loadProgram(program) catch |err| {
            log.warn("program {d} (registration {d}-{d}) could not be loaded: {s}", .{ program, registrations.bankOfProgram(program), registrations.slotOfProgram(program), @errorName(err) });
            return;
        };
        log.info("program {d}: registration {d}-{d} loaded", .{ program, registrations.bankOfProgram(program), registrations.slotOfProgram(program) });
    }

    /// Reads which registrations split, for `program_splits`.
    pub fn scanProgramSplits(self: *Plugin) void {
        if (!glue.ready) return;
        self.programs_scanned = true;
        var folder_buf: [fileio.max_path]u8 = undefined;
        const folder = state.registrationFolder(&folder_buf, glue.resourcePath()) catch return;
        var lib = registrations.scan(allocator, folder) catch return;
        defer lib.deinit(allocator);
        for (lib.entries.items) |e| {
            const program = registrations.programOf(e.bank, e.slot) orelse continue;
            var name_buf: [96]u8 = undefined;
            self.program_splits[program].store(patchSplits(registrations.patchName(&name_buf, e)), .monotonic);
        }
    }

    /// Tells the host that the Registration and Split parameters changed
    /// without automation. Main thread only.
    pub fn rescanParamValues(self: *Plugin) void {
        if (self.host_params == null) return;
        if (self.host_params.*.rescan) |rescan| rescan(self.host, c.CLAP_PARAM_RESCAN_VALUES);
    }

    pub fn loadPresetFile(self: *Plugin, path: []const u8, name: []const u8) !void {
        const scene = try allocator.create(dump.Dump);
        defer allocator.destroy(scene);
        scene.* = .{};
        try state.loadPresetFile(allocator, path, scene);
        self.loadScene(scene, name);
    }

    // ---- once per timer tick, on the main thread ----

    pub fn tickMain(self: *Plugin) void {
        self.ticks +%= 1;
        if (!self.programs_scanned) self.scanProgramSplits();
        self.applyPendingProgram();
        self.logTraces();
        self.logLoopState();
        self.findTrack();
        self.connectKeyboard();
    }

    /// Writes a line when the audio loop changes state.
    pub fn logLoopState(self: *Plugin) void {
        if (self.slot) |slot| {
            if (self.ticks % 300 == 0 and self.loop_state.load(.monotonic) == @intFromEnum(audio.LoopState.running)) {
                const ticks = if (shared_bridge) |b| b.ticks.load(.monotonic) else 0;
                log.info("audio loop: {d} device callbacks, send underruns {d}, return overruns {d}", .{ ticks, slot.out_underruns.load(.monotonic), slot.in_overruns.load(.monotonic) });
            }
        }
        const current = self.loop_state.load(.monotonic);
        if (current == self.loop_state_logged) return;
        self.loop_state_logged = current;
        const state_value: audio.LoopState = @enumFromInt(current);
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

fn pluginInit(p: P) callconv(.C) bool {
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
    return true;
}

fn pluginDestroy(p: P) callconv(.C) void {
    const self = Plugin.from(p);
    ui.close(self);
    for (&instances) |*slot| {
        if (slot.* == self) slot.* = null;
    }
    if (self.slot) |slot| {
        if (shared_bridge) |b| b.release(slot);
    }
    if (self.loop) |l| allocator.destroy(l);
    allocator.destroy(self.eng);
    allocator.destroy(self.shared);
    allocator.destroy(self);
}

fn pluginActivate(p: P, sample_rate: f64, min_frames: u32, max_frames: u32) callconv(.C) bool {
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

fn pluginDeactivate(p: P) callconv(.C) void {
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

fn pluginStartProcessing(p: P) callconv(.C) bool {
    Plugin.from(p).processing = true;
    log.info("start processing", .{});
    return true;
}

fn pluginStopProcessing(p: P) callconv(.C) void {
    Plugin.from(p).processing = false;
}

fn pluginReset(p: P) callconv(.C) void {
    _ = p;
}

fn pluginOnMainThread(p: P) callconv(.C) void {
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
    return body[0] == roland.roland_id or (body[0] == 0x7E and body[2] == 0x06);
}

fn pluginProcess(p: P, proc: [*c]const c.clap_process_t) callconv(.C) c.clap_process_status {
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
            if (ev.data[0] == 0xC0 | program_channel) {
                self.requestProgram(@intCast(ev.data[1] & 0x7F));
                return;
            }
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
pub fn patchSplits(name: []const u8) bool {
    if (!glue.ready) return false;
    var buf: [1024]u8 = undefined;
    const path = state.splitsPath(&buf, glue.resourcePath()) catch return false;
    return split.isSplit(allocator, path, name);
}

/// Sets the current patch's split and remembers it for that patch.
pub fn setPatchSplit(self: *Plugin, on: bool) void {
    self.settings.split.store(on, .monotonic);
    const program = self.program.load(.monotonic);
    if (program != 0) self.program_splits[program - 1].store(on, .monotonic);
    self.rescanParamValues();
    if (!glue.ready) return;
    var buf: [1024]u8 = undefined;
    const path = state.splitsPath(&buf, glue.resourcePath()) catch return;
    split.setSplit(allocator, path, self.settings.presetName(), on) catch |err| log.warn("could not save the split list: {s}", .{@errorName(err)});
}

/// A parameter of the plugin itself changed, from automation.
pub fn applyExtra(self: *Plugin, extra: usize, value: f64) void {
    switch (extra) {
        0 => self.setLoopEnabled(value >= 0.5),
        1 => self.settings.setSendDb(@floatCast(value)),
        2 => self.settings.setReturnDb(@floatCast(value)),
        // Automation sends its value again while it holds still; only a new
        // value loads a registration.
        extra_patch => {
            const v: u8 = @intFromFloat(std.math.clamp(@round(value), 0, 128));
            if (v != 0 and v != self.program.load(.monotonic)) self.requestProgram(@intCast(v - 1));
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
    self.loop_state.store(@intFromEnum(loop.state), .monotonic);

    const previous = self.ping_state.load(.acquire);
    const current = @intFromEnum(loop.ping.state);
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

fn pluginGetExtension(p: P, id: [*c]const u8) callconv(.C) ?*const anyopaque {
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

fn audioPortsCount(p: P, is_input: bool) callconv(.C) u32 {
    _ = p;
    _ = is_input;
    return 1;
}

fn audioPortsGet(p: P, index: u32, is_input: bool, info: [*c]c.clap_audio_port_info_t) callconv(.C) bool {
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

fn notePortsCount(p: P, is_input: bool) callconv(.C) u32 {
    _ = p;
    _ = is_input;
    return 1;
}

fn notePortsGet(p: P, index: u32, is_input: bool, info: [*c]c.clap_note_port_info_t) callconv(.C) bool {
    _ = p;
    if (index != 0) return false;
    info.*.id = 0;
    info.*.supported_dialects = c.CLAP_NOTE_DIALECT_MIDI;
    info.*.preferred_dialect = c.CLAP_NOTE_DIALECT_MIDI;
    clap.copyInto(&info.*.name, if (is_input) "Keyboard in" else "Keyboard out");
    return true;
}

fn paramsCount(p: P) callconv(.C) u32 {
    _ = p;
    return total_params;
}

fn paramsGetInfo(p: P, index: u32, info: [*c]c.clap_param_info_t) callconv(.C) bool {
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

fn paramsGetValue(p: P, id: c.clap_id, out: [*c]f64) callconv(.C) bool {
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
            extra_patch => @floatFromInt(self.program.load(.monotonic)),
            else => if (self.settings.split.load(.monotonic)) 1 else 0,
        };
        return true;
    }
    return false;
}

fn paramsValueToText(p: P, id: c.clap_id, value: f64, out: [*c]u8, capacity: u32) callconv(.C) bool {
    _ = p;
    const buf = out[0..capacity];
    if (engine.paramIndexOfId(id) != null) {
        _ = std.fmt.bufPrintZ(buf, "{d}", .{@as(i64, @intFromFloat(@round(value)))}) catch return false;
        return true;
    }
    if (extraIndexOfId(id)) |extra| {
        switch (extra) {
            0, extra_split => _ = std.fmt.bufPrintZ(buf, "{s}", .{if (value >= 0.5) "On" else "Off"}) catch return false,
            extra_patch => {
                const v: u8 = @intFromFloat(std.math.clamp(@round(value), 0, 128));
                if (v == 0) {
                    _ = std.fmt.bufPrintZ(buf, "None", .{}) catch return false;
                } else {
                    const program: u7 = @intCast(v - 1);
                    _ = std.fmt.bufPrintZ(buf, "{d}-{d}", .{ registrations.bankOfProgram(program), registrations.slotOfProgram(program) }) catch return false;
                }
            },
            else => _ = std.fmt.bufPrintZ(buf, "{d:.1} dB", .{value}) catch return false,
        }
        return true;
    }
    return false;
}

fn paramsTextToValue(p: P, id: c.clap_id, text: [*c]const u8, out: [*c]f64) callconv(.C) bool {
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
fn paramsFlush(p: P, in_events: [*c]const c.clap_input_events_t, out_events: [*c]const c.clap_output_events_t) callconv(.C) void {
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

fn latencyGet(p: P) callconv(.C) u32 {
    return Plugin.from(p).latencyFrames();
}

fn stateSave(p: P, stream: [*c]const c.clap_ostream_t) callconv(.C) bool {
    const self = Plugin.from(p);
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    state.write(buf.writer(), self.shared, &self.settings) catch return false;
    const write = stream.*.write orelse return false;
    var done: usize = 0;
    while (done < buf.items.len) {
        const n = write(stream, buf.items[done..].ptr, buf.items.len - done);
        if (n <= 0) return false;
        done += @intCast(n);
    }
    return true;
}

fn stateLoad(p: P, stream: [*c]const c.clap_istream_t) callconv(.C) bool {
    const self = Plugin.from(p);
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const read = stream.*.read orelse return false;
    var chunk: [4096]u8 = undefined;
    while (true) {
        const n = read(stream, &chunk, chunk.len);
        if (n < 0) return false;
        if (n == 0) break;
        buf.appendSlice(chunk[0..@intCast(n)]) catch return false;
    }
    var reader = std.io.fixedBufferStream(buf.items);
    state.read(reader.reader(), self.shared, &self.settings) catch |err| {
        log.warn("the saved state could not be read: {s}", .{@errorName(err)});
        return false;
    };
    self.applyLoopSettings();
    return true;
}

fn presetFromLocation(p: P, kind: u32, location: [*c]const u8, load_key: [*c]const u8) callconv(.C) bool {
    _ = load_key;
    if (kind != c.CLAP_PRESET_DISCOVERY_LOCATION_FILE) return false;
    const self = Plugin.from(p);
    const path = std.mem.span(location);
    const base = std.fs.path.basename(path);
    self.loadPresetFile(path, state.displayName(base)) catch |err| {
        log.warn("preset {s} could not be loaded: {s}", .{ path, @errorName(err) });
        return false;
    };
    return true;
}

fn guiIsApiSupported(p: P, api: [*c]const u8, is_floating: bool) callconv(.C) bool {
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

fn guiGetPreferredApi(p: P, api: [*c][*c]const u8, is_floating: [*c]bool) callconv(.C) bool {
    _ = p;
    api.* = switch (@import("builtin").os.tag) {
        .macos => &c.CLAP_WINDOW_API_COCOA,
        .windows => &c.CLAP_WINDOW_API_WIN32,
        else => &c.CLAP_WINDOW_API_X11,
    };
    is_floating.* = true;
    return true;
}

fn guiCreate(p: P, api: [*c]const u8, is_floating: bool) callconv(.C) bool {
    _ = p;
    log.info("gui create: api {s}, floating {}", .{ std.mem.span(api), is_floating });
    return std.mem.eql(u8, std.mem.span(api), platformApi());
}

fn guiDestroy(p: P) callconv(.C) void {
    ui.close(Plugin.from(p));
}

fn guiSetScale(p: P, scale: f64) callconv(.C) bool {
    _ = p;
    _ = scale;
    return false;
}

fn guiGetSize(p: P, width: [*c]u32, height: [*c]u32) callconv(.C) bool {
    _ = p;
    width.* = embedded_width;
    height.* = embedded_height;
    return true;
}

fn guiCanResize(p: P) callconv(.C) bool {
    _ = p;
    return false;
}

fn guiGetResizeHints(p: P, hints: [*c]c.clap_gui_resize_hints_t) callconv(.C) bool {
    _ = p;
    _ = hints;
    return false;
}

fn guiAdjustSize(p: P, width: [*c]u32, height: [*c]u32) callconv(.C) bool {
    _ = p;
    width.* = embedded_width;
    height.* = embedded_height;
    return true;
}

fn guiSetSize(p: P, width: u32, height: u32) callconv(.C) bool {
    _ = p;
    _ = width;
    _ = height;
    return true;
}

fn guiSetParent(p: P, window: [*c]const c.clap_window_t) callconv(.C) bool {
    _ = p;
    _ = window;
    return true;
}

fn guiSetTransient(p: P, window: [*c]const c.clap_window_t) callconv(.C) bool {
    _ = p;
    _ = window;
    return true;
}

fn guiSuggestTitle(p: P, title: [*c]const u8) callconv(.C) void {
    _ = p;
    _ = title;
}

fn guiShow(p: P) callconv(.C) bool {
    log.info("the host asked to show the interface", .{});
    ui.open(Plugin.from(p));
    return true;
}

fn guiHide(p: P) callconv(.C) bool {
    ui.close(Plugin.from(p));
    return true;
}

// ---- REAPER's timer ----

/// Runs on REAPER's main thread about thirty times a second.
pub fn onTimer() callconv(.C) void {
    for (instances) |maybe| {
        const self = maybe orelse continue;
        self.tickMain();
    }
    ui.drawAll();
}

/// Called when the library unloads.
pub fn shutdown() void {
    if (timer_registered) {
        glue.unregisterTimer(onTimer);
        timer_registered = false;
    }
    glue.unregisterHook();
    debug_api.unregister();
    ui.shutdown();
    if (shared_bridge) |b| {
        allocator.destroy(b);
        shared_bridge = null;
    }
}
