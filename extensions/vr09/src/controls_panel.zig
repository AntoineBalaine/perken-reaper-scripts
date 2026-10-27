//! The Controls tab: a tab bar with one tab for each section of the instrument, and in each tab the cards
//! of that section. This is a port of the design lab's `panel.lua` (the part that draws the controls), so
//! that a section that looks right in the lab is copied here card by card.
//!
//! A parameter that the catalog has is a real control: it reads and writes the plugin's value. A parameter
//! that Roland documents and the catalog does not have (see `extras.zig`) is drawn as the lab draws it: when
//! it has a reason (the unit refuses it, or the synth engine does not answer), it is disabled and the reason
//! is in a tooltip, and otherwise it moves on the screen and nothing is sent to the keyboard. The choice of
//! a tone and the "Part on" switches move on the screen in the same way.
const std = @import("std");
const imgui = @import("reaper_imgui");
const engine = @import("engine.zig");
const catalog = @import("catalog.zig");
const extras = @import("extras.zig");
const tones = @import("tones.zig");
const theme = @import("theme.zig");
const widgets = @import("widgets.zig");

/// What the tab keeps between frames, besides the plugin's own values.
pub const State = struct {
    /// The tone chosen for each part, and the text of its search field. The plugin has no tone parameter
    /// yet, so the choice is only shown.
    tone_keys: [8]u64 = [_]u64{0} ** 8,
    tone_index: [8]usize = [_]usize{0} ** 8,
    tone_filter: [8][widgets.tone_filter_cap:0]u8 = [_][widgets.tone_filter_cap:0]u8{[_:0]u8{0} ** widgets.tone_filter_cap} ** 8,
    /// The values that the user gave to the extras, which only the screen keeps. An extra that was not
    /// touched shows its default.
    extra_values: [extras.params.len]i32 = [_]i32{0} ** extras.params.len,
    extra_touched: [extras.params.len]bool = [_]bool{false} ** extras.params.len,
    /// The parts whose "Part on" switch was turned off, by the hash of the part's name.
    part_keys: [16]u64 = [_]u64{0} ** 16,
    part_off: [16]bool = [_]bool{false} ** 16,
    /// Set when the engine's queue of changes was full, and a change was dropped.
    overflow: bool = false,
    /// A notice that the panel shows, set by a card. Empty when there is none.
    notice: [160:0]u8 = [_:0]u8{0} ** 160,
};

/// What every card draws with.
const Ui = struct {
    ctx: imgui.ContextPtr,
    shared: *engine.Shared,
    state: *State,
};

// ---- the parameters ----

/// A parameter of the catalog or an extra, with what the panel needs to draw it.
const Ref = struct {
    control: widgets.Control,
    /// The full label, and the short one of an extra.
    label: []const u8,
    short: []const u8,
    /// The position in the catalog of a real parameter, or null for an extra.
    index: ?usize,
    /// The position among the extras of an extra, or null for a real parameter.
    extra: ?usize = null,
};

fn refOfParam(param: catalog.Param, index: usize) Ref {
    return .{
        .control = .{ .id = param.id, .low = param.low, .high = param.high, .names = param.names },
        .label = param.label,
        .short = "",
        .index = index,
    };
}

fn refOfExtra(extra: *const extras.Extra) Ref {
    const position = @divExact(@intFromPtr(extra) - @intFromPtr(&extras.params[0]), @sizeOf(extras.Extra));
    return .{
        .extra = position,
        .control = .{
            .id = extra.id,
            .low = extra.low,
            .high = extra.high,
            .shift = extra.shift,
            .scale = extra.scale,
            .signed = extra.signed,
            .unit = extra.unit,
            .default = extra.default,
            .disabled = extra.disabled,
            .names = extra.names,
            .values = extra.values,
        },
        .label = extra.label,
        .short = extra.short,
        .index = null,
    };
}

/// The parameter with this id: one of the extras, or one of the catalog's.
fn findRef(id: []const u8) ?Ref {
    if (extras.find(id)) |extra| return refOfExtra(extra);
    for (catalog.params, 0..) |param, i| {
        if (std.mem.eql(u8, param.id, id)) return refOfParam(param, i);
    }
    return null;
}

const refs_cap = 32;

/// The refs of the ids that exist, in the order of the ids. Returns how many were written.
fn collect(ids: []const []const u8, out: *[refs_cap]Ref) usize {
    var count: usize = 0;
    for (ids) |id| {
        if (count == refs_cap) break;
        if (findRef(id)) |ref| {
            out[count] = ref;
            count += 1;
        }
    }
    return count;
}

/// The catalog's parameters of a group, in the catalog's order.
fn collectGroup(group: []const u8, out: *[refs_cap]Ref) usize {
    var count: usize = 0;
    for (catalog.params, 0..) |param, i| {
        if (!std.mem.eql(u8, param.group, group)) continue;
        if (count == refs_cap) break;
        out[count] = refOfParam(param, i);
        count += 1;
    }
    return count;
}

fn valueOf(ui: Ui, ref: Ref) i32 {
    if (ref.index) |i| return ui.shared.paramValue(i);
    if (ref.extra) |e| {
        if (ui.state.extra_touched[e]) return ui.state.extra_values[e];
    }
    return ref.control.default orelse ref.control.low;
}

/// A real parameter goes to the engine. An extra is kept by the panel, so that it moves on the screen.
fn setValue(ui: Ui, ref: Ref, value: i32) void {
    if (ref.index) |i| {
        if (!ui.shared.changeParam(i, @intCast(std.math.clamp(value, 0, 255)))) ui.state.overflow = true;
        return;
    }
    if (ref.extra) |e| {
        ui.state.extra_values[e] = value;
        ui.state.extra_touched[e] = true;
    }
}

fn idIn(list: []const []const u8, id: []const u8) bool {
    for (list) |item| {
        if (std.mem.eql(u8, item, id)) return true;
    }
    return false;
}

