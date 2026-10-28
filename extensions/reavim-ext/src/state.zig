//! Engine state shared between the key handler (vim.zig), the runner
//! (composition side effects change modes), and the UI.
const std = @import("std");
const grammar = @import("grammar.zig");

/// The std.Io that this extension does its file and process work with. Because REAPER loads the extension
/// as a library, there is no main() to receive one from, so the extension owns it here. ReaperPluginEntry
/// replaces this single-threaded default with host_io.create(), which adds the allocator and the
/// environment that spawning a process needs; tests keep the default.
pub var io_threaded: std.Io.Threaded = .init_single_threaded;

pub fn io() std.Io {
    return io_threaded.io();
}

pub const VimMode = enum { off, insert, normal, visual_track, visual_timeline };
pub const Side = enum { left, right };

pub var mode: VimMode = .off;
pub var visual_track_pivot: c_int = 0;
/// The track where a Shift+Up/Down track selection started, outside the
/// visual modes. Because other ways of selecting tracks leave it stale,
/// extendTrackSelection checks it against the actual selection before use.
pub var track_anchor: ?c_int = null;
pub var timeline_side: Side = .left;

pub fn grammarMode() grammar.Mode {
    return switch (mode) {
        .visual_track => .visual_track,
        .visual_timeline => .visual_timeline,
        else => .normal,
    };
}

/// setModeToNormal per reavim state_interface: mode normal, side left.
/// (reavim also forces context back to "main"; the context is per-keypress
/// in our engine, so only the buffer owner needs to care.)
pub fn setModeToNormal() void {
    if (mode != .off) mode = .normal;
    timeline_side = .left;
}
