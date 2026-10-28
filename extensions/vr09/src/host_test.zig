//! Tests that drive the plugin through its CLAP interface with a mock host:
//! events in, events out, parameters, state, and the pass-through of notes.
const std = @import("std");
const clap = @import("clap.zig");
const c = clap.c;
const plugin = @import("plugin.zig");
const engine = @import("engine.zig");
const catalog = @import("catalog.zig");
const roland = @import("roland.zig");
const dump = @import("dump.zig");
const debug_api = @import("debug_api.zig");
const actions = @import("actions.zig");
const types = @import("action_types.zig");
const dispatch = @import("dispatch.zig");
const library = @import("library.zig");
const strings = @import("strings.zig");

const entry = @import("clap_entry.zig").clap_entry;

const P = [*c]const c.clap_plugin_t;

/// One event the mock host delivers or receives, owned by the test.
const Stored = struct {
    bytes: [512]u8 align(8) = undefined,
    size: usize = 0,
    sysex: [64]u8 = undefined,

    pub fn header(self: *const Stored) *const c.clap_event_header_t {
        return @ptrCast(@alignCast(&self.bytes));
    }
};

const MockHost = struct {
    host: c.clap_host_t,
    input: [16]Stored = undefined,
    input_count: usize = 0,
    output: [128]Stored = undefined,
    output_count: usize = 0,

    pub fn init(self: *MockHost) void {
        self.host = .{
            .clap_version = clap.version(),
            .host_data = self,
            .name = "mock",
            .vendor = "test",
            .url = "",
            .version = "1",
            .get_extension = getExtension,
            .request_restart = noop,
            .request_process = noop,
            .request_callback = noop,
        };
        self.input_count = 0;
        self.output_count = 0;
    }

    pub fn getExtension(host: [*c]const c.clap_host_t, id: [*c]const u8) callconv(.C) ?*const anyopaque {
        _ = host;
        _ = id;
        return null;
    }

    pub fn noop(host: [*c]const c.clap_host_t) callconv(.C) void {
        _ = host;
    }

    pub fn inputSize(list: [*c]const c.clap_input_events_t) callconv(.C) u32 {
        const self: *MockHost = @ptrCast(@alignCast(list.*.ctx));
        return @intCast(self.input_count);
    }

    pub fn inputGet(list: [*c]const c.clap_input_events_t, index: u32) callconv(.C) [*c]const c.clap_event_header_t {
        const self: *MockHost = @ptrCast(@alignCast(list.*.ctx));
        return self.input[index].header();
    }

    pub fn outputPush(list: [*c]const c.clap_output_events_t, event: [*c]const c.clap_event_header_t) callconv(.C) bool {
        const self: *MockHost = @ptrCast(@alignCast(list.*.ctx));
        if (self.output_count == self.output.len) return false;
        const slot = &self.output[self.output_count];
        const size = event.*.size;
        @memcpy(slot.bytes[0..size], @as([*]const u8, @ptrCast(event))[0..size]);
        slot.size = size;
        // A SysEx event points at the plugin's buffer, which is only valid
        // during this call, so the bytes are copied.
        if (event.*.type == c.CLAP_EVENT_MIDI_SYSEX) {
            const ev: *const c.clap_event_midi_sysex_t = @ptrCast(@alignCast(event));
            @memcpy(slot.sysex[0..ev.size], ev.buffer[0..ev.size]);
        }
        self.output_count += 1;
        return true;
    }

    pub fn addInput(self: *MockHost, comptime T: type, event: T) *Stored {
        const slot = &self.input[self.input_count];
        self.input_count += 1;
        @memcpy(slot.bytes[0..@sizeOf(T)], std.mem.asBytes(&event));
        slot.size = @sizeOf(T);
        return slot;
    }

    pub fn header(comptime T: type, event_type: u16, time: u32, flags: u32) c.clap_event_header_t {
        return .{ .size = @sizeOf(T), .time = time, .space_id = c.CLAP_CORE_EVENT_SPACE_ID, .type = event_type, .flags = flags };
    }

    pub fn addNote(self: *MockHost, status: u8, key: u8, velocity: u8, time: u32, live: bool) void {
        _ = self.addInput(c.clap_event_midi_t, .{
            .header = header(c.clap_event_midi_t, c.CLAP_EVENT_MIDI, time, if (live) c.CLAP_EVENT_IS_LIVE else 0),
            .port_index = 0,
            .data = .{ status, key, velocity },
        });
    }

    pub fn addParam(self: *MockHost, id: u32, value: f64, time: u32) void {
        _ = self.addInput(c.clap_event_param_value_t, .{
            .header = header(c.clap_event_param_value_t, c.CLAP_EVENT_PARAM_VALUE, time, 0),
            .param_id = id,
            .cookie = null,
            .note_id = -1,
            .port_index = -1,
            .channel = -1,
            .key = -1,
            .value = value,
        });
    }

    /// Runs one block of 512 frames of silence.
    pub fn process(self: *MockHost, p: P) void {
        var left: [512]f32 = [_]f32{0} ** 512;
        var right: [512]f32 = [_]f32{0} ** 512;
        var out_left: [512]f32 = undefined;
        var out_right: [512]f32 = undefined;
        var in_ptrs = [_][*c]f32{ &left, &right };
        var out_ptrs = [_][*c]f32{ &out_left, &out_right };
        const in_buf = c.clap_audio_buffer_t{ .data32 = &in_ptrs, .data64 = null, .channel_count = 2, .latency = 0, .constant_mask = 0 };
        var out_buf = c.clap_audio_buffer_t{ .data32 = &out_ptrs, .data64 = null, .channel_count = 2, .latency = 0, .constant_mask = 0 };
        const in_events = c.clap_input_events_t{ .ctx = self, .size = inputSize, .get = inputGet };
        const out_events = c.clap_output_events_t{ .ctx = self, .try_push = outputPush };
        self.output_count = 0;
        const proc = c.clap_process_t{
            .steady_time = 0,
            .frames_count = 512,
            .transport = null,
            .audio_inputs = &in_buf,
            .audio_outputs = &out_buf,
            .audio_inputs_count = 1,
            .audio_outputs_count = 1,
            .in_events = &in_events,
            .out_events = &out_events,
        };
        _ = p.*.process.?(p, &proc);
        self.input_count = 0;
    }

    pub fn sysexOutputs(self: *MockHost, buf: *[16][]const u8) usize {
        var n: usize = 0;
        for (self.output[0..self.output_count]) |*e| {
            if (e.header().type != c.CLAP_EVENT_MIDI_SYSEX) continue;
            const ev: *const c.clap_event_midi_sysex_t = @ptrCast(@alignCast(&e.bytes));
            buf[n] = e.sysex[0..ev.size];
            n += 1;
        }
        return n;
    }
};