/// "Rotary woofer slow speed" is shown as "woofer slow speed" in the card of the group "Rotary". The
/// words in `suffixes` (such as " volume") are taken off the end of the label too.
fn shortLabel(label: []const u8, group: []const u8, suffixes: []const []const u8) []const u8 {
    var text = label;
    if (text.len > group.len and std.mem.startsWith(u8, text, group) and text[group.len] == ' ') text = text[group.len + 1 ..];
    for (suffixes) |suffix| {
        if (std.mem.endsWith(u8, text, suffix)) {
            text = text[0 .. text.len - suffix.len];
            break;
        }
    }
    return text;
}

/// The stop knobs that show their chosen name in a display that opens a list, even though they have eight
/// stops or fewer, because their names are too long to be written around the knob.
const as_list_ids = [_][]const u8{ "footswitch-left", "footswitch-right", "engine-osc-wave" };

/// Draws the control of a parameter: a knob with named stops when its values have names, a knob
/// otherwise, and writes the new value back. `bipolar` is true for a knob whose value rests in the middle.
fn drawRef(ui: Ui, ref: Ref, label: []const u8, bipolar: bool) void {
    var id: [64:0]u8 = undefined;
    imgui.api.PushID(ui.ctx, std.fmt.bufPrintZ(&id, "{s}", .{ref.control.id}) catch "ref");
    const value = valueOf(ui, ref);
    const change = if (ref.control.names.len > 0)
        widgets.stopKnob(ui.ctx, ref.control, value, label, idIn(&as_list_ids, ref.control.id))
    else
        widgets.knob(ui.ctx, ref.control, value, label, bipolar);
    imgui.api.PopID(ui.ctx);
    if (change.changed) setValue(ui, ref, change.value);
}

// ---- the cards ----

/// The height the tallest card of a row needs, from the last time each was drawn, so that the cards of the
/// row can all take it; null the first time, when the cards size themselves.
fn rowHeight(titles: []const []const u8) ?f64 {
    var tallest: ?f64 = null;
    for (titles) |title| {
        if (widgets.naturalHeight(title)) |height| {
            if (tallest == null or height > tallest.?) tallest = height;
        }
    }
    return tallest;
}

fn sameLine(ctx: imgui.ContextPtr) void {
    imgui.api.SameLine(ctx, null, null);
}

fn wrappedNote(ctx: imgui.ContextPtr, text: [:0]const u8, width: f64) void {
    var wrap = width;
    imgui.api.PushTextWrapPos(ctx, &wrap);
    imgui.api.TextColored(ctx, theme.text_dim, text);
    imgui.api.PopTextWrapPos(ctx);
}

/// The switch that says whether a part sounds. The plugin has no such parameter yet, so the panel keeps it by
/// the part's name, and a part that is not in the table is on.
fn partToggle(ui: Ui, key: []const u8) void {
    const hash = hashOf(key);
    var slot: usize = ui.state.part_keys.len - 1;
    for (ui.state.part_keys, 0..) |existing, i| {
        if (existing == hash) {
            slot = i;
            break;
        }
        if (existing == 0) {
            ui.state.part_keys[i] = hash;
            slot = i;
            break;
        }
    }
    var on = !ui.state.part_off[slot];
    if (widgets.toggle(ui.ctx, "Part on", &on)) ui.state.part_off[slot] = !on;
}

/// A switch for an extra that is either 0 or 1.
fn extraToggle(ui: Ui, id: []const u8, label: [:0]const u8) void {
    const ref = findRef(id) orelse return;
    var on = valueOf(ui, ref) == 1;
    if (widgets.toggle(ui.ctx, label, &on)) setValue(ui, ref, if (on) 1 else 0);
}

const IdText = struct { id: []const u8, text: []const u8 };

/// What a card of knobs can be asked.
const KnobCard = struct {
    /// The card's title, which is also what the labels do not repeat.
    title: []const u8,
    /// What the labels start with, when the title is not it.
    strip: ?[]const u8 = null,
    /// Words the labels end with, which the knob does not need ("volume").
    suffixes: []const []const u8 = &.{},
    /// The label of a knob, by the parameter's id, when the catalog's is too long.
    labels: []const IdText = &.{},
    /// True for a card whose values all rest in the middle of their range.
    bipolar: bool = false,
    /// The ids of the knobs that rest in the middle, when only some of them do.
    bipolar_ids: []const []const u8 = &.{},
    /// How many knobs a row holds, when the card has more than one row.
    columns: usize = 0,
    /// The captions engraved over the knobs of the first row, or of each row.
    brackets: []const widgets.Bracket = &.{},
    brackets_by_row: []const []const widgets.Bracket = &.{},
    accent: ?c_int = null,
    /// The card's height, when it takes the height of a row.
    height: ?f64 = null,
};

const Size = struct { w: f64, h: f64 };

fn labelFor(card: KnobCard, ref: Ref) []const u8 {
    for (card.labels) |item| {
        if (std.mem.eql(u8, item.id, ref.control.id)) return item.text;
    }
    return shortLabel(ref.label, card.strip orelse card.title, card.suffixes);
}

/// A card of knobs. Returns the size of the card, so that a card beside it can match it, or null when the
/// card is not drawn.
fn cardOfKnobs(ui: Ui, refs: []const Ref, card: KnobCard) ?Size {
    if (!widgets.beginCard(ui.ctx, card.title, null, card.height, card.accent)) return null;
    const count = refs.len;
    const per_row = if (card.columns > 0) card.columns else count;
    for (refs, 0..) |ref, i| {
        if (i % per_row == 0) {
            const row = i / per_row;
            const brackets: []const widgets.Bracket = if (row < card.brackets_by_row.len)
                card.brackets_by_row[row]
            else if (row == 0)
                card.brackets
            else
                &.{};
            if (brackets.len > 0) widgets.bracketRow(ui.ctx, brackets, @min(per_row, count - i));
        }
        const bipolar = card.bipolar or idIn(card.bipolar_ids, ref.control.id);
        drawRef(ui, ref, labelFor(card, ref), bipolar);
        if (i + 1 < count and (i + 1) % per_row != 0) sameLine(ui.ctx);
    }
    widgets.endCard(ui.ctx);
    var w: f64 = 0;
    var h: f64 = 0;
    imgui.api.GetItemRectSize(ui.ctx, &w, &h);
    return .{ .w = w, .h = h };
}

