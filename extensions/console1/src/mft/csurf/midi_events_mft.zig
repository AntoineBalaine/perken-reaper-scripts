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
const mft_push = @import("../mft_push.zig");
const mft_transport = @import("../mft_transport.zig");
const mft_auto = @import("../mft_auto.zig");
const mft_fxsel = @import("../mft_fxsel.zig");
const mft_presets = @import("../mft_presets.zig");
const browser_source = @import("../mft_browser_source.zig");
const map_store = @import("../mft_map_store.zig");
const mft_settings = @import("../mft_settings.zig");
const settings_rows = @import("../mft_settings_rows.zig");
const midi_out = @import("../midi_out_mft.zig");
const mft_feedback = @import("../mft_feedback.zig");
const log = std.log.scoped(.mft_midi);

pub fn OnMidiEvent(evt: *c.MIDI_event_t, globals: *MftGlobals) void {
    const msg = c.MIDI_event_message(evt);
    const status = msg[0] & 0xf0;
    const chan = msg[0] & 0x0f;
    const cc = if (status == 0xb0) msg[1] else msg[0];
    const val = if (status == 0xb0) msg[2] else msg[1];

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
        .fill_browser => if (state.strip_target) globals.map_store.listStrips(io, &state.browser) else globals.map_store.listFx(io, state.module, &state.browser),
        .load_plugin => |name| {
            // A plugin that has several maps asks which one to load it with, on a screen of its own.
            const owner: map_store.Owner = if (state.strip_target) .strip else .{ .module = state.module };
            if (state.screen != .maps) {
                globals.map_store.listMaps(io, owner, name, &state.maps);
                if (state.maps.count > 1) {
                    mft_fxsel.openMaps(state, name, globals.map_store.defaultMapName(io, owner, name));
                    return;
                }
            }
            const track = globals.current_track orelse {
                state.setNote("There is no track to load the plugin on.");
                return;
            };
            const loaded = if (state.strip_target) mft_fx.loadStrip(globals, track, name) else mft_fx.loadPlugin(globals, track, state.module, name);
            if (loaded) {
                if (state.map_return) {
                    // The browser was opened from the mapping panel, which was open all along: it shows the new plugin, with the map that it has.
                    state.map_return = false;
                    state.screen = .map;
                    state.map_single = state.strip_target;
                    applyOutcome(globals, state, .open_mapping);
                    return;
                }
                // The controller goes to the page of the module that got the plugin.
                closeFxSel(globals, mft_fxsel.pageOf(state.module));
            } else {
                state.setNote("The plugin could not be loaded: the track has a channel strip, or REAPER could not add it.");
            }
        },
        .load_plugin_map => |map_name| {
            const owner: map_store.Owner = if (state.strip_target) .strip else .{ .module = state.module };
            globals.map_store.useMap(owner, state.mapsPlugin(), map_name) catch |err| {
                state.setNote("The map could not be chosen.");
                log.warn("failed to choose the map {s}: {s}", .{ map_name, @errorName(err) });
                return;
            };
            applyOutcome(globals, state, .{ .load_plugin = state.mapsPlugin() });
        },
        .set_default_map => |map_name| {
            const owner: map_store.Owner = if (state.strip_target) .strip else .{ .module = state.module };
            globals.map_store.setDefaultMap(io, owner, state.mapsPlugin(), map_name) catch |err| {
                log.warn("failed to save the default map: {s}", .{@errorName(err)});
                state.setNote(if (err == error.UnsupportedName) "A map whose name has an equal sign cannot be the default." else "The default map could not be written to default_maps.ini.");
                return;
            };
        },
        .set_default_plugin => |name| {
            // Because the name belongs to the list of the browser, the preferences keep a copy of their own, for the session.
            const owned = globals.arena.allocator().dupeSentinel(u8, name, 0) catch {
                state.setNote("The default could not be changed: out of memory.");
                return;
            };
            globals.preferences.setDefaultPlugin(state.module, state.strip_target, owned);
            // The settings panel reads the default plugins again the next time that it is drawn.
            mft_settings.markUnsynced();
            globals.preferences.saveToDisk(io, globals.resource_path) catch |err| {
                log.warn("failed to save the default plugin: {s}", .{@errorName(err)});
                state.setNote("The default is changed for this session, but preferences.ini could not be written.");
                return;
            };
        },
        .fill_presets => {
            state.presets.clear();
            const track = globals.current_track orelse return;
            const fx = (if (state.strip_target) mft_fx.findStrip(track) else mft_fx.fxForModule(track, state.module)) orelse {
                state.setNote("This module has no plugin on the track.");
                return;
            };
            mft_presets.listNames(io, track, fx, &state.presets);
        },
        .load_preset => |name| {
            const track = globals.current_track orelse return;
            const fx = (if (state.strip_target) mft_fx.findStrip(track) else mft_fx.fxForModule(track, state.module)) orelse {
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
            const fx = (if (state.strip_target) mft_fx.findStrip(track) else mft_fx.fxForModule(track, state.module)) orelse {
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
        .open_mapping => {
            // The mapping mode opens whatever the track has: the panel has a plate for every module, and a module that has no plugin says so.
            state.map_edits = @splat(.{});
            state.map_loaded = @splat(.{});
            state.map_fx_index = @splat(-1);
            state.map_error = @splat(@splat(0));
            for (&state.map_fx_name) |*name| name[0] = 0;
            // The AUTO page has no plugin: its map is there whatever the track has.
            state.map_auto = globals.map_store.getAuto(io);
            state.map_auto_loaded = state.map_auto;
            state.map_auto_error[0] = 0;
            state.map_strip = .{};
            state.map_strip_loaded = .{};
            state.map_strip_fx = -1;
            state.map_strip_name[0] = 0;
            state.map_strip_error[0] = 0;
            const track = globals.current_track orelse return;
            // The channel strip of the track, whose map the single FX mode edits. A track that has one opens in that mode.
            if (mft_fx.findStrip(track)) |strip_fx| {
                if (mft_fx.fxMapName(track, strip_fx, &state.map_strip_name)) |name| {
                    state.map_strip_fx = strip_fx;
                    state.map_strip = globals.map_store.getStrip(io, name) orelse .{};
                    state.map_strip_loaded = state.map_strip;
                    state.map_single = true;
                    state.strip_target = true;
                }
            }
            inline for (@typeInfo(MappableModule).@"enum".field_names) |field_name| {
                const module = @field(MappableModule, field_name);
                const i = mft_fxsel.moduleIndex(module);
                if (mft_fx.fxForModule(track, module)) |fx| {
                    if (mft_fx.fxMapName(track, fx, &state.map_fx_name[i])) |name| {
                        state.map_fx_index[i] = fx;
                        state.map_edits[i] = globals.map_store.get(io, module, name) orelse .{};
                        state.map_loaded[i] = state.map_edits[i];
                    }
                }
            }
        },
        .store_mapping => storeChangedMappings(globals, state),
        .save_mapping => {
            storeChangedMappings(globals, state);
            closeFxSel(globals, mft_fxsel.pageOf(state.module));
        },
    }
}

/// Saves the mappings of the modules that were changed, each as the user's map of its plugin. A map that cannot be saved leaves its reason for the panel,
/// which marks the plate of the module with it.
pub fn storeChangedMappings(globals: *MftGlobals, state: *mft_fxsel.FxSelState) void {
    const io = mft_globals.hostIo();
    if (state.map_strip_fx >= 0 and mft_fxsel.isStripChanged(state)) {
        const length = std.mem.sliceTo(&state.map_strip_name, 0).len;
        if (globals.map_store.saveStrip(io, state.map_strip_name[0..length :0], &state.map_strip)) {
            state.map_strip_loaded = state.map_strip;
            state.map_strip_error[0] = 0;
        } else |err| {
            _ = std.mem.printSentinel(&state.map_strip_error, "The map file could not be written: {s}.", .{@errorName(err)}, 0) catch {};
        }
    }
    if (mft_fxsel.isAutoChanged(state)) {
        if (globals.map_store.saveAuto(io, &state.map_auto)) {
            state.map_auto_loaded = state.map_auto;
            state.map_auto_error[0] = 0;
        } else |err| {
            _ = std.mem.printSentinel(&state.map_auto_error, "The map file could not be written: {s}.", .{@errorName(err)}, 0) catch {};
        }
    }
    inline for (@typeInfo(MappableModule).@"enum".field_names) |field_name| {
        const module = @field(MappableModule, field_name);
        const i = mft_fxsel.moduleIndex(module);
        if (state.map_fx_index[i] >= 0 and mft_fxsel.isChanged(state, module)) {
            const length = std.mem.sliceTo(&state.map_fx_name[i], 0).len;
            if (globals.map_store.saveUser(io, module, state.map_fx_name[i][0..length :0], &state.map_edits[i])) {
                state.map_loaded[i] = state.map_edits[i];
                state.map_error[i][0] = 0;
            } else |err| {
                _ = std.mem.printSentinel(&state.map_error[i], "The map file could not be written: {s}.", .{@errorName(err)}, 0) catch {};
            }
        }
    }
}

/// A parameter of an FX moved in REAPER. While the mapping mode is open, the selected control learns it, as the learn of the Console 1 does: touching a
/// parameter of the plugin that is being mapped gives it to the control.
pub fn learnParam(globals: *MftGlobals, track: reaper.MediaTrack, fx_index: u16, param: u16) void {
    const state = &(globals.mft.fxsel orelse return);
    if (state.screen != .map or !state.map_learn or track != globals.current_track) return;
    // The AUTO plate learns a parameter of any FX of the track, which it keeps by the name of the plugin.
    if (state.map_focus_auto) {
        var name_buf: [160:0]u8 = undefined;
        const name = mft_fx.fxMapName(track, fx_index, &name_buf) orelse return;
        mft_fxsel.assignAuto(state, state.map_selected, .{ .fx_param = mft_auto.FxParam.init(name, param) });
        storeChangedMappings(globals, state);
        return;
    }
    if (mft_fxsel.mapFx(state, state.module) != @as(c_int, fx_index)) return;
    mft_fxsel.assign(state, param);
    storeChangedMappings(globals, state);
}

/// Goes back from the SETTINGS page to the page that was in use before it, when Save or Cancel asked for it.
pub fn pollSettings(globals: *MftGlobals) void {
    if (!globals.mft.settings_leave) return;
    globals.mft.settings_leave = false;
    if (globals.mft.active_module != .SETTINGS) return;
    globals.mft.active_module = globals.mft.settings_return;
    showCurrentFrame(globals);
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
                // The third knob of the bottom row is the order of the modules of the track, which goes to the next or the previous order.
                if (slot == 8 + mft_transport.order_knob) {
                    turnOrder(globals, delta);
                    return;
                }
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
        // A knob of the AUTO page runs its action, or moves its parameter as the knobs of a module do.
        .AUTO => {
            const target = globals.map_store.getAuto(io).knobs[slot] orelse return;
            if (target != .fx_param) {
                if (mft_fx.autoCommand(target)) |id| reaper.Main_OnCommand(id, 0);
                return;
            }
        },
        else => {},
    }

    globals.mft.markTurnedIfHeld(cc);
    const fine: f32 = if (globals.mft.isHeld(cc)) globals.preferences.fine else 1.0;
    const delta_f32 = @as(f32, @floatFromInt(delta)) * mft.BASE_SENSITIVITY * fine * globals.preferences.sensitivity;

    const track = globals.current_track orelse return;
    const routing = if (globals.mft.active_module == .AUTO) mft_fx.resolveAuto(globals, track) else blk: {
        const module = MappableModule.fromActive(globals.mft.active_module) orelse return;
        break :blk mft_fx.resolveModule(globals, track, module);
    };
    const target = routing.targets[slot] orelse return;

    globals.mft.last_fx_index = target.fx_index;
    const current = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
    // A parameter with few steps (a list of choices, a switch) moves one step for a few ticks, and the others move with the turn.
    const stepping = mft_fx.paramStepping(track, target.fx_index, @intCast(target.param));
    const new_val = if (mft_push.turnsBySteps(stepping)) blk: {
        const steps = mft_push.countTicks(&globals.mft.step_ticks[slot], delta);
        if (steps == 0) return;
        break :blk mft_push.steppedValue(current, stepping, steps);
    } else std.math.clamp(current + @as(f64, delta_f32), 0.0, 1.0);
    _ = reaper.TrackFX_SetParamNormalized(track, target.fx_index, @intCast(target.param), new_val);

    // When the FX chain window is open, focus the plugin whose parameter is
    // being tweaked, so switching modules brings that module's FX to the front.
    if (reaper.TrackFX_GetChainVisible(track) != -1) {
        reaper.TrackFX_Show(track, target.fx_index, 1);
    }

    // Because REAPER also reports the move of the parameter, the ring may be told twice: it is sent once, since the byte is kept.
    midi_out.setRing(globals, slot, mft_feedback.ringByte(new_val));
}

// How many ticks of the first encoder of the SETTINGS page move the highlight by one row, as the list of the FX Selection counts them.
const settings_ticks_per_row = 4;

// The SETTINGS page: the first encoder moves the highlight through the rows, round from the last to the first, one row for a few ticks, and the second one
// adjusts the highlighted row. The mouse of the panel changes the same values.
fn settingsRotate(globals: *MftGlobals, slot: u4, delta: i8) void {
    switch (slot) {
        0 => {
            const total: i32 = @as(i32, globals.mft.settings_ticks) + delta;
            const steps = @divTrunc(total, settings_ticks_per_row);
            globals.mft.settings_ticks = @intCast(total - steps * settings_ticks_per_row);
            if (steps == 0) return;
            const n: i32 = settings_rows.row_count;
            globals.mft.settings_cursor = @intCast(@mod(@as(i32, globals.mft.settings_cursor) + steps, n));
        },
        1 => {
            const row = settings_rows.rows[@min(globals.mft.settings_cursor, settings_rows.row_count - 1)];
            settings_rows.adjust(&globals.preferences, row, delta);
            // A color is sent to the LEDs as it changes.
            if (row.kind == .hue) sendHue(globals, 0);
        },
        else => return,
    }
    midi_out.syncRings(globals, false);
}

// The pushes of the SETTINGS page: the second one flips a switch or the mode, the seventh saves, and the eighth goes back to the saved values.
fn settingsPress(globals: *MftGlobals, push: u8) void {
    switch (push) {
        1 => settings_rows.flip(&globals.preferences, settings_rows.rows[@min(globals.mft.settings_cursor, settings_rows.row_count - 1)]),
        6 => mft_settings.save(globals),
        7 => mft_settings.cancel(globals),
        else => return,
    }
    midi_out.syncRings(globals, false);
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

// How many ticks of the Order knob change the order once, since each change moves FX of the track.
const order_ticks_per_step = 4;

// A turn of the Order knob: the order changes once for each few ticks.
fn turnOrder(globals: *MftGlobals, delta: i8) void {
    const total: i32 = @as(i32, globals.mft.order_ticks) + delta;
    const steps = @divTrunc(total, order_ticks_per_step);
    globals.mft.order_ticks = @intCast(total - steps * order_ticks_per_step);
    if (steps == 0) return;
    stepOrder(globals, steps);
    // Because the player turns the knob to reach an order, the pop-up of the knob says the order that the track is in now.
    const track = globals.current_track orelse return;
    const text: []const u8 = if (mft_fx.trackOrder(track)) |order| order.label() else "No modules";
    globals.mft.push_note.set(8 + mft_transport.order_knob, text, std.Io.Timestamp.now(mft_globals.hostIo(), .awake).toMilliseconds());
}

// Puts the modules of the current track in the next order (or the previous one, for a turn to the left), starting from the order that they are in, or the
// order that the settings prefer when they are in none.
pub fn stepOrder(globals: *MftGlobals, delta: i32) void {
    if (delta == 0) return;
    const track = globals.current_track orelse return;
    const current = mft_fx.trackOrder(track) orelse globals.preferences.module_order;
    mft_fx.applyOrder(track, current.step(if (delta > 0) 1 else -1));
}

// A push of the AUTO page: it runs its action, or steps its parameter as a push of a module does.
fn autoPress(globals: *MftGlobals, push: u3) void {
    const target = globals.map_store.getAuto(mft_globals.hostIo()).pushes[push] orelse return;
    switch (target) {
        .action, .named_action => if (mft_fx.autoCommand(target)) |id| reaper.Main_OnCommand(id, 0),
        .fx_param => {
            const track = globals.current_track orelse return;
            const route = mft_fx.resolveAuto(globals, track).pushes[push] orelse return;
            var note: [32:0]u8 = undefined;
            mft_fx.runPush(track, route, &note);
        },
    }
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
            .SETTINGS => {
                globals.mft.activity.markPress(cc, pressed, std.Io.Timestamp.now(io, .awake).toMilliseconds());
                if (pressed) settingsPress(globals, cc);
            },
            .AUTO => {
                globals.mft.activity.markPress(cc, pressed, std.Io.Timestamp.now(io, .awake).toMilliseconds());
                if (pressed) autoPress(globals, @intCast(cc));
            },
            // On a page, a turn with the push down is a fine adjustment, and a push that is released without a turn is a click.
            else => if (pressed) globals.mft.setHeld(cc) else if (globals.mft.releaseIsClick(cc)) pushClick(globals, @intCast(cc)),
        }
        return;
    }
    if (!pressed) return;
    const module = mft_state.pageForEncoder(cc) orelse return;
    // Save and Cancel of the settings go back to the page that was in use before them.
    if (module == .SETTINGS and globals.mft.active_module != .SETTINGS) globals.mft.settings_return = globals.mft.active_module;
    globals.mft.active_module = module;

    // Switching to a mappable module inserts its default plugins onto the current track if absent, matching the Console One behavior, unless the
    // settings turned the auto insert off.
    if (globals.preferences.auto_insert) {
        if (MappableModule.fromActive(module)) |mappable| {
            if (globals.current_track) |track| {
                // The pop-up of the button says why the single FX mode inserted nothing.
                const why: []const u8 = switch (mft_fx.ensureModuleFx(globals, track, mappable)) {
                    .ok => "",
                    .no_default_strip => "No default strip set",
                    .strip_not_added => "Strip not found",
                };
                if (why.len > 0) globals.mft.push_note.set(cc, why, std.Io.Timestamp.now(io, .awake).toMilliseconds());
            }
        }
    }
    // The settings can ask that a module button also puts the modules of the track in the order that they prefer.
    if (globals.preferences.auto_reorder and MappableModule.fromActive(module) != null) {
        if (globals.current_track) |track| {
            if (mft_fx.trackOrder(track) != globals.preferences.module_order) mft_fx.applyOrder(track, globals.preferences.module_order);
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
        mft.SIDE_BUTTON_CCS[0] => { // L1: toggle the FX chain of the track
            // The chain opens on the plugin of the active module when it has one. Otherwise it opens on the first FX, which is the chain itself when the
            // track has none: REAPER shows an empty chain, from which plugins can be added.
            const module_fx: ?c_int = if (MappableModule.fromActive(globals.mft.active_module)) |module|
                mft_fx.moduleFxToShow(globals, track, module, globals.mft.last_fx_index)
            else
                null;
            mft_fx.toggleFxChain(track, module_fx orelse 0);
        },
        mft.SIDE_BUTTON_CCS[3] => mft_fx.toggleMute(track), // R1
        mft.SIDE_BUTTON_CCS[4] => mft_fx.toggleSolo(track), // R2
        mft.SIDE_BUTTON_CCS[5] => mft_fx.togglePhase(track), // R3
        else => {},
    }
}