fn createPlugin(host: *MockHost) P {
    const factory: *const c.clap_plugin_factory_t = @ptrCast(@alignCast(entry.get_factory.?(&c.CLAP_PLUGIN_FACTORY_ID)));
    const p = factory.create_plugin.?(factory, &host.host, plugin.plugin_id);
    std.debug.assert(p != null);
    std.debug.assert(p.*.init.?(p));
    std.debug.assert(p.*.activate.?(p, 48000, 1, 512));
    std.debug.assert(p.*.start_processing.?(p));
    return p;
}

fn destroyPlugin(p: P) void {
    p.*.stop_processing.?(p);
    p.*.deactivate.?(p);
    p.*.destroy.?(p);
}

test "the entry point exposes one plugin and its extensions" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    const params: *const c.clap_plugin_params_t = @ptrCast(@alignCast(p.*.get_extension.?(p, &c.CLAP_EXT_PARAMS)));
    try std.testing.expectEqual(@as(u32, plugin.total_params), params.count.?(p));
    var info: c.clap_param_info_t = undefined;
    try std.testing.expect(params.get_info.?(p, 0, &info));
    try std.testing.expectEqual(engine.param_ids[0], info.id);
    try std.testing.expectEqual(@as(f64, 8), info.max_value);
    try std.testing.expect(!params.get_info.?(p, plugin.total_params, &info));

    const note_ports: *const c.clap_plugin_note_ports_t = @ptrCast(@alignCast(p.*.get_extension.?(p, &c.CLAP_EXT_NOTE_PORTS)));
    try std.testing.expectEqual(@as(u32, 1), note_ports.count.?(p, true));
    var note_info: c.clap_note_port_info_t = undefined;
    try std.testing.expect(note_ports.get.?(p, 0, false, &note_info));
    try std.testing.expect(note_info.supported_dialects & c.CLAP_NOTE_DIALECT_MIDI != 0);

    const latency: *const c.clap_plugin_latency_t = @ptrCast(@alignCast(p.*.get_extension.?(p, &c.CLAP_EXT_LATENCY)));
    try std.testing.expectEqual(@as(u32, 0), latency.get.?(p));
    try std.testing.expect(p.*.get_extension.?(p, "clap.does-not-exist") == null);
}

test "the first block asks the keyboard who it is" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    host.process(p);
    var found: [16][]const u8 = undefined;
    const n = host.sysexOutputs(&found);
    try std.testing.expect(n >= 1);
    try std.testing.expectEqualSlices(u8, &roland.identity_request, found[0]);
}

test "a host automation event becomes a DT1 for the right address" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    const drawbar = engine.paramIndexOfId(engine.hashId("organ-upper-d8")).?;
    host.addParam(engine.param_ids[drawbar], 7, 10);
    host.process(p);
    host.process(p);
    var found: [16][]const u8 = undefined;
    // The identity request went out in the first block; the DT1 follows.
    var all: usize = 0;
    var saw_dt1 = false;
    for (0..2) |_| {
        all += host.sysexOutputs(&found);
    }
    host.addParam(engine.param_ids[drawbar], 6, 0);
    host.process(p);
    const n = host.sysexOutputs(&found);
    for (found[0..n]) |msg| {
        const parsed = roland.parseDt1(msg) catch continue;
        if (parsed.address == catalog.params[drawbar].address and parsed.bytes()[0] == 6) saw_dt1 = true;
    }
    try std.testing.expect(saw_dt1);
}

test "the reverb type and level are written together, as the unit requires" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    const type_id = engine.hashId("reverb-type");
    const level_id = engine.hashId("reverb-level");
    host.process(p);
    host.process(p);

    // Both parameters change in one block: one message carries both bytes.
    host.addParam(type_id, 5, 0);
    host.addParam(level_id, 50, 0);
    host.process(p);
    var found: [16][]const u8 = undefined;
    var n = host.sysexOutputs(&found);
    var saw: usize = 0;
    for (found[0..n]) |msg| {
        const parsed = roland.parseDt1(msg) catch continue;
        if (parsed.address != 0) continue;
        saw += 1;
        try std.testing.expectEqualSlices(u8, &.{ 5, 50 }, parsed.bytes());
    }
    try std.testing.expectEqual(@as(usize, 1), saw);

    // Only the level changes: the type travels with it.
    host.addParam(level_id, 60, 0);
    host.process(p);
    n = host.sysexOutputs(&found);
    saw = 0;
    for (found[0..n]) |msg| {
        const parsed = roland.parseDt1(msg) catch continue;
        if (parsed.address != 0) continue;
        saw += 1;
        try std.testing.expectEqualSlices(u8, &.{ 5, 60 }, parsed.bytes());
    }
    try std.testing.expectEqual(@as(usize, 1), saw);
}

