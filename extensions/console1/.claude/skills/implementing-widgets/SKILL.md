---
name: implementing-widgets
description: Step-by-step guide for implementing new GUI widgets, covering component structure, ImGui integration, theme/style application, and integration with panels and the main loop. Use in conjunction with state-machine-architecture and implementing-actions skills.
---

# Implementing GUI Widgets

This skill provides a step-by-step guide for implementing new GUI widgets in the REAPER Console1 extension. For understanding the overall architecture and how widgets fit into the action system, refer to the state-machine-architecture and implementing-actions skills.

## Step 1: Create Widget Component File

Widgets are individual UI components stored in the `src/components/` directory. Each widget typically has its own file.

Location: `src/components/<widget_name>.zig`

Example widget structure from `src/components/knob.zig` (lines 23-29):

```zig
pub const Knob = struct {
    id: [:0]const u8,
    value: f64 = 0.5,
    radius: f64 = 20.0,
    flags: ControlFlags = .{},
    pos: Position,
};
```

The struct holds the widget's configuration data. Not all widgets require a struct - simpler widgets may just export drawing functions directly.

## Step 2: Define Widget Function Signature

Widgets export a drawing function that renders the widget and returns interaction state.

Standard pattern from `src/components/knob.zig` (lines 73-78):

```zig
pub fn drawWidget(
    ctx: imgui.ContextPtr,
    value: *f64,
    id: [:0]const u8,
    flags: ControlFlags,
) !bool
```

Parameters:
- `ctx: imgui.ContextPtr` - ImGui context for all rendering operations
- `value: *f64` - Pointer to the widget's value (allows in-place modification)
- `id: [:0]const u8` - Unique identifier for this widget instance
- `flags: ControlFlags` - Control behavior flags (selected, disabled, etc.)

Return values:
- Simple widgets return `bool` - true when the user is interacting with the widget
- Complex widgets return union enums for more nuanced actions

Example of complex return from `src/components/mappingKnob.zig` (lines 24-32):

```zig
pub fn drawWidget(
    ctx: imgui.ContextPtr,
    value: f64,
    id: [:0]const u8,
    flags: ControlFlags,
    comptime cc: CCs,
    assignment_label: [:0]const u8,
    fx_params: []mapping_panel.FxParameter,
) !?Res  // Returns optional union enum

const Res = union(enum) {
    click,
    param_idx: u32,
    remove_mapping
};
```

## Step 3: Implement ImGui Layout and Rendering

Widgets use ImGui's DrawList API for custom rendering. The typical pattern involves:

1. Get the current cursor position
2. Calculate the widget's bounding rectangle
3. Optionally push a clip rect if the widget needs rendering boundaries
4. Get the draw list for rendering
5. Render graphics using DrawList functions
6. Create an invisible button for interaction detection
7. Advance the cursor to reserve space

Example from `src/components/knob.zig` (lines 88-98):

```zig
// Get current cursor position
var cur_pos = Position{ .x = undefined, .y = undefined };
try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

// Calculate widget rectangle
const total_width = @max(radius * 2, label_size.w);
const widget_rect = Rectangle{
    .min_x = cur_pos.x,
    .min_y = cur_pos.y,
    .max_x = cur_pos.x + total_width,
    .max_y = cur_pos.y + (radius + label_size.h) * val_disp + text_padding,
};
```

Push clip rect if needed (not all widgets require this):

```zig
try imgui.PushClipRect(.{ ctx, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, false });
defer imgui.PopClipRect(.{ctx}) catch {};
```

Get draw list and render graphics (from `src/components/knob.zig` lines 161-163):

```zig
const drwls = try imgui.GetWindowDrawList(.{ctx});

// Draw circle background
try imgui.DrawList_AddCircleFilled(.{ drwls, center_x, center_y, radius, circleColor, 16 });

// Draw arc showing value
try imgui.DrawList_AddArc(.{ drwls, center_x, center_y, radius, angle_min(), angle(value.*, 0, 1), arcColor, 16, 3.0 });

// Draw indicator triangle
try imgui.DrawList_AddTriangleFilled(.{ drwls, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, dotColor });
```

