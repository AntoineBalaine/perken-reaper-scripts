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
const TrckErr = error{ fxAddFail, fxRenameFail, moduleFindFail, fxFindNameFail, fxHasNoName, enumConvertFail };
// TODO: this is in top scope because I couldn't figure out how to pass the buffer as a fn param. the constness of fn params doesn't let me use the buffer
var buf: [255:0]u8 = undefined;

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

    const ModuleCounter = struct {
        INPUT: u8 = 0,
        EQ: u8 = 0,
        GATE: u8 = 0,
        COMP: u8 = 0,
        SAT: u8 = 0,
    };

    pub fn addMissingModules(
        self: *Track,
        count: i32,
        modules: std.StringHashMap(ModulesList),
        defaults: *std.EnumArray(ModulesList, [:0]const u8),
    ) !void {
        var tmp_buf: [255:0]u8 = undefined;

        const tr = self.ptr.?;
        const container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
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
                .INPUT => moduleCounter.INPUT += 1,
                .EQ => moduleCounter.EQ += 1,
                .GATE => moduleCounter.GATE += 1,
                .COMP => moduleCounter.COMP += 1,
                .SAT => moduleCounter.SAT += 1,
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
                    .SAT => 4,
                };

                const fx_added = reaper.TrackFX_AddByName(
                    self.ptr.?,
                    @as([*:0]const u8, defaultFX),
                    false,
                    self.getSubContainerIdx(
                        subidx + 1, // make it 1-based
                        reaper.TrackFX_GetByName(self.ptr.?, CONTROLLER_NAME, false) + 1, // make it 1-based
                    ),
                );
                if (fx_added == -1) {
                    return TrckErr.fxAddFail;
                }
            }
        }
    }

    pub fn checkTrackState(self: *Track, modules: std.StringHashMap(ModulesList), defaults: *std.EnumArray(ModulesList, [:0]const u8)) !void {
        if (self.ptr == null) {
            return;
        }
        const tr = self.ptr.?;
        var container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
        if (container_idx == -1) {
            try self.loadDefaultChain(null, defaults);
            return;
        }
        const rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buf, buf.len + 1);
        if (!rv) {
            try self.loadDefaultChain(container_idx, defaults);
            return;
        }
        const count = try std.fmt.parseInt(i32, std.mem.span(@as([*:0]const u8, &buf)), 10);
        const fieldsLen = @typeInfo(ModulesList).Enum.fields.len;
        if (count != fieldsLen) {
            try self.addMissingModules(
                count,
                modules,
                defaults,
            );
        }
        var moduleChecks = ModuleCheck.init(.{
            .INPUT = .{ false, 0 },
            .EQ = .{ false, 1 },
            .GATE = .{ false, 2 },
            .COMP = .{ false, 3 },
            .SAT = .{ false, 4 },
        });
        var tmp_buf: [255:0]u8 = undefined;

        // we have to re-query since addMissingModules() might have made an update.
        if (count != fieldsLen) {
            container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
        }
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
                std.debug.print("fxHasNoName\n", .{});
                return TrckErr.fxHasNoName;
            }
            const fxName = std.mem.span(@as([*:0]const u8, &buf));

            const moduleType = modules.get(fxName) orelse {
                continue;
            };

            var modcheck = moduleChecks.get(moduleType);
            if (modcheck[0] == true) { // already found
                continue;
            }
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
                    if (idx != (count - 1)) {
                        const cont_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);

                        const src = self.getSubContainerIdx(@as(u8, @intCast(idx)) + 1, cont_idx + 1);
                        const dest = self.getSubContainerIdx(@as(u8, @intCast(count)), cont_idx + 1);
                        reaper.TrackFX_CopyToTrack(
                            tr,
                            src,
                            tr,
                            dest,
                            true,
                        );
                        // now that the fx indexes are all invalid, let's recurse.
                        return try self.checkTrackState(modules, defaults);
                    }
                },
                else => {},
            }
        }

        const eq = moduleChecks.get(.EQ)[1];
        const gt = moduleChecks.get(.GATE)[1];
        const cp = moduleChecks.get(.COMP)[1];
        if (eq < gt and eq < cp) {
            if (cp < gt) {
                // TODO: move the gate to be before the compressor
            }
            self.order = .@"EQ-S-C";
        } else if (gt < cp and gt < eq) {
            if (cp < eq) {
                self.order = .@"S-C-EQ";
            } else {
                self.order = .@"S-EQ-C";
            }
        } else if (cp < eq and gt < gt) {
            if (eq < gt) {
                // TODO: mv cmp after the two - first index after the gate
                self.order = .@"EQ-S-C";
            } else {
                // TODO: mv cmp between the two - first index after the gate
                self.order = .@"S-C-EQ";
            }
        }
    }
};