test "a single-byte effect is written alone" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    host.process(p);
    host.process(p);
    host.addParam(engine.hashId("mfx-type"), 6, 0);
    host.process(p);
    var found: [16][]const u8 = undefined;
    const n = host.sysexOutputs(&found);
    var saw = false;
    for (found[0..n]) |msg| {
        const parsed = roland.parseDt1(msg) catch continue;
        if (parsed.address != 0x5D) continue;
        saw = true;
        try std.testing.expectEqualSlices(u8, &.{6}, parsed.bytes());
    }
    try std.testing.expect(saw);
}

test "notes pass through by default, in order, and are dropped when asked" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    host.addNote(0x90, 60, 100, 5, false);
    host.addNote(0x90, 64, 100, 6, true);
    host.addNote(0xF8, 0, 0, 7, false);
    host.addNote(0x80, 60, 0, 300, false);
    host.process(p);
    var notes: usize = 0;
    var last_time: u32 = 0;
    for (host.output[0..host.output_count]) |*e| {
        const h = e.header();
        try std.testing.expect(h.time >= last_time);
        last_time = h.time;
        if (h.type != c.CLAP_EVENT_MIDI) continue;
        const ev: *const c.clap_event_midi_t = @ptrCast(@alignCast(&e.bytes));
        notes += 1;
        try std.testing.expect(ev.data[0] < 0xF8);
        // Without a split, the notes of channel 1 go to the Upper part.
        try std.testing.expectEqual(@as(u8, 3), ev.data[0] & 0x0F);
    }
    try std.testing.expectEqual(@as(usize, 3), notes);

    self.settings.pass_midi.store(false, .monotonic);
    host.addNote(0x90, 60, 100, 5, false);
    host.addNote(0x90, 64, 100, 6, true);
    host.addNote(0x80, 60, 0, 300, false);
    host.process(p);
    for (host.output[0..host.output_count]) |*e| try std.testing.expect(e.header().type != c.CLAP_EVENT_MIDI);
    try std.testing.expectEqual(@as(u32, 3), self.shared.midi_dropped.load(.monotonic));
}

fn midiOutputs(host: *MockHost, buf: *[16][3]u8) usize {
    var n: usize = 0;
    for (host.output[0..host.output_count]) |*e| {
        if (e.header().type != c.CLAP_EVENT_MIDI) continue;
        const ev: *const c.clap_event_midi_t = @ptrCast(@alignCast(&e.bytes));
        buf[n] = ev.data;
        n += 1;
    }
    return n;
}

test "a Program Change on channel 16 passes through like any other message" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    // The plugin no longer reads it: scenes are selected by the Scene parameter.
    host.addNote(0xCF, 4, 0, 0, false);
    host.process(p);
    var found: [16][3]u8 = undefined;
    const n = midiOutputs(&host, &found);
    try std.testing.expectEqual(@as(usize, 1), n);
    try std.testing.expectEqual(@as(u8, 0xCF), found[0][0]);
}

test "the Split parameter overrides the split" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    self.settings.split.store(true, .monotonic);

    var found: [16][3]u8 = undefined;
    host.addParam(engine.hashId("split"), 0, 0);
    host.addNote(0x90, 50, 100, 1, false);
    host.process(p);
    try std.testing.expectEqual(@as(usize, 1), midiOutputs(&host, &found));
    try std.testing.expectEqual([3]u8{ 0x93, 50, 100 }, found[0]);
}

test "the Scene parameter asks for a scene once, and shows its name" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    var verse = dump.Dump{};
    _ = verse.set(.kb, 0x02 << 14 | 5, 3);
    var chorus = dump.Dump{};
    _ = chorus.set(.kb, 0x02 << 14 | 5, 9);
    _ = try self.scene_list.add("Verse", &verse);
    _ = try self.scene_list.add("Chorus", &chorus);

    const params: *const c.clap_plugin_params_t = @ptrCast(@alignCast(p.*.get_extension.?(p, &c.CLAP_EXT_PARAMS)));
    const scene_id = engine.hashId("scene");
    var text: [32]u8 = undefined;
    try std.testing.expect(params.value_to_text.?(p, scene_id, 0, &text, text.len));
    try std.testing.expectEqualStrings("None", std.mem.sliceTo(&text, 0));
    try std.testing.expect(params.value_to_text.?(p, scene_id, 2, &text, text.len));
    try std.testing.expectEqualStrings("2 Chorus", std.mem.sliceTo(&text, 0));
    try std.testing.expect(params.value_to_text.?(p, scene_id, 3, &text, text.len));
    try std.testing.expectEqualStrings("3 (empty)", std.mem.sliceTo(&text, 0));

    // A new value asks for the scene; the same value again, as automation sends while it holds still, does not.
    host.addParam(scene_id, 2, 0);
    host.process(p);
    try std.testing.expectEqual(@as(u8, 2), self.pending_scene.load(.monotonic));
    var value: f64 = 0;
    try std.testing.expect(params.get_value.?(p, scene_id, &value));
    try std.testing.expectEqual(@as(f64, 2), value);
    self.pending_scene.store(0, .monotonic);
    host.addParam(scene_id, 2, 0);
    host.process(p);
    try std.testing.expectEqual(@as(u8, 0), self.pending_scene.load(.monotonic));
    // Zero means no scene and asks for nothing.
    host.addParam(scene_id, 0, 0);
    host.process(p);
    try std.testing.expectEqual(@as(u8, 0), self.pending_scene.load(.monotonic));

    // The main thread loads the scene's patch and names it.
    try self.selectScene(2);
    try std.testing.expectEqual(@as(?u8, 9), self.shared.getDesired(.kb, 0x02 << 14 | 5));
    try std.testing.expectEqualStrings("Chorus", self.settings.presetName());
    try std.testing.expectError(error.NoSuchScene, self.selectScene(5));
}

