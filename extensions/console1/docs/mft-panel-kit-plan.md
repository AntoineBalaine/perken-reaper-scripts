# MFT panel on the shared panel kit

## Goal

Because the VR-09 plugin's theme, fonts and widgets now live in `extensions/reaziglib` as the modules `panel_theme`, `panel_fonts` and `panel_widgets`, the MFT panel can use them instead of its own copy of the Console One theme and its text-only cells. After this change the panel looks like the VR-09 panel: engraved cards, rotary dials, push buttons, lamps and recessed screens, in the embedded Saira Condensed and Librestile fonts.

## Decisions

- The panel stays a read-only mirror of the controller. The dials and the side buttons show the controller's state and do not act on a click. The Save, Cancel, LED test and calibration buttons are real buttons today and stay real.
- The accent of each card and dial is the module's color from the controller's color wheel (`hueToRgb`), so the panel matches the LEDs on the hardware.
- The settings form and the calibration wizard are rebuilt with the kit. The kit has no text input, so the five slot-name inputs stay raw `InputText` calls, drawn with the new theme.

## What exists today

- `src/mft/mft_imgui.zig` (392 lines) draws one window named `MFT`. Its module state is `ctx`, `disabled` and `ready`. `onTimer` creates the ReaImGui context when the panel is shown and drops it when it is hidden, because an unused context is garbage-collected.
- The 4x4 grid is bordered child windows with text: the parameter name, a gauge such as `[####----]` and `hold:fine`. The bottom two rows are module selectors with a colored border.
- The six side buttons are `Button` calls whose result is ignored.
- `src/mft/mft_theme.zig` (124 lines) parses `src/mft/resources/default_reaper_theme.ini`, a copy of the Console One theme, and pushes it as colors and style vars.
- `src/mft/mft_settings.zig` draws the settings rows as colored text, five `InputText` fields and two buttons.
- `src/mft/mft_tests.zig` runs `assertPanelBalanced` against `MockImGui` for four cases (IO, TRANSPORT, SETTINGS, and IO while calibrating).

What the build already gives us:

- `addMftTarget` in `console1/build.zig` calls `reaziglib.addSharedModules(reazig_dep, lib.root_module)`, and the `mft_test` step calls it too. So `@import("panel_theme")`, `@import("panel_fonts")` and `@import("panel_widgets")` work in `src/mft` without a build change.
- MFT and the kit use the same `reaper_imgui` module. MFT calls the tuple wrappers (`try imgui.Button(.{ ctx, ... })`), which return errors, and the kit calls `imgui.api.*` directly. Both can run in one frame.

## Why not the Console One components

Console One has its own widget set in `src/components` (`knob.zig`, `button.zig`, and the wrapper in `widgets.zig`). Because `reaper_mft` is a separate library that cannot import files outside `src/mft`, it cannot use them. The shared kit in reaziglib is reachable from both libraries, so the dial goes there.

## What has to change

### reaziglib

1. `src/panel/widgets.zig` gets a display-only dial. Because `knob` reacts to drags, the wheel and alt-click, a mirror cannot use it: a disabled knob is drawn dim, which would tell the player that the encoder is off. We split the drawing out of `knob` and call it from both.

```
fn drawKnobFace(panel: *Panel, at: Point, control: Control, value: i32, bipolar: bool, lit: c_int, hot: bool) void
    // the block of `knob` from `const dl = ...` to the pointer line, unchanged

pub fn knob(...)
    // the interaction as today, then
    drawKnobFace(panel, at, control, result, bipolar, lit, hot)

pub fn dial(panel: *Panel, control: Control, value: i32, label: []const u8, lit: ?c_int) void
    BeginGroup
    centeredValue(shownValue(control, value), knob_w, lit orelse accent(panel))
    at = cursorScreenPos(panel)
    Dummy(knob_w, knob_d + 8)
    drawKnobFace(panel, at, control, value, false, lit orelse accent(panel), false)
    centeredLabel(upper(label), knob_w, knob_label_lines)
    EndGroup
```

   `Control` is the existing struct of `widgets.zig`. A dial that has no mapped parameter is drawn with `lit = theme.text_dim` and the value 0.

2. `src/models/mock_imgui.zig` gets a mock for every function that the panel kit calls and the mock lacked, 18 in all, because the mock stops with the name of any function it does not know. Six of them are called by the widgets that MFT uses: `BeginTooltip`, `EndTooltip`, `DrawList_AddRectFilledMultiColor`, `GetTextLineHeight`, `PushTextWrapPos` and `PopTextWrapPos`. Each one is a field of `ImguiMocks` with a `const Name = &mockName;` line and a function, in the style of `mockGetCursorPosY`. `BeginTooltip` returns false and `GetTextLineHeight` returns 16.0. The others trace and return. Because the text wrap is a push and a pop, it has a pair category of its own, so that `assertBalanced` checks it.

3. A test for `dial` in `widgets.zig`, with the mock: a call draws and leaves the group and style stacks balanced.

4. `reaziglib/README.md`: the table of panel modules mentions the dial.

### console1, `src/mft`

