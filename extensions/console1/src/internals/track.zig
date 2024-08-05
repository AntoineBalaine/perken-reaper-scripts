const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const config = @import("config.zig");
const ModulesList = config.ModulesList;
const FxMap = @import("mappings.zig").FxMap;
const UserSettings = @import("../internals/userPrefs.zig").UserSettings;
const Conf = @import("config.zig");
pub const CONTROLLER_NAME = "PRKN_C1";

pub const ModulesOrder = enum(u8) {
    @"EQ-S-C" = 0x7F,
    @"S-C-EQ" = 0x3F,
    @"S-EQ-C" = 0x0,
};

const SCRouting = enum(u8) {
    off = 0x0,
    toShape = 0x7F,
    toComp = 0x3F,
};

// Tuple contains: isLoaded, idxInContainer
pub const ModuleCheck = std.EnumArray(ModulesList, std.meta.Tuple(&.{ bool, u8 }));
const TrckErr = error{ fxAddFail, fxRenameFail, moduleFindFail, fxFindNameFail, fxHasNoName, enumConvertFail };
// TODO: this is in top scope because I couldn't figure out how to pass the buffer as a fn param. the constness of fn params doesn't let me use the buffer
var buf: [255:0]u8 = undefined;

pub const Track = @This();

order: ModulesOrder = .@"S-EQ-C",
scRouting: SCRouting = .off,
fxMap: FxMap = FxMap{},

pub fn init() Track {
    const track: Track = .{};
    return track;
}

pub fn deinit(self: *Track) void {
    self.order = .@"S-EQ-C";
}

// To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index.
// e.g. to address the third item in the container at the second position of the track FX chain for tr,
// the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2.
// This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic.
pub fn getSubContainerIdx(self: *Track, subidx: u8, container_idx: c_int, mediaTrack: reaper.MediaTrack) c_int {
    _ = self;
    return 0x2000000 + (subidx * (reaper.TrackFX_GetCount(mediaTrack) + 1)) + container_idx;
}

/// if container_idx is provided, then load the chain into it.
fn loadDefaultChain(
    self: *Track,
    container_idx: ?c_int,
    mediaTrack: reaper.MediaTrack,
) !void {
    var cont_idx: c_int = undefined;
    if (container_idx) |idx| {
        cont_idx = idx;
    } else {
        cont_idx = reaper.TrackFX_AddByName(mediaTrack, "Container", false, -1);
        if (cont_idx == -1) {
            return TrckErr.fxAddFail;
        }
        // rename the container
        const rename_success = reaper.TrackFX_SetNamedConfigParm(mediaTrack, cont_idx, "renamed_name", CONTROLLER_NAME);
        if (!rename_success) {
            return TrckErr.fxRenameFail;
        }
    }

    // push them into the current container.
    var iterator = Conf.defaults.iterator();
    var idx: u8 = 0;
    while (iterator.next()) |field| : (idx += 1) {
        const fxName = Conf.defaults.get(field.key);
        const fx_added = reaper.TrackFX_AddByName(
            mediaTrack,
            @as([*:0]const u8, fxName),
            false,
            self.getSubContainerIdx(idx + 1, // make it 1-based
                reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1, // make it 1-based
                mediaTrack),
        );
        if (fx_added == -1) {
            return TrckErr.fxAddFail;
        } else {
            switch (field.key) {
                .INPUT => self.fxMap.INPUT = .{ idx, Conf.mappings.get(fxName, field.key, Conf.modulesList).INPUT },
                .GATE => self.fxMap.GATE = .{ idx, Conf.mappings.get(fxName, field.key, Conf.modulesList).GATE },
                .EQ => self.fxMap.EQ = .{ idx, Conf.mappings.get(fxName, field.key, Conf.modulesList).EQ },
                .COMP => self.fxMap.COMP = .{ idx, Conf.mappings.get(fxName, field.key, Conf.modulesList).COMP },
                .OUTPT => self.fxMap.OUTPT = .{ idx, Conf.mappings.get(fxName, field.key, Conf.modulesList).OUTPT },
            }
        }
    }
    self.order = .@"S-EQ-C"; // this assumes that iterators go in order of declaration
}

