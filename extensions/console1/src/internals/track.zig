const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Modules = @import("modules.zig").Modules;
const CONTROLLER_NAME = "PRKN_C1";

const ModulesOrder = union(enum) {
    @"EQ-S-C",
    @"S-C-EQ",
    @"S-EQ-C",
};

const ModuleCheck = std.EnumArray(std.meta.FieldEnum(Track.modules), std.meta.Tuple(&.{ bool, u8 }));

pub const Track = struct {
    track: ?reaper.MediaTrack,
    order: ModulesOrder = .@"S-EQ-C",
    pub fn init(allocator: std.mem.Allocator, trackPtr: reaper.MediaTrack) Track {
        const track: Track = .{ .track = trackPtr, .modules = .{
            .INPUT = std.AutoHashMap([]const u8, void).init(allocator),
            .GATE = std.AutoHashMap([]const u8, void).init(allocator),
            .EQ = std.AutoHashMap([]const u8, void).init(allocator),
            .COMP = std.AutoHashMap([]const u8, void).init(allocator),
            .SAT = std.AutoHashMap([]const u8, void).init(allocator),
        } };
        return track;
    }
    pub fn deinit(allocator: std.mem.Allocator) void {
        _ = allocator;
        @panic("track deinit not implemented yet");
    }
    /// find the default FX for the provided module
    fn findDefaultForModule(self: *Track, key: []const u8) void {
        _ = self; // autofix
        _ = key;
        @panic("findDefaultForModule not implemented yet");
    }
    fn getSubContainerIdx(self: *Track, subidx: u8, container_idx: c_int) u32 {
        _ = self; // autofix
        _ = subidx; // autofix
        _ = container_idx; // autofix
        @panic("getSubContainer is unchecked");
        // return 0x2000000 + (reaper.TrackFX_GetCount(tr) + 1) * subidx + container_idx;
    }
    /// if container_idx is provided, then load the chain into it.
    pub fn loadDefaultChain(self: *Track, container_idx: ?c_int) void {
        _ = container_idx;
        _ = self;
        @panic("loadDefaultChain not implemented");
    }

    pub fn checkTrackState(self: *Track, modules: Modules) void {
        if (self.track == null) {
            return;
        }
        const tr = self.track.?;
        const container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false);
        if (container_idx == -1) {
            self.loadDefaultChain(null);
            return;
        }
        var isDirty = false;
        var memory: [1024]u8 = undefined;
        var buffer: []u8 = &memory;
        const rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_count", &buffer, buffer.len);
        if (!rv) {
            self.loadDefaultChain(container_idx);
            return;
        }
        const count = try std.fmt.parseInt(i32, buffer, 10);
        const fieldsLen = @typeInfo(@TypeOf(modules)).fields.len;
        if (count != fieldsLen) {
            // container's dirty, invalidate and reload
            reaper.TrackFX_Delete(tr, container_idx);
            self.loadDefaultChain(null);
            return;
        }
        var moduleChecks = ModuleCheck.init(.{
            .INPUT = .{ false, 0 },
            .EQ = .{ false, 1 },
            .GATE = .{ false, 2 },
            .COMP = .{ false, 3 },
            .SAT = .{ false, 4 },
        });
        for (0..count - 1) |i| {
            const cntr_rv = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, std.fmt.bufPrint("container_item.{d}", i), buffer, buffer.len);
            _ = cntr_rv; // autofix

            const fx_name: [128]u8 = undefined;
            const fx_name_buffer: []u8 = &memory;
            const has_name = reaper.TrackFX_GetFxName(tr, container_idx, fx_name, fx_name_buffer.len);
            if (!has_name) {
                continue;
            }
            const fieldEnum = std.meta.FieldEnum(@TypeOf(modules));
            const fx_name_enum = std.meta.stringToEnum(fieldEnum, fx_name_buffer) orelse continue;
            var modcheck = moduleChecks.get(fx_name_enum);
            modcheck[0] = true;
            modcheck[1] = @as(u8, i);
            switch (fx_name_enum) {
                .INPUT => isDirty = true,
                .SAT => isDirty = true,
                else => {},
            }
        }
        if (isDirty) {
            if (moduleChecks.get(.INPUT)[1] != 0) {
                const subidx = moduleChecks.get(.INPUT)[1];
                reaper.TrackFX_CopyToTrack(
                    tr,
                    getSubContainerIdx(tr, subidx, container_idx),
                    tr,

                    getSubContainerIdx(tr, 0, container_idx),
                );
                // now that the fx indexes are all invalid, let's recurse.
                return self.checkTrackState();
            }

            if (moduleChecks.get(.SAT)[1] != 0) {
                const subidx = moduleChecks.get(.SAT)[1];
                reaper.TrackFX_CopyToTrack(
                    tr,
                    getSubContainerIdx(tr, subidx, container_idx),
                    tr,

                    getSubContainerIdx(tr, @typeInfo(@TypeOf(modules)).fields.len, container_idx),
                );
                // now that the fx indexes are all invalid, let's recurse.
                return self.checkTrackState();
            }
        }

        // for each missing module, insert it in the correct position
        const it = moduleChecks.iterator();
        while (it.next()) |moduleCheck| {
            if (!moduleCheck[0]) {
                // FIXME: module check keys are actually indexes, not strings.
                const defaultForModule = self.findDefaultForModule(moduleCheck.key);
                const fx_idx = reaper.TrackFX_AddByName(tr, defaultForModule, false, -1);
                reaper.TrackFX_CopyToTrack(tr, fx_idx, tr, getSubContainerIdx(moduleCheck[1], container_idx), true);
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
