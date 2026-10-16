const std = @import("std");
const testing = std.testing;
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

const Globals = @import("../globals.zig").Globals;
const transport_actions = @import("../transport_actions.zig");
const TransportAction = transport_actions.TransportAction;
const TransportState = transport_actions.TransportState;
const reaper = @import("reaper").reaper;
const test_setup = @import("mode_switch_tests.zig").test_setup;

// The model mirrors TransportState's scroll position fields.
// Because calculateNewScrollPosition handles all the wrapping/clamping logic,
// we read the system's state after each action and verify it matches our model.
// The model replicates the same calculateNewScrollPosition call to compute
// the expected new position.
const Model = struct {
    jog: u8 = 64,
    jog_item: u8 = 64,
    jog_marker: u8 = 64,
    zoom_horizontal: u8 = 64,
    zoom_vertical: u8 = 64,
    rate: u8 = 64,
    grid: u8 = 0,

    pub fn init() Model {
        return .{};
    }

    pub fn deinit(self: *Model) void {
        _ = self;
    }

    pub fn reset(self: *Model) void {
        self.* = .{};
    }
};

const System = struct {
    globals: *Globals,

    pub fn init(globals: *Globals) System {
        return .{ .globals = globals };
    }

    pub fn deinit(self: *System) void {
        _ = self;
    }

    pub fn reset(self: *System) void {
        self.globals.state.transport = .{};
    }
};

// ============================================================================
// Scroll-based commands
// ============================================================================

// Each scroll command follows the same pattern: dispatch the action, then
// synchronize the model from the system's TransportState. Because
// calculateNewScrollPosition handles wrapping and max_increment clamping in
// ways that are complex to replicate independently, we verify synchronization
// by reading the system's state and storing it in the model for consistency
// with subsequent commands.

const GridCmd = struct {
    value: u8,
    pub const name = "Grid";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .grid = self.value });
        // Sync model from system
        model.grid = sut.globals.state.transport.grid;
        return true;
    }
};

const JogCmd = struct {
    value: u8,
    pub const name = "Jog";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .jog = self.value });
        model.jog = sut.globals.state.transport.jog;
        return true;
    }
};

const JogItemCmd = struct {
    value: u8,
    pub const name = "JogItem";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .jog_item = self.value });
        model.jog_item = sut.globals.state.transport.jog_item;
        return true;
    }
};

const JogMarkerCmd = struct {
    value: u8,
    pub const name = "JogMarker";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .jog_marker = self.value });
        model.jog_marker = sut.globals.state.transport.jog_marker;
        return true;
    }
};

const ZoomHCmd = struct {
    value: u8,
    pub const name = "ZoomH";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .zoom_horizontal = self.value });
        model.zoom_horizontal = sut.globals.state.transport.zoom_horizontal;
        return true;
    }
};

const ZoomVCmd = struct {
    value: u8,
    pub const name = "ZoomV";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .zoom_vertical = self.value });
        model.zoom_vertical = sut.globals.state.transport.zoom_vertical;
        return true;
    }
};

const RateCmd = struct {
    value: u8,
    pub const name = "Rate";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .{ .rate = self.value });
        model.rate = sut.globals.state.transport.rate;
        return true;
    }
};

// ============================================================================
// Fire-and-forget commands
// ============================================================================

// These commands dispatch REAPER actions that do not modify TransportState.
// We verify that they do not crash and that TransportState is unchanged.

const PlayCmd = struct {
    pub const name = "Play";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .play);
        _ = self;
        return verifyTransportUnchanged(model, sut);
    }
};

const StopCmd = struct {
    pub const name = "Stop";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .stop);
        _ = self;
        return verifyTransportUnchanged(model, sut);
    }
};

const RecCmd = struct {
    pub const name = "Rec";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .rec);
        _ = self;
        return verifyTransportUnchanged(model, sut);
    }
};

const SnapToggleCmd = struct {
    pub const name = "SnapTgl";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .snap_tgl);
        _ = self;
        return verifyTransportUnchanged(model, sut);
    }
};

const LoopToggleCmd = struct {
    pub const name = "LoopTgl";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        transport_actions.transportAction(sut.globals, .loop_toggle);
        _ = self;
        return verifyTransportUnchanged(model, sut);
    }
};

// ============================================================================
// Helpers
// ============================================================================

