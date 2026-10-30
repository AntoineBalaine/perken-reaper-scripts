// ReaPack API functions
pub var ReaPack_BrowsePackages: *fn (filter: [*:0]const u8) callconv(.c) void = undefined;
pub var ReaPack_GetRepositoryInfo: *fn (name: [*:0]const u8, urlOut: ?[*]u8, urlOutSize: c_int, enabledOut: ?*bool, autoInstallOut: ?*bool) callconv(.c) bool = undefined;
pub var ReaPack_AddSetRepository: *fn (name: [*:0]const u8, url: [*:0]const u8, enabled: bool, autoInstall: c_int) callconv(.c) bool = undefined;
pub var ReaPack_ProcessQueue: *fn (sync: bool) callconv(.c) void = undefined;
pub var ReaPack_FreeEntry: *fn (entry: ?*anyopaque) callconv(.c) void = undefined;
pub var ReaPack_EnumPackages: *fn (index: c_int, nameOut: ?[*]u8, nameOutSize: c_int) callconv(.c) bool = undefined;

// Initialize ReaPack API
pub fn init(plugin_getapi: *fn (name: [*:0]const u8) callconv(.c) ?*anyopaque) !void {
    @setRuntimeSafety(false);

    // Check if ReaPack is installed by trying to get one of its core functions

    const browse_func = plugin_getapi("ReaPack_BrowsePackages");

    if (browse_func == null) {
        return error.ReaPackNotInstalled;
    }
    ReaPack_BrowsePackages = @ptrCast(@alignCast(browse_func));

    // ReaPack_GetRepositoryInfo = @ptrCast(plugin_getapi("ReaPack_GetRepositoryInfo"));
    // if (ReaPack_GetRepositoryInfo == null) {
    //     last_error = "Failed to get ReaPack_GetRepositoryInfo function";
    //     return error.InvalidFunction;
    // }
    //
    // ReaPack_AddSetRepository = @ptrCast(plugin_getapi("ReaPack_AddSetRepository"));
    // if (ReaPack_AddSetRepository == null) {
    //     last_error = "Failed to get ReaPack_AddSetRepository function";
    //     return error.InvalidFunction;
    // }
    //
    // ReaPack_ProcessQueue = @ptrCast(plugin_getapi("ReaPack_ProcessQueue"));
    // if (ReaPack_ProcessQueue == null) {
    //     last_error = "Failed to get ReaPack_ProcessQueue function";
    //     return error.InvalidFunction;
    // }
    //
    // ReaPack_FreeEntry = @ptrCast(plugin_getapi("ReaPack_FreeEntry"));
    // ReaPack_EnumPackages = @ptrCast(plugin_getapi("ReaPack_EnumPackages"));
}

// Error type for ReaPack-related errors
pub const ReaPackError = error{
    ReaPackNotInstalled,
    InvalidFunction,
};
