//! The `std.Io` implementation that an extension uses.
//!
//! Since Zig 0.16, every file, clock, sleep and entropy operation goes through a `std.Io`. A program receives
//! one in `main`, but REAPER loads the extensions as libraries, so there is no `main` to receive it from.
//! Because of that, each extension owns one `std.Io.Threaded` in its globals, built by `create`, and passes
//! its `io()` to the functions that do I/O; the library functions of reaziglib take an `io: std.Io` parameter,
//! as the standard library does.
const std = @import("std");
const builtin = @import("builtin");

/// Returns the `std.Io.Threaded` that an extension keeps in its globals.
///
/// It starts from `init_single_threaded`, and not from `init`, because `init` installs handlers for SIGIO
/// and SIGPIPE, which would change the behavior of REAPER's own process. Because `init_single_threaded`
/// allocates with a failing allocator and sees an empty environment on POSIX systems, two things are added:
/// - the C allocator, which spawning a process needs for its argument and environment copies;
/// - the process environment, so that spawned processes inherit PATH, HOME and the rest, as they did when
///   std.process.Child read the environment itself.
pub fn create() std.Io.Threaded {
    var threaded: std.Io.Threaded = .init_single_threaded;
    threaded.allocator = std.heap.c_allocator;
    if (comptime builtin.link_libc and std.process.Environ.Block == std.process.Environ.PosixBlock) {
        threaded.environ = .{ .process_environ = .{ .block = .{ .slice = std.mem.span(std.c.environ) } } };
        threaded.environ_initialized = false;
    }
    return threaded;
}

test create {
    var threaded = create();
    const io = threaded.io();
    // Because the instance must serve the clock and the entropy, both are exercised here.
    _ = std.Io.Timestamp.now(io, .real);
    var bytes: [4]u8 = undefined;
    io.random(&bytes);
}