/// A card of controls drawn one beside the other, each labelled with its short name: the card of the
/// extras, and of the parts of a section whose parameters are looked up by id.
fn cardOfIds(ui: Ui, title: []const u8, ids: []const []const u8, card_accent: ?c_int, height: ?f64) void {
    if (!widgets.beginCard(ui.ctx, title, null, height, card_accent)) return;
    var refs: [refs_cap]Ref = undefined;
    const count = collect(ids, &refs);
    for (refs[0..count], 0..) |ref, i| {
        const label = if (ref.short.len > 0) ref.short else shortLabel(ref.label, title, &.{});
        drawRef(ui, ref, label, ref.control.signed);
        if (i + 1 < count) sameLine(ui.ctx);
    }
    widgets.endCard(ui.ctx);
}

fn cardOfDrawbars(ui: Ui, group: []const u8, height: ?f64) void {
    if (!widgets.beginCard(ui.ctx, group, null, height, theme.part.organ)) return;
    partToggle(ui, group);
    var refs: [refs_cap]Ref = undefined;
    const count = collectGroup(group, &refs);
    for (refs[0..count], 0..) |ref, i| {
        var id: [64:0]u8 = undefined;
        imgui.api.PushID(ui.ctx, std.fmt.bufPrintZ(&id, "{s}", .{ref.control.id}) catch "bar");
        const change = widgets.drawbar(ui.ctx, ref.control, valueOf(ui, ref), ref.label, false);
        imgui.api.PopID(ui.ctx);
        if (change.changed) setValue(ui, ref, change.value);
        if (i + 1 < count) sameLine(ui.ctx);
    }
    widgets.endCard(ui.ctx);
}

/// The rotary speaker: its switch and the three knobs of the woofer on one row, and the three knobs of the
/// tweeter under them. Because the catalog lists the switch first, then the woofer, then the tweeter, the
/// parameters are taken by their position.
fn cardOfRotary(ui: Ui, height: ?f64) void {
    if (!widgets.beginCard(ui.ctx, "Rotary", null, height, theme.part.organ)) return;
    var refs: [refs_cap]Ref = undefined;
    const count = collectGroup("Rotary", &refs);
    for (refs[0..count], 0..) |ref, i| {
        if (i == 0) {
            var id: [64:0]u8 = undefined;
            imgui.api.PushID(ui.ctx, std.fmt.bufPrintZ(&id, "{s}", .{ref.control.id}) catch "rotary");
            const change = widgets.switchControl(ui.ctx, valueOf(ui, ref), "speaker speed", "FAST", "SLOW");
            imgui.api.PopID(ui.ctx);
            if (change.changed) setValue(ui, ref, change.value);
        } else {
            drawRef(ui, ref, shortLabel(ref.label, "Rotary", &.{}), false);
        }
        // The second row starts under the switch, which is left empty.
        if (i == 0 or i == 1 or i == 2 or i == 4 or i == 5) {
            sameLine(ui.ctx);
        } else if (i == 3) {
            imgui.api.Dummy(ui.ctx, 76, 1);
            sameLine(ui.ctx);
        }
    }
    widgets.endCard(ui.ctx);
}

/// What the synth's attack, decay and release shape. The catalog does not say, so this is the part of the
/// sound that Roland's controllers 72, 73 and 75 (release, attack and decay time) act on in a General MIDI 2
/// module, which is its volume; the cutoff and resonance are the filter.
const envelope_of = "volume";

fn refEnding(refs: []const Ref, suffix: []const u8) ?Ref {
    for (refs) |ref| {
        if (std.mem.endsWith(u8, ref.control.id, suffix)) return ref;
    }
    return null;
}

/// A card beside the synth's knobs, with the screen that draws their envelope and lets the user drag its
/// handles.
fn cardOfEnvelope(ui: Ui, group: []const u8, title: []const u8, size: Size, card_accent: ?c_int) void {
    var refs: [refs_cap]Ref = undefined;
    const count = collectGroup(group, &refs);
    const attack = refEnding(refs[0..count], "-attack") orelse return;
    const decay = refEnding(refs[0..count], "-decay") orelse return;
    const release = refEnding(refs[0..count], "-release") orelse return;
    var heading: [96]u8 = undefined;
    const text = std.fmt.bufPrint(&heading, "{s} {s} envelope", .{ title, envelope_of }) catch title;
    if (!widgets.beginCard(ui.ctx, text, size.w, size.h, card_accent)) return;
    const three = [3]Ref{ attack, decay, release };
    const change = widgets.envelope(
        ui.ctx,
        .{ attack.control, decay.control, release.control },
        .{ valueOf(ui, attack), valueOf(ui, decay), valueOf(ui, release) },
    );
    for (three, 0..) |ref, i| {
        if (change.changed[i]) setValue(ui, ref, change.values[i]);
    }
    widgets.endCard(ui.ctx);
}