5. `mft_imgui.zig`:
   - New imports: `const theme = @import("panel_theme");`, `const panel_fonts = @import("panel_fonts");`, `const widgets = @import("panel_widgets");`. The import `mft_theme` goes away.
   - New module state: `var fonts: panel_fonts.Fonts = .{};` and `var kit: widgets.Panel = .{};`.
   - `onTimer`: after `CreateContext` succeeds, `fonts = panel_fonts.create(ctx);`. When the context is dropped (hidden, or after a draw error), also `fonts = .{}; kit = .{};`, because the fonts belong to the context.
   - `draw`: set `kit.ctx = ctx; kit.fonts = fonts;`, then `theme.push(ctx)` with a deferred `theme.pop(ctx)`, and push `fonts.text` around the window when it is not null, as `vr09/src/ui.zig` does.
   - `drawCell` and `drawCellContents` are rewritten (see the layout below). `gauge` is deleted, with its test if it has one.
   - `color_pass`, `color_fail` and `color_muted` are replaced by `theme.green`, `theme.red` and `theme.grey`.
   - `hueToRgb`, `hsvToRgb` and `moduleColor` stay: they give the accent.
6. `mft_settings.zig`: `drawForm(ctx, globals)` becomes `drawForm(kit: *widgets.Panel, globals: *MftGlobals) !void`, and `row` draws a `widgets.display` that is lit with the accent when it is the cursor's row. The two buttons become `widgets.pushButton`.
7. `mft_theme.zig` and `resources/default_reaper_theme.ini` are deleted, together with their line in `mft_tests.zig` and the paragraph about the theme INI in `src/mft/README.md` (around line 159), which now says that the panel uses the shared panel kit.
8. `.github/workflows/mft.yml`: the release publishes bare binaries, and the SIL Open Font License asks that its text goes with the fonts. One matrix row (`linux-x86_64`) also copies `extensions/reaziglib/assets/fonts/*.txt` into `release-binaries/`, so that the release has the license files once.

## Layout

```
draw(globals)
    kit.ctx = ctx; kit.fonts = fonts
    theme.push(ctx); push fonts.text
    Begin("MFT")
        accent = moduleColor(globals, active)

        beginCard("MFT", null, null, accent)
            display(@tagName(active), accent, 140)
        endCard

        if active == SETTINGS
            drawForm(kit, globals)            // its own card

        beginCard("Encoders", null, null, accent)
            left column:  display("L1 Chain"), display("L2 Hide"), display("L3 FXsel")
            SameLine
            grid: for row in 0..3
                      for col in 0..3
                          drawCell(idx)
            SameLine
            right column: display("R1 Mute"), display("R2 Solo"), display("R3 Phase")
        endCard

        drawWizard(globals)                  // its own card
    End

drawCell(idx)
    if idx < 8
        mapped:   dial(control{0..100, unit "%"}, round(value * 100), parameter name, accent)
        unmapped: dial(control, 0, "K<n>", theme.text_dim)
        TRANSPORT: dial replaced by two centeredValue lines: rotationLabel, pressLabel
    else if moduleForCell(idx) is a module
        kit.accent = moduleColor(module)      // the lamp and the button take it
        lamp(kit.accent, lit = module == active)
        display(module_labels[idx - 8], lit ? kit.accent : theme.text_dim, cell_w)
    else
        display("-", theme.text_dim, cell_w)
```

The side buttons are `display` calls and not `pushButton` calls, because a button that reacts to the mouse and does nothing is misleading in a mirror.

`hold:fine` becomes a tooltip on each dial: `widgets.tooltip(kit, "Hold the encoder while turning for fine adjustment")`.

The calibration card holds a `lamp` colored by the step status (green for pass, red for fail, grey for pending and skipped), the step text as `centeredValue` lines, and the Retry, Skip, Next, Finish and Stop buttons as `pushButton`. The LED test is a `toggle`.

## Assumptions to check with assertions

- `kit.ctx == ctx` at the start of `draw`.
- A card that returns false from `beginCard` is not followed by `endCard`. This is the rule the existing comment about `BeginChild` states, and `beginCard` already pops its colors in that case.
- Every module has an accent: `std.debug.assert(moduleColor(...) != 0)`.

## Order of work and commits

Each commit builds with `zig build mft` and passes `zig build mft-test`, and the reaziglib commit passes the reaziglib tests too. Each file is formatted with `zig fmt`.

- [x] 1. `reaziglib: a display-only dial, and the mock functions that the panel kit needs`: items 1 to 4 above. Run `zig build test` in `extensions/reaziglib`, and the tests of vr09 (`zig build test` in `extensions/vr09`) because `knob` is refactored.
- [x] 2. One bash command removes `src/mft/mft_theme.zig` and `src/mft/resources/default_reaper_theme.ini`. Nothing else is created or moved.
- [x] 3. `mft: the panel is drawn with the shared panel kit`: item 5 and the removal of the theme from item 7 (the `mft_tests.zig` line and the README paragraph). Update `assertPanelBalanced` so that it sets `kit` and `fonts` the way `draw` expects, and add a case for a mapped and an unmapped dial.
- [x] 4. `mft: the settings form and the calibration wizard use the kit`: item 6, and a balanced-stack test for the settings form with a cursor on a row and on a slot field.
- [x] 5. `chore: ship the font licenses with the MFT release`: item 8.
- [ ] 6. Try it in REAPER (the extension is installed by `extensions/build-install.sh mft`; REAPER has to be restarted): show and hide the panel several times (the context is recreated each time), switch modules, open the settings, start a calibration, and look for ImGui errors in the console.

## Risks

- The fonts add about 220 KB to `reaper_mft`.
- The panel stops matching the look of Console One, which is the point of this change. The Console One panel is not touched.
- The kit's calls do not return errors, so an ImGui assertion that destroys the context is noticed at the next wrapper call, such as `Begin` on the next frame, and not at the call that caused it. `onTimer` already drops the context when `draw` fails, so the recovery stays the same.
- The release process changes by one step: a row of the CI matrix uploads the license files.