test "the debug commands add, list, move, select and remove scenes" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    var out: [4096]u8 = undefined;
    // Three scenes from the plugin's own state, each with its own byte.
    for ([_][]const u8{ "A", "B", "C" }, 0..) |n, i| {
        _ = self.shared.setDesired(.kb, 0x02 << 14 | 5, @intCast(i + 1));
        var arg_buf: [16]u8 = undefined;
        const arg = try std.fmt.bufPrint(&arg_buf, "current|{s}", .{n});
        var fbs = std.io.fixedBufferStream(&out);
        try debug_api.dispatch(fbs.writer(), null, -1, "scene_add", arg);
        try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"ok\":true") != null);
    }
    try std.testing.expectEqual(@as(u8, 3), self.scene_list.count);

    // Move A to the end: the others move up, and the reply says where every position went.
    var fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_move", "1,3");
    try std.testing.expectEqualStrings("{\"ok\":true,\"map\":[3,1,2]}", fbs.getWritten());
    try std.testing.expectEqualStrings("B", self.scene_list.get(1).?.name());
    try std.testing.expectEqualStrings("A", self.scene_list.get(3).?.name());

    // Selecting loads that scene's patch and makes it current; the current scene follows a move.
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_select", "3");
    try std.testing.expectEqual(@as(?u8, 1), self.shared.getDesired(.kb, 0x02 << 14 | 5));
    try std.testing.expectEqual(@as(u8, 3), self.scene.load(.monotonic));
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_move", "3,1");
    try std.testing.expectEqual(@as(u8, 1), self.scene.load(.monotonic));

    // Removing the current scene leaves none selected, and the later positions shift down: the removed
    // scene's points fall to 0, the second scene becomes the first and the third the second.
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_remove", "1");
    try std.testing.expectEqualStrings("{\"ok\":true,\"map\":[0,1,2]}", fbs.getWritten());
    try std.testing.expectEqual(@as(u8, 0), self.scene.load(.monotonic));
    try std.testing.expectEqual(@as(u8, 2), self.scene_list.count);

    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scenes", "");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"count\":2") != null);
    // A tone scene knows only the three tone bytes, and keeps the library ID and label it came with.
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_add_tone", "upper_synth 12 3 1|Lead|205|Tone Lead");
    try std.testing.expectEqualStrings("{\"ok\":true,\"position\":3}", fbs.getWritten());
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scenes", "");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "{\"position\":3,\"patch_id\":205,\"name\":\"Lead\",\"label\":\"Tone Lead\"}") != null);
    try std.testing.expectEqual(@as(usize, 3), self.scene_list.get(3).?.patch.knownCount());
    // load_tone writes a tone to the keyboard without adding a scene.
    const count_before = self.scene_list.count;
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "load_tone", "upper_piano 58 6 0|Vintage EP");
    try std.testing.expectEqualStrings("{\"ok\":true}", fbs.getWritten());
    try std.testing.expectEqual(count_before, self.scene_list.count);
    // The upper piano's tone bytes (01 01 01 to 03) are the only ones the state knows.
    try std.testing.expectEqual(@as(?u8, 58), self.shared.getDesired(.kb, 1 << 14 | 1 << 7 | 1));
    try std.testing.expectEqual(@as(?u8, 6), self.shared.getDesired(.kb, 1 << 14 | 1 << 7 | 2));
    try std.testing.expectEqual(@as(?u8, null), self.shared.getDesired(.kb, 0x02 << 14 | 5));
    try std.testing.expectEqualStrings("Vintage EP", self.settings.presetName());
    // A byte above 127 would end the SysEx message, so a tone with one is refused.
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "load_tone", "upper_piano 200 6 0|Too high");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"ok\":false") != null);
    try std.testing.expectEqual(@as(?u8, 58), self.shared.getDesired(.kb, 1 << 14 | 1 << 7 | 1));
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_add_tone", "drum 1 1 0");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"ok\":false") != null);

    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_select", "9");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"ok\":false") != null);
}

fn tonePatch(self: *plugin.Plugin, part: [:0]const u8, number: u8, msb: u8, lsb: u8, name: [:0]const u8) types.Patch {
    return .{
        .source = .{ .tone = .{ .part = self.strings.intern(part), .number = number, .msb = msb, .lsb = lsb } },
        .name = self.strings.intern(name),
        .label = self.strings.intern(name),
    };
}

