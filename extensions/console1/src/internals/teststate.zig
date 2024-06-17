const std = @import("std");
const reaper = @import("../reaper.zig").reaper;

pub const testStruct = struct {
    val: i32 = 0,
    pub fn callMe(self: testStruct) void {
        _ = self;
        reaper.ShowConsoleMsg("hello from zig");
    }
};

//find if all modules are represented
// for each represented module, which fx from the available mappings does it represent?
// pub fn onTrCh(track: *reaper.MediaTrack, prefs: Prefs) void {
//     const modules_names = [_][]const u8{ "eq", "cmp", "shape" };
//     // don’t instantiate
//     for (modules_names) |module_name| {
//         if (!prefs.defaultFx[module_name]) {
//             continue;
//         }
//         var mod_idx = reaper.TrackFX_AddByName(track, module_name, 0);
//         if (mod_idx == -1) {
//             mod_idx = reaper.TrackFX_AddByName(track,
//             // todo how to access elements in hashmap?
//             prefs.defaultFx[module_name], 1);
//             reaper.TrackFX_SetNamedConfigParm(track, mod_idx, "renamed_name", module_name);
//         }
//     }
//     // TODO load realearn instance matching the current module, if it’s not loaded.
// }
