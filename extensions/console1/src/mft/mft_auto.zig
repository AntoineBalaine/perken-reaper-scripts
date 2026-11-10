//! The AUTO page. Because the page is meant to be filled by the user, none of its knobs has a function yet, and only the pushes of the
//! first five encoders have the automation modes as a suggestion.
const std = @import("std");
const reaper = @import("reaper").reaper;

/// REAPER's numbers for the automation modes of a track.
pub const Mode = enum(c_int) {
    trim_read = 0,
    read = 1,
    touch = 2,
    write = 3,
    latch = 4,
    latch_preview = 5,
};

/// What the push of an encoder of the AUTO page does, or null for a push that is free.
pub fn pushMode(push: usize) ?Mode {
    return switch (push) {
        0 => .trim_read,
        1 => .read,
        2 => .latch,
        3 => .latch_preview,
        4 => .write,
        else => null,
    };
}

/// The word under a push of the AUTO page, which is a dash for a push that is free.
pub fn pushLabel(push: usize) [:0]const u8 {
    return switch (push) {
        0 => "Auto: Trim",
        1 => "Auto: Read",
        2 => "Auto: Latch",
        3 => "Auto: Preview",
        4 => "Auto: Write",
        else => "-",
    };
}

/// Puts the track in the automation mode that the push stands for.
pub fn onPress(track: reaper.MediaTrack, push: usize) void {
    const mode = pushMode(push) orelse return;
    reaper.SetTrackAutomationMode(track, @backingInt(mode));
}

test "the first five pushes have an automation mode and a word, and the others are free with a dash" {
    const t = std.testing;
    try t.expectEqual(@as(?Mode, .trim_read), pushMode(0));
    try t.expectEqual(@as(?Mode, .write), pushMode(4));
    try t.expectEqual(@as(?Mode, null), pushMode(5));
    try t.expectEqualStrings("Auto: Latch", pushLabel(2));
    try t.expectEqualStrings("-", pushLabel(7));
    try t.expectEqual(@as(c_int, 4), @backingInt(Mode.latch));
}