fn cardOfSynth(ui: Ui, group: []const u8) void {
    const upper = std.mem.eql(u8, group, "Synth upper");
    const strip = if (upper) "Upper synth" else "Lower synth";
    // The catalog lists the resonance first, then the attack, the decay and the release.
    const brackets = [_]widgets.Bracket{
        .{ .label = "Filter", .from = 1, .to = 1 },
        .{ .label = envelope_of ++ " envelope", .from = 2, .to = 4 },
    };
    const tint = if (upper) theme.part.upper else theme.part.lower;
    var refs: [refs_cap]Ref = undefined;
    const count = collectGroup(group, &refs);
    const size = cardOfKnobs(ui, refs[0..count], .{ .title = group, .strip = strip, .bipolar = true, .brackets = &brackets, .accent = tint }) orelse return;
    sameLine(ui.ctx);
    cardOfEnvelope(ui, group, strip, size, tint);
}

/// The mixer's levels, in the order of the catalog: the rhythm and the song, then the upper part's piano and
/// two synths, then the lower part's piano and synth. Each of the three is a card of its own. Because the
/// upper and lower parts are two panels of the same kind, they are put one under the other, and the backing
/// card follows the upper one on its row, so that the tab uses its width.
fn cardOfMixer(ui: Ui) void {
    var all: [refs_cap]Ref = undefined;
    const total = collectGroup("Mixer", &all);
    const suffixes = [_][]const u8{ " volume", " level" };
    const row = rowHeight(&.{ "Upper", "Backing" });
    var band: [refs_cap]Ref = undefined;

    // The volume of the upper piano's second layer comes after the upper piano's.
    var n: usize = 0;
    if (total >= 5) {
        band[n] = all[2];
        n += 1;
        if (findRef("upper-piano-dual2-volume")) |dual2| {
            band[n] = dual2;
            n += 1;
        }
        for (all[3..5]) |ref| {
            band[n] = ref;
            n += 1;
        }
        _ = cardOfKnobs(ui, band[0..n], .{ .title = "Upper", .suffixes = &suffixes, .accent = theme.part.upper, .height = row });
    }
    if (total >= 2) {
        sameLine(ui.ctx);
        _ = cardOfKnobs(ui, all[0..2], .{ .title = "Backing", .suffixes = &suffixes, .accent = theme.part.backing, .height = row });
    }
    if (total >= 7) _ = cardOfKnobs(ui, all[5..7], .{ .title = "Lower", .suffixes = &suffixes, .accent = theme.part.lower });
}

/// The piano's volumes of its upper, upper dual 2 and lower parts, then the controllers of the piano that is
/// the second layer of a dual patch, with its channel volume and pan, which the catalog does not have.
fn cardOfPianoMain(ui: Ui) void {
    var refs: [refs_cap]Ref = undefined;
    var n: usize = 0;
    for ([_][]const u8{ "upper-piano-volume", "upper-piano-dual2-volume", "lower-piano-volume" }) |id| {
        if (findRef(id)) |ref| {
            refs[n] = ref;
            n += 1;
        }
    }
    const volumes = n;
    var group: [refs_cap]Ref = undefined;
    const group_count = collectGroup("Control change piano", &group);
    for (group[0..group_count]) |ref| {
        refs[n] = ref;
        n += 1;
    }
    for ([_][]const u8{ "cc-piano-volume", "cc-piano-pan" }) |id| {
        if (findRef(id)) |ref| {
            refs[n] = ref;
            n += 1;
        }
    }
    const brackets = [_]widgets.Bracket{
        .{ .label = "Volume", .from = 1, .to = volumes },
        .{ .label = "Dual 2", .from = volumes + 1, .to = n },
    };
    _ = cardOfKnobs(ui, refs[0..n], .{
        .title = "Piano",
        .strip = "Piano (dual 2)",
        .suffixes = &.{" volume"},
        .brackets = &brackets,
        .accent = theme.part.piano,
        .bipolar_ids = &.{"cc-piano-pan"},
    });
}

const PianoShaping = struct { id: []const u8, title: []const u8, upper: bool };
const piano_shaping = [_]PianoShaping{
    .{ .id = "upper-piano", .title = "Upper piano shaping", .upper = true },
    .{ .id = "upper-piano-dual2", .title = "Upper piano dual 2 shaping", .upper = true },
    .{ .id = "lower-piano", .title = "Lower piano shaping", .upper = false },
};

/// The sound shaping of each of the three piano parts, in a card of its own: the cutoff and the resonance
/// under a filter bracket, and the attack, decay and release under an envelope bracket.
fn cardsOfPianoShaping(ui: Ui) void {
    const brackets = [_]widgets.Bracket{
        .{ .label = "Filter", .from = 1, .to = 2 },
        .{ .label = envelope_of ++ " envelope", .from = 3, .to = 5 },
    };
    for (piano_shaping) |shaping| {
        var refs: [5]Ref = undefined;
        var labels: [5]IdText = undefined;
        var n: usize = 0;
        for ([_][]const u8{ "cutoff", "resonance", "attack", "decay", "release" }) |name| {
            var id_buf: [64]u8 = undefined;
            const id = std.fmt.bufPrint(&id_buf, "{s}-{s}", .{ shaping.id, name }) catch continue;
            const ref = findRef(id) orelse continue;
            refs[n] = ref;
            labels[n] = .{ .id = ref.control.id, .text = ref.short };
            n += 1;
        }
        _ = cardOfKnobs(ui, refs[0..n], .{
            .title = shaping.title,
            .labels = labels[0..n],
            .bipolar = true,
            .brackets = &brackets,
            .accent = if (shaping.upper) theme.part.upper else theme.part.lower,
        });
    }
}

/// The controllers that rest in the middle of their range (64) are bipolar knobs: the vibrato, the pan, the
/// cutoff, the resonance and the envelope. The others, the sends and the expression, are levels.
const bipolar_controllers = [_][]const u8{
    "cc-upper-vibrato-depth", "cc-upper-vibrato-rate", "cc-upper-pan",     "cc-upper-cutoff", "cc-upper-resonance",
    "cc-upper-release",       "cc-upper-attack",       "cc-upper-decay",   "cc-lower-cutoff", "cc-lower-pan",
};