test "the dispatcher carries out the actions that the panel returned, one after the other" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    const asked = [_]types.Action{
        .{ .add_scene = tonePatch(self, "upper_synth", 12, 3, 1, "Lead") },
        .{ .add_scene = tonePatch(self, "upper_piano", 58, 6, 0, "Vintage EP") },
        .{ .add_scene = tonePatch(self, "lower_piano", 56, 2, 0, "Grand") },
        .{ .select_scene = 2 },
        .{ .rename_scene = .{ .position = 3, .name = self.strings.intern("Pad") } },
    };
    for (asked) |action| dispatch.dispatch(self, action);

    try std.testing.expectEqual(@as(u8, 3), self.scene_list.count);
    try std.testing.expectEqualStrings("Lead", self.scene_list.get(1).?.name());
    try std.testing.expectEqualStrings("Pad", self.scene_list.get(3).?.name());
    try std.testing.expectEqual(@as(u8, 2), self.scene.load(.monotonic));
    // The last action that said something is the one the player reads.
    try std.testing.expect(!self.ui.notice_is_error);
}

test "the dispatcher moves and removes scenes, and the current scene follows" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    for ([_][:0]const u8{ "A", "B", "C" }, 0..) |name, i| {
        _ = try dispatch.addScene(self, tonePatch(self, "upper_piano", @intCast(i + 1), 0, 0, name));
    }
    try std.testing.expectEqual(@as(u8, 3), self.scene_list.count);

    dispatch.dispatch(self, .{ .select_scene = 1 });
    dispatch.dispatch(self, .{ .move_scene = .{ .from = 1, .to = 3 } });
    try std.testing.expectEqualStrings("B", self.scene_list.get(1).?.name());
    try std.testing.expectEqualStrings("A", self.scene_list.get(3).?.name());
    try std.testing.expectEqual(@as(u8, 3), self.scene.load(.monotonic));

    dispatch.dispatch(self, .{ .remove_scene = 3 });
    try std.testing.expectEqual(@as(u8, 2), self.scene_list.count);
    try std.testing.expectEqual(@as(u8, 0), self.scene.load(.monotonic));
}

test "the dispatcher says what went wrong, and a change of the engine goes through" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    dispatch.dispatch(self, .{ .select_scene = 9 });
    try std.testing.expect(self.ui.notice_is_error);
    try std.testing.expectEqualStrings("There is no scene 9.", std.mem.sliceTo(&self.ui.notice_text, 0));

    // A patch that the panel cannot send is said, and it is not an error of the player's.
    dispatch.dispatch(self, .{ .send_patch = .{ .source = .unsupported, .name = self.strings.intern("Hip Hop"), .label = self.strings.intern("Hip Hop") } });
    try std.testing.expect(!self.ui.notice_is_error);
    try std.testing.expect(std.mem.indexOf(u8, std.mem.sliceTo(&self.ui.notice_text, 0), "Hip Hop") != null);

    // A change of a parameter waits in the engine's queue for the main thread to take.
    dispatch.dispatch(self, .{ .set_param = .{ .index = 0, .value = 6 } });
    const change = self.shared.ui_changes.pop() orelse return error.TestExpectedAChange;
    try std.testing.expectEqual(@as(usize, 0), change.index);
    try std.testing.expectEqual(@as(u8, 6), change.value);

    dispatch.dispatch(self, .{ .set_pass_midi = true });
    try std.testing.expect(self.settings.pass_midi.load(.monotonic));
    dispatch.dispatch(self, .{ .set_sysex_bare = true });
    try std.testing.expect(self.settings.sysex_bare.load(.monotonic));
}

test "a patch is found by its ID in the sources, and its text is stored once" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    const tones_mod = @import("tones.zig");

    // The first tone has the ID 101 and goes to the upper piano part.
    const first = library.patchById(self, 101).?;
    try std.testing.expectEqualStrings(tones_mod.piano[0].name, self.strings.get(first.name));
    try std.testing.expectEqualStrings("upper_piano", self.strings.get(first.source.tone.part));
    try std.testing.expectEqual(@as(u16, 101), first.id);
    // The first synth follows the last piano.
    const synth = library.patchById(self, @intCast(101 + tones_mod.piano.len)).?;
    try std.testing.expectEqualStrings("upper_synth", self.strings.get(synth.source.tone.part));
    // A drum kit has a name and no source that the panel can send.
    const kit = library.patchById(self, @intCast(101 + tones_mod.piano.len + tones_mod.synth.len)).?;
    try std.testing.expectEqualStrings(tones_mod.drum[0].name, self.strings.get(kit.name));
    try std.testing.expect(kit.source == .unsupported);
    try std.testing.expect(library.patchById(self, 100) == null);
    try std.testing.expect(library.patchById(self, @intCast(101 + tones_mod.piano.len + tones_mod.synth.len + tones_mod.drum.len)) == null);

    // Finding the same patch again stores no new text: the IDs are the same.
    const again = library.patchById(self, 101).?;
    try std.testing.expectEqual(first.name, again.name);
    try std.testing.expectEqual(first.source.tone.part, again.source.tone.part);
}

fn presetNames(self: *plugin.Plugin, out: *std.ArrayList([]const u8)) !void {
    for (library.rows(self)) |row| {
        if (row.kind == .preset) try out.append(self.strings.get(row.name));
    }
}

