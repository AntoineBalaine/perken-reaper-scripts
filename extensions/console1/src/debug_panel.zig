const std = @import("std");
const imgui = @import("reaper_imgui");
const State = @import("statemachine.zig").State;

const DEBUG_BUF_SIZE = 512;

pub fn safePrint(buf: [:0]u8, comptime fmt: []const u8, args: anytype) [:0]const u8 {
    return std.fmt.bufPrintZ(buf, fmt, args) catch |err| switch (err) {
        error.NoSpaceLeft => blk: {
            const ellipsis = "…";
            const end = buf.len - ellipsis.len - 1;
            @memcpy(buf[end .. end + ellipsis.len], ellipsis);
            buf[end + ellipsis.len] = '\x00';
            break :blk @as([:0]const u8, buf[0 .. end + ellipsis.len :0]);
        },
    };
}

pub fn drawDebugPanel(ctx: imgui.ContextPtr, state: *State) !void {
    if (try imgui.Begin(.{ ctx, "Debug Panel" })) {
        defer imgui.End(.{ctx}) catch {};

        var buf: [DEBUG_BUF_SIZE:0]u8 = undefined;

        const frame_rate = safePrint(&buf, "Frame rate: {d:.0}", .{try imgui.GetFramerate(.{ctx})});
        try imgui.Text(.{ ctx, frame_rate });

        // Current State Section
        const mode_text = safePrint(&buf, "Current Mode: {s}", .{@tagName(state.current_mode)});
        try imgui.TextWrapped(.{ ctx, mode_text });

        if (try imgui.CollapsingHeader(.{ ctx, "Recent Events" })) {
            if (try imgui.BeginTable(.{ ctx, "Events", 3 })) {
                defer imgui.EndTable(.{ctx}) catch {};
                // defer imgui.EndTable(.{ctx}) catch {};

                try imgui.TableSetupColumn(.{ ctx, "Type" });
                try imgui.TableSetupColumn(.{ ctx, "Details" });
                try imgui.TableHeadersRow(.{ctx});

                // Get recent events (last 10 for example)
            }
        }

        if (try imgui.CollapsingHeader(.{ ctx, "Track State" })) {
            const track_text = safePrint(&buf, "Last Touched Track: {?}", .{state.current_tr_id});
            try imgui.Text(.{ ctx, track_text });
            const sel_count = safePrint(&buf, "Selected tracks: {?}", .{state.selectedTracks.count()});
            try imgui.Text(.{ ctx, sel_count });

            var it = state.selectedTracks.iterator();
            while (it.next()) |entry| {
                const tr_text = safePrint(&buf, "Track: {d}", .{entry.key_ptr.*});
                try imgui.Text(.{ ctx, tr_text });
            }

            if (state.fx_ctrl.track_state.module_locations.get(.COMP)) |comp| {
                const comp_text = safePrint(&buf, "Comp FX: {d}", .{comp.fx_index});
                try imgui.Text(.{ ctx, comp_text });
            }
        }
    }
}

test "safePrint" {
    const testing = std.testing;
    const expect = testing.expect;
    const expectEqualStrings = testing.expectEqualStrings;

    // Test buffer that's large enough
    {
        var buf: [32:0]u8 = undefined;
        const result = safePrint(&buf, "test {d}", .{42});
        try expectEqualStrings("test 42", result);
    }

    // Test buffer that's exactly the right size (including null terminator)
    {
        var buf: [8:0]u8 = undefined;
        const result = safePrint(&buf, "test {d}", .{42});
        try expectEqualStrings("test 42", result);
    }

    // Test truncation
    {
        var buf: [7:0]u8 = undefined;
        const result = safePrint(&buf, "test {d}", .{42});
        try expectEqualStrings("tes…", result);
    }

    // Test very small buffer
    {
        var buf: [4:0]u8 = undefined;
        const result = safePrint(&buf, "test this", .{});
        try expectEqualStrings("…", result);
    }

    // Test empty format string
    {
        var buf: [8:0]u8 = undefined;
        const result = safePrint(&buf, "", .{});
        try expectEqualStrings("", result);
    }

    // Verify null termination
    {
        var buf: [8:0]u8 = undefined;
        _ = safePrint(&buf, "test", .{});
        try expect(buf[4] == 0);
    }
}