const ModuleCounter = struct {
    INPUT: u8 = 0,
    EQ: u8 = 0,
    GATE: u8 = 0,
    COMP: u8 = 0,
    OUTPT: u8 = 0,
};

pub fn addMissingModules(
    self: *Track,
    count: i32,
    container_idx: c_int,
    mediaTrack: reaper.MediaTrack,
) !void {
    var tmp_buf: [255:0]u8 = undefined;

    const tr = mediaTrack;
    var moduleCounter = ModuleCounter{};

    for (0..@as(usize, @intCast(count))) |idx| {
        _ = try std.fmt.bufPrint(&tmp_buf, "container_item.{d}", .{idx});
        const moduleIdxFound = reaper.TrackFX_GetNamedConfigParm(
            tr,
            container_idx,
            @as([*:0]const u8, &tmp_buf),
            @as([*:0]u8, &buf),
            buf.len + 1,
        );
        if (!moduleIdxFound) {
            std.debug.print("moduleFindFail\n", .{});
            return TrckErr.moduleFindFail;
        }

        const fxId: c_int = try std.fmt.parseInt(c_int, std.mem.span(@as([*:0]const u8, &buf)), 10);
        const has_name = reaper.TrackFX_GetFXName(tr, fxId, @as([*:0]u8, &buf), buf.len + 1);
        if (!has_name) {
            std.debug.print("fxHasNoName\n", .{});
            return TrckErr.fxHasNoName;
        }
        const fxName = std.mem.span(@as([*:0]const u8, &buf));
        // if fx is found in config, it’s valid.
        const moduleType = Conf.modulesList.get(fxName) orelse {
            continue;
        };

        switch (moduleType) {
            .INPUT => {
                moduleCounter.INPUT += 1;
            },
            .EQ => moduleCounter.EQ += 1,
            .GATE => moduleCounter.GATE += 1,
            .COMP => moduleCounter.COMP += 1,
            .OUTPT => moduleCounter.OUTPT += 1,
        }
    }
    inline for (std.meta.fields(@TypeOf(moduleCounter))) |field| {
        const V = @field(moduleCounter, field.name);
        if (V == 0) {
            // add the missing module
            const module = std.meta.stringToEnum(ModulesList, field.name) orelse return TrckErr.enumConvertFail;
            const defaultFX = Conf.defaults.get(module);

            const subidx: u8 = switch (module) {
                .INPUT => 0,
                .EQ => 1,
                .GATE => 2,
                .COMP => 3,
                .OUTPT => 4,
            };

            const fx_added = reaper.TrackFX_AddByName(
                mediaTrack,
                @as([*:0]const u8, defaultFX),
                false,
                self.getSubContainerIdx(subidx + 1, // make it 1-based
                    reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1, // make it 1-based
                    mediaTrack),
            );
            if (fx_added == -1) {
                return TrckErr.fxAddFail;
            }
        }
    }
}

