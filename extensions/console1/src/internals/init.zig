const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Allocator = std.mem.Allocator;
const fs_helpers = @import("fs_helpers.zig");
const containsSubstring = @import("str_helpers.zig").containsSubstring;
const parseConfig = @import("configLoad.zig").parseConfig;

/// check that realearn can be found in `fxtags.ini`
fn isRealearnInstalled(allocator: Allocator) !bool {
    const resourcePath = reaper.GetResourcePath();
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ std.mem.span(resourcePath), "reaper-fxtags.ini" });
    defer allocator.free(file_path);
    const fileContents = try fs_helpers.readFile(allocator, file_path);
    defer allocator.free(fileContents);
    const searchString = "realearn";
    var splits = std.mem.splitAny(u8, fileContents, "\n");
    while (splits.next()) |line| {
        var buf: [searchString.len]u8 = undefined;
        _ = std.ascii.lowerString(&buf, line[0..searchString.len]);
        if (std.mem.eql(u8, &buf, searchString)) {
            return true;
        }
    }
    return false;
}

// C: MediaTrack* GetMasterTrack(ReaProject* proj)
// -- get a track from a project by track count (zero-based) (proj=0 for active project)
// C: int TrackFX_GetRecCount(MediaTrack* track)
// -- On the master track, this accesses monitoring FX rather than record input FX.
// reaper.TrackFX_GetRecCount(reaper.GetMasterTrack(0))
// -- iterate
// C: bool TrackFX_GetFXName(MediaTrack* track, int fx, char* bufOut, int bufOut_sz)
// -- FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track)
fn isRealearnOnMonitoring() !bool {
    const cur_proj = reaper.EnumProjects(-1, null);
    const masterTrack = reaper.GetMasterTrack(cur_proj);
    const fxCount = reaper.TrackFX_GetRecCount(masterTrack);
    std.debug.print("fx count: {d}\n", .{fxCount});
    for (0..@intCast(fxCount)) |fxIndex| {
        std.debug.print("in loop", .{});
        const search_str = "realearn";
        const t = 0x1000000;
        const x: u32 = @intCast(fxIndex);
        const z = t + x;

        var buf: [128]u8 = undefined;
        const has_fx_name = reaper.TrackFX_GetFXName(masterTrack, @intCast(z), @ptrCast(&buf[0]), buf.len);
        if (has_fx_name) {
            var bufLower: [buf.len]u8 = undefined;
            _ = std.ascii.lowerString(&bufLower, &buf);
            std.debug.print("fx name: {s}\n", .{buf});
            if (containsSubstring(@constCast(@ptrCast(search_str)), @ptrCast(&bufLower))) {
                return true;
            }
        }
    }
    return false;
}

pub const InitError = error{
    RealearnNotInstalled,
};

pub fn init(allocator: Allocator) !void {
    const isInstalled = try isRealearnInstalled(allocator);
    if (!isInstalled) {
        return InitError.RealearnNotInstalled;
    }
    const isOnMonitoring = try isRealearnOnMonitoring();
    if (!isOnMonitoring) {
        reaper.ShowConsoleMsg("Realearn is not on monitoring FX chain\n");
    } else {
        reaper.ShowConsoleMsg("Realearn found\n");
    }
    _ = try parseConfig(allocator, "c1");
}
