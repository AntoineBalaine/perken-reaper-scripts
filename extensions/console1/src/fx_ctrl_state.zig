const std = @import("std");
const c1 = @import("c1.zig");
const MapStore = @import("mappings.zig");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const FxMap = @import("mappings.zig").FxMap;
const globals = @import("globals.zig");
const constants = @import("constants.zig");
const validation = @import("fx_ctrl_validation.zig");

// Mode-specific state structures
const FxControlState = @This();

pub const TrackList = struct {
    pub const TrackNameSize = 32; // Including null terminator
    pub const PageSize = 20;

    // Fixed size buffer for track names
    track_names: [PageSize]struct { id: c_int, name: [TrackNameSize:0]u8 },
    name_count: usize = 0,
    blink_counter: u8 = 0, // For LED blinking

    pub fn init() TrackList {
        return .{
            .track_names = undefined,
        };
    }
};

pub const ModulesOrder = enum(u8) {
    @"EQ-S-C" = 0x7F,
    @"S-C-EQ" = 0x3F,
    @"S-EQ-C" = 0x0,
};

pub const SCRouting = enum(u8) {
    off = 0x0,
    toShape = 0x7F,
    toComp = 0x3F,
};

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

/// Union to handle different types of controls
const ControlValue = union(enum) {
    param: ParamValue, // For FX parameters
    track: TrackValue, // For track selection buttons
    meter: MeterValue, // For meters
    button: bool, // For simple on/off buttons (mute, solo, etc.)
};

/// Track FX state and mappings
track_state: validation.TrackState = validation.TrackState{},

/// Static map containing all the CCs and their labels.
///
/// Unfortunately, I can’t use an enum map
/// because of the eval branch quota limitations on large enums.
values: std.AutoArrayHashMap(c1.CCs, ControlValue),
scRouting: SCRouting = .off,

/// Display settings
display: ?u8 = null,
vol_lastpos: u8 = 0,

/// Paging
/// 0-based page number
current_page: u8 = 0,
track_list: TrackList,

pub fn init(gpa: std.mem.Allocator) FxControlState {
    var values = std.AutoArrayHashMap(c1.CCs, ControlValue).init(gpa);

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
        .track_list = TrackList.init(),
    };
}

pub fn deinit(self: *@This()) void {
    self.values.deinit();
}

// Tuple contains: isLoaded, idxInContainer
pub const ModuleCheck = std.EnumArray(ModulesList, std.meta.Tuple(&.{ bool, u8 }));
const TrckErr = error{ fxAddFail, fxRenameFail, moduleFindFail, fxFindNameFail, fxHasNoName, enumConvertFail };
// TODO: this is in top scope because I couldn't figure out how to pass the buffer as a fn param. the constness of fn params doesn't let me use the buffer
var buf: [255:0]u8 = undefined;

pub const Track = @This();

// To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index.
// e.g. to address the third item in the container at the second position of the track FX chain for tr,
// the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2.
// This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic.
pub fn getSubContainerIdx(self: *@This(), subidx: u8, container_idx: c_int, mediaTrack: reaper.MediaTrack) c_int {
    _ = self;
    return 0x2000000 + (subidx * (reaper.TrackFX_GetCount(mediaTrack) + 1)) + container_idx;
}

/// if container_idx is provided, then load the chain into it.
const ModuleCounter = struct {
    INPUT: u8 = 0,
    EQ: u8 = 0,
    GATE: u8 = 0,
    COMP: u8 = 0,
    OUTPT: u8 = 0,
};

/// validate track
/// NOTE: track validation is meant to fail silently.
pub fn validateTrack(
    self: *@This(),
    newOrder: ?ModulesOrder,
    mediaTrack: reaper.MediaTrack,
    reRoute: ?SCRouting,
) !void {
    validation.validateTrack(&self.track_state, mediaTrack);

    if (!globals.preferences.manual_routing) {
        // Always get and update current routing
        self.scRouting = self.getCurrentRouting(mediaTrack);

        // If reRoute specified, apply new routing
        if (reRoute) |routing| {
            try self.setSideChainRouting(mediaTrack, routing);
        }
    }

    if (newOrder) |order| {
        try validation.setModulesOrder(&self.track_state, order, mediaTrack);
    }
}