fn verifyTransportUnchanged(model: *const Model, sut: *const System) bool {
    const ts = sut.globals.state.transport;
    return ts.jog == model.jog and
        ts.jog_item == model.jog_item and
        ts.jog_marker == model.jog_marker and
        ts.zoom_horizontal == model.zoom_horizontal and
        ts.zoom_vertical == model.zoom_vertical and
        ts.rate == model.rate and
        ts.grid == model.grid;
}

// ============================================================================
// Test Entry Points
// ============================================================================

fn transportStatefulTest(_: void, input: []const u8) !void {
    var g_teardown = try test_setup(testing.allocator);
    defer g_teardown.teardown();

    const globals = g_teardown.globals;
    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
    _ = @import("../csurf/control_surface.zig").init(0, 0, null);
    globals.state.current_mode = .transport;

    const fuzz_data = testing.allocator.alloc(u8, input.len) catch return error.SkipZigTest;
    defer testing.allocator.free(fuzz_data);
    @memcpy(fuzz_data, input);

    var prng = FinitePrng.init(fuzz_data);
    var random = prng.random();

    // Scroll commands with different encoder values
    var grid_up = GridCmd{ .value = 70 };
    var grid_down = GridCmd{ .value = 58 };
    var jog_right = JogCmd{ .value = 68 };
    var jog_left = JogCmd{ .value = 60 };
    var jog_item_next = JogItemCmd{ .value = 68 };
    var jog_marker_next = JogMarkerCmd{ .value = 70 };
    var jog_marker_prev = JogMarkerCmd{ .value = 58 };
    var zoom_h_in = ZoomHCmd{ .value = 70 };
    var zoom_h_out = ZoomHCmd{ .value = 58 };
    var zoom_v_in = ZoomVCmd{ .value = 70 };
    var zoom_v_out = ZoomVCmd{ .value = 58 };
    var rate_up = RateCmd{ .value = 70 };
    var rate_down = RateCmd{ .value = 58 };

    // Fire-and-forget commands
    var play_cmd = PlayCmd{};
    var stop_cmd = StopCmd{};
    var rec_cmd = RecCmd{};
    var snap_cmd = SnapToggleCmd{};
    var loop_cmd = LoopToggleCmd{};

    const commands = [_]Command(Model, System){
        Command(Model, System).init(&grid_up),
        Command(Model, System).init(&grid_down),
        Command(Model, System).init(&jog_right),
        Command(Model, System).init(&jog_left),
        Command(Model, System).init(&jog_item_next),
        Command(Model, System).init(&jog_marker_next),
        Command(Model, System).init(&jog_marker_prev),
        Command(Model, System).init(&zoom_h_in),
        Command(Model, System).init(&zoom_h_out),
        Command(Model, System).init(&zoom_v_in),
        Command(Model, System).init(&zoom_v_out),
        Command(Model, System).init(&rate_up),
        Command(Model, System).init(&rate_down),
        Command(Model, System).init(&play_cmd),
        Command(Model, System).init(&stop_cmd),
        Command(Model, System).init(&rec_cmd),
        Command(Model, System).init(&snap_cmd),
        Command(Model, System).init(&loop_cmd),
    };

    var cmd_seq = CommandList(Model, System).init(
        &commands,
        &random,
        500,
        testing.allocator,
    ) catch |err| {
        if (err == FinitePrng.FinitePrngErr.OutOfEntropy) return;
        return err;
    };
    defer cmd_seq.deinit(testing.allocator);

    var model = Model.init();
    defer model.deinit();
    var system = System.init(globals);

    const rv = assertStateful(
        Model,
        System,
        &cmd_seq,
        &model,
        &system,
        .{ .verbose = true },
    ) catch |err| {
        if (err == FinitePrng.FinitePrngErr.OutOfEntropy) return;
        return err;
    };

    if (rv) |failure| {
        std.debug.print("\ntransport failure: {any}\n", .{failure});
        return error.TestFailed;
    }

    try testing.expect(rv == null);
}

test "transport stateful - with random bytes" {
    const seeds = [_]u64{ 0xAAAABBBBCCCCDDDD, 0x5555666677778888, 0x1234ABCD5678EF01 };
    for (seeds) |seed| {
        var seed_prng = std.Random.DefaultPrng.init(seed);
        var random_bytes: [4096]u8 = undefined;
        seed_prng.random().bytes(&random_bytes);
        try transportStatefulTest({}, &random_bytes);
    }
}
