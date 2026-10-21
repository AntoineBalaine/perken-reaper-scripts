//! The test root: every file that carries tests.
comptime {
    _ = @import("roland.zig");
    _ = @import("dump.zig");
    _ = @import("engine.zig");
    _ = @import("audio.zig");
    _ = @import("spsc.zig");
    _ = @import("outbuf.zig");
    _ = @import("fileio.zig");
    _ = @import("state.zig");
    _ = @import("reaper_glue.zig");
    _ = @import("catalog.zig");
    _ = @import("host_test.zig");
}
