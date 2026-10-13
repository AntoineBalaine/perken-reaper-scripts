// Minimal bindings for the SWS extension's SNM fast-string chunk API. They are
// resolved through REAPER's plugin_getapi rather than reaziglib, because
// reaziglib only binds the core REAPER API. SWS registers these functions
// when it loads, which happens after this extension (plugin files load in
// name order), so init() runs when a feature first needs them, not at load.
// If SWS is not installed the functions stay unresolved and `available`
// remains false.

const std = @import("std");
const reaper = @import("reaper").reaper;

/// Opaque WDL_FastString handle owned by SWS.
pub const FastString = *anyopaque;

pub var available: bool = false;

pub var SNM_CreateFastString: *fn (str: [*:0]const u8) callconv(.C) FastString = undefined;
pub var SNM_GetSetObjectState: *fn (obj: *anyopaque, state: FastString, setnewvalue: bool, wantminimalstate: bool) callconv(.C) bool = undefined;
pub var SNM_GetFastString: *fn (str: FastString) callconv(.C) [*:0]const u8 = undefined;
pub var SNM_SetFastString: *fn (str: FastString, newstr: [*:0]const u8) callconv(.C) FastString = undefined;
pub var SNM_DeleteFastString: *fn (str: FastString) callconv(.C) void = undefined;

/// Resolves the SNM functions. Leaves `available` false if any are missing.
pub fn init() void {
    const get_func = reaper.plugin_getapi;
    SNM_CreateFastString = @alignCast(@ptrCast(get_func("SNM_CreateFastString") orelse return));
    SNM_GetSetObjectState = @alignCast(@ptrCast(get_func("SNM_GetSetObjectState") orelse return));
    SNM_GetFastString = @alignCast(@ptrCast(get_func("SNM_GetFastString") orelse return));
    SNM_SetFastString = @alignCast(@ptrCast(get_func("SNM_SetFastString") orelse return));
    SNM_DeleteFastString = @alignCast(@ptrCast(get_func("SNM_DeleteFastString") orelse return));
    available = true;
}
