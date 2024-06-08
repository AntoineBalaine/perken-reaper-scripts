const std = @import("std");
const reaper = @import("../reaper.zig").reaper;

pub const testStruct = struct {
    val: i32 = 0,
    pub fn callMe(self: testStruct) void {
        _ = self;
        reaper.ShowConsoleMsg("hello from zig");
    }
};
