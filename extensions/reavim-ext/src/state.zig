//! Engine state shared between the key handler (vim.zig), the runner
//! (composition side effects change modes), and the UI.
const grammar = @import("grammar.zig");

pub const VimMode = enum { off, insert, normal, visual_track, visual_timeline };
pub const Side = enum { left, right };

pub var mode: VimMode = .off;
pub var visual_track_pivot: c_int = 0;
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
