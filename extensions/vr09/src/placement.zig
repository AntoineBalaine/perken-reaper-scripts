//! Where the panel opens. A window that sticks out of the screen is moved by
//! the window manager, and ImGui is never told, so the mouse then lands a few
//! dozen pixels away from where ImGui believes the window to be. The panel
//! therefore opens at the wanted point only where it fits on the screen.
const std = @import("std");

/// The layout of SWELL's RECT, which REAPER fills in.
pub const Rect = extern struct {
    left: c_int,
    top: c_int,
    right: c_int,
    bottom: c_int,
};

pub const Point = struct { x: i32, y: i32 };

/// The position nearest to (x, y) at which a window of w by h lies inside the
/// area. A window larger than the area sticks to its top left corner.
pub fn fitInto(area: Rect, x: i32, y: i32, w: i32, h: i32) Point {
    return .{
        .x = std.math.clamp(x, area.left, @max(area.left, area.right - w)),
        .y = std.math.clamp(y, area.top, @max(area.top, area.bottom - h)),
    };
}

/// Whether REAPER filled the area in with something a screen can be.
pub fn isUsable(area: Rect) bool {
    return area.right > area.left and area.bottom > area.top;
}

test "a window near the right edge moves left to fit" {
    const screen = Rect{ .left = 0, .top = 0, .right = 1920, .bottom = 1200 };
    const at = fitInto(screen, 1364, 61, 640, 560);
    try std.testing.expectEqual(@as(i32, 1280), at.x);
    try std.testing.expectEqual(@as(i32, 61), at.y);
}

test "a window near the bottom edge moves up to fit" {
    const screen = Rect{ .left = 0, .top = 0, .right = 1920, .bottom = 1200 };
    const at = fitInto(screen, 100, 900, 640, 560);
    try std.testing.expectEqual(@as(i32, 100), at.x);
    try std.testing.expectEqual(@as(i32, 640), at.y);
}

test "a window that fits stays where it was asked" {
    const screen = Rect{ .left = 0, .top = 0, .right = 1920, .bottom = 1200 };
    const at = fitInto(screen, 862, 340, 640, 560);
    try std.testing.expectEqual(@as(i32, 862), at.x);
    try std.testing.expectEqual(@as(i32, 340), at.y);
}

test "a second screen has its own edges" {
    const second = Rect{ .left = 1920, .top = 0, .right = 3840, .bottom = 1080 };
    const at = fitInto(second, 3700, 10, 640, 560);
    try std.testing.expectEqual(@as(i32, 3200), at.x);
    const left_of = fitInto(second, 1000, 10, 640, 560);
    try std.testing.expectEqual(@as(i32, 1920), left_of.x);
}

test "a window larger than the area sticks to its top left" {
    const small = Rect{ .left = 0, .top = 0, .right = 500, .bottom = 400 };
    const at = fitInto(small, 300, 300, 640, 560);
    try std.testing.expectEqual(@as(i32, 0), at.x);
    try std.testing.expectEqual(@as(i32, 0), at.y);
}

test "an empty area is not a screen" {
    try std.testing.expect(!isUsable(.{ .left = 0, .top = 0, .right = 0, .bottom = 0 }));
    try std.testing.expect(isUsable(.{ .left = 0, .top = 0, .right = 1, .bottom = 1 }));
}