/// The upper part has twelve controllers, in two rows of six, and seven on the first row once the channel
/// volume is added after the expression. Because the catalog lists them in this order, the brackets are
/// placed by position: vibrato and sends over the first row, filter and envelope over the second.
fn cardOfUpperControllers(ui: Ui) void {
    var group: [refs_cap]Ref = undefined;
    const group_count = collectGroup("Control change upper", &group);
    var refs: [refs_cap]Ref = undefined;
    var n: usize = 0;
    for (group[0..group_count]) |ref| {
        refs[n] = ref;
        n += 1;
        if (std.mem.eql(u8, ref.control.id, "cc-upper-expression")) {
            if (findRef("cc-upper-volume")) |volume| {
                refs[n] = volume;
                n += 1;
            }
        }
    }
    const first = [_]widgets.Bracket{ .{ .label = "Vibrato", .from = 1, .to = 2 }, .{ .label = "Sends", .from = 3, .to = 4 } };
    const second = [_]widgets.Bracket{ .{ .label = "Filter", .from = 1, .to = 2 }, .{ .label = envelope_of ++ " envelope", .from = 3, .to = 5 } };
    const rows = [_][]const widgets.Bracket{ &first, &second };
    _ = cardOfKnobs(ui, refs[0..n], .{
        .title = "Upper controllers",
        .strip = "Upper",
        .columns = 7,
        .bipolar_ids = &bipolar_controllers,
        .accent = theme.part.upper,
        .brackets_by_row = &rows,
    });
}

/// The channel volume and the pan, which the catalog does not have for the lower part, come last.
fn cardOfLowerControllers(ui: Ui) void {
    var refs: [refs_cap]Ref = undefined;
    var n = collectGroup("Control change lower", &refs);
    for ([_][]const u8{ "cc-lower-volume", "cc-lower-pan" }) |id| {
        if (findRef(id)) |ref| {
            refs[n] = ref;
            n += 1;
        }
    }
    _ = cardOfKnobs(ui, refs[0..n], .{
        .title = "Lower controllers",
        .strip = "Lower",
        .bipolar_ids = &bipolar_controllers,
        .accent = theme.part.lower,
    });
}

/// The overall volume, and the tone level that the documentation has at the system address 61.
fn cardOfMasterController(ui: Ui) void {
    var group: [refs_cap]Ref = undefined;
    const group_count = collectGroup("Control change master", &group);
    if (group_count == 0) return;
    var refs: [2]Ref = undefined;
    var n: usize = 1;
    refs[0] = group[0];
    if (findRef("tone-level")) |tone_level| {
        refs[1] = tone_level;
        n = 2;
    }
    const labels = [_]IdText{ .{ .id = "cc-master-expression", .text = "overall volume" }, .{ .id = "tone-level", .text = "tone level" } };
    _ = cardOfKnobs(ui, refs[0..n], .{ .title = "Master", .accent = theme.part.master, .labels = &labels, .bipolar_ids = &.{"tone-level"} });
}

// ---- the effects ----

const Effect = struct { title: []const u8, tint: c_int, ids: []const []const u8 };

/// The effects, one card for each, in two rows. Each lists the ids of its parameters in the order they are
/// shown. A parameter with named values is a knob with stops, and a level is a knob.
const effect_rows = [_][]const Effect{
    &.{
        .{ .title = "Reverb", .tint = theme.fx.reverb, .ids = &.{ "reverb-type", "reverb-variation", "reverb-level", "wall-type" } },
        .{ .title = "Vibrato / chorus", .tint = theme.fx.chorus, .ids = &.{"vibrato-chorus-type"} },
    },
    &.{
        .{ .title = "MFX", .tint = theme.fx.mfx, .ids = &.{ "mfx-type", "mfx-level" } },
        .{ .title = "Delay", .tint = theme.fx.delay, .ids = &.{ "delay-type", "delay-level" } },
        .{ .title = "Compressor", .tint = theme.fx.compressor, .ids = &.{"compressor-level"} },
    },
};

/// Draws the card of one effect, at the given height when there is one.
fn cardOfEffect(ui: Ui, effect: Effect, height: ?f64) void {
    var refs: [refs_cap]Ref = undefined;
    const count = collect(effect.ids, &refs);
    _ = cardOfKnobs(ui, refs[0..count], .{ .title = effect.title, .accent = effect.tint, .height = height });
}

/// Draws the effects' cards. Because the cards of a row sit side by side, they all take the height of the
/// tallest one, so that the row has an even edge.
fn cardOfEffects(ui: Ui) void {
    for (effect_rows) |row| {
        var titles: [4][]const u8 = undefined;
        for (row, 0..) |effect, i| titles[i] = effect.title;
        const height = rowHeight(titles[0..row.len]);
        for (row, 0..) |effect, i| {
            if (i > 0) sameLine(ui.ctx);
            cardOfEffect(ui, effect, height);
        }
    }
}

// ---- the organ ----

/// The organ's own settings in a card: its character on the first row, and its levels on the second, then
/// the switches. The unit refuses the EQ and the overdrive's dry mix, and the rest the plugin does not have,
/// so that all of it is drawn disabled.
fn cardOfOrganVoicing(ui: Ui, height: ?f64) void {
    if (!widgets.beginCard(ui.ctx, "Organ voicing", null, height, theme.part.organ)) return;
    const rows = [_][]const []const u8{
        &.{ "organ-type", "rotary-type", "percussion", "percussion-level" },
        &.{ "organ-eq-high", "organ-eq-low", "overdrive-dry" },
    };
    for (rows) |ids| {
        var refs: [refs_cap]Ref = undefined;
        const count = collect(ids, &refs);
        for (refs[0..count], 0..) |ref, i| {
            drawRef(ui, ref, ref.short, ref.control.signed);
            if (i + 1 < count) sameLine(ui.ctx);
        }
    }
    const switches = [_]IdText{
        .{ .id = "vibrato-upper", .text = "Vibrato / chorus, upper" },
        .{ .id = "vibrato-lower", .text = "Vibrato / chorus, lower" },
        .{ .id = "rotary-on", .text = "Rotary speaker" },
    };
    for (switches, 0..) |item, i| {
        var label: [64:0]u8 = undefined;
        extraToggle(ui, item.id, std.fmt.bufPrintZ(&label, "{s}", .{item.text}) catch "");
        if (i + 1 < switches.len) sameLine(ui.ctx);
    }
    widgets.endCard(ui.ctx);
}