Create invisible button for interaction (from `src/components/button.zig` line 114):

```zig
_ = try imgui.InvisibleButton(.{ ctx, id, button_size, button_size });
```

Advance cursor with dummy to reserve space:

```zig
try imgui.Dummy(.{ ctx, widget_rect.max_x - widget_rect.min_x, widget_rect.max_y - widget_rect.min_y });
```

## Step 4: Detect User Interaction

After creating the invisible button, use ImGui's interaction detection functions to check if the user is interacting with the widget.

From `src/components/knob.zig` (lines 186-222):

```zig
fn YControl(ctx: imgui.ContextPtr, value: *f64, flags: ControlFlags) !bool {
    const active = try imgui.IsItemActive(.{ctx});
    const hovered = try imgui.IsItemHovered(.{ctx});

    if (active) {
        var delta_y: f64 = undefined;
        try imgui.GetMouseDragDelta(.{ ctx, &delta_y, imgui.MouseButton_Left, 0, 1 });

        // Calculate new value from drag
        const sensitivity = 0.005;
        value.* = std.math.clamp(value.* - delta_y * sensitivity, 0.0, 1.0);

        try imgui.ResetMouseDragDelta(.{ ctx, imgui.MouseButton_Left });
        return true;
    }

    return false;
}
```

Common interaction detection functions:
- `imgui.IsItemHovered()` - Check if mouse is over the invisible button
- `imgui.IsItemActive()` - Check if widget is being dragged or held
- `imgui.GetMouseDragDelta()` - Get drag distance for value calculation
- `imgui.ResetMouseDragDelta()` - Reset delta after processing

## Step 5: Access Theme Colors (Optional)

Because theme and style are applied at the beginning of the GUI loop via `PushStyle` in `src/gui_lib.zig`, widgets access already-applied colors through ImGui's style system.

From `src/components/knob.zig` (lines 144-153):

```zig
var circleColor = try imgui.GetStyleColor(.{ ctx, imgui.Col_TitleBg });
var dotColor = try imgui.GetStyleColor(.{
    ctx,
    if (active) imgui.Col_SliderGrabActive else imgui.Col_SliderGrab
});

if (isHovered and !active) {
    dotColor = adjustBrightness(dotColor, -30, false);
    circleColor = adjustBrightness(circleColor, 50, false);
}
```

The `adjustBrightness` helper function applies dynamic color adjustments:

```zig
pub inline fn adjustBrightness(color: c_int, amt: i8, no_alpha: bool) c_int {
    var rgba: RGBA = @bitCast(color);
    rgba.r = fixBrightness(rgba.r, amt);
    rgba.g = fixBrightness(rgba.g, amt);
    rgba.b = fixBrightness(rgba.b, amt);
    return @as(c_int, @bitCast(rgba));
}
```

Common ImGui color slots:
- `imgui.Col_TitleBg` - Background colors
- `imgui.Col_SliderGrab` - Interactive element colors
- `imgui.Col_SliderGrabActive` - Active state colors
- `imgui.Col_Text` - Text colors
- `imgui.Col_Button` - Button colors

You can also access REAPER theme colors directly via `Theme.clrs` from `src/theme/Theme.zig`.

## Step 6: Define Return Type

Widgets return data to indicate interaction state and pass information back to the calling panel.

Simple widgets return boolean:

```zig
pub fn drawWidget(ctx: imgui.ContextPtr, value: *f64, id: [:0]const u8, flags: ControlFlags) !bool {
    // ... widget implementation
    return active;  // true when user is interacting
}
```

Complex widgets return union enums for richer actions. From `src/components/mappingKnob.zig`:

```zig
const Res = union(enum) {
    click,              // Knob was clicked
    param_idx: u32,     // Parameter was selected from dropdown
    remove_mapping      // User requested to remove mapping
};

pub fn drawWidget(...) !?Res {
    // ... widget implementation
    if (knob_clicked) return .click;
    if (param_selected) return .{ .param_idx = selected_index };
    if (remove_clicked) return .remove_mapping;
    return null;  // No interaction
}
```

