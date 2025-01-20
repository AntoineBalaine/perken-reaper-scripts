# FEATURES
- implement re-entrancy protection
- Default fx mode: Channel Strip Panel [MODIFY BROWSER]
- track list panel? [PAGINATION + GUI]
- midi feedback upon state changes
- save preset?
# BUGS
- fix loading fx upon track validation
  - fix scrolling through the browser with the console
  - modify browser logic to account for insertion position in the channel strip
- `Auto` modifier
# ARCH
- use arenas
- Error handling: GUI, file reading, allocations
- validate state transitions at compile time?
# WIDGETS
- How can the knob display its «disabled» state?
# BUILD
- [fix] generate evts to be stored in evt log from logFn
- expose components such as Knob as modules?
- it would be clearer and safer to structure the call to external compiler like this (don’t forget to replicate in the test build):
```zig
const cpp_flags = [_][]const u8{
    "-c",
    "-fPIC",
    "-O2",
    "-std=c++14",
    b.fmt("-I{s}", .{wdl_dep.path("").getPath(b)}),
    "-DSWELL_PROVIDED_BY_APP",
};

inline for (comptime cppfiles) |cppfile| {
    const filearg = try std.fmt.allocPrint(
        b.allocator,
        "{s}.o",
        .{std.fs.path.basename(cppfile.getPath(b))},
    );
    const cxx = b.addSystemCommand(&[_][]const u8{
        if (target.result.isDarwin()) "clang" else "gcc",
    });
    cxx.addArgs(&cpp_flags);
    cxx.addArg("-o");
    lib.addObjectFile(cxx.addOutputFileArg(filearg));
    cxx.addFileArg(cppfile);
    cxx.step.dependOn(&php_cmd.step);
}
```

# midi feedback upon state changes
- fx_ctrl => implemented
- fx_sel
- mapping_panel,
- settings,
- startup,
- midi_learn,
- error_state,
# Error handling: GUI, file reading, allocations
# validate state transitions at compile time
# memory management: use arenas for session data
- temporary alloc,
- session-wide alloc (one a startup, one at close-up): use an arena
  if some config files can’t be found, embed basic config in the binary to provide them.
# build.zig: pull cpp dependencies from `zig fetch`
- https://github.com/travisstaloch/flatbufferz/blob/main/build.zig#L98
# save preset?
# track list panel
# fix loading fx upon track validation
# implement hiding the GUI
- toggle UI, toggle extension active
- toggleActionHook: toggle UI, toggle extension active
# implement re-entrancy protection
# `Auto` modifier
- must be active in EVERY MODE
# Default fx mode: Channel Strip Panel
# MODIFY BROWSER LOGIC TO ACCOUNT FOR INSERTION POSITION IN THE CHANNEL STRIP
# FIX SCROLLING THROUGH THE BROWSER WITH THE CONSOLE

features
build
nice to have

# Default fx mode: Channel Strip Panel
  * Open from settings menu
    Check that it's possible to go through the git history of a file in neovim.
    Add a default channel strip mode. Settings can transition to it, and it can only transition back to it.
    When open, it's assigned to a ModuleList, similar to the fx_sel mode.
    Buttons track 1 through track 5 can open it.
  * FX selection interface
    Modify (again) the fx_browser so that it returns the fx selection
    the fx_sel_panel should be re-used by the default fx for selecting a default fx.
    Update the UI from settings menu: default fX should have a circled numbered button that shows which track btns to click to open the panel.
  * Order configuration
    should be selectable from the settings menu

# MODIFY BROWSER LOGIC TO ACCOUNT FOR INSERTION POSITION IN THE CHANNEL STRIP
I’d like to rely on the re-entrancy for this - which requires replacing whatever module for which we’re trying to select.
-> browser replaces an fx
-> reaper calls csurf
-> mapstore checks existence of mapping
-> if doesn’t exists, creates one
-> dispatches an action to open the mapping panel

# WHAT TO DO WHEN THE RESOURCES FOLDER IS NOT FOUND
embed the resources folder in the binary and create the files.

# FIX SCROLLING THROUGH THE BROWSER WITH THE CONSOLE
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
