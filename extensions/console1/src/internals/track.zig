const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const config = @import("config.zig");
const ModulesList = config.ModulesList;
const FxMap = @import("mappings.zig").FxMap;
pub const CONTROLLER_NAME = "PRKN_C1";

const ModulesOrder = enum(u8) {
    @"EQ-S-C" = 0x7F,
    @"S-C-EQ" = 0x3F,
    @"S-EQ-C" = 0x0,
};

pub const ModuleCheck = std.EnumArray(ModulesList, std.meta.Tuple(&.{ bool, u8 }));
const TrckErr = error{ fxAddFail, fxRenameFail, moduleFindFail, fxFindNameFail, fxHasNoName, enumConvertFail };
// TODO: this is in top scope because I couldn't figure out how to pass the buffer as a fn param. the constness of fn params doesn't let me use the buffer
var buf: [255:0]u8 = undefined;

pub const Track = @This();

order: ModulesOrder = .@"S-EQ-C",
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
    defaults: *config.Defaults,
    modules: config.Modules,
    mappings: *config.MapStore,
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
    var iterator = defaults.iterator();
    var idx: u8 = 0;
    while (iterator.next()) |field| : (idx += 1) {
        const fxName = defaults.get(field.key);
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
                .INPUT => self.fxMap.INPUT = .{ idx, mappings.get(fxName, field.key, modules).INPUT },
                .GATE => self.fxMap.GATE = .{ idx, mappings.get(fxName, field.key, modules).GATE },
                .EQ => self.fxMap.EQ = .{ idx, mappings.get(fxName, field.key, modules).EQ },
                .COMP => self.fxMap.COMP = .{ idx, mappings.get(fxName, field.key, modules).COMP },
                .OUTPT => self.fxMap.OUTPT = .{ idx, mappings.get(fxName, field.key, modules).OUTPT },
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
    modules: std.StringHashMap(ModulesList),
    defaults: *std.EnumArray(ModulesList, [:0]const u8),
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
        const moduleType = modules.get(fxName) orelse {
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
            const defaultFX = defaults.get(module);

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
    modules: std.StringHashMap(ModulesList),
    defaults: *std.EnumArray(ModulesList, [:0]const u8),
    mappings: *config.MapStore,
    newOrder: ?ModulesOrder,
    mediaTrack: reaper.MediaTrack,
) !void {
    const tr = mediaTrack;
    const container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
    if (container_idx == -1) {
        try self.loadDefaultChain(null, defaults, modules, mappings, mediaTrack);
        return;
    }
    const rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buf, buf.len + 1);
    if (!rv) {
        try self.loadDefaultChain(container_idx, defaults, modules, mappings, mediaTrack);
        return;
    }
    const count = try std.fmt.parseInt(i32, std.mem.span(@as([*:0]const u8, &buf)), 10);
    const fieldsLen = @typeInfo(ModulesList).Enum.fields.len;
    if (count != fieldsLen) {
        try self.addMissingModules(count, modules, defaults, container_idx, mediaTrack);
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
            std.debug.print("moduleFindFail\n", .{});
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

        const moduleType = modules.get(fxName) orelse { // no mapping available
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
                    return try self.checkTrackState(modules, defaults, mappings, newOrder, mediaTrack);
                } else {
                    self.fxMap.INPUT = .{ @as(u8, @intCast(idx)), mappings.get(fxName, .INPUT, modules).INPUT };
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
                    return try self.checkTrackState(modules, defaults, mappings, newOrder, mediaTrack);
                } else {
                    self.fxMap.OUTPT = .{ @as(u8, @intCast(idx)), mappings.get(fxName, .OUTPT, modules).OUTPT };
                }
            },
            .GATE => self.fxMap.GATE = .{ @as(u8, @intCast(idx)), mappings.get(fxName, .GATE, modules).GATE },
            .EQ => self.fxMap.EQ = .{ @as(u8, @intCast(idx)), mappings.get(fxName, .EQ, modules).EQ },
            .COMP => self.fxMap.COMP = .{ @as(u8, @intCast(idx)), mappings.get(fxName, .COMP, modules).COMP },
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
