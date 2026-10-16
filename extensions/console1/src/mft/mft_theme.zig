const std = @import("std");
const ini = @import("ini");
const imgui = @import("reaper_imgui");

// The MFT panel uses the same palette and style as the Console One UI. The theme
// INI is a copy of the Console One's. The parse helpers below mirror
// theme/c1_theme.zig; they are duplicated here because the MFT is a separate
// module and cannot import files outside its own directory.
const embedded = @embedFile("resources/default_reaper_theme.ini");

// The subset of ImGui colors the theme defines. Field names match the ImGui
// Col_ slots so they can be pushed by name.
pub const WindowColors = struct {
    ActiveToggle: c_int = 0,
    Border: c_int = 0,
    ErrorText: c_int = 0,
    Button: c_int = 0,
    ButtonActive: c_int = 0,
    ButtonHovered: c_int = 0,
    CheckMark: c_int = 0,
    ChildBg: c_int = 0,
    DragDropTarget: c_int = 0,
    FrameBg: c_int = 0,
    FrameBgActive: c_int = 0,
    FrameBgHovered: c_int = 0,
    Header: c_int = 0,
    HeaderActive: c_int = 0,
    HeaderHovered: c_int = 0,
    PopupBg: c_int = 0,
    SliderGrab: c_int = 0,
    SliderGrabActive: c_int = 0,
    Tab: c_int = 0,
    TabActive: c_int = 0,
    TabHovered: c_int = 0,
    Text: c_int = 0,
    TextSelectedBg: c_int = 0,
    TitleBg: c_int = 0,
    TitleBgActive: c_int = 0,
    WindowBg: c_int = 0,
};

var palette: WindowColors = .{};
var initialized = false;

fn parseHexColor(hex: [:0]const u8) ?c_int {
    if (hex.len != 8) return null;
    const val = std.fmt.parseInt(u32, hex, 16) catch return null;
    return @bitCast(val);
}

fn setField(target: *WindowColors, key: [:0]const u8, color: c_int) void {
    inline for (std.meta.fields(WindowColors)) |field| {
        if (std.mem.eql(u8, key, field.name)) {
            @field(target, field.name) = color;
            return;
        }
    }
}

pub fn init() void {
    if (initialized) return;
    var fbs = std.io.fixedBufferStream(embedded);
    var parser = ini.parse(std.heap.page_allocator, fbs.reader());
    defer parser.deinit();

    var in_main = false;
    while (parser.next() catch null) |record| {
        switch (record) {
            .section => |heading| in_main = std.mem.eql(u8, heading, "main"),
            .property => |kv| {
                if (in_main) {
                    if (parseHexColor(kv.value)) |color| setField(&palette, kv.key, color);
                }
            },
            .enumeration => {},
        }
    }
    initialized = true;
}

pub const PushCounts = struct { colors: u32 = 0, vars: u32 = 0 };

// Push the Console One palette and main style vars. Each WindowColors field is
// pushed to the matching ImGui color slot when one exists and the value is set.
pub fn pushStyle(ctx: imgui.ContextPtr) PushCounts {
    init();
    var counts = PushCounts{};

    inline for (std.meta.fields(WindowColors)) |field| {
        const col_name = "Col_" ++ field.name;
        if (@hasDecl(imgui, col_name)) {
            const val = @field(palette, field.name);
            if (val != 0) {
                if (imgui.PushStyleColor(.{ ctx, @field(imgui, col_name), val })) |_| {
                    counts.colors += 1;
                } else |_| {}
            }
        }
    }

    if (imgui.PushStyleVar(.{ ctx, imgui.StyleVar_FrameRounding, 4.0 })) |_| {
        counts.vars += 1;
    } else |_| {}
    if (imgui.PushStyleVar(.{ ctx, imgui.StyleVar_ChildRounding, 4.0 })) |_| {
        counts.vars += 1;
    } else |_| {}
    if (imgui.PushStyleVar(.{ ctx, imgui.StyleVar_FrameBorderSize, 1.0 })) |_| {
        counts.vars += 1;
    } else |_| {}

    return counts;
}

pub fn popStyle(ctx: imgui.ContextPtr, counts: PushCounts) void {
    if (counts.vars > 0) imgui.PopStyleVar(.{ ctx, @as(c_int, @intCast(counts.vars)) }) catch {};
    if (counts.colors > 0) imgui.PopStyleColor(.{ ctx, @as(c_int, @intCast(counts.colors)) }) catch {};
}

test "theme: init parses the main palette" {
    init();
    try std.testing.expect(palette.WindowBg != 0);
    try std.testing.expect(palette.Text != 0);
    try std.testing.expect(palette.Button != 0);
}
