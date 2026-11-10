//! The layout of the controller, as seen from the maps of the Console 1, and the conversion of a Console 1 map into a map of the controller.
//!
//! Because the Console 1 names each of its controls (`Eq_LoFrq`, `Comp_Thresh`) and the controller has positions on a page, a table says which
//! page and which position each control goes to. The conversion is a pure function of the text of a map, so that the unit tests can reach it and
//! the porting script can use it for every map of the Console 1 at once.
const std = @import("std");
const mappings = @import("mft_mappings.zig");

pub const MappableModule = mappings.MappableModule;
pub const MftModuleMapping = mappings.MftModuleMapping;

/// Where a control of the Console 1 goes: a knob (by its position, from 0 to 15) or a push (from 0 to 7) of a page.
pub const Placement = struct {
    page: MappableModule,
    position: union(enum) { knob: u4, push: u3 },
};

const Entry = struct { name: []const u8, placement: Placement };

fn knob(name: []const u8, page: MappableModule, position: u4) Entry {
    return .{ .name = name, .placement = .{ .page = page, .position = .{ .knob = position } } };
}

fn push(name: []const u8, page: MappableModule, position: u3) Entry {
    return .{ .name = name, .placement = .{ .page = page, .position = .{ .push = position } } };
}

/// The controls of the Console 1 that the controller has a place for. The bypass of a module, the filters to compressor, the display of the
/// input, the presets and the reassignable controls of the strip have none: the bypass is a key of the controller, and the others are not
/// done on it.
const table = [_]Entry{
    knob("Inpt_Gain", .INPUT, 0),
    knob("Inpt_LoCut", .INPUT, 1),
    knob("Inpt_HiCut", .INPUT, 2),
    knob("Shp_Gate", .GATE, 0),
    knob("Shp_GateRelease", .GATE, 1),
    knob("Shp_Punch", .GATE, 2),
    knob("Shp_sustain", .GATE, 3),
    knob("Shp_shape", .GATE, 4),
    knob("Shp_hard_gate", .GATE, 5),
    knob("Eq_LoFrq", .EQ, 0),
    knob("Eq_LoMidFrq", .EQ, 1),
    knob("Eq_HiMidFrq", .EQ, 2),
    knob("Eq_HiFrq", .EQ, 3),
    knob("Eq_LoGain", .EQ, 4),
    knob("Eq_LoMidGain", .EQ, 5),
    knob("Eq_HiMidGain", .EQ, 6),
    knob("Eq_HiGain", .EQ, 7),
    knob("Eq_LoMidQ", .EQ, 9),
    knob("Eq_HiMidQ", .EQ, 10),
    push("Eq_lp_shape", .EQ, 0),
    push("Eq_hp_shape", .EQ, 3),
    knob("Comp_Thresh", .COMP, 0),
    knob("Comp_Ratio", .COMP, 1),
    knob("Comp_Attack", .COMP, 2),
    knob("Comp_Release", .COMP, 3),
    knob("Comp_LoCut", .COMP, 4),
    knob("Comp_HiCut", .COMP, 5),
    knob("Comp_GR", .COMP, 8),
    knob("Comp_DryWet", .COMP, 15),
    knob("Out_Drive", .OUTPUT, 0),
    knob("Out_DriveChar", .OUTPUT, 1),
    knob("Out_Pan", .OUTPUT, 2),
    knob("Out_Vol", .OUTPUT, 3),
};