test "a registration or a preset is found by its ID in the rows of the table" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    // Nothing is read before the rows are asked for, and nothing lists the registrations or the presets here.
    try std.testing.expect(!self.library.built);
    try std.testing.expect(library.patchById(self, 5) == null);
    try std.testing.expect(self.library.built);
    library.addPreset(self, "Warm Pad.vr09");
    const found = library.patchById(self, library.presetId("Warm Pad")).?;
    try std.testing.expectEqualStrings("Warm Pad", self.strings.get(found.name));
    try std.testing.expectEqualStrings("Warm Pad.vr09", self.strings.get(found.source.preset));
    try std.testing.expect(library.patchById(self, library.presetId("Other")) == null);
}

test "two presets never share a patch ID, so a template finds the right one" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    _ = library.rows(self);
    // The same name in two files has the same hash, and so has to be told apart.
    library.addPreset(self, "foo.vr09");
    library.addPreset(self, "foo.json");
    var values: [2]u32 = undefined;
    var found: usize = 0;
    for (library.rows(self)) |row| {
        if (row.kind != .preset) continue;
        values[found] = row.value;
        found += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), found);
    try std.testing.expect(values[0] != values[1]);
    const first = library.patchById(self, values[0]).?;
    const second = library.patchById(self, values[1]).?;
    try std.testing.expect(first.source.preset != second.source.preset);
    // A value that a tone has is not a preset's.
    try std.testing.expect(values[0] >= 1000 and values[1] >= 1000);
}

test "saving and deleting a preset adds and removes its row, in the order of the names" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    // Before the first read, a saved preset has no row to add: the read finds the file by itself.
    library.addPreset(self, "Early.vr09");
    try std.testing.expect(!self.library.built);

    const tone_rows = library.rows(self).len;
    library.addPreset(self, "Pad.vr09");
    library.addPreset(self, "organ.vr09");
    library.addPreset(self, "Zed.vr09");
    library.addPreset(self, "Pad.vr09");
    var names = std.ArrayList([]const u8).init(std.testing.allocator);
    defer names.deinit();
    try presetNames(self, &names);
    try std.testing.expectEqual(@as(usize, 3), names.items.len);
    try std.testing.expectEqualStrings("organ", names.items[0]);
    try std.testing.expectEqualStrings("Pad", names.items[1]);
    try std.testing.expectEqualStrings("Zed", names.items[2]);
    try std.testing.expectEqual(tone_rows + 3, library.rows(self).len);

    library.removePreset(self, "Pad.vr09");
    library.removePreset(self, "Missing.vr09");
    names.clearRetainingCapacity();
    try presetNames(self, &names);
    try std.testing.expectEqual(@as(usize, 2), names.items.len);
    try std.testing.expectEqualStrings("Zed", names.items[1]);
    try std.testing.expect(library.patchById(self, library.presetId("Pad")) == null);
}

test "the folders are read into rows: the registrations by bank and slot, the presets by name" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    var registration_dir = std.testing.tmpDir(.{});
    defer registration_dir.cleanup();
    for ([_][]const u8{ "10-1_B.json", "2-1_Sweet_Dream.json", "verify.json", "2-2_C.vr09" }) |n| {
        try registration_dir.dir.writeFile(.{ .sub_path = n, .data = "{}" });
    }
    var preset_dir = std.testing.tmpDir(.{});
    defer preset_dir.cleanup();
    for ([_][]const u8{ "b.vr09", "A.vr09" }) |n| {
        try preset_dir.dir.writeFile(.{ .sub_path = n, .data = "{}" });
    }
    var registration_buf: [std.fs.max_path_bytes]u8 = undefined;
    const registration_folder = try registration_dir.dir.realpath(".", &registration_buf);
    var preset_buf: [std.fs.max_path_bytes]u8 = undefined;
    const preset_folder = try preset_dir.dir.realpath(".", &preset_buf);

    var found = library.Library{};
    defer found.deinit(plugin.allocator);
    library.appendRegistrations(self, &found, registration_folder);
    try std.testing.expectEqual(@as(u32, 2), found.registration_count);
    try std.testing.expectEqualStrings("Sweet Dream", self.strings.get(found.rows.items[0].name));
    try std.testing.expectEqualStrings("2-1", self.strings.get(found.rows.items[0].number));
    try std.testing.expectEqual(@as(u32, 5), found.rows.items[0].value);
    try std.testing.expectEqualStrings("10-1_B.json", self.strings.get(found.rows.items[1].file));
    library.appendPresets(self, &found, preset_folder);
    try std.testing.expectEqual(@as(usize, 4), found.rows.items.len);
    try std.testing.expectEqualStrings("A", self.strings.get(found.rows.items[2].name));
    try std.testing.expectEqualStrings("b", self.strings.get(found.rows.items[3].name));
}

test "choosing a tone in a card writes only the tone, and the knobs, the name and the split stay" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    const tones_mod = @import("tones.zig");

    // The card of the lower synth is the sixth part.
    const tone = &tones_mod.synth[3];
    // A knob and a name that the player has set before the card is used.
    _ = self.shared.setDesired(.kb, 0x02 << 14 | 5, 42);
    self.settings.setPresetName("My patch");
    dispatch.dispatch(self, .{ .choose_tone = .{ .part = 5, .tone = tone } });
    var written = dump.Dump{};
    self.shared.desiredSnapshot(&written);
    try std.testing.expectEqual(@as(usize, 4), written.knownCount());
    try std.testing.expectEqual(@as(?u8, 42), written.get(.kb, 0x02 << 14 | 5));
    try std.testing.expectEqualStrings("My patch", self.settings.presetName());
    const block = dump.blockByName("lower_synth").?;
    const base = dump.block_offsets[block] + 1;
    try std.testing.expectEqual(tone.number, written.values[base]);
    try std.testing.expectEqual(tone.msb, written.values[base + 1]);
    try std.testing.expectEqual(tone.lsb, written.values[base + 2]);
}

