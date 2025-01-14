const std = @import("std");
const track = @import("internals/track.zig");
const c1 = @import("c1.zig");
const MapStore = @import("mappings.zig");
const FxMap = MapStore.FxMap;
// Mode-specific state structures
const FxControlState = @This();
comptime {
    @setEvalBranchQuota(9999999); // Increase the quota to handle the large enum
}

// Value types for different CC controls
const ParamValue = struct {
    normalized: f64 = 0.0,
    formatted: ?[:0]const u8 = null,
    label: [:0]const u8, // Hardcoded label matching Console1
};

const TrackValue = struct {
    is_selected: bool = false,
    track_number: ?usize = null, // null if no track at this position
    label: [:0]const u8, // "Track 1", "Track 2", etc.
};

const MeterValue = struct {
    current_value: f64 = 0.0,
    peak_value: f64 = 0.0,
    label: [:0]const u8,
};

// Union to handle different types of controls
const ControlValue = union(enum) {
    param: ParamValue, // For FX parameters
    track: TrackValue, // For track selection buttons
    meter: MeterValue, // For meters
    button: bool, // For simple on/off buttons (mute, solo, etc.)
};

// Current parameter mappings
fxMap: FxMap = FxMap{},

values: std.AutoHashMap(c1.CCs, ControlValue),
// Module ordering
order: track.ModulesOrder = .@"S-EQ-C",
scRouting: track.SCRouting = .off,

// Display settings
show_plugin_ui: bool = false,

// Paging
current_page: u8 = 0, // 0-based page number
pub fn init(gpa: std.mem.Allocator) FxControlState {
    var values = std.AutoHashMap(c1.CCs, ControlValue).init(gpa);

    // Initialize with appropriate types and labels
    inline for (comptime std.enums.values(c1.CCs)) |cc| {
        values.put(cc, switch (cc) {
            // Track selection buttons
            .Tr_tr1, .Tr_tr10, .Tr_tr11, .Tr_tr12, .Tr_tr13, .Tr_tr14, .Tr_tr15, .Tr_tr16, .Tr_tr17, .Tr_tr18, .Tr_tr19, .Tr_tr2, .Tr_tr20, .Tr_tr3, .Tr_tr4, .Tr_tr5, .Tr_tr6, .Tr_tr7, .Tr_tr8, .Tr_tr9 => .{ .track = .{
                .label = cc.getLabel(),
            } },
            // Meters
            .Shp_Mtr, .Comp_Mtr, .Inpt_MtrLft, .Inpt_MtrRgt, .Out_MtrLft, .Out_MtrRgt => .{ .meter = .{
                .label = cc.getLabel(),
            } },
            // Simple buttons
            .Out_mute,
            .Out_solo,
            .Comp_comp,
            .Eq_eq,
            .Eq_hp_shape,
            .Eq_lp_shape,
            .Shp_hard_gate,
            .Shp_shape,
            => .{
                .button = false,
            },
            // Everything else is a parameter
            else => .{ .param = .{
                .label = cc.getLabel(),
            } },
        }) catch unreachable;
    }

    return .{
        .values = values,
    };
}

pub fn deinit(self: *@This()) void {
    self.values.deinit();
}

pub fn getTrackOffset(self: @This()) usize {
    return self.current_page * 20;
}

pub fn getPageForTrack(track_number: usize) u8 {
    return @intCast(track_number / 20);
}

pub fn isTrackInCurrentPage(self: @This(), track_number: usize) bool {
    const page_start = self.getTrackOffset();
    return track_number >= page_start and track_number < page_start + 20;
}

// Helper to update a parameter value
pub fn updateParam(self: *@This(), cc: c1.CCs, normalized: f64, formatted: ?[]const u8) void {
    if (self.values.getPtr(cc)) |value| {
        if (value.* == .param) {
            value.param.normalized = normalized;
            if (formatted) |fmt| {
                value.param.formatted = fmt;
            }
        }
    }
}