/// The words that the mapping panel writes for a control of the Console 1, which are its default role on the page.
const role_words = [_]struct { control: []const u8, words: []const u8 }{
    .{ .control = "Inpt_Gain", .words = "Gain" },
    .{ .control = "Inpt_LoCut", .words = "Lo Cut" },
    .{ .control = "Inpt_HiCut", .words = "Hi Cut" },
    .{ .control = "Shp_Gate", .words = "Gate" },
    .{ .control = "Shp_GateRelease", .words = "Release" },
    .{ .control = "Shp_Punch", .words = "Punch" },
    .{ .control = "Shp_sustain", .words = "Sustain" },
    .{ .control = "Shp_shape", .words = "Shape" },
    .{ .control = "Shp_hard_gate", .words = "Hard Gate" },
    .{ .control = "Eq_LoFrq", .words = "Lo Frq" },
    .{ .control = "Eq_LoMidFrq", .words = "LoMid Frq" },
    .{ .control = "Eq_HiMidFrq", .words = "HiMid Frq" },
    .{ .control = "Eq_HiFrq", .words = "Hi Frq" },
    .{ .control = "Eq_LoGain", .words = "Lo Gain" },
    .{ .control = "Eq_LoMidGain", .words = "LoMid Gain" },
    .{ .control = "Eq_HiMidGain", .words = "HiMid Gain" },
    .{ .control = "Eq_HiGain", .words = "Hi Gain" },
    .{ .control = "Eq_LoMidQ", .words = "LoMid Q" },
    .{ .control = "Eq_HiMidQ", .words = "HiMid Q" },
    .{ .control = "Eq_lp_shape", .words = "Lo Shape" },
    .{ .control = "Eq_hp_shape", .words = "Hi Shape" },
    .{ .control = "Comp_Thresh", .words = "Thresh" },
    .{ .control = "Comp_Ratio", .words = "Ratio" },
    .{ .control = "Comp_Attack", .words = "Attack" },
    .{ .control = "Comp_Release", .words = "Release" },
    .{ .control = "Comp_LoCut", .words = "Lo Cut" },
    .{ .control = "Comp_HiCut", .words = "Hi Cut" },
    .{ .control = "Comp_GR", .words = "GR" },
    .{ .control = "Comp_DryWet", .words = "Dry/Wet" },
    .{ .control = "Out_Drive", .words = "Drive" },
    .{ .control = "Out_DriveChar", .words = "Char" },
    .{ .control = "Out_Pan", .words = "Pan" },
    .{ .control = "Out_Vol", .words = "Volume" },
};

/// What the control at a position of a page is for by default, in the words of the mapping panel, or "no default" for a position that the page gives
/// no control. The dry/wet is the last knob of every module, and the EQ has the bandwidths of its outer bands and the shapes of its middle ones, which
/// the Console 1 has no control for.
pub fn roleLabel(page: MappableModule, is_push: bool, position: usize) []const u8 {
    for (table) |entry| {
        if (entry.placement.page != page) continue;
        const same = switch (entry.placement.position) {
            .knob => |k| !is_push and k == position,
            .push => |p| is_push and p == position,
        };
        if (!same) continue;
        for (role_words) |role| {
            if (std.mem.eql(u8, role.control, entry.name)) return role.words;
        }
    }
    if (!is_push and position == 15) return "Dry/Wet";
    if (page == .EQ) {
        if (!is_push and position == 8) return "Lo Q";
        if (!is_push and position == 11) return "Hi Q";
        if (is_push and position == 1) return "LoMid Shape";
        if (is_push and position == 2) return "HiMid Shape";
    }
    return "no default";
}

/// The place of a control of the Console 1, or null for a control that has none.
pub fn place(control: []const u8) ?Placement {
    for (table) |entry| {
        if (std.mem.eql(u8, entry.name, control)) return entry.placement;
    }
    return null;
}

/// The result of reading one map of the Console 1.
pub const Converted = struct {
    /// The module the map is for, or null for a channel strip, which has a map for every page.
    module: ?MappableModule = null,
    /// The name of the FX, which points into the text that was read.
    fx_name: []const u8 = "",
    /// The mapping of each page. A module map only fills its own page.
    pages: [@typeInfo(MappableModule).@"enum".field_names.len]MftModuleMapping = @splat(.{}),
    /// How many controls had a place, and the names of those that had none, so that the script can tell them.
    placed: usize = 0,
    unplaced: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *Converted, allocator: std.mem.Allocator) void {
        self.unplaced.deinit(allocator);
    }

    pub fn isStrip(self: *const Converted) bool {
        return self.module == null;
    }
};