/// The pedal part, drawn disabled, with the drawbars its organ block would have: the plugin has no parameter
/// for it yet.
fn cardOfOrganPedal(ui: Ui, height: ?f64) void {
    if (!widgets.beginCard(ui.ctx, "Organ pedal", null, height, null)) return;
    var first = true;
    for (&extras.params) |*extra| {
        if (!std.mem.startsWith(u8, extra.id, "organ-pedal-")) continue;
        if (!first) sameLine(ui.ctx);
        first = false;
        const ref = refOfExtra(extra);
        var id: [64:0]u8 = undefined;
        imgui.api.PushID(ui.ctx, std.fmt.bufPrintZ(&id, "{s}", .{ref.control.id}) catch "pedal");
        _ = widgets.drawbar(ui.ctx, ref.control, valueOf(ui, ref), ref.label, true);
        imgui.api.PopID(ui.ctx);
    }
    imgui.api.TextColored(ui.ctx, theme.text_dim, "Not in the plugin yet (MIDI channel 2).");
    widgets.endCard(ui.ctx);
}

fn organExtras(ui: Ui) void {
    const height = rowHeight(&.{ "Organ voicing", "Organ pedal" });
    cardOfOrganVoicing(ui, height);
    sameLine(ui.ctx);
    cardOfOrganPedal(ui, height);
    // The rotary speaker's times and its brake, which the unit refuses, under them.
    cardOfIds(ui, "Rotary times", &.{ "woofer-rise", "woofer-fall", "tweeter-rise", "tweeter-fall", "rotary-brake" }, theme.part.organ, null);
}

// ---- the tones, the drums and the performance ----

fn hashOf(text: []const u8) u64 {
    return std.hash.Wyhash.hash(0, text);
}

/// The choice kept for a part: its position in its list and its search text. A part that has none yet takes
/// the first free slot.
fn toneSlot(state: *State, id: []const u8) usize {
    const key = hashOf(id);
    for (state.tone_keys, 0..) |existing, i| {
        if (existing == key) return i;
    }
    for (&state.tone_keys, 0..) |*existing, i| {
        if (existing.* == 0) {
            existing.* = key;
            return i;
        }
    }
    return state.tone_keys.len - 1;
}

/// Draws a tone picker for a part and keeps its choice. Returns true when the choice changed.
fn toneChoice(ui: Ui, id: [:0]const u8, list: []const tones.Tone) bool {
    const slot = toneSlot(ui.state, id);
    const before = ui.state.tone_index[slot];
    const chosen = widgets.tonePicker(ui.ctx, id, list, before, &ui.state.tone_filter[slot]);
    ui.state.tone_index[slot] = chosen;
    return chosen != before;
}

const TonePart = struct { id: [:0]const u8, title: []const u8, synth: bool, upper: bool };
const tone_parts = [_]TonePart{
    .{ .id = "upper-piano", .title = "Upper piano", .synth = false, .upper = true },
    .{ .id = "upper-piano-dual2", .title = "Upper piano dual 2", .synth = false, .upper = true },
    .{ .id = "lower-piano", .title = "Lower piano", .synth = false, .upper = false },
    .{ .id = "upper-synth", .title = "Upper synth", .synth = true, .upper = true },
    .{ .id = "upper-synth-dual2", .title = "Upper synth dual 2", .synth = true, .upper = true },
    .{ .id = "lower-synth", .title = "Lower synth", .synth = true, .upper = false },
};
const tone_parts_per_row = 3;

fn setNotice(state: *State, comptime fmt: []const u8, args: anytype) void {
    _ = std.fmt.bufPrintZ(&state.notice, fmt, args) catch {
        state.notice[0] = 0;
    };
}

/// The card of one part's tone. The plugin has no tone parameter yet, so the choice is only shown.
fn cardOfTone(ui: Ui, part: TonePart) void {
    if (!widgets.beginCard(ui.ctx, part.title, null, null, if (part.upper) theme.part.upper else theme.part.lower)) return;
    const list: []const tones.Tone = if (part.synth) &tones.synth else &tones.piano;
    if (toneChoice(ui, part.id, list)) {
        const slot = toneSlot(ui.state, part.id);
        setNotice(ui.state, "{s}: {s} (shown only: the plugin does not send tones yet).", .{ part.title, list[ui.state.tone_index[slot]].name });
    }
    partToggle(ui, part.id);
    var ids: [3][]const u8 = undefined;
    var buffers: [3][64]u8 = undefined;
    for ([_][]const u8{ "octave", "portamento", "portamento-time" }, 0..) |name, i| {
        ids[i] = std.fmt.bufPrint(&buffers[i], "{s}-{s}", .{ part.id, name }) catch "";
    }
    var refs: [refs_cap]Ref = undefined;
    const count = collect(&ids, &refs);
    for (refs[0..count], 0..) |ref, i| {
        drawRef(ui, ref, ref.short, false);
        if (i + 1 < count) sameLine(ui.ctx);
    }
    widgets.endCard(ui.ctx);
}

fn tonesSection(ui: Ui) void {
    for (tone_parts, 0..) |part, i| {
        if (i % tone_parts_per_row != 0) sameLine(ui.ctx);
        cardOfTone(ui, part);
    }
}

