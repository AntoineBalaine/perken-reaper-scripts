SCROLLING THROUGH THE BROWSER WITH THE CONSOLE
Now, the idea here is that it’s possible to browse through the list of mappings with a knob of the console. This requires a scroll action for the fx_sel mode.
In imgui, when scrolling through a menu, is there an api to find out the scroll position inside a menu, and is there an API for incrementing that scroll position/selection?
ImGui doesn't directly expose a scroll position for menu items, but there are a few approaches we could use:

1. **Manual Selection Tracking**
```zig
pub const ModuleSelectionState = struct {
    current_index: usize = 0,
    items_count: usize = 0,
    section: enum { mapped, unmapped } = .mapped,
};

pub fn ModulePopup(
    ctx: imgui.ContextPtr,
    module: config.ModulesList,
    mappings: std.StringHashMap(void),
    selection: *ModuleSelectionState,
) !void {
    // ... window setup ...

    if (try imgui.BeginChild(.{ ctx, "mapped_fx_list", .{ .w = 0, .h = 150 } })) {
        defer imgui.EndChild(.{ctx}) catch {};

        // Update total count
        selection.items_count = mappings.count();

        var iterator = mappings.iterator();
        var index: usize = 0;
        while (iterator.next()) |entry| {
            const fx_name = entry.key_ptr.*;

            // Set colors/highlight for current selection
            if (index == selection.current_index and selection.section == .mapped) {
                try imgui.PushStyleColor(.{ ctx, .text, 0xFF00FFFF });
                // Optionally scroll to make selection visible
                if (try imgui.IsItemVisible(.{ctx}) == false) {
                    try imgui.SetScrollHereY(.{ ctx, 0.5 }); // 0.5 = center
                }
            }

            const is_selected = try imgui.Selectable(.{
                ctx,
                fx_name,
                .{ .selected = index == selection.current_index },
            });

            if (index == selection.current_index) {
                try imgui.PopStyleColor(.{ctx});
            }

            if (is_selected) {
                // Handle selection...
            }

            index += 1;
        }
    }
}

// In your action handler:
pub fn handleScroll(state: *State, delta: i32) void {
    if (state.current_mode == .fx_sel) {
        const new_index = @intCast(usize, @max(0,
            @min(
                state.fx_sel.current_index + delta,
                state.fx_sel.items_count - 1
            )));
        state.fx_sel.current_index = new_index;
    }
}
```

2. **Using ListBox/ListClipper**
```zig
// Alternative approach using ListBox
if (try imgui.BeginListBox(.{ ctx, "##mapped_fx" })) {
    defer imgui.EndListBox(.{ctx}) catch {};

    var clipper = try imgui.ListClipper.begin(.{
        ctx,
        mappings.count(),
    });

    while (try clipper.step()) {
        var i: usize = clipper.DisplayStart;
        while (i < clipper.DisplayEnd) : (i += 1) {
            // Draw visible items only
            if (i == selection.current_index) {
                try imgui.SetItemDefaultFocus(.{ctx});
            }
            // ... draw item
        }
    }
}
```

The first approach gives you more control but requires more manual management. The second approach is more efficient for large lists but gives less control over the selection behavior.
