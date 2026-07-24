const std = @import("std");
const reaper = @import("reaper").reaper;

// Transport control for TRANSPORT mode. First pass: the first three encoder
// presses drive play, stop, and record. The remaining presses and the encoder
// rotations (jog, scrub, zoom, ...) are left for a layout Antoine confirms.

// Label shown in the panel for each top-row encoder in transport mode.
pub fn label(idx: usize) [:0]const u8 {
    return switch (idx) {
        0 => "Play",
        1 => "Stop",
        2 => "Rec",
        else => "-",
    };
}

pub fn onPress(idx: u3) void {
    switch (idx) {
        0 => reaper.CSurf_OnPlay(),
        1 => reaper.CSurf_OnStop(),
        2 => reaper.CSurf_OnRecord(),
        else => {},
    }
}

test "transport labels" {
    try std.testing.expectEqualStrings("Play", label(0));
    try std.testing.expectEqualStrings("Rec", label(2));
    try std.testing.expectEqualStrings("-", label(7));
}
