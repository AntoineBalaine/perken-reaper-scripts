const std = @import("std");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const ModulesList = statemachine.ModulesList;
const c1 = @import("c1.zig");

pub const debug_window_active = @import("builtin").mode == .Debug;

// pub var debug_window_active = debugconfig.@"test";
pub var event_log: ?*EventLog = null; // Pointer to state's event log
pub var log_file: ?*std.fs.File = null; // Just need the file handle

// Circular buffer for debug overlay
const DebugBufferSize = 1024;

pub const EventType = enum {
    state_change,
    midi_input,
    parameter_update,
    // etc.
};

pub const Event = union(EventType) {
    state_change: struct {
        old_mode: Mode,
        new_mode: Mode,
    },
    midi_input: struct {
        cc: c1.CCs,
        value: u8,
    },
    parameter_update: struct {
        module: ModulesList,
        param: u32,
        value: f64,
    },

    pub fn format(
        self: Event,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .state_change => |state| {
                try writer.print("State: {s} -> {s}", .{
                    @tagName(state.old_mode),
                    @tagName(state.new_mode),
                });
            },
            .midi_input => |midi| {
                try writer.print("MIDI CC {s}: {d}", .{
                    @tagName(midi.cc),
                    midi.value,
                });
            },
            .parameter_update => |param| {
                try writer.print("Parameter {s}.{d}: {d}", .{
                    @tagName(param.module),
                    param.param,
                    param.value,
                });
            },
        }
    }
};
pub const EventLog = @import("logger_evt.zig");

const Color = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    const green = "\x1b[0;32m";
    // Add more colors as needed
};

test {
    std.testing.refAllDecls(@This());
}

test "eventlog" {
    const testing = std.testing;
    var e_log = EventLog.init();
    event_log = &e_log;
    // log some events
    event_log.?.log(.{
        .parameter_update = .{
            .module = .COMP,
            .param = 1,
            .value = 0.5,
        },
    });

    // test recent events
    const recent_events = event_log.?.recent(10);
    try testing.expect(recent_events.len == 1);

    // test finding last event
    const last_param = event_log.?.findLastEvent(.parameter_update);
    try testing.expect(last_param != null);
    if (last_param) |event| {
        try testing.expect(event.parameter_update.value == 0.5);
    }
}

test "log function" {
    const testing = std.testing;
    init(); // Initialize logging allocator
    var e_log = EventLog.init();
    event_log = &e_log;

    // Test basic logging (will print to stderr during test)
    std.log.scoped(.midi_input).info("Test message with value: {d}", .{42});

    // Test event logging
    const event = Event{
        .parameter_update = .{
            .module = .COMP,
            .param = 1,
            .value = 0.5,
        },
    };
    std.log.scoped(.parameters).debug("Parameter changed: {}", .{event});

    // Verify event was logged
    const last_param_event = event_log.?.findLastEvent(.parameter_update);
    try testing.expect(last_param_event != null);
    if (last_param_event) |evt| {
        try testing.expect(evt.parameter_update.value == 0.5);
        try testing.expect(evt.parameter_update.module == .COMP);
        try testing.expect(evt.parameter_update.param == 1);
    }

    deinit(); // Clean up logging allocator
}

test "midi events circular buffer" {
    const testing = std.testing;
    var e_log = EventLog.init();

    // Insert 100 MIDI events with different CC values
    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        e_log.log(.{
            .midi_input = .{
                .cc = c1.CCs.Comp_Attack, // Using CC1 for example
                .value = i, // Each event has a different value
            },
        });
    }

    // Get last 50 events
    const recent_events = e_log.recent(50);

    // Verify we got exactly 50 events
    try testing.expectEqual(50, recent_events.len);

    // Verify the values are correct (should be the most recent ones: 50-99)
    for (recent_events, 0..) |event, index| {
        switch (event) {
            .midi_input => |midi| {
                // The values should start from 50 and go up to 99
                const expected_value = 100 - (@as(u8, @intCast(index)) + 1);
                try testing.expectEqual(expected_value, midi.value);
            },
            else => unreachable,
        }
    }

    // Optional: Test getting fewer events
    const fewer = e_log.recent(10);
    try testing.expectEqual(@as(usize, 10), fewer.len);
}

// FIXME: set as main app log level
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Check if any argument is an Event
    const Args = @TypeOf(args);
    const args_type_info = @typeInfo(Args);
    if (args_type_info == .Struct) {
        inline for (args_type_info.Struct.fields) |field| {
            if (field.type == Event) {
                if (event_log) |evt_log| {
                    evt_log.log(@field(args, field.name));
                }
            }
        }
    }

    const scope_prefix = "(" ++ switch (scope) {
        .gpa, // general purpose allocator
        .csurf,
        .dispatch,
        .extension,
        .fx_sel_actions,
        .imgui_loop,
        .mapping_actions,
        .mapping_list,
        .mappings,
        .midi_input,
        .parameters,
        .preferences,
        .settings,
        .track_list,
        => @tagName(scope),
        .default => @tagName(scope),
        else => @compileError("Unknown scope type: " ++ @tagName(scope)),
    } ++ "): ";

    const color = switch (level) {
        .debug => Color.blue,
        .info => Color.green,
        .warn => Color.yellow,
        .err => Color.red,
    };

    const prefix = color ++ "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ Color.reset ++ "\n", args) catch return;

    // File logging
    if (log_file) |file| {
        const message = std.fmt.allocPrint(
            logging_allocator,
            "[{s}]{s}" ++ format ++ "\n",
            .{ @tagName(level), scope_prefix } ++ args,
        ) catch return;
        defer logging_allocator.free(message);
        file.writeAll(message) catch {};
    }
}

var arena: std.heap.ArenaAllocator = undefined;
var logging_allocator: std.mem.Allocator = undefined;

pub fn init() void {
    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    logging_allocator = arena.allocator();
}

pub fn deinit() void {
    arena.deinit();
}
