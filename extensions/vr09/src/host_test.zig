//! Tests that drive the plugin through its CLAP interface with a mock host:
//! events in, events out, parameters, state, and the pass-through of notes.
const std = @import("std");
const clap = @import("clap.zig");
const c = clap.c;
const plugin = @import("plugin.zig");
const engine = @import("engine.zig");
const catalog = @import("catalog.zig");
const roland = @import("roland.zig");

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

test "notes are dropped by default and pass through, in order, when asked" {
    try std.testing.expect(entry.init.?("test"));
    defer entry.deinit.?();
    var host: MockHost = undefined;
    host.init();
    const p = createPlugin(&host);
    defer destroyPlugin(p);
    const self = plugin.Plugin.from(p);

    host.addNote(0x90, 60, 100, 5, false);
    host.addNote(0x90, 64, 100, 6, true);
    host.addNote(0x80, 60, 0, 300, false);
    host.process(p);
    for (host.output[0..host.output_count]) |*e| try std.testing.expect(e.header().type != c.CLAP_EVENT_MIDI);
    try std.testing.expectEqual(@as(u32, 3), self.shared.midi_dropped.load(.monotonic));

    self.settings.pass_midi.store(true, .monotonic);
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
    }
    try std.testing.expectEqual(@as(usize, 3), notes);
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