pub const ConvertError = error{ NotAMap, OutOfMemory };

/// The module that a `module=` header of a Console 1 map names. The output is `OUTPT` there.
fn moduleOfHeader(text: []const u8) ?MappableModule {
    if (std.mem.eql(u8, text, "INPUT")) return .INPUT;
    if (std.mem.eql(u8, text, "GATE")) return .GATE;
    if (std.mem.eql(u8, text, "EQ")) return .EQ;
    if (std.mem.eql(u8, text, "COMP")) return .COMP;
    if (std.mem.eql(u8, text, "OUTPT") or std.mem.eql(u8, text, "OUTPUT")) return .OUTPUT;
    return null;
}

/// Converts the text of a map of the Console 1 (lines of `Control=parameter ; comment`). A control that the controller has a place for goes to
/// that place, and when two controls have the same place the last one wins. Because a module map of the Console 1 has the controls of its own
/// module only, a page that has no dry/wet of its own gets REAPER's `wet` on the knob 16, as every page of the controller has; a strip does not,
/// since its dry/wet would be the whole strip's.
pub fn convert(allocator: std.mem.Allocator, text: []const u8) ConvertError!Converted {
    var out = Converted{};
    errdefer out.deinit(allocator);
    var has_module = false;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const no_comment = if (std.mem.indexOfScalar(u8, raw, ';')) |at| raw[0..at] else raw;
        const line = std.mem.trim(u8, no_comment, " \t\r");
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
        if (std.mem.eql(u8, key, "module")) {
            has_module = true;
            out.module = moduleOfHeader(value);
            if (out.module == null and !std.mem.eql(u8, value, "STRIP")) return error.NotAMap;
        } else if (std.mem.eql(u8, key, "fx_name")) {
            out.fx_name = value;
        } else if (value.len != 0) {
            const parameter = std.fmt.parseInt(u16, value, 10) catch continue;
            if (place(key)) |placement| {
                const page = &out.pages[@backingInt(placement.page)];
                switch (placement.position) {
                    .knob => |position| page.setSlot(position, parameter),
                    .push => |position| page.setPush(position, .{ .param = parameter }),
                }
                out.placed += 1;
            } else if (std.mem.indexOfScalar(u8, key, '_') != null and !std.mem.startsWith(u8, key, "fx_")) {
                try out.unplaced.append(allocator, key);
            }
        }
    }
    if (!has_module) return error.NotAMap;
    if (out.module) |module| {
        const page = &out.pages[@backingInt(module)];
        if (page.slotToParam(15) == null) page.setSlot(15, mappings.wet_param);
    }
    return out;
}

fn writeValue(w: *std.Io.Writer, parameter: u16) std.Io.Writer.Error!void {
    if (parameter == mappings.wet_param) try w.writeAll("wet") else try w.print("{d}", .{parameter});
}

fn writePage(w: *std.Io.Writer, page: *const MftModuleMapping) std.Io.Writer.Error!void {
    for (page.knobs, 0..) |maybe, i| {
        const parameter = maybe orelse continue;
        try w.print("knob_{d} = ", .{i + 1});
        try writeValue(w, parameter);
        try w.writeByte('\n');
    }
    for (page.pushes, 0..) |maybe, i| {
        const action = maybe orelse continue;
        try w.print("push_{d} = ", .{i + 1});
        switch (action) {
            .param => |parameter| try writeValue(w, parameter),
            .band => |band| try w.print("band:{d}", .{band}),
        }
        try w.writeByte('\n');
    }
}

