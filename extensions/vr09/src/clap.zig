//! The CLAP headers, included as C, and the few helpers the plugin needs to
//! fill their fixed-size string fields.
const std = @import("std");

pub const c = @import("clap_c");

/// Copies `text` into a fixed-size C character array, cut to fit and always
/// ending in a zero.
pub fn copyInto(dest: anytype, text: []const u8) void {
    const bytes: [*]u8 = @ptrCast(dest);
    const capacity = @sizeOf(@TypeOf(dest.*));
    const n = @min(text.len, capacity - 1);
    @memcpy(bytes[0..n], text[0..n]);
    @memset(bytes[n..capacity], 0);
}

pub fn version() c.clap_version_t {
    return .{
        .major = c.CLAP_VERSION_MAJOR,
        .minor = c.CLAP_VERSION_MINOR,
        .revision = c.CLAP_VERSION_REVISION,
    };
}

/// True when the host's CLAP is new enough for this plugin to load.
pub fn isCompatible(v: c.clap_version_t) bool {
    return v.major >= 1;
}

/// A C string constant declared as a character array, as a Zig slice without
/// its terminator.
pub fn s(comptime constant: anytype) []const u8 {
    return constant[0..constant.len];
}