pub fn checkTrackState(
    self: *Track,
    newOrder: ?ModulesOrder,
    mediaTrack: reaper.MediaTrack,
    newRouting: ?SCRouting,
) !void {
    const tr = mediaTrack;
    var container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
    if (container_idx == -1) { // if no container
        try self.loadDefaultChain(null, mediaTrack);
        container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
    }

    // if no fx in container
    if (!reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buf, buf.len + 1)) {
        try self.loadDefaultChain(container_idx, mediaTrack);
        _ = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buf, buf.len + 1);
    }
    const count = try std.fmt.parseInt(i32, std.mem.span(@as([*:0]const u8, &buf)), 10);
    const fieldsLen = @typeInfo(ModulesList).Enum.fields.len;
    if (count != fieldsLen) {
        try self.addMissingModules(count, container_idx, mediaTrack);
    }
    var moduleChecks = ModuleCheck.init(.{
        .INPUT = .{ false, 0 },
        .EQ = .{ false, 1 },
        .GATE = .{ false, 2 },
        .COMP = .{ false, 3 },
        .OUTPT = .{ false, 4 },
    });
    var tmp_buf: [255:0]u8 = undefined;

    // we have to re-query since addMissingModules() might have made an update.
    for (0..@as(usize, @intCast(count))) |idx| {
        _ = try std.fmt.bufPrint(&tmp_buf, "container_item.{d}", .{idx});
        const moduleIdxFound = reaper.TrackFX_GetNamedConfigParm(
            tr,
            container_idx,
            @as([*:0]const u8, &tmp_buf),
            &buf,
            buf.len + 1,
        );
        if (!moduleIdxFound) {
            // FIXME: handle this more gracefully
            return TrckErr.moduleFindFail;
        }

        const fxId: c_int = try std.fmt.parseInt(c_int, std.mem.span(@as([*:0]const u8, &buf)), 10);
        const has_name = reaper.TrackFX_GetFXName(tr, fxId, @as([*:0]u8, &buf), buf.len + 1);
        if (!has_name) {
            // FIXME: handle this more gracefully
            std.debug.print("\nfxHasNoName\n", .{});
            return TrckErr.fxHasNoName;
        }
        const fxName = std.mem.span(@as([*:0]const u8, &buf));

        const moduleType = Conf.modulesList.get(fxName) orelse { // no mapping available
            continue;
        };

        if (moduleChecks.get(moduleType)[0] == true) { // already found
            continue;
        }
        moduleChecks.set(moduleType, .{ true, @as(u8, @intCast(idx)) });

        switch (moduleType) {
            .INPUT => {
                if (idx != 0) {
                    reaper.TrackFX_CopyToTrack(
                        tr,
                        self.getSubContainerIdx(@as(u8, @intCast(idx)) + 1, container_idx + 1, mediaTrack),
                        tr,

                        self.getSubContainerIdx(0 + 1, container_idx + 1, mediaTrack),
                        true,
                    );
                    // now that the fx indexes are all invalid, let's recurse.
                    return try self.checkTrackState(newOrder, mediaTrack, newRouting);
                } else {
                    self.fxMap.INPUT = .{ @as(u8, @intCast(idx)), Conf.mappings.get(fxName, .INPUT, Conf.modulesList).INPUT };
                }
            },
            .OUTPT => {
                if (idx != (count - 1)) {
                    reaper.TrackFX_CopyToTrack(
                        tr,
                        self.getSubContainerIdx(@as(u8, @intCast(idx)) + 1, container_idx + 1, mediaTrack),
                        tr,
                        self.getSubContainerIdx(@as(u8, @intCast(count)), container_idx + 1, mediaTrack),
                        true,
                    );
                    // now that the fx indexes are all invalid, let's recurse.
                    return try self.checkTrackState(newOrder, mediaTrack, newRouting);
                } else {
                    self.fxMap.OUTPT = .{ @as(u8, @intCast(idx)), Conf.mappings.get(fxName, .OUTPT, Conf.modulesList).OUTPT };
                }
            },
            .GATE => self.fxMap.GATE = .{ @as(u8, @intCast(idx)), Conf.mappings.get(fxName, .GATE, Conf.modulesList).GATE },
            .EQ => self.fxMap.EQ = .{ @as(u8, @intCast(idx)), Conf.mappings.get(fxName, .EQ, Conf.modulesList).EQ },
            .COMP => self.fxMap.COMP = .{ @as(u8, @intCast(idx)), Conf.mappings.get(fxName, .COMP, Conf.modulesList).COMP },
        }
    }

    const eq = moduleChecks.get(.EQ)[1];
    const gt = moduleChecks.get(.GATE)[1];
    const cp = moduleChecks.get(.COMP)[1];
    if (eq < gt and eq < cp) {
        if (cp < gt) {
            // move the gate to be before the compressor
            reaper.TrackFX_CopyToTrack(
                tr,
                self.getSubContainerIdx(gt + 1, container_idx + 1, mediaTrack),
                tr,
                self.getSubContainerIdx(cp + 1, container_idx + 1, mediaTrack),
                true,
            );
            // update indexes
            moduleChecks.set(.GATE, .{ true, cp });
            moduleChecks.set(.COMP, .{ true, cp + 1 });
        }
        self.order = .@"EQ-S-C";
    } else if (gt < cp and gt < eq) {
        if (cp < eq) {
            self.order = .@"S-C-EQ";
        } else {
            self.order = .@"S-EQ-C";
        }
    } else if (cp < eq and cp < gt) {
        // mv cmp after the gate
        reaper.TrackFX_CopyToTrack(
            tr,
            self.getSubContainerIdx(cp + 1, container_idx + 1, mediaTrack),
            tr,
            self.getSubContainerIdx(gt + 1, container_idx + 1, mediaTrack),
            true,
        );
        moduleChecks.set(.COMP, .{ true, gt });
        moduleChecks.set(.GATE, .{ true, gt - 1 });
        moduleChecks.set(.EQ, .{ true, eq - 1 });

        // update indexes
        if (eq < gt) {
            self.order = .@"EQ-S-C";
        } else {
            self.order = .@"S-C-EQ";
        }
    }

    if (newOrder) |order| { // reorder fx after finding where they are
        self.reorder(tr, order, container_idx, moduleChecks);
    }
    if (!UserSettings.manual_routing) {
        self.setChanStripSC(tr, container_idx, moduleChecks, newRouting);
    }
}

