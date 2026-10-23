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
    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_add_tone", "drum 1 1 0");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"ok\":false") != null);

    fbs = std.io.fixedBufferStream(&out);
    try debug_api.dispatch(fbs.writer(), null, -1, "scene_select", "9");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"ok\":false") != null);
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