Panels convert these widget returns into mode-specific action types that flow through the dispatch system.

## Step 7: Create Widget Wrapper (Optional)

The widget wrapper system in `src/components/widgets.zig` provides a flexible calling convention with optional parameters.

Example from `src/components/widgets.zig` (lines 17-25):

```zig
pub const roundButton = function(&roundButtonWidget, 3, &.{
    imgui.ContextPtr,
    [:0]const u8,
    [:0]const u8,
    ?[:0]const u8,    // Optional tooltip
    ?f64,             // Optional radius
    ?button.TextPosition,  // Optional text position
    ?bool,            // Optional disabled flag
});
```

This allows calling the widget with or without optional parameters:

```zig
// With all parameters
try roundButton(.{ ctx, "Label", "id", "Tooltip text", 10.0, .above, false });

// With defaults for optional parameters
try roundButton(.{ ctx, "Label", "id", null, null, null, null });
```

To create a wrapper, register your widget function using the `function()` helper with the required parameter count and type array.

## Step 8: Integration into Panels

Panels call widgets and convert their return values into mode-specific actions.

Example from `src/fx_ctrl_panel.zig` (line 177):

```zig
if (try Knobs.drawWidget(
    ctx,
    &gain_prm.normalized,      // Value pointer
    gain_display_label,        // Label
    .{
        .no_val_display = gain_no_val_display,
        .disabled = gain_disabled
    }  // Flags
)) {
    rv = .{ .cc = .Inpt_Gain, .value = gain_prm.normalized };
}
```

The panel function returns an optional action type:

```zig
pub fn drawFxControlPanel(ctx: imgui.ContextPtr, globals: *Globals, translations: *TranslationStore) !?WidgetInput {
    var rv: ?WidgetInput = null;

    // Call widgets and check returns
    if (try someWidget(...)) {
        rv = .{ .cc = .SomeControl, .value = some_value };
    }

    return rv;
}
```

The main GUI loop in `src/gui_lib.zig` (lines 54-77) receives panel returns and wraps them in ModeAction:

```zig
switch (globals.state.current_mode) {
    .fx_ctrl => {
        if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals, &globals.translations)) |ctrl_input| {
            rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } };
        }
    },
    // ... other modes
}
```

The returned ModeAction is then dispatched through `src/imgui_loop.zig` to the action system.

## Common ImGui DrawList Functions

Frequently used rendering functions:

- `DrawList_AddCircleFilled(drwls, center_x, center_y, radius, color, segments)` - Filled circles
- `DrawList_AddCircle(drwls, center_x, center_y, radius, color, segments, thickness)` - Circle outlines
- `DrawList_AddArc(drwls, center_x, center_y, radius, angle_start, angle_end, color, segments, thickness)` - Arcs for knob wipers
- `DrawList_AddTriangleFilled(drwls, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, color)` - Triangle indicators
- `DrawList_AddText(drwls, x, y, color, text)` - Text rendering
- `DrawList_AddRectFilled(drwls, min_x, min_y, max_x, max_y, color, rounding, flags)` - Filled rectangles
- `DrawList_AddLine(drwls, x1, y1, x2, y2, color, thickness)` - Lines and borders

## Control Flags Pattern

The `ControlFlags` struct pattern from `src/components/knob.zig` (lines 35-43):

```zig
pub const ControlFlags = packed struct {
    selected: bool = false,           // Widget is currently selected
    trackStart: TrackStart = .left,   // Track alignment hint
    disabled: bool = false,            // Widget is non-interactive
    no_val_display: bool = false,      // Hide value label
};
```

Panels pass flags to control widget behavior and appearance.

## Position and Rectangle Structures

Helper structures for layout calculations from `src/components/knob.zig`:

```zig
pub const Position = struct {
    x: f64,
    y: f64,
};

pub const Rectangle = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
};
```

These structures simplify coordinate calculations and bounding box management for widget layout.