pub fn reorder(self: *Track, tr: reaper.MediaTrack, newOrder: ModulesOrder, container_idx: c_int, moduleChecks: ModuleCheck) void {
    if (newOrder == self.order) return;
    const eq = moduleChecks.get(.EQ)[1];
    const gt = moduleChecks.get(.GATE)[1];
    const cp = moduleChecks.get(.COMP)[1];
    switch (newOrder) {
        .@"EQ-S-C" => {
            // move eq before gate
            reaper.TrackFX_CopyToTrack(
                tr,
                self.getSubContainerIdx(eq + 1, container_idx + 1, tr),
                tr,
                self.getSubContainerIdx(gt + 1, container_idx + 1, tr),
                true,
            );
        },
        .@"S-C-EQ" => {
            // move eq after compressor
            reaper.TrackFX_CopyToTrack(
                tr,
                self.getSubContainerIdx(eq + 1, container_idx + 1, tr),
                tr,
                self.getSubContainerIdx(cp + 1, container_idx + 1, tr),
                true,
            );
        },
        .@"S-EQ-C" => {
            { // move eq before compressor
                reaper.TrackFX_CopyToTrack(
                    tr,
                    self.getSubContainerIdx(eq + 1, container_idx + 1, tr),
                    tr,
                    self.getSubContainerIdx(cp, container_idx + 1, tr),
                    true,
                );
            }
        },
    }
}

