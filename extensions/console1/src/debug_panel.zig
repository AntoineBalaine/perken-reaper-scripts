const std = @import("std");
const imgui = @import("reaper_imgui");
const State = @import("statemachine.zig").State;
const utils = @import("utils");

const DEBUG_BUF_SIZE = 512;

pub fn drawDebugPanel(ctx: imgui.ContextPtr, state: *State) !void {
    if (try imgui.Begin(.{ ctx, "Debug Panel" })) {
        defer imgui.End(.{ctx}) catch {};

        var buf: [DEBUG_BUF_SIZE:0]u8 = undefined;

        const frame_rate = utils.safePrint(&buf, "Frame rate: {d:.0}", .{try imgui.GetFramerate(.{ctx})});
        try imgui.Text(.{ ctx, frame_rate });

        // Current State Section
        const mode_text = utils.safePrint(&buf, "Current Mode: {s}", .{@tagName(state.current_mode)});
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
            const track_text = utils.safePrint(&buf, "Last Touched Track: {?d}", .{state.current_tr_id});
            try imgui.Text(.{ ctx, track_text });
            const sel_count = utils.safePrint(&buf, "Selected tracks: {d}", .{state.selectedTracks.count()});
            try imgui.Text(.{ ctx, sel_count });

            var it = state.selectedTracks.iterator();
            while (it.next()) |entry| {
                const tr_text = utils.safePrint(&buf, "Track: {d}", .{entry.key_ptr.*});
                try imgui.Text(.{ ctx, tr_text });
            }

            switch (state.fx_ctrl.track_state.mode) {
                .multi_fx => |locs| {
                    inline for (comptime std.enums.values(@import("statemachine.zig").PhysicalModule)) |module| {
                        if (locs.get(module)) |loc| {
                            const loc_text = utils.safePrint(&buf, "{s} FX: {d}", .{ @tagName(module), loc.fx_index });
                            try imgui.Text(.{ ctx, loc_text });
                        }
                    }
                },
                .channel_strip => |strip| {
                    const strip_text = utils.safePrint(&buf, "Strip FX: {d}", .{strip.fx_index});
                    try imgui.Text(.{ ctx, strip_text });
                },
            }
        }
    }
}
