//! The state that the whole extension shares.
const std = @import("std");

/// The std.Io that this extension does its file and process work with. Because REAPER loads the extension
/// as a library, there is no main() to receive one from, so the extension owns it here. ReaperPluginEntry
/// replaces this single-threaded default with host_io.create(), which adds the allocator and the
/// environment that spawning a process needs; tests keep the default.
pub var io_threaded: std.Io.Threaded = .init_single_threaded;

pub fn io() std.Io {
    return io_threaded.io();
}