fn validateTrackChannels(mediaTrack: reaper.MediaTrack) !void {
    const track_channels = reaper.GetMediaTrackInfo_Value(mediaTrack, "I_NCHAN");
    if (track_channels < 4) {
        _ = pReaper.SetMediaTrackInfo_Value(.{ mediaTrack, "I_NCHAN", @as(f64, 4) });
    }
}

fn setSideChainRouting(
    self: *@This(),
    mediaTrack: reaper.MediaTrack,
    new_routing: SCRouting,
) !void {
    // Get current FX indices from track_state
    const gate_loc = self.track_state.module_locations.get(.GATE);
    const comp_loc = self.track_state.module_locations.get(.COMP);

    if (gate_loc) |gate| {
        _ = getSetFxSC(
            mediaTrack,
            gate.fx_index,
            if (new_routing == .toShape) .turnOn else .turnOff,
        );
    }

    if (comp_loc) |comp| {
        _ = getSetFxSC(
            mediaTrack,
            comp.fx_index,
            if (new_routing == .toComp) .turnOn else .turnOff,
        );
    }

    self.scRouting = new_routing;
}

const SCAction = enum {
    turnOn,
    turnOff,
};

fn getCurrentRouting(self: *@This(), mediaTrack: reaper.MediaTrack) SCRouting {
    const gate_loc = self.track_state.module_locations.get(.GATE);
    const comp_loc = self.track_state.module_locations.get(.COMP);

    if (gate_loc != null and comp_loc != null) {
        const gate_connected = getSetFxSC(mediaTrack, gate_loc.?.fx_index, null);
        const comp_connected = getSetFxSC(mediaTrack, comp_loc.?.fx_index, null);

        // Check for invalid state (both connected)
        if (gate_connected and comp_connected) {
            // Turn off the one that was connected last
            if (gate_loc.?.fx_index > comp_loc.?.fx_index) {
                _ = getSetFxSC(mediaTrack, gate_loc.?.fx_index, .turnOff);
                return .toComp;
            } else {
                _ = getSetFxSC(mediaTrack, comp_loc.?.fx_index, .turnOff);
                return .toShape;
            }
        }

        if (!gate_connected and !comp_connected) {
            return .off;
        } else {
            return if (gate_connected) .toShape else .toComp;
        }
    }

    return .off; // Default if modules aren't found
}

const ScChange = enum { turnOn, turnOff, toggle };

/// turn fx side chain on channels 3-4.
/// onOff: if null, then just toggle.
/// returns whether the FX' chan 3-4 are connected
fn getSetFxSC(tr: reaper.MediaTrack, subIdx: c_int, onOff: ?ScChange) bool {
    // WARNING: brittle - I'm assuming that both channels  have the same toggles here
    // if they go out of sync (e.g. «chan3 is toggled, chan4 isn't»), this result will be false.
    var connected = true;

    // since we expect chan#3 & chan#4 to go in fxIn#3 & fxIn#4, we can use the same var for both.
    const channels = [2]u8{ 2, 3 };
    const isOutput: u8 = 0; // input = 0, output = 1

    var hi32: c_int = 0;

    for (channels) |channel| {
        // Get current pins
        var low32 = reaper.TrackFX_GetPinMappings(tr, subIdx, isOutput, channel, &hi32);
        const channelMask = std.math.pow(u8, 2, channel);
        const isConnected = (low32 & channelMask) > 0;
        if (onOff) |onoff| {
            if (isConnected) {
                // would this work?    low32 = low32 & channelMask;
                switch (onoff) {
                    .turnOn => connected = isConnected,
                    else => {
                        low32 = low32 - channelMask; // disconnect
                        const pinSuccess = pReaper.TrackFX_SetPinMappings(.{ tr, subIdx, isOutput, channel, low32, hi32 });
                        connected = if (pinSuccess) !isConnected else isConnected;
                    },
                }
            } else {
                switch (onoff) {
                    .turnOff => connected = isConnected,
                    else => {
                        low32 = low32 + channelMask; // connect
                        const pinSuccess = pReaper.TrackFX_SetPinMappings(.{ tr, subIdx, isOutput, channel, low32, hi32 });
                        connected = if (pinSuccess) !isConnected else isConnected;
                    },
                }
            }
        } else {
            connected = isConnected;
        }
    }
    return connected;
}
