//! What stands in for `debug_api.zig` when the plugin is built without it (`-Ddebug_api=false`, the default, which
//! is how the releases are built): the plugin registers nothing in REAPER's API and keeps no log ring.
const std = @import("std");

pub fn register() void {}

pub fn unregister() void {}

pub const logFn = std.log.defaultLog;