/// The drum part: its kit from the tone list, its volume, and a switch. The document lists these at the drum
/// block's offsets, but the unit's dumps do not match them, so the card says it is unconfirmed.
fn drumsSection(ui: Ui) void {
    if (!widgets.beginCard(ui.ctx, "Drum kit", null, null, theme.part.master)) return;
    _ = toneChoice(ui, "drum", &tones.drum);
    partToggle(ui, "drum");
    if (findRef("drum-volume")) |ref| drawRef(ui, ref, "volume", false);
    wrappedNote(ui.ctx, "Roland documents the kit and the volume at the drum block's offsets, but the unit's dumps do not match them: unconfirmed. The drums play on MIDI channel 11.", 360);
    widgets.endCard(ui.ctx);
}

/// The pedals' settings: the part the damper pedal acts on, the wheel brake, and the two N.control switches,
/// which are the two bits of one value.
fn cardOfPedals(ui: Ui, tint: c_int) void {
    if (!widgets.beginCard(ui.ctx, "Pedals", null, null, tint)) return;
    for ([_][]const u8{ "damper-part", "wheel-brake" }) |id| {
        if (findRef(id)) |ref| {
            drawRef(ui, ref, ref.short, false);
            sameLine(ui.ctx);
        }
    }
    // The two N.control switches are the two bits of one value, 0 to 3.
    if (findRef("n-control")) |ref| {
        const n = valueOf(ui, ref);
        var first = n & 1 == 1;
        var second = n & 2 == 2;
        const changed_first = widgets.toggle(ui.ctx, "N.control 1", &first);
        sameLine(ui.ctx);
        const changed_second = widgets.toggle(ui.ctx, "N.control 2", &second);
        if (changed_first or changed_second) setValue(ui, ref, (if (first) @as(i32, 1) else 0) | (if (second) @as(i32, 2) else 0));
    }
    widgets.endCard(ui.ctx);
}

/// The keyboard's performance controls: what the two footswitches and the D-Beam do, and the transposition
/// and the touch.
fn performanceSection(ui: Ui) void {
    const height = rowHeight(&.{ "Footswitches", "D-Beam", "Keyboard" });
    cardOfIds(ui, "Footswitches", &.{ "footswitch-left", "footswitch-right" }, theme.part.master, height);
    sameLine(ui.ctx);
    cardOfIds(ui, "D-Beam", &.{"d-beam"}, theme.part.master, height);
    sameLine(ui.ctx);
    cardOfIds(ui, "Keyboard", &.{ "transpose", "initial-touch", "expression-curve" }, theme.part.master, height);
    cardOfPedals(ui, theme.part.master);
}

// ---- the synth engine ----

const EngineCard = struct { title: []const u8, ids: []const []const u8 = &.{}, tone_card: bool = false };

/// The synth engine that Roland documents: one partial's oscillator, filter, amplifier and LFO, in rows of
/// cards. The unit does not answer at its addresses, so every control is disabled.
const engine_rows = [_][]const EngineCard{
    &.{
        .{ .title = "Oscillator", .ids = &.{ "engine-osc-wave", "engine-osc-variation", "engine-osc-pitch", "engine-osc-detune", "engine-osc-pwm-depth", "engine-osc-pulse-width" } },
        .{ .title = "Pitch envelope", .ids = &.{ "engine-pitch-env-attack", "engine-pitch-env-decay", "engine-pitch-env-depth" } },
        .{ .title = "PCM and super saw", .ids = &.{ "engine-wave-number", "engine-super-saw-detune" } },
    },
    &.{
        .{ .title = "Filter", .ids = &.{ "engine-filter-mode", "engine-filter-slope", "engine-filter-cutoff", "engine-filter-keyfollow", "engine-filter-resonance" } },
        .{ .title = "Filter envelope", .ids = &.{ "engine-filter-env-attack", "engine-filter-env-decay", "engine-filter-env-sustain", "engine-filter-env-release", "engine-filter-env-depth" } },
    },
    &.{
        .{ .title = "Amplifier", .ids = &.{ "engine-amp-level", "engine-amp-velocity", "engine-amp-pan" } },
        .{ .title = "Amplifier envelope", .ids = &.{ "engine-amp-env-attack", "engine-amp-env-decay", "engine-amp-env-sustain", "engine-amp-env-release" } },
        .{ .title = "Unison and ring", .ids = &.{ "engine-unison", "engine-unison-size", "engine-ring" } },
    },
    &.{
        .{ .title = "Synth tone", .tone_card = true },
        .{ .title = "Portamento", .ids = &.{ "engine-porta-switch", "engine-porta-time", "engine-mono-poly" } },
        .{ .title = "Partials", .ids = &.{ "engine-partial1-switch", "engine-partial2-switch", "engine-partial3-switch", "engine-partial1-select", "engine-partial2-select", "engine-partial3-select" } },
    },
    &.{
        .{ .title = "LFO", .ids = &.{ "engine-lfo-shape", "engine-lfo-rate", "engine-lfo-sync", "engine-lfo-sync-note", "engine-lfo-fade", "engine-lfo-pitch-depth", "engine-lfo-filter-depth", "engine-lfo-amp-depth" } },
        .{ .title = "Modulation LFO", .ids = &.{ "engine-mod-lfo-shape", "engine-mod-lfo-rate", "engine-mod-lfo-sync", "engine-mod-lfo-sync-note", "engine-mod-lfo-pitch-depth", "engine-mod-lfo-filter-depth", "engine-mod-lfo-amp-depth", "engine-mod-lfo-rate-control" } },
    },
};

/// The synth tone's own card: its name on a display, and its level, wave shape and category.
fn cardOfEngineTone(ui: Ui, height: ?f64) void {
    if (!widgets.beginCard(ui.ctx, "Synth tone", null, height, null)) return;
    widgets.display(ui.ctx, "Init Tone", theme.text_dim, 160);
    cardRow(ui, &.{ "engine-tone-level", "engine-wave-shape", "engine-tone-category" });
    widgets.endCard(ui.ctx);
}