/// Writes the map of one module: the headers, then its knobs and pushes. A map that the user made is written with this too.
pub fn writeModuleMap(w: *std.Io.Writer, module: MappableModule, fx_name: []const u8, page: *const MftModuleMapping) std.Io.Writer.Error!void {
    try w.print("version = {d}\nmodule = {s}\nfx_name = {s}\n", .{ mappings.MFT_MAPPING_FORMAT_VERSION, module.dirName(), fx_name });
    try writePage(w, page);
}

/// Writes the map of a channel strip: the headers, then a section for each page that has controls.
pub fn writeStripMap(w: *std.Io.Writer, fx_name: []const u8, strip: *const mappings.StripMapping) std.Io.Writer.Error!void {
    try w.print("version = {d}\nmodule = STRIP\nfx_name = {s}\n", .{ mappings.MFT_MAPPING_FORMAT_VERSION, fx_name });
    inline for (@typeInfo(MappableModule).@"enum".field_names, 0..) |name, i| {
        const page = &strip.pages[i];
        if (!page.isEmpty()) {
            try w.print("\n[{s}]\n", .{name});
            try writePage(w, page);
        }
    }
}

/// Writes a converted map as a map file of the controller: the headers, then the page of a module map, or a section for each page that has
/// controls for a strip.
pub fn write(converted: *const Converted, w: *std.Io.Writer) std.Io.Writer.Error!void {
    if (converted.module) |module| return writeModuleMap(w, module, converted.fx_name, &converted.pages[@backingInt(module)]);
    try w.print("version = {d}\n", .{mappings.MFT_MAPPING_FORMAT_VERSION});
    try w.print("module = STRIP\nfx_name = {s}\n", .{converted.fx_name});
    inline for (@typeInfo(MappableModule).@"enum".field_names, 0..) |name, i| {
        const page = &converted.pages[i];
        if (!page.isEmpty()) {
            try w.print("\n[{s}]\n", .{name});
            try writePage(w, page);
        }
    }
}

test "place: the controls of the design have their positions, and the bypass and the filters to compressor have none" {
    const t = std.testing;
    try t.expectEqual(@as(?Placement, .{ .page = .EQ, .position = .{ .knob = 0 } }), place("Eq_LoFrq"));
    try t.expectEqual(@as(?Placement, .{ .page = .EQ, .position = .{ .push = 3 } }), place("Eq_hp_shape"));
    try t.expectEqual(@as(?Placement, .{ .page = .COMP, .position = .{ .knob = 15 } }), place("Comp_DryWet"));
    try t.expectEqual(@as(?Placement, null), place("Eq_eq"));
    try t.expectEqual(@as(?Placement, null), place("Inpt_filt_to_comp"));
}

test "place: no two controls share a position, and the dry/wet is the last knob only on the compressor" {
    const t = std.testing;
    for (table, 0..) |a, i| {
        for (table[i + 1 ..]) |b| {
            if (a.placement.page != b.placement.page) continue;
            const same = switch (a.placement.position) {
                .knob => |ka| switch (b.placement.position) {
                    .knob => |kb| ka == kb,
                    .push => false,
                },
                .push => |pa| switch (b.placement.position) {
                    .push => |pb| pa == pb,
                    .knob => false,
                },
            };
            try t.expect(!same);
        }
    }
}

test "convert: a module map goes to the page of its module, the dry/wet is added, and the bypass is left out" {
    const t = std.testing;
    const text =
        \\version = 1
        \\module=COMP
        \\fx_name=VST: ReaComp (Cockos)
        \\Comp_Thresh=0
        \\Comp_Ratio=1 ; the ratio
        \\Comp_LoCut=7
        \\Comp_comp=21
        \\Comp_GR=
        \\
    ;
    var converted = try convert(t.allocator, text);
    defer converted.deinit(t.allocator);
    try t.expectEqual(@as(?MappableModule, .COMP), converted.module);
    try t.expectEqualStrings("VST: ReaComp (Cockos)", converted.fx_name);
    const page = &converted.pages[@backingInt(MappableModule.COMP)];
    try t.expectEqual(@as(?u16, 0), page.slotToParam(0));
    try t.expectEqual(@as(?u16, 1), page.slotToParam(1));
    try t.expectEqual(@as(?u16, 7), page.slotToParam(4));
    try t.expectEqual(@as(?u16, mappings.wet_param), page.slotToParam(15));
    try t.expectEqual(@as(usize, 3), converted.placed);
    try t.expectEqual(@as(usize, 1), converted.unplaced.items.len);
    try t.expectEqualStrings("Comp_comp", converted.unplaced.items[0]);
}

