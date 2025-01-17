//! Event logger: keeps a ring buffer and some query methods
//! to retrieve events.
const std = @import("std");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const ModulesList = statemachine.ModulesList;
const c1 = @import("c1.zig");
// const debugconfig = @import("config");
const logger = @import("logger.zig");
const Event = logger.Event;
const EventType = logger.EventType;

const RingBufferType = @import("ring_buffer.zig").RingBufferType;

const Self = @This();
const RingBuffer = RingBufferType(Event, .{ .array = 128 });

ring_buffer: RingBuffer,

pub fn init() Self {
    return .{
        .ring_buffer = RingBuffer.init(),
    };
}

pub fn log(self: *Self, event: Event) void {
    self.ring_buffer.push(event) catch {
        // If buffer is full, remove oldest event and try again
        _ = self.ring_buffer.pop();
        self.ring_buffer.push(event) catch unreachable;
    };
}

pub fn recent(self: *Self, comptime max_items: usize) []const Event {
    const count_max = @TypeOf(self.ring_buffer).count_max;
    if (max_items > count_max) {
        @compileError(std.fmt.comptimePrint("Too many max items. Found {d}, expected {d}.", .{ max_items, count_max }));
    }
    const count = @min(max_items, self.ring_buffer.count);
    var result: [count_max]Event = undefined;

    var found: usize = 0;
    var it = self.ring_buffer.reverse_iterator();
    while (it.next()) |event| {
        if (found >= count) break;
        result[found] = event;
        found += 1;
    }

    // Shrink slice to actual size
    return result[0..found];
}

pub fn getEventsByType(self: *Self, event_type: EventType, comptime max_items: usize) []const Event {
    const count_max = @TypeOf(self.ring_buffer).count_max;
    if (max_items > count_max) {
        @compileError(std.fmt.comptimePrint("Too many max items. Found {d}, expected {d}.", .{ max_items, count_max }));
    }
    var result: [count_max]Event = undefined;
    var found: usize = 0;

    var it = self.ring_buffer.reverse_iterator();
    while (it.next()) |event| {
        if (found >= max_items) break;
        if (@as(EventType, event) == event_type) {
            result[found] = event;
            found += 1;
        }
    }

    // Shrink slice to actual size
    return result[0..found];
}

pub fn clear(self: *Self) void {
    self.ring_buffer.clear();
}

pub fn findLastEvent(self: *Self, event_type: EventType) ?Event {
    var i: usize = 0;
    while (i < self.ring_buffer.count) : (i += 1) {
        if (self.ring_buffer.get(self.ring_buffer.count - 1 - i)) |event| {
            if (@as(EventType, event) == event_type) {
                return event;
            }
        }
    }
    return null;
}

test "EventLogger" {
    const testing = std.testing;
    var event_logger = Self.init();
    // Test logging events
    event_logger.log(.{
        .state_change = .{
            .old_mode = .fx_ctrl,
            .new_mode = .fx_sel,
        },
    });

    event_logger.log(.{
        .midi_input = .{
            .cc = .Comp_Attack,
            .value = 64,
        },
    });

    // Test recent events
    {
        const recent_events = event_logger.recent(2);

        try testing.expectEqual(@as(usize, 2), recent_events.len);
        try testing.expect(recent_events[0] == .midi_input);
        try testing.expect(recent_events[1] == .state_change);
    }

    // Test getting events by type
    {
        const midi_events = event_logger.getEventsByType(.midi_input, 10);

        try testing.expectEqual(@as(usize, 1), midi_events.len);
        try testing.expect(midi_events[0] == .midi_input);
    }

    // Test finding last event of specific type
    if (event_logger.findLastEvent(.state_change)) |event| {
        try testing.expect(event == .state_change);
        try testing.expectEqual(Mode.fx_ctrl, event.state_change.old_mode);
        try testing.expectEqual(Mode.fx_sel, event.state_change.new_mode);
    } else {
        try testing.expect(false);
    }

    // Test clear
    event_logger.clear();
    try testing.expect(event_logger.ring_buffer.empty());

    // Test buffer overflow
    var i: usize = 0;
    while (i < 130) : (i += 1) {
        event_logger.log(.{
            .parameter_update = .{
                .module = .COMP,
                .param = @as(u32, @intCast(i)),
                .value = 0.5,
            },
        });
    }

    try testing.expectEqual(@as(usize, 128), event_logger.ring_buffer.count);
}
