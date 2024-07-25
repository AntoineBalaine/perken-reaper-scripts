const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const config = @import("config.zig");
const ModulesList = config.ModulesList;
const CONTROLLER_NAME = "PRKN_C1";

const ModulesOrder = union(enum) {
    @"EQ-S-C",
    @"S-C-EQ",
    @"S-EQ-C",
};

const ModuleCheck = std.EnumArray(ModulesList, std.meta.Tuple(&.{ bool, u8 }));
const TrckErr = error{ fxAddFail, fxRenameFail, moduleFindFail, fxFindNameFail };

pub const Track = struct {
    ptr: ?reaper.MediaTrack,
    order: ModulesOrder = .@"S-EQ-C",
    pub fn init(trackPtr: reaper.MediaTrack) Track {
        const track: Track = .{
            .ptr = trackPtr,
        };
        return track;
    }

    pub fn deinit(self: *Track) void {
        self.ptr = null;
        self.order = .@"S-EQ-C";
    }

    // To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index.
    // e.g. to address the third item in the container at the second position of the track FX chain for tr,
    // the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2.
    // This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic.
    fn getSubContainerIdx(self: *Track, subidx: u8, container_idx: c_int) c_int {
        return 0x2000000 + (subidx * (reaper.TrackFX_GetCount(self.ptr.?) + 1)) + container_idx;
    }

    /// if container_idx is provided, then load the chain into it.
    fn loadDefaultChain(self: *Track, container_idx: ?c_int, defaults: *std.EnumArray(ModulesList, [:0]const u8)) !void {
        var cont_idx: c_int = undefined;
        if (container_idx) |idx| {
            cont_idx = idx;
        } else {
            cont_idx = reaper.TrackFX_AddByName(self.ptr.?, "Container", false, -1);
            if (cont_idx == -1) {
                return TrckErr.fxAddFail;
            }
            // rename the container
            const rename_success = reaper.TrackFX_SetNamedConfigParm(self.ptr.?, cont_idx, "renamed_name", CONTROLLER_NAME);
            if (!rename_success) {
                return TrckErr.fxRenameFail;
            }
        }

        // push them into the current container.
        var iterator = defaults.iterator();
        var idx: u8 = 0;
        while (iterator.next()) |field| : (idx += 1) {
            const fx_added = reaper.TrackFX_AddByName(
                self.ptr.?,
                @as([*:0]const u8, defaults.get(field.key)),
                false,
                self.getSubContainerIdx(
                    idx + 1, // make it 1-based
                    reaper.TrackFX_GetByName(self.ptr.?, CONTROLLER_NAME, false) + 1, // make it 1-based
                ),
            );
            if (fx_added == -1) {
                return TrckErr.fxAddFail;
            }
        }
    }

    pub fn checkTrackState(self: *Track, modules: std.StringHashMap(ModulesList), defaults: *std.EnumArray(ModulesList, [:0]const u8)) !void {
        if (self.ptr == null) {
            return;
        }
        const tr = self.ptr.?;
        const container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
        if (container_idx == -1) {
            try self.loadDefaultChain(null, defaults);
            return;
        }
        var buf: [255:0]u8 = undefined;
        const rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buf, buf.len + 1);
        if (!rv) {
            try self.loadDefaultChain(container_idx, defaults);
            return;
        }
        const count = try std.fmt.parseInt(i32, std.mem.span(@as([*:0]const u8, &buf)), 10);
        const fieldsLen = @typeInfo(ModulesList).Enum.fields.len;
        if (count != fieldsLen) {
            // FIXME: check and implement this logic
            // // for each missing module, insert it in the correct position
            // var it = moduleChecks.iterator();
            // while (it.next()) |moduleCheck| {
            //     if (!moduleCheck.value[0]) {
            //         // TODO: config validation should make sure this can never be empty
            //         const defaultForModule = defaults.get(moduleCheck.key);
            //         const fx_idx = reaper.TrackFX_AddByName(tr, defaultForModule, false, -1);
            //         reaper.TrackFX_CopyToTrack(
            //             tr,
            //             fx_idx,
            //             tr,
            //             self.getSubContainerIdx(moduleCheck.value[1], container_idx),
            //             true,
            //         );
            //     }
            // }

            // container's dirty, invalidate and reload
            _ = reaper.TrackFX_Delete(tr, container_idx);
            try self.loadDefaultChain(null, defaults);

            return;
        }
        var moduleChecks = ModuleCheck.init(.{
            .INPUT = .{ false, 0 },
            .EQ = .{ false, 1 },
            .GATE = .{ false, 2 },
            .COMP = .{ false, 3 },
            .SAT = .{ false, 4 },
        });
        // NOTE: might need to check this needs to be count-1
        var tmp_buf: [255:0]u8 = undefined;
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
                std.debug.print("fxFindNameFail\n", .{});
                return TrckErr.fxFindNameFail;
            }
            const fxName = std.mem.span(@as([*:0]const u8, &buf));
            // if fx is found in config, it’s valid.
            const moduleType = modules.get(fxName) orelse {
                // FIXME: handle this more gracefully
                std.debug.print("fxFindNameFail: {s}\n", .{fxName});
                return TrckErr.fxFindNameFail;
            };

            var modcheck = moduleChecks.get(moduleType);
            modcheck[0] = true;
            modcheck[1] = @as(u8, @intCast(idx));
            switch (moduleType) {
                .INPUT => {
                    if (idx != 0) {
                        const cont_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
                        reaper.TrackFX_CopyToTrack(
                            tr,
                            self.getSubContainerIdx(@as(u8, @intCast(idx)) + 1, cont_idx + 1),
                            tr,

                            self.getSubContainerIdx(0 + 1, cont_idx + 1),
                            true,
                        );
                        // now that the fx indexes are all invalid, let's recurse.
                        return try self.checkTrackState(modules, defaults);
                    }
                },
                .SAT => {
                    if (idx != 4) {
                        const cont_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
                        reaper.TrackFX_CopyToTrack(
                            tr,
                            self.getSubContainerIdx(@as(u8, @intCast(idx)) + 1, cont_idx + 1),
                            tr,

                            self.getSubContainerIdx(@typeInfo(ModulesList).Enum.fields.len + 1, cont_idx + 1),
                            true,
                        );
                        // now that the fx indexes are all invalid, let's recurse.
                        return try self.checkTrackState(modules, defaults);
                    }
                },
                else => {},
            }
        }

        var order: ModulesOrder = undefined;
        if (moduleChecks.get(.EQ)[1] == 1 and moduleChecks.get(.GATE)[1] == 2 and moduleChecks.get(.COMP)[1] == 3) {
            order = .@"EQ-S-C";
        } else if (moduleChecks.get(.GATE)[1] == 1 and moduleChecks.get(.COMP)[1] == 2 and moduleChecks.get(.EQ)[1] == 3) {
            order = .@"EQ-S-C";
        } else {
            order = .@"S-EQ-C";
        }
        self.order = order;
    }
};
