const std = @import("std");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const MftModuleMapping = mappings.MftModuleMapping;

pub const ResolvedFx = struct {
    fx_index: c_int,
    mapping: MftModuleMapping,
};

// Find the first FX on the track whose name has a mapping for the active
// module. Because the MFT dedicates the eight encoders to one module at a
// time, a single FX per module is enough.
pub fn resolveFx(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule) ?ResolvedFx {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var name_buf: [512:0]u8 = undefined;
        if (!reaper.TrackFX_GetFXName(track, i, &name_buf, name_buf.len)) continue;
        const name: [:0]const u8 = std.mem.sliceTo(&name_buf, 0);
        if (globals.map_store.get(module, name)) |mapping| {
            return .{ .fx_index = i, .mapping = mapping };
        }
    }
    return null;
}
