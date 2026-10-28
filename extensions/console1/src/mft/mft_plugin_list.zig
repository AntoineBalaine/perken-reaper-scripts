//! The plugins that are installed in REAPER, for the drop-down of the settings form. The list is read from REAPER the
//! first time it is asked for, sorted by name, and read again after `invalidate`: the settings form invalidates it each
//! time it is left, so that opening the form again sees the plugins that were added meanwhile.
const std = @import("std");
const reaper = @import("reaper").reaper;

const allocator = std.heap.c_allocator;

/// Gives the name of the installed plugin at an index, or null past the last one. The tests replace it, because the
/// functions of REAPER are not there.
pub var source: *const fn (index: usize) ?[:0]const u8 = reaperSource;

pub fn reaperSource(index: usize) ?[:0]const u8 {
    var name: [*:0]u8 = undefined;
    var ident: [*:0]u8 = undefined;
    if (!reaper.EnumInstalledFX(@intCast(index), &name, &ident)) return null;
    return std.mem.span(name);
}

var names: std.ArrayListUnmanaged([:0]u8) = .empty;
var loaded = false;

fn lessName(_: void, a: [:0]u8, b: [:0]u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}

fn clear() void {
    for (names.items) |name| allocator.free(name);
    names.clearRetainingCapacity();
}

/// Reads the names again, replacing the ones read before. Each name is copied, because REAPER owns the text it gives.
pub fn refresh() void {
    clear();
    var index: usize = 0;
    while (source(index)) |name| : (index += 1) {
        const copy = allocator.dupeSentinel(u8, name, 0) catch break;
        names.append(allocator, copy) catch {
            allocator.free(copy);
            break;
        };
    }
    std.mem.sort([:0]u8, names.items, {}, lessName);
    loaded = true;
}

/// Says that the list has to be read again the next time it is asked for.
pub fn invalidate() void {
    loaded = false;
}

/// The names of the installed plugins, sorted. They are valid until the next `refresh`.
pub fn all() []const [:0]u8 {
    if (!loaded) refresh();
    return names.items;
}

var fake_names: []const [:0]const u8 = &.{};

fn fakeSource(index: usize) ?[:0]const u8 {
    if (index >= fake_names.len) return null;
    return fake_names[index];
}

test "the names are read, copied and sorted without regard to the case" {
    source = fakeSource;
    defer {
        source = reaperSource;
        clear();
        loaded = false;
    }
    fake_names = &.{ "VST: ReaEQ (Cockos)", "JS: Saturation", "vst3: Zed", "CLAP: Alpha" };
    const list = all();
    try std.testing.expectEqual(@as(usize, 4), list.len);
    try std.testing.expectEqualStrings("CLAP: Alpha", list[0]);
    try std.testing.expectEqualStrings("JS: Saturation", list[1]);
    // "vst3" sorts before "vst:" because the digit comes before the colon.
    try std.testing.expectEqualStrings("vst3: Zed", list[2]);
    try std.testing.expectEqualStrings("VST: ReaEQ (Cockos)", list[3]);
    // The names are the list's own copies.
    try std.testing.expect(list[0].ptr != fake_names[3].ptr);
}

test "the list is read again after it is invalidated, and not before" {
    source = fakeSource;
    defer {
        source = reaperSource;
        clear();
        loaded = false;
    }
    fake_names = &.{"JS: One"};
    try std.testing.expectEqual(@as(usize, 1), all().len);
    fake_names = &.{ "JS: One", "JS: Two" };
    try std.testing.expectEqual(@as(usize, 1), all().len);
    invalidate();
    try std.testing.expectEqual(@as(usize, 2), all().len);
}
