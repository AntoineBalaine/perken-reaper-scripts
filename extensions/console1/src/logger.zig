// 2. Debugging Infrastructure
//    - Event system implementation
//      * EventType enum and Event union
//      * EventLog struct with ArrayList
//      * Basic logging functions
//    - Debug levels
//      * LogLevel enum
//      * Integration with Reaper console
//    - Debug overlay prototype
//      * Collapsible ImGui window
//      * Event history display
//      * State visualization
//      * MIDI activity monitor

const std = @import("std");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const ModulesList = statemachine.ModulesList;
const c1 = @import("c1.zig");
const debugconfig = @import("config");

pub var debug_window_active = debugconfig.@"test";
pub var event_log: ?*EventLog = null; // Pointer to state's event log
pub var log_file: ?*std.fs.File = null; // Just need the file handle
pub var log_level: ?*LogLevel = null; // Just need the level
// Circular buffer for debug overlay
const DebugBufferSize = 1024;

pub const LogLevel = enum(u8) {
    debug, // Very detailed information, function entries/exits
    info, // General operational information
    warning, // Issues that don't stop operation but need attention
    err, // Serious issues that impair functionality

    // Helper to check if a level should be logged
    pub fn shouldLog(self: LogLevel, current_level: LogLevel) bool {
        return @intFromEnum(self) >= @intFromEnum(current_level);
    }
};

const EventType = enum {
    state_change,
    midi_input,
    parameter_update,
    // etc.
};

const Event =
    union(EventType) {
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
};

pub const EventLog = struct {
    const Self = @This();
    // Fixed size to avoid allocations during real-time operation
    const MaxEvents = 128;

    events: [MaxEvents]Event,
    count: usize = 0, // Total number of events logged
    position: usize = 0, // Current position in circular buffer

    pub fn init() Self {
        return .{
            .events = undefined,
        };
    }

    pub fn log(self: *Self, event: Event) void {
        self.events[self.position] = event;
        self.position = @rem(self.position + 1, MaxEvents);
        self.count += 1;
    }

    // Returns slice of most recent events, newest first
    pub fn recent(self: *Self, max_items: usize) []const Event {
        const num_items = @min(max_items, @min(self.count, MaxEvents));
        if (num_items == 0) return &[0]Event{};

        // If we haven't wrapped around yet
        if (self.count <= MaxEvents) {
            const start = if (self.position >= num_items)
                self.position - num_items
            else
                0;
            return self.events[start..self.position];
        }

        // If we've wrapped around, need to handle circular buffer
        if (self.position >= num_items) {
            return self.events[self.position - num_items .. self.position];
        } else {
            // Need to return items from end of buffer and start
            const items_from_end = self.events[MaxEvents - (num_items - self.position) ..];
            // const items_from_start = self.events[0..self.position];
            // Note: In real implementation, you'd need to handle
            // returning these two slices together somehow
            // Could use an array list or custom iterator
            return items_from_end;
        }
    }

    // Get events of specific type
    pub fn getEventsByType(self: *Self, event_type: EventType, max_items: usize) []const Event {
        var matching: [MaxEvents]Event = undefined;
        var count: usize = 0;

        // Start from most recent
        var i: usize = 0;
        while (i < @min(self.count, MaxEvents) and count < max_items) : (i += 1) {
            const idx = (self.position - 1 + MaxEvents - i) % MaxEvents;
            const event = self.events[idx];
            if (event.type == event_type) {
                matching[count] = event;
                count += 1;
            }
        }

        return matching[0..count];
    }

    // Clear all events
    pub fn clear(self: *Self) void {
        self.count = 0;
        self.position = 0;
    }

    // Example: Find last event of specific type
    pub fn findLastEvent(self: *Self, event_type: EventType) ?Event {
        if (self.count == 0) return null;

        var i: usize = 0;
        while (i < @min(self.count, MaxEvents)) : (i += 1) {
            const idx = @mod(self.position - 1 + MaxEvents - i, MaxEvents);
            // const idx = std.math.mod() catch 0;
            const event = self.events[idx];
            if (event.type == event_type) {
                return event;
            }
        }

        return null;
    }
};

const Color = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    // Add more colors as needed
};

pub fn log(
    comptime level: LogLevel,
    comptime format: []const u8,
    args: anytype,
    event: ?Event,
    allocator: std.mem.Allocator,
) void {
    if (log_level) |current_level| {
        if (!level.shouldLog(current_level.*)) return;
    }
    const color = switch (level) {
        .debug => Color.blue,
        .info => Color.blue,
        .warning => Color.yellow,
        .err => Color.red,
    };

    // Print to CLI

    std.debug.print(color ++ "[{s}] " ++ format ++ Color.reset ++ "\n", .{@tagName(level)} ++ args);
    // std.debug.print("[{s}] " ++ format ++ "\n", .{@tagName(level)} ++ args);

    // Log to file if enabled
    if (log_file) |file| {
        const full_message = std.fmt.allocPrint(
            allocator,
            "[{s}] " ++ format ++ "\n",
            .{@tagName(level)} ++ args,
        ) catch return;
        defer allocator.free(full_message);

        file.writeAll(full_message) catch {};
    }

    // Add to event log if event provided
    if (event) |e| {
        if (event_log) |evt_log| {
            evt_log.log(e);
        }
    }

    // Update debug overlay if active
}

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
        try testing.expect(event.data.parameter_update.value == 0.5);
    }
}

test "log function" {
    const testing = std.testing;
    const tmp_allocator = testing.allocator;
    var e_log = EventLog.init();
    event_log = &e_log;

    // Test basic logging (will print to stderr during test)
    log(
        .info,
        "Test message with value: {d}",
        .{42},
        null,
        tmp_allocator,
    );

    // Test event logging
    log(
        .debug,
        "Parameter changed: {d}",
        .{0.5},
        Event{
            .type = .parameter_update,
            .data = .{
                .parameter_update = .{
                    .module = .COMP,
                    .param = 1,
                    .value = 0.5,
                },
            },
        },
        tmp_allocator,
    );

    // Verify event was logged
    const last_param_event = event_log.?.findLastEvent(.parameter_update);
    try testing.expect(last_param_event != null);
    if (last_param_event) |event| {
        try testing.expect(event.data.parameter_update.value == 0.5);
        try testing.expect(event.data.parameter_update.module == .COMP);
        try testing.expect(event.data.parameter_update.param == 1);
    }
}