test "convert: a channel strip fills several pages and gets no dry/wet; a map without a module is refused" {
    const t = std.testing;
    const text =
        \\version = 1
        \\module=STRIP
        \\fx_name=JS: Lumina Channel Strip
        \\Inpt_Gain=0 ; Input Gain
        \\Eq_LoFrq=3
        \\Eq_hp_shape=10
        \\Out_Vol=29
        \\
    ;
    var converted = try convert(t.allocator, text);
    defer converted.deinit(t.allocator);
    try t.expect(converted.isStrip());
    try t.expectEqual(@as(?u16, 0), converted.pages[@backingInt(MappableModule.INPUT)].slotToParam(0));
    try t.expectEqual(@as(?u16, 29), converted.pages[@backingInt(MappableModule.OUTPUT)].slotToParam(3));
    try t.expectEqual(@as(?mappings.PushAction, .{ .param = 10 }), converted.pages[@backingInt(MappableModule.EQ)].pushAt(3));
    try t.expectEqual(@as(?u16, null), converted.pages[@backingInt(MappableModule.EQ)].slotToParam(15));
    try t.expectError(error.NotAMap, convert(t.allocator, "Eq_LoFrq=3\n"));
}

test "write: a module map has its page and a strip has a section for each page that has controls" {
    const t = std.testing;
    var module_map = try convert(t.allocator, "module=GATE\nfx_name=VST: ReaGate (Cockos)\nShp_Gate=0\nShp_Punch=4\n");
    defer module_map.deinit(t.allocator);
    var aw: std.Io.Writer.Allocating = .init(t.allocator);
    defer aw.deinit();
    try write(&module_map, &aw.writer);
    try t.expectEqualStrings("version = 2\nmodule = GATE\nfx_name = VST: ReaGate (Cockos)\nknob_1 = 0\nknob_3 = 4\nknob_16 = wet\n", aw.written());

    var strip = try convert(t.allocator, "module=STRIP\nfx_name=JS: X\nInpt_Gain=0\nEq_hp_shape=10\n");
    defer strip.deinit(t.allocator);
    var sw: std.Io.Writer.Allocating = .init(t.allocator);
    defer sw.deinit();
    try write(&strip, &sw.writer);
    try t.expectEqualStrings("version = 2\nmodule = STRIP\nfx_name = JS: X\n\n[INPUT]\nknob_1 = 0\n\n[EQ]\npush_4 = 10\n", sw.written());
}

test "roleLabel: the default role of a position, the dry/wet on the last knob, and no default where the page has none" {
    const t = std.testing;
    try t.expectEqualStrings("Gain", roleLabel(.INPUT, false, 0));
    try t.expectEqualStrings("Thresh", roleLabel(.COMP, false, 0));
    try t.expectEqualStrings("Lo Shape", roleLabel(.EQ, true, 0));
    try t.expectEqualStrings("LoMid Shape", roleLabel(.EQ, true, 1));
    try t.expectEqualStrings("Hi Q", roleLabel(.EQ, false, 11));
    try t.expectEqualStrings("Dry/Wet", roleLabel(.GATE, false, 15));
    try t.expectEqualStrings("GR", roleLabel(.COMP, false, 8));
    try t.expectEqualStrings("no default", roleLabel(.INPUT, false, 9));
    try t.expectEqualStrings("no default", roleLabel(.OUTPUT, true, 5));
}