test "a tone patch becomes a scene that holds only its three bytes, and an unsupported one is refused" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    const position = try dispatch.addScene(self, tonePatch(self, "upper_synth", 12, 3, 1, "Lead"));
    try std.testing.expectEqual(@as(u8, 1), position);
    try std.testing.expectError(error.NotSupported, dispatch.addScene(self, .{ .source = .unsupported, .name = self.strings.intern("Kit"), .label = self.strings.intern("Kit") }));
    try std.testing.expectError(error.BadPart, dispatch.addScene(self, tonePatch(self, "drum", 1, 1, 0, "Kit")));
    try std.testing.expectEqual(@as(u8, 1), self.scene_list.count);
}

test "the step actions move between the scenes of an instance and stop at the ends" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    for ([_]u8{ 1, 2, 3 }) |value| {
        var patch = dump.Dump{};
        _ = patch.set(.kb, 0x02 << 14 | 5, value);
        _ = try self.scene_list.add("Scene", &patch);
    }

    // With none selected, either direction goes to the first scene.
    actions.step(-1);
    try std.testing.expectEqual(@as(u8, 1), self.scene.load(.monotonic));
    actions.step(1);
    actions.step(1);
    try std.testing.expectEqual(@as(u8, 3), self.scene.load(.monotonic));
    try std.testing.expectEqual(@as(?u8, 3), self.shared.getDesired(.kb, 0x02 << 14 | 5));
    // The last scene is the end: another step does not wrap round to the first.
    actions.step(1);
    try std.testing.expectEqual(@as(u8, 3), self.scene.load(.monotonic));
    actions.step(-1);
    try std.testing.expectEqual(@as(u8, 2), self.scene.load(.monotonic));
}

test "saving the keyboard reads it first and writes the preset when the read ends" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    // Nothing is read from a keyboard that does not answer, and a name is needed.
    try std.testing.expectError(error.NotConnected, self.startSave("Warm pad"));
    self.shared.connected.store(true, .release);
    try std.testing.expectError(error.EmptyName, self.startSave(" . "));

    // Starting asks for a read, and writes nothing yet.
    try self.startSave("Warm pad");
    try std.testing.expectEqual(plugin.SaveState.reading, self.save.state);
    try std.testing.expectError(error.Busy, self.startSave("Another"));
    self.advanceSave();
    try std.testing.expectEqual(plugin.SaveState.reading, self.save.state);

    // The read ends and the keyboard answered: the preset is written, from what the read gave.
    _ = self.shared.setDesired(.kb, 0x02 << 14 | 5, 42);
    _ = self.shared.captures_done.fetchAdd(1, .release);
    self.shared.capture_answered.store(true, .monotonic);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var root_buf: [std.fs.max_path_bytes]u8 = undefined;
    const root = try tmp.dir.realpath(".", &root_buf);
    self.finishSave(root);
    try std.testing.expectEqual(plugin.SaveState.done, self.save.state);
    try std.testing.expectEqualStrings("Warm pad.vr09", self.save.fileName());
    try std.testing.expect(self.save.known >= 1);
    var back = try std.testing.allocator.create(dump.Dump);
    defer std.testing.allocator.destroy(back);
    back.* = .{};
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/Warm pad.vr09", .{root});
    try @import("state.zig").loadPresetFile(std.testing.allocator, path, back);
    try std.testing.expectEqual(@as(?u8, 42), back.get(.kb, 0x02 << 14 | 5));

    // A read that the keyboard did not answer is a failed save, with the reason.
    try self.startSave("Second");
    _ = self.shared.captures_done.fetchAdd(1, .release);
    self.shared.capture_answered.store(false, .monotonic);
    self.advanceSave();
    try std.testing.expectEqual(plugin.SaveState.failed, self.save.state);
    try std.testing.expectEqualStrings("the keyboard did not answer", self.save.failure());
    // A failed save can be tried again.
    try self.startSave("Second");
    try std.testing.expectEqual(plugin.SaveState.reading, self.save.state);
}

test "the panel's save starts the plugin's save job, and its result is told once" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    const asked = self.strings.intern("Warm pad");

    // A keyboard that does not answer is told at once, and nothing starts.
    dispatch.dispatch(self, .{ .save_keyboard = asked });
    try std.testing.expectEqual(plugin.SaveState.idle, self.save.state);
    try std.testing.expect(std.mem.indexOf(u8, std.mem.sliceTo(&self.ui.notice_text, 0), "does not answer") != null);

    // The save runs on the plugin's job, and the panel only looks at it.
    self.shared.connected.store(true, .release);
    dispatch.dispatch(self, .{ .save_keyboard = asked });
    try std.testing.expectEqual(plugin.SaveState.reading, self.save.state);
    self.ui.notice_text[0] = 0;
    dispatch.reportSave(self);
    try std.testing.expectEqual(@as(u8, 0), self.ui.notice_text[0]);

    _ = self.shared.setDesired(.kb, 0x02 << 14 | 5, 42);
    _ = self.shared.captures_done.fetchAdd(1, .release);
    self.shared.capture_answered.store(true, .monotonic);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var root_buf: [std.fs.max_path_bytes]u8 = undefined;
    const root = try tmp.dir.realpath(".", &root_buf);
    self.finishSave(root);
    dispatch.reportSave(self);
    try std.testing.expect(std.mem.indexOf(u8, std.mem.sliceTo(&self.ui.notice_text, 0), "saved it as Warm pad") != null);

    // The result is told once: the next frame says nothing more.
    self.ui.notice_text[0] = 0;
    dispatch.reportSave(self);
    try std.testing.expectEqual(@as(u8, 0), self.ui.notice_text[0]);
}

