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
const TrckErr = error{fxAddFail};

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

    fn getSubContainerIdx(self: *Track, subidx: u8, container_idx: c_int, fx_count: ?c_int) u32 {
        if (fx_count == null) fx_count = reaper.TrackFX_GetCount(self.ptr);
        return 0x2000000 + (fx_count.? + 1) * subidx + container_idx;
    }

    /// if container_idx is provided, then load the chain into it.
    fn loadDefaultChain(self: *Track, container_idx: ?c_int, defaults: *std.EnumArray(ModulesList, [:0]const u8)) !void {
        var cont_idx: c_int = undefined;
        if (container_idx == null) {
            cont_idx = reaper.TrackFX_AddByName(self.ptr.?, "container", false, -1);
            if (cont_idx == -1) {
                return TrckErr.fxAddFail;
            }
            // rename the container
            reaper.TrackFX_SetNamedConfigParm(self.ptr.?, cont_idx, "renamed_name", CONTROLLER_NAME);
        } else {
            cont_idx = container_idx.?;
        }

        const fx_count = reaper.TrackFX_GetCount(self.ptr);

        // push them into the current container.
        const iterator = defaults.iterator();
        var idx = 0;
        while (iterator.next()) |field| : (idx += 1) {
            // FIXME: what are we getting back as a key from the iterator? enum variants or array indexes?
            reaper.TrackFX_AddByName(self.ptr.?, defaults.get(field.key), false, self.getSubContainerIdx(idx, cont_idx, fx_count));
        }
    }

    pub fn checkTrackState(self: *Track, modules: std.StringHashMap(ModulesList), defaults: *std.EnumArray(ModulesList, [:0]const u8)) !void {
        if (self.ptr == null) {
            return;
        }
        const tr = self.ptr.?;
        const container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
        if (container_idx == -1) {
            try self.loadDefaultChain(null);
            return;
        }
        var isDirty = false;
        var memory: [1024]u8 = undefined;
        var buffer: []u8 = &memory;
        const rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buffer, buffer.len);
        if (!rv) {
            try self.loadDefaultChain(container_idx);
            return;
        }
        const count = try std.fmt.parseInt(i32, buffer, 10);
        const fieldsLen = @typeInfo(ModulesList).fields.len;
        if (count != fieldsLen) {
            // container's dirty, invalidate and reload
            reaper.TrackFX_Delete(tr, container_idx);
            try self.loadDefaultChain(null);
            return;
        }
        var moduleChecks = ModuleCheck.init(.{
            .INPUT = .{ false, 0 },
            .EQ = .{ false, 1 },
            .GATE = .{ false, 2 },
            .COMP = .{ false, 3 },
            .SAT = .{ false, 4 },
        });
        for (0..count - 1) |idx| {
            const container_rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, std.fmt.bufPrint("container_item.{d}", idx), buffer, buffer.len);
            // FIXME: this should be checked
            _ = container_rv; // autofix

            const fx_name: [128]u8 = undefined;
            const fx_name_buffer: []u8 = &memory;
            const has_name = reaper.TrackFX_GetFXName(tr, container_idx, fx_name, fx_name_buffer.len);
            if (!has_name) {
                continue;
            }
            // if fx is found in config, it’s valid.
            const moduleType = modules.get(fx_name) orelse continue;
            var modcheck = moduleChecks.get(moduleType);
            modcheck[0] = true;
            modcheck[1] = @as(u8, idx);
            switch (moduleType) {
                .INPUT => {
                    if (idx != 0) isDirty = true;
                },
                .SAT => {
                    if (idx != 4) isDirty = true;
                },
                else => {},
            }
        }
        if (isDirty) {
            if (moduleChecks.get(.INPUT)[1] != 0) {
                const subidx = moduleChecks.get(.INPUT)[1];
                reaper.TrackFX_CopyToTrack(
                    tr,
                    self.getSubContainerIdx(tr, subidx, container_idx, null),
                    tr,

                    self.getSubContainerIdx(tr, 0, container_idx, null),
                );
                // now that the fx indexes are all invalid, let's recurse.
                return try self.checkTrackState(modules);
            }

            if (moduleChecks.get(.SAT)[1] != 0) {
                const subidx = moduleChecks.get(.SAT)[1];
                reaper.TrackFX_CopyToTrack(
                    tr,
                    self.getSubContainerIdx(tr, subidx, container_idx, null),
                    tr,

                    self.getSubContainerIdx(tr, @typeInfo(ModulesList).fields.len, container_idx, null),
                );
                // now that the fx indexes are all invalid, let's recurse.
                return try self.checkTrackState(modules);
            }
        }

        // for each missing module, insert it in the correct position
        const it = moduleChecks.iterator();
        while (it.next()) |moduleCheck| {
            if (!moduleCheck.value[0]) {
                // TODO: config validation should make sure this can never be empty
                const defaultForModule = defaults.get(moduleCheck.key);
                const fx_idx = reaper.TrackFX_AddByName(tr, defaultForModule, false, -1);
                reaper.TrackFX_CopyToTrack(tr, fx_idx, tr, self.getSubContainerIdx(moduleCheck.value[1], container_idx), true);
            }
        }
        var order: ModulesOrder = undefined;
        if (moduleChecks.get(.EQ)[1] == 1 and moduleChecks.get(.GATE)[1] == 2 and moduleChecks.get(.COMP)[1] == 3) {
            order = .@"EQ-S-C";
        } else if (moduleChecks.get(.GATE)[1] == 1 and moduleChecks.get(.COMP)[1] == 2 and moduleChecks.EQ[2] == 3) {
            order = .@"EQ-S-C";
        } else {
            order = .@"S-EQ-C";
        }
        self.order = order;
    }
};
