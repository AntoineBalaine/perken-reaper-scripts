// Minimal bindings for the SWS extension's SNM fast-string chunk API. These
// are resolved at load time through the REAPER plugin GetFunc mechanism rather
// than reaziglib, because reaziglib only binds the core REAPER API. If SWS is
// not installed the functions stay unresolved and `available` remains false.

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

const GetFunc = *fn (name: [*:0]const u8) callconv(.C) ?*anyopaque;

/// Resolves the SNM functions. Leaves `available` false if any are missing.
pub fn init(get_func: GetFunc) void {
    SNM_CreateFastString = @alignCast(@ptrCast(get_func("SNM_CreateFastString") orelse return));
    SNM_GetSetObjectState = @alignCast(@ptrCast(get_func("SNM_GetSetObjectState") orelse return));
    SNM_GetFastString = @alignCast(@ptrCast(get_func("SNM_GetFastString") orelse return));
    SNM_SetFastString = @alignCast(@ptrCast(get_func("SNM_SetFastString") orelse return));
    SNM_DeleteFastString = @alignCast(@ptrCast(get_func("SNM_DeleteFastString") orelse return));
    available = true;
}