/// The controls of some ids on one row, each under its short name.
fn cardRow(ui: Ui, ids: []const []const u8) void {
    var refs: [refs_cap]Ref = undefined;
    const count = collect(ids, &refs);
    for (refs[0..count], 0..) |ref, i| {
        drawRef(ui, ref, ref.short, ref.control.signed);
        if (i + 1 < count) sameLine(ui.ctx);
    }
}

fn engineSection(ui: Ui) void {
    wrappedNote(ui.ctx, "One partial of the synth tone, as Roland documents it. The unit does not answer at these addresses, so the controls are disabled.", 640);
    for (engine_rows) |row| {
        var titles: [4][]const u8 = undefined;
        for (row, 0..) |card, i| titles[i] = card.title;
        const height = rowHeight(titles[0..row.len]);
        for (row, 0..) |card, i| {
            if (i > 0) sameLine(ui.ctx);
            if (card.tone_card) cardOfEngineTone(ui, height) else cardOfIds(ui, card.title, card.ids, null, height);
        }
    }
}

/// The General MIDI 2 sound generator: the program of each of the channels that it plays on.
fn gm2Section(ui: Ui) void {
    wrappedNote(ui.ctx, "The GM2 sounds play on MIDI channels 5 to 10, 12, 14 and 15, chosen with Program Change and Bank Select. The names of the sounds are not in the panel yet.", 640);
    var ids: [9][]const u8 = undefined;
    var buffers: [9][32]u8 = undefined;
    for ([_]u8{ 5, 6, 7, 8, 9, 10, 12, 14, 15 }, 0..) |channel, i| {
        ids[i] = std.fmt.bufPrint(&buffers[i], "gm2-ch{d}-program", .{channel}) catch "";
    }
    cardOfIds(ui, "GM2 programs", &ids, theme.part.master, null);
}

// ---- the sections ----

const Section = enum { organ, tones, synth, engine, piano, drums, mixer, fx, controllers, performance, gm2 };

const SectionTab = struct { name: [:0]const u8, kind: Section };

/// The instrument's sections, each one a tab. Because the catalog has no group for drums, the rhythm and
/// song levels stay in the Mixer. The piano's volumes are in the Mixer, where the catalog lists them, and in
/// the Piano tab as well.
const section_tabs = [_]SectionTab{
    .{ .name = "ORGAN", .kind = .organ },
    .{ .name = "TONES", .kind = .tones },
    .{ .name = "SYNTH", .kind = .synth },
    .{ .name = "ENGINE", .kind = .engine },
    .{ .name = "PIANO", .kind = .piano },
    .{ .name = "DRUMS", .kind = .drums },
    .{ .name = "MIXER", .kind = .mixer },
    .{ .name = "FX", .kind = .fx },
    .{ .name = "CONTROLLERS", .kind = .controllers },
    .{ .name = "PERFORMANCE", .kind = .performance },
    .{ .name = "GM2", .kind = .gm2 },
};

/// Draws the organ: the drawbars side by side first, because an organ player looks at them first, then the
/// organ's and the rotary speaker's knobs on one row, then the cards that the organ adds.
fn organSection(ui: Ui) void {
    const drawbar_groups = [_][]const u8{ "Organ upper drawbars", "Organ lower drawbars" };
    const drawbar_height = rowHeight(&drawbar_groups);
    for (drawbar_groups, 0..) |group, i| {
        if (i > 0) sameLine(ui.ctx);
        cardOfDrawbars(ui, group, drawbar_height);
    }
    const knob_height = rowHeight(&.{ "Organ", "Rotary" });
    var refs: [refs_cap]Ref = undefined;
    const count = collectGroup("Organ", &refs);
    _ = cardOfKnobs(ui, refs[0..count], .{ .title = "Organ", .accent = theme.part.organ, .height = knob_height });
    sameLine(ui.ctx);
    cardOfRotary(ui, knob_height);
    organExtras(ui);
}

fn drawSection(ui: Ui, kind: Section) void {
    switch (kind) {
        .organ => organSection(ui),
        .tones => tonesSection(ui),
        .synth => {
            cardOfSynth(ui, "Synth upper");
            cardOfSynth(ui, "Synth lower");
        },
        .engine => engineSection(ui),
        .piano => {
            cardOfPianoMain(ui);
            cardsOfPianoShaping(ui);
        },
        .drums => drumsSection(ui),
        .mixer => cardOfMixer(ui),
        .fx => cardOfEffects(ui),
        .controllers => {
            cardOfUpperControllers(ui);
            cardOfLowerControllers(ui);
            // The master card is not stacked: it sits on the row of the lower controllers, as in the lab.
            sameLine(ui.ctx);
            cardOfMasterController(ui);
        },
        .performance => performanceSection(ui),
        .gm2 => gm2Section(ui),
    }
}

/// The Controls tab holds a tab bar of its own, with one tab for each section of the instrument.
pub fn draw(shared: *engine.Shared, state: *State, ctx: imgui.ContextPtr) void {
    const ui = Ui{ .ctx = ctx, .shared = shared, .state = state };
    if (!imgui.api.BeginTabBar(ctx, "##sections", null)) return;
    for (section_tabs) |tab| {
        if (!widgets.beginTab(ctx, tab.name, null)) continue;
        // EndChild only follows a BeginChild that returned true.
        if (imgui.api.BeginChild(ctx, "##section", null, null, null, null)) {
            drawSection(ui, tab.kind);
            imgui.api.EndChild(ctx);
        }
        imgui.api.EndTabItem(ctx);
    }
    imgui.api.EndTabBar(ctx);
}

test "every card compiles" {
    std.testing.refAllDecls(@This());
}