test "a scene number that does not exist goes back to the loaded scene" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    _ = try dispatch.addScene(self, tonePatch(self, "upper_piano", 1, 0, 0, "A"));
    try self.selectScene(1);

    // Automation asks for a scene that the list does not have: the number is shown at once, then taken back.
    self.requestScene(9);
    try std.testing.expectEqual(@as(u8, 9), self.scene.load(.monotonic));
    self.applyPendingScene();
    try std.testing.expectEqual(@as(u8, 1), self.scene.load(.monotonic));

    // Once the scene exists, the same value loads it, because it is a new value again.
    var i: usize = 0;
    while (i < 8) : (i += 1) _ = try dispatch.addScene(self, tonePatch(self, "upper_piano", 2, 0, 0, "More"));
    self.requestScene(9);
    self.applyPendingScene();
    try std.testing.expectEqual(@as(u8, 9), self.scene.load(.monotonic));
}

test "a notice that is too long keeps its beginning" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    const long = "x" ** 400;
    self.ui.notice("Exported to {s}.", .{long}, false);
    try std.testing.expect(std.mem.startsWith(u8, std.mem.sliceTo(&self.ui.notice_text, 0), "Exported to xxx"));
    try std.testing.expectEqual(self.ui.notice_text.len, std.mem.sliceTo(&self.ui.notice_text, 0).len);
}

test "automation of the loop leaves the track's flag to the main thread" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    // The audio thread's side: the setting is stored and the flag is marked, and nothing calls REAPER.
    plugin.applyExtra(self, 0, 1.0);
    try std.testing.expect(self.settings.loop_enabled.load(.monotonic));
    try std.testing.expect(self.loop_flag_dirty.load(.acquire));
    // The main thread's tick takes the mark.
    self.tickMain();
    try std.testing.expect(!self.loop_flag_dirty.load(.acquire));
    // The same value again changes nothing.
    plugin.applyExtra(self, 0, 1.0);
    try std.testing.expect(!self.loop_flag_dirty.load(.acquire));
}

test "a control change parameter sends a CC and nothing else" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);

    const cutoff = engine.paramIndexOfId(engine.hashId("cc-upper-cutoff")).?;
    host.addParam(engine.param_ids[cutoff], 90, 20);
    host.process(p);
    var cc_seen = false;
    for (host.output[0..host.output_count]) |*e| {
        if (e.header().type != c.CLAP_EVENT_MIDI) continue;
        const ev: *const c.clap_event_midi_t = @ptrCast(@alignCast(&e.bytes));
        if (ev.data[0] == 0xB3 and ev.data[1] == 74 and ev.data[2] == 90) cc_seen = true;
    }
    try std.testing.expect(cc_seen);
}

/// An in-memory stream for the state extension's save and load.
const TestStream = struct {
    bytes: std.ArrayList(u8),
    pos: usize = 0,

    pub fn write(s: [*c]const c.clap_ostream_t, buffer: ?*const anyopaque, size: u64) callconv(.C) i64 {
        const self_: *TestStream = @ptrCast(@alignCast(s.*.ctx));
        const b: [*]const u8 = @ptrCast(buffer.?);
        self_.bytes.appendSlice(b[0..size]) catch return -1;
        return @intCast(size);
    }

    pub fn read(s: [*c]const c.clap_istream_t, buffer: ?*anyopaque, size: u64) callconv(.C) i64 {
        const self_: *TestStream = @ptrCast(@alignCast(s.*.ctx));
        const n = @min(size, self_.bytes.items.len - self_.pos);
        const b: [*]u8 = @ptrCast(buffer.?);
        @memcpy(b[0..n], self_.bytes.items[self_.pos .. self_.pos + n]);
        self_.pos += n;
        return @intCast(n);
    }
};

test "the state survives a save and a load into another instance" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);
    const drawbar = engine.paramIndexOfId(engine.hashId("organ-upper-d8")).?;
    host.addParam(engine.param_ids[drawbar], 5, 0);
    host.process(p);
    self.settings.setPresetName("Test pad");

    var stream = TestStream{ .bytes = std.ArrayList(u8).init(std.testing.allocator) };
    defer stream.bytes.deinit();
    const state_ext: *const c.clap_plugin_state_t = @ptrCast(@alignCast(p.*.get_extension.?(p, &c.CLAP_EXT_STATE)));
    const out_stream = c.clap_ostream_t{ .ctx = &stream, .write = TestStream.write };
    try std.testing.expect(state_ext.save.?(p, &out_stream));
    try std.testing.expect(stream.bytes.items.len > 1800);

    var host2: MockHost = undefined;
    host2.init();
    const p2 = createPlugin(&host2);
    defer destroyPlugin(p2);
    const in_stream = c.clap_istream_t{ .ctx = &stream, .read = TestStream.read };
    try std.testing.expect(state_ext.load.?(p2, &in_stream));
    const other = plugin.Plugin.from(p2);
    try std.testing.expectEqual(@as(u8, 5), other.shared.paramValue(drawbar));
    try std.testing.expectEqualStrings("Test pad", other.settings.presetName());
    try std.testing.expect(other.shared.restored.load(.acquire));
}