/// validate track routing:
/// set track to have 4 channels if it doesn't already.
/// if called during track-init, toggle all the SC inputs (gate & comp) in the container to OFF
/// else, just validate whether they're there.
fn setChanStripSC(self: *Track, tr: reaper.MediaTrack, container_idx: c_int, moduleChecks: ModuleCheck, newRouting: ?SCRouting) void {
    var inputPinsOut: c_int = 0;
    var outputPinsOut: c_int = 0;
    _ = reaper.TrackFX_GetIOSize(tr, container_idx, &inputPinsOut, &outputPinsOut);
    const trIns = reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN");
    if (trIns < 4) {
        _ = reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", @as(f64, 4));
    }
    _ = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_nch", &buf, buf.len);
    const num = std.mem.span(@as([*:0]const u8, &buf));
    const containerChannels = std.fmt.parseInt(u8, num, 10) catch null;
    if (containerChannels) |containrChannels| {
        if (containrChannels < 4) {
            // create a container with 4 channels - mapping i/o should be automatic
            // WARNING: for custom fx mappings (i.e. non-stock plugins),
            // is the i/o setup really automatic?
            _ = reaper.TrackFX_SetNamedConfigParm(tr, container_idx, "container_nch", "4");
            _ = reaper.TrackFX_SetNamedConfigParm(tr, container_idx, "container_nch_in", "4");
        }
    }

    if (newRouting) |newRoutg| {
        switch (newRoutg) {
            .off => {
                _ = getSetFxSC(
                    tr,
                    self.getSubContainerIdx(moduleChecks.get(.COMP)[1] + 1, container_idx + 1, tr),
                    .turnOff,
                );
                _ = getSetFxSC(
                    tr,
                    self.getSubContainerIdx(moduleChecks.get(.GATE)[1] + 1, container_idx + 1, tr),
                    .turnOff,
                );
            },
            .toShape => {
                _ = getSetFxSC(
                    tr,
                    self.getSubContainerIdx(moduleChecks.get(.COMP)[1] + 1, container_idx + 1, tr),
                    .turnOff,
                );
                _ = getSetFxSC(
                    tr,
                    self.getSubContainerIdx(moduleChecks.get(.GATE)[1] + 1, container_idx + 1, tr),
                    .turnOn,
                );
            },
            .toComp => {
                _ = getSetFxSC(
                    tr,
                    self.getSubContainerIdx(moduleChecks.get(.COMP)[1] + 1, container_idx + 1, tr),
                    .turnOn,
                );
                _ = getSetFxSC(
                    tr,
                    self.getSubContainerIdx(moduleChecks.get(.GATE)[1] + 1, container_idx + 1, tr),
                    .turnOff,
                );
            },
        }
        self.scRouting = newRoutg;
    } else {
        self.scRouting = self.getRouting(tr, moduleChecks, container_idx);
    }
}

fn getRouting(self: *Track, tr: reaper.MediaTrack, moduleChecks: ModuleCheck, container_idx: c_int) SCRouting {
    const gt = moduleChecks.get(.GATE);
    const cp = moduleChecks.get(.COMP);
    const gtConnected = getSetFxSC(
        tr,
        self.getSubContainerIdx(gt[1] + 1, container_idx + 1, tr),
        null,
    );
    const cpConnected =
        getSetFxSC(
        tr,
        self.getSubContainerIdx(gt[1] + 1, container_idx + 1, tr),
        null,
    );

    // just validate
    if (gtConnected and cpConnected) {
        // it's invalid, toggle whichever's latest
        const subidx = if (gt[1] > cp[1]) gt[1] else cp[1];
        _ = getSetFxSC(
            tr,
            self.getSubContainerIdx(subidx + 1, container_idx + 1, tr),
            .turnOff,
        );
        return if (gt[1] > cp[1]) .toComp else .toShape;
    }
    if (!gtConnected and !cpConnected) {
        return .off;
    } else {
        return if (gtConnected) .toShape else .toComp;
    }
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
        const channelMask = std.math.pow(u8, channel, 2);
        const isConnected = (low32 & channelMask) > 0;
        if (onOff) |onoff| {
            if (isConnected) {
                // would this work?    low32 = low32 & channelMask;
                switch (onoff) {
                    .turnOn => connected = isConnected,
                    else => {
                        // would this work?    low32 = low32 | channelMask;
                        low32 = low32 - channelMask; // disconnect
                        const pinSuccess = reaper.TrackFX_SetPinMappings(tr, subIdx, isOutput, channel, low32, hi32);
                        connected = if (pinSuccess) !isConnected else isConnected;
                    },
                }
            } else {
                switch (onoff) {
                    .turnOff => connected = isConnected,
                    else => {
                        // would this work?    low32 = low32 | channelMask;
                        low32 = low32 + channelMask; // connect
                        const pinSuccess = reaper.TrackFX_SetPinMappings(tr, subIdx, isOutput, channel, low32, hi32);
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
