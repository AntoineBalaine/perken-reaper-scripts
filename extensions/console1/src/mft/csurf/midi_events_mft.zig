const std = @import("std");
const mft_globals = @import("../mft_globals.zig");
const builtin = @import("builtin");
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
const reaper = @import("reaper").reaper;
const mft = @import("../mft.zig");
const MftGlobals = @import("../mft_globals.zig").MftGlobals;
const mft_state = @import("../mft_state.zig");
const MftActiveModule = mft_state.MftActiveModule;
const mappings = @import("../mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_fx = @import("../mft_fx.zig");
const mft_transport = @import("../mft_transport.zig");
const mft_auto = @import("../mft_auto.zig");
const mft_fxsel = @import("../mft_fxsel.zig");
const mft_presets = @import("../mft_presets.zig");
const browser_source = @import("../mft_browser_source.zig");
const mft_settings = @import("../mft_settings.zig");
const midi_out = @import("../midi_out_mft.zig");
const mft_feedback = @import("../mft_feedback.zig");
const log = std.log.scoped(.mft_midi);

pub fn OnMidiEvent(evt: *c.MIDI_event_t, globals: *MftGlobals) void {
    const msg = c.MIDI_event_message(evt);
    const status = msg[0] & 0xf0;
    const chan = msg[0] & 0x0f;
    const cc = if (status == 0xb0) msg[1] else msg[0];
    const val = if (status == 0xb0) msg[2] else msg[1];

    // While calibration is running, every event is captured by the wizard
    // instead of driving parameters or switching modules.
    if (globals.wizard.active) {
        globals.wizard.onMidi(chan, cc, val);
        return;
    }

    // The FX SEL mode takes over the encoders: nothing reaches the page while it is open. The side keys stay as they are.
    if (globals.mft.fxsel) |*state| {
        if (chan == mft.ENCODER_ROT_CHANNEL or chan == mft.ENCODER_BTN_CHANNEL) {
            onFxSelEvent(state, chan, cc, val, globals);
            return;
        }
    }

    switch (chan) {
        mft.ENCODER_ROT_CHANNEL => onEncoderRotation(cc, val, globals),
        mft.ENCODER_BTN_CHANNEL => onEncoderButton(cc, val, globals),
        mft.SIDE_BTN_CHANNEL => onSideButton(cc, val, globals),
        else => {},
    }
}

// Sends the colors and the rings that the controller shows now: those of the FX SEL mode while it is open, and those of the page otherwise.
fn showCurrentFrame(globals: *MftGlobals) void {
    if (globals.m_midi_out) |mo| {
        const hues = if (globals.mft.fxsel != null) globals.preferences.fxselHues() else globals.preferences.pageHues(globals.mft.active_module);
        midi_out.sendPageColors(mo, hues);
    }
    midi_out.syncRings(globals, true);
}

/// Opens the FX SEL mode on the module of the page in use, or on the EQ when the page has none.
pub fn openFxSel(globals: *MftGlobals) void {
    var state = mft_fxsel.FxSelState{};
    state.module = MappableModule.fromActive(globals.mft.active_module) orelse .EQ;
    state.return_page = globals.mft.active_module;
    globals.mft.fxsel = state;
    showCurrentFrame(globals);
}

/// Closes the FX SEL mode and goes back to a page.
pub fn closeFxSel(globals: *MftGlobals, page: MftActiveModule) void {
    globals.mft.fxsel = null;
    globals.mft.active_module = page;
    showCurrentFrame(globals);
}

fn onFxSelEvent(state: *mft_fxsel.FxSelState, chan: u8, cc: u8, val: u8, globals: *MftGlobals) void {
    const io = mft_globals.hostIo();
    state.setNote("");
    var outcome: mft_fxsel.Outcome = .none;
    // The browser's levels come from the plugins that REAPER has, which are read the first time that the browser is open.
    const source = if (state.screen == .browse) browser_source.get(globals, state.browser.count) else null;
    if (chan == mft.ENCODER_ROT_CHANNEL) {
        outcome = mft_fxsel.turn(state, cc, mft.decodeRelative(val), source);
    } else {
        const pressed = val == 127;
        if (cc < 8) globals.mft.activity.markPress(cc, pressed, std.Io.Timestamp.now(io, .awake).toMilliseconds());
        if (!pressed) return;
        outcome = mft_fxsel.press(state, cc, source);
    }
    applyOutcome(globals, state, outcome);
}

/// Does what an event of the FX SEL mode asked for, beyond the change of its state. The events of the controller come here at once, and those of the
/// window through `pollFxSel`.
pub fn applyOutcome(globals: *MftGlobals, state: *mft_fxsel.FxSelState, outcome: mft_fxsel.Outcome) void {
    const io = mft_globals.hostIo();
    switch (outcome) {
        .none => {},
        .leave => closeFxSel(globals, state.return_page),
        .fill_browser => globals.map_store.listFx(io, state.module, &state.browser),
        .load_plugin => |name| {
            const track = globals.current_track orelse {
                state.setNote("There is no track to load the plugin on.");
                return;
            };
            if (mft_fx.loadPlugin(track, state.module, name)) {
                // The controller goes to the page of the module that got the plugin.
                closeFxSel(globals, mft_fxsel.pageOf(state.module));
            } else {
                state.setNote("The plugin could not be loaded: the track has a channel strip, or REAPER could not add it.");
            }
        },
        .fill_presets => {
            state.presets.clear();
            const track = globals.current_track orelse return;
            const fx = mft_fx.fxForModule(track, state.module) orelse {
                state.setNote("This module has no plugin on the track.");
                return;
            };
            mft_presets.listNames(io, track, fx, &state.presets);
        },
        .load_preset => |name| {
            const track = globals.current_track orelse return;
            const fx = mft_fx.fxForModule(track, state.module) orelse {
                state.setNote("This module has no plugin on the track.");
                return;
            };
            if (mft_presets.load(track, fx, name)) closeFxSel(globals, mft_fxsel.pageOf(state.module)) else state.setNote("The preset could not be loaded.");
        },
        .save_preset => |name| {
            const track = globals.current_track orelse {
                state.setNote("There is no track to save the preset from.");
                return;
            };
            const fx = mft_fx.fxForModule(track, state.module) orelse {
                state.setNote("This module has no plugin on the track.");
                return;
            };
            if (mft_presets.save(io, track, fx, name)) {
                closeFxSel(globals, mft_fxsel.pageOf(state.module));
            } else |err| {
                var buf: [96]u8 = undefined;
                state.setNote(std.fmt.bufPrint(&buf, "The preset could not be saved ({s}).", .{@errorName(err)}) catch "The preset could not be saved.");
            }
        },
        .not_done => |action| {
            var buf: [96]u8 = undefined;
            state.setNote(std.fmt.bufPrint(&buf, "{s} is not done yet.", .{action.label()}) catch "Not done yet.");
        },
    }
}

/// Carries out what the window of the FX SEL mode chose. The window draws in the timer of the panel, which does not load plugins, so it leaves its
/// choice in the state and the run of the surface does it.
pub fn pollFxSel(globals: *MftGlobals) void {
    const state = &(globals.mft.fxsel orelse return);
    const outcome = state.pending;
    state.pending = .none;
    if (outcome != .none) applyOutcome(globals, state, outcome);
}

fn onEncoderRotation(cc: u8, val: u8, globals: *MftGlobals) void {
    const io = mft_globals.hostIo();
    if (cc >= mappings.knob_count) return;
    const slot: u4 = @intCast(cc);

    const delta = mft.decodeRelative(val);
    if (delta == 0) return;

    // Transport mode drives its own continuous functions; settings mode has none
    // yet. Only a mappable module routes to FX parameters.
    switch (globals.mft.active_module) {
        .TRANSPORT => {
            // The bottom row has its own functions: the loop, the volume and the pan.
            if (slot >= 8) {
                mft_transport.onBottomRotate(slot - 8, delta, globals.current_track);
                return;
            }
            globals.mft.activity.markTurn(slot, std.Io.Timestamp.now(io, .awake).toMilliseconds());
            // Knob 3 held + turned does vertical zoom instead of horizontal.
            if (slot == 2 and globals.mft.isHeld(2)) {
                globals.mft.transport_turned = true;
                mft_transport.zoomVertical(delta);
            } else {
                mft_transport.onRotate(@intCast(slot), delta);
            }
            return;
        },
        .SETTINGS => return settingsRotate(globals, slot, delta),
        // The AUTO page has no knob that does anything yet.
        .AUTO => return,
        else => {},
    }

    globals.mft.markTurnedIfHeld(cc);
    const fine: f32 = if (globals.mft.isHeld(cc)) mft.FINE_SENSITIVITY_MULTIPLIER else 1.0;
    const delta_f32 = @as(f32, @floatFromInt(delta)) * mft.BASE_SENSITIVITY * fine * globals.preferences.sensitivity;

    const module = MappableModule.fromActive(globals.mft.active_module) orelse return;
    const track = globals.current_track orelse return;
    const routing = mft_fx.resolveModule(globals, track, module);
    const target = routing.targets[slot] orelse return;

    globals.mft.last_fx_index = target.fx_index;
    const current = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
    const new_val = std.math.clamp(current + @as(f64, delta_f32), 0.0, 1.0);
    _ = reaper.TrackFX_SetParamNormalized(track, target.fx_index, @intCast(target.param), new_val);

    // When the FX chain window is open, focus the plugin whose parameter is
    // being tweaked, so switching modules brings that module's FX to the front.
    if (reaper.TrackFX_GetChainVisible(track) != -1) {
        reaper.TrackFX_Show(track, target.fx_index, 1);
    }

    // Because REAPER also reports the move of the parameter, the ring may be told twice: it is sent once, since the byte is kept.
    midi_out.setRing(globals, slot, mft_feedback.ringByte(new_val));
}

fn wrapHue(cur: u8, delta: i8) u8 {
    return @intCast(@mod(@as(i16, cur) + delta, 128));
}

// Settings mode: encoder 1 scrolls the highlighted row, encoder 2 adjusts the
// selected value. Text (plugin name) rows are edited with the keyboard in the
// panel, so encoder 2 has no effect on them.
fn settingsRotate(globals: *MftGlobals, slot: u4, delta: i8) void {
    switch (slot) {
        0 => {
            const n = @as(i16, globals.mft.settings_cursor) + delta;
            globals.mft.settings_cursor = @intCast(@mod(n, mft_settings.ITEM_COUNT));
        },
        1 => adjustSelectedSetting(globals, delta),
        else => {},
    }
}

fn adjustSelectedSetting(globals: *MftGlobals, delta: i8) void {
    const cursor = globals.mft.settings_cursor;
    // The colors come first, in the order of the pages, then the sensitivity; the rest are plugin-name rows,
    // which only the keyboard edits. The mouse of the panel changes the same values through the same functions.
    if (cursor < mft_state.page_count) {
        const module: MftActiveModule = @fromBackingInt(@intCast(cursor));
        const hue = wrapHue(globals.preferences.colorForModule(module), delta);
        mft_settings.setHue(globals, module, hue);
    } else if (cursor == mft_settings.SENSITIVITY_ROW) {
        const next = globals.preferences.sensitivity + @as(f32, @floatFromInt(delta)) * mft_settings.SENSITIVITY_STEP;
        mft_settings.setSensitivity(globals, next);
    }
}

// Sends a hue to the LEDs of the controller, when it is connected. The settings install it as the way to send colors.
fn sendHue(globals: *MftGlobals, hue: u8) void {
    // The hue was already stored in the preferences, so the LEDs are sent from them.
    _ = hue;
    if (globals.m_midi_out) |mo| {
        const hues = if (globals.mft.fxsel != null) globals.preferences.fxselHues() else globals.preferences.pageHues(globals.mft.active_module);
        midi_out.sendPageColors(mo, hues);
    }
}

pub fn installSettingsHook() void {
    mft_settings.send_hue = &sendHue;
}

// Knob 3 uses press-and-turn for vertical zoom, so its click action (fit
// horizontal) is deferred to release and suppressed when a turn happened while
// held. The other knobs fire their press action immediately.
fn transportButton(globals: *MftGlobals, idx: u3, pressed: bool) void {
    if (idx == 2) {
        if (pressed) {
            globals.mft.setHeld(2);
            globals.mft.transport_turned = false;
        } else {
            if (globals.mft.isHeld(2) and !globals.mft.transport_turned) {
                mft_transport.onPress(2);
            }
            globals.mft.clearHeld(2);
        }
        return;
    }
    if (pressed) mft_transport.onPress(idx);
}

// A click on the push of an encoder: it does what the map of the page gives that push.
fn pushClick(globals: *MftGlobals, push: u3) void {
    const module = MappableModule.fromActive(globals.mft.active_module) orelse return;
    const track = globals.current_track orelse return;
    const routing = mft_fx.resolveModule(globals, track, module);
    const route = routing.pushes[push] orelse return;
    globals.mft.last_fx_index = route.fx_index;
    var note: [32:0]u8 = undefined;
    mft_fx.runPush(track, route, &note);
    const text = std.mem.sliceTo(&note, 0);
    if (text.len > 0) globals.mft.push_note.set(push, text, std.Io.Timestamp.now(mft_globals.hostIo(), .awake).toMilliseconds());
}

fn onEncoderButton(cc: u8, val: u8, globals: *MftGlobals) void {
    const io = mft_globals.hostIo();
    const pressed = val == 127;
    if (cc < 8) {
        // Presses on the top two rows depend on the active mode. In a mappable
        // module they arm fine-tune; in transport mode they drive transport.
        switch (globals.mft.active_module) {
            .TRANSPORT => {
                globals.mft.activity.markPress(cc, pressed, std.Io.Timestamp.now(io, .awake).toMilliseconds());
                transportButton(globals, @intCast(cc), pressed);
            },
            .SETTINGS => {},
            .AUTO => {
                globals.mft.activity.markPress(cc, pressed, std.Io.Timestamp.now(io, .awake).toMilliseconds());
                if (pressed) if (globals.current_track) |track| mft_auto.onPress(track, cc);
            },
            // On a page, a turn with the push down is a fine adjustment, and a push that is released without a turn is a click.
            else => if (pressed) globals.mft.setHeld(cc) else if (globals.mft.releaseIsClick(cc)) pushClick(globals, @intCast(cc)),
        }
        return;
    }
    if (!pressed) return;
    const module = mft_state.pageForEncoder(cc) orelse return;
    globals.mft.active_module = module;

    // Switching to a mappable module auto-inserts its default plugins onto the
    // current track if absent, matching the Console One behavior.
    if (MappableModule.fromActive(module)) |mappable| {
        if (globals.current_track) |track| {
            mft_fx.ensureModuleFx(globals, track, mappable);
        }
    }

    if (globals.m_midi_out) |mo| {
        midi_out.sendPageColors(mo, globals.preferences.pageHues(module));
    }
    // The rings stood for the parameters of the module that was left: they now show the ones of this module.
    midi_out.syncRings(globals, true);
}

fn onSideButton(cc: u8, val: u8, globals: *MftGlobals) void {
    const io = mft_globals.hostIo();
    // The panel lights a key while it is down and for a moment after, so the release counts too.
    for (mft.SIDE_BUTTON_CCS, 0..) |key_cc, key| {
        if (key_cc == cc) globals.mft.activity.markSide(key, val == 127, std.Io.Timestamp.now(io, .awake).toMilliseconds());
    }
    if (val != 127) return;
    // Side buttons on channel 4, CCs 8-13: L1-L3 then R1-R3. L2 (panel toggle)
    // needs no track; the others act on the current track when there is one.
    if (cc == mft.SIDE_BUTTON_CCS[1]) {
        // L2 hides the panel on the transport page, and bypasses the plugin of the page on the pages that have one.
        if (globals.mft.active_module == .TRANSPORT) {
            globals.mft.panel_visible = !globals.mft.panel_visible;
        } else if (MappableModule.fromActive(globals.mft.active_module)) |module| {
            if (globals.current_track) |track| mft_fx.toggleBypass(track, module);
        }
        return;
    }
    if (cc == mft.SIDE_BUTTON_CCS[2]) {
        // L3 opens the FX SEL mode, and closes it when it is open.
        if (globals.mft.fxsel) |state| closeFxSel(globals, state.return_page) else openFxSel(globals);
        return;
    }
    const track = globals.current_track orelse return;
    switch (cc) {
        mft.SIDE_BUTTON_CCS[0] => { // L1: toggle the active module's FX chain
            if (MappableModule.fromActive(globals.mft.active_module)) |module| {
                if (mft_fx.moduleFxToShow(globals, track, module, globals.mft.last_fx_index)) |fx| {
                    mft_fx.toggleFxChain(track, fx);
                }
            }
        },
        mft.SIDE_BUTTON_CCS[3] => mft_fx.toggleMute(track), // R1
        mft.SIDE_BUTTON_CCS[4] => mft_fx.toggleSolo(track), // R2
        mft.SIDE_BUTTON_CCS[5] => mft_fx.togglePhase(track), // R3
        else => {},
    }
}
