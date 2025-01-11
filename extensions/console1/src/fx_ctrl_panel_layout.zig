const std = @import("std");
const Knobs = @import("components/knob.zig");
const c1 = @import("internals/c1.zig");
const knob_size = 40.0;
// Define as actual enum types
const Row = enum { top, middle, bottom };
const Col = enum {
    c1,
    c2,
    c3,
    c4,
};

const KnobLayout = struct {
    row: Row,
    col: Col,
};
const COLUMN_SPACING = 20.0;
const ROW_SPACING = 20.0;
const MODULE_SPACING = 40.0;
const MODULE_SPACING_H = 40.0;
const ROW_HEIGHT = knob_size + ROW_SPACING;
const COLUMN_WIDTH = knob_size + COLUMN_SPACING;

// Define positions for each knob
const INPUT_LAYOUT = .{
    .Inpt_Gain = KnobLayout{ .row = .bottom, .col = .c1 },
    .Inpt_HiCut = KnobLayout{ .row = .middle, .col = .c2 },
    .Inpt_LoCut = KnobLayout{ .row = .bottom, .col = .c2 },
};

const SHAPE_LAYOUT = .{
    .Shp_Gate = KnobLayout{ .row = .top, .col = .c1 },
    .Shp_GateRelease = KnobLayout{ .row = .top, .col = .c2 },
    .Shp_hard_gate = KnobLayout{ .row = .middle, .col = .c2 },
};

const EQ_LAYOUT = .{
    .Eq_LoFrq = KnobLayout{ .row = .top, .col = .c1 },
    .Eq_LoGain = KnobLayout{ .row = .top, .col = .c2 },
    .Eq_LoMidFrq = KnobLayout{ .row = .top, .col = .c3 },
    .Eq_LoMidGain = KnobLayout{ .row = .top, .col = .c4 },
};

const COMP_LAYOUT = .{
    .Comp_Ratio = KnobLayout{ .row = .top, .col = .c1 },
    .Comp_Thresh = KnobLayout{ .row = .top, .col = .c2 },
    .Comp_Attack = KnobLayout{ .row = .middle, .col = .c2 },
    .Comp_Release = KnobLayout{ .row = .bottom, .col = .c2 },
};

const OUT_LAYOUT = .{
    .Out_Drive = KnobLayout{ .row = .top, .col = .c1 },
    .Out_Pan = KnobLayout{ .row = .middle, .col = .c1 },
    .Out_Vol = KnobLayout{ .row = .bottom, .col = .c2 },
};

pub fn getKnobPosition(comptime cc: c1.CCs) Knobs.Position {
    const layout: KnobLayout = switch (cc) {
        .Inpt_Gain, .Inpt_HiCut, .Inpt_LoCut => @field(INPUT_LAYOUT, @tagName(cc)),

        .Shp_Gate, .Shp_GateRelease, .Shp_hard_gate => @field(SHAPE_LAYOUT, @tagName(cc)),

        .Eq_LoFrq, .Eq_LoGain, .Eq_LoMidFrq, .Eq_LoMidGain => @field(EQ_LAYOUT, @tagName(cc)),

        .Comp_Thresh, .Comp_Ratio, .Comp_Attack, .Comp_Release => @field(COMP_LAYOUT, @tagName(cc)),

        .Out_Drive, .Out_Vol, .Out_Pan => @field(OUT_LAYOUT, @tagName(cc)),

        else => unreachable,
    };

    const row_offset = switch (layout.row) {
        .top => 0,
        .middle => ROW_HEIGHT,
        .bottom => ROW_HEIGHT * 2,
    };

    const col_offset: f64 = @as(f64, @floatFromInt(@intFromEnum(layout.col))) * COLUMN_WIDTH;

    const module_offset: f64 = switch (cc) {
        .Inpt_Gain, .Inpt_HiCut, .Inpt_LoCut => 0,
        .Shp_Gate, .Shp_GateRelease, .Shp_hard_gate => COLUMN_WIDTH * 4 + MODULE_SPACING_H,
        .Eq_LoFrq, .Eq_LoGain, .Eq_LoMidFrq, .Eq_LoMidGain => COLUMN_WIDTH * 8 + MODULE_SPACING_H * 2,
        .Comp_Ratio, .Comp_Thresh, .Comp_Attack, .Comp_Release => COLUMN_WIDTH * 12 + MODULE_SPACING_H * 3,
        .Out_Drive, .Out_Pan, .Out_Vol => COLUMN_WIDTH * 16 + MODULE_SPACING_H * 4,
        else => unreachable,
    };

    return .{
        .x = col_offset + module_offset, // Add module_offset to x instead of y
        .y = row_offset, // y only depends on row position
    };
}
