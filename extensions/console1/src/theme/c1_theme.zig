const std = @import("std");
const ini = @import("ini");
const imgui = @import("reaper_imgui");
const fontello = @embedFile("../assets/fontello1.ttf");
const systemfont = "sans-serif";

pub const FONT_SMALL_SIZE: c_int = 14;
pub const ICON_FONT_SMALL_SIZE: c_int = 13;

const Fonts = struct {
    MAIN: imgui.FontPtr = undefined,
    ICON_FONT_SMALL: imgui.FontPtr = undefined,
};

pub var fonts = Fonts{};

pub fn initFonts(ctx: imgui.ContextPtr) !void {
    fonts.MAIN = try imgui.CreateFont(.{ systemfont, FONT_SMALL_SIZE, null });
    fonts.ICON_FONT_SMALL = try imgui.CreateFontFromMem(.{ fontello, fontello.len, ICON_FONT_SMALL_SIZE, null });
    if (ctx) |context| {
        const mainFontResource: imgui.ResourcePtr = @ptrCast(fonts.MAIN);
        try imgui.Attach(.{ context, mainFontResource });
        const fontelloResource: imgui.ResourcePtr = @ptrCast(fonts.ICON_FONT_SMALL);
        try imgui.Attach(.{ context, fontelloResource });
    }
}

const IconsList = enum {
    arrow_down,
    arrow_right,
    close,
    kebab,
    plus,
    save,
    wrench,
    pin,
};

pub const Icons = std.EnumArray(IconsList, [:0]const u8).init(.{
    .arrow_down = "~",
    .arrow_right = "_",
    .close = "?",
    .kebab = "ß",
    .plus = "B",
    .save = "Ä",
    .wrench = "k",
    .pin = "R",
});

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
    KnobBg: c_int = 0,
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
    TabSelected: c_int = 0,
    TabSelectedOverline: c_int = 0,
    Text: c_int = 0,
    TextSelectedBg: c_int = 0,
    TitleBg: c_int = 0,
    TitleBgActive: c_int = 0,
    WindowBg: c_int = 0,
};

pub const C1Theme = struct {
    config: WindowColors = .{},
    main: WindowColors = .{},
};

pub var theme: C1Theme = .{};

const embedded_ini = @embedFile("../resources/default_reaper_theme.ini");

pub fn init() void {
    var fbs: std.Io.Reader = .fixed(embedded_ini);
    var parser = ini.parse(std.heap.page_allocator, &fbs, ";#");
    defer parser.deinit();
    theme = parseTheme(&parser);
}

pub fn parseHexColor(hex: [:0]const u8) ?c_int {
    if (hex.len != 8) return null;
    const val = std.fmt.parseInt(u32, hex, 16) catch return null;
    return @bitCast(val);
}

const Section = enum { none, config, main };

pub fn parseTheme(parser: anytype) C1Theme {
    var result: C1Theme = .{};
    var current_section: Section = .none;

    while (parser.next() catch null) |record| {
        switch (record) {
            .section => |heading| {
                if (std.meta.stringToEnum(Section, heading)) |section| {
                    current_section = section;
                } else {
                    current_section = .none;
                }
            },
            .property => |kv| {
                const color = parseHexColor(kv.value) orelse continue;
                switch (current_section) {
                    .config => setField(WindowColors, &result.config, kv.key, color),
                    .main => setField(WindowColors, &result.main, kv.key, color),
                    .none => {},
                }
            },
            .enumeration => {},
        }
    }

    return result;
}

fn setField(comptime T: type, target: *T, key: [:0]const u8, color: c_int) void {
    inline for (@typeInfo(T).@"struct".field_names) |field_name| {
        if (std.mem.eql(u8, key, field_name)) {
            @field(target, field_name) = color;
            return;
        }
    }
}

test "parseHexColor parses valid 8-digit hex" {
    const color = parseHexColor("FF00A5FF").?;
    const as_u32: u32 = @bitCast(color);
    try std.testing.expectEqual(@as(u32, 0xFF00A5FF), as_u32);
}

test "parseHexColor rejects invalid input" {
    try std.testing.expect(parseHexColor("FF00A5") == null);
    try std.testing.expect(parseHexColor("ZZZZZZZZ") == null);
    try std.testing.expect(parseHexColor("") == null);
}

test "parseTheme loads a complete INI" {
    const ini_content =
        \\[config]
        \\Text = 2B2B24FF
        \\WindowBg = B1B1ABFF
        \\
        \\[main]
        \\Border = 4F4F4FFF
        \\Text = 898981FF
        \\ActiveToggle = FF00A5FF
    ;

    var fbs: std.Io.Reader = .fixed(ini_content);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();
    const result = parseTheme(&parser);

    const u = struct {
        fn f(c: c_int) u32 {
            return @bitCast(c);
        }
    }.f;

    try std.testing.expectEqual(@as(u32, 0x2B2B24FF), u(result.config.Text));
    try std.testing.expectEqual(@as(u32, 0xB1B1ABFF), u(result.config.WindowBg));
    try std.testing.expectEqual(@as(u32, 0x4F4F4FFF), u(result.main.Border));
    try std.testing.expectEqual(@as(u32, 0x898981FF), u(result.main.Text));
    try std.testing.expectEqual(@as(u32, 0xFF00A5FF), u(result.main.ActiveToggle));
}

test "parseTheme ignores unknown sections and keys" {
    const ini_content =
        \\[unknown_section]
        \\Foo = AABBCCDD
        \\
        \\[main]
        \\UnknownKey = 11223344
        \\Text = 898981FF
    ;

    var fbs: std.Io.Reader = .fixed(ini_content);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();
    const result = parseTheme(&parser);

    const u = struct {
        fn f(c: c_int) u32 {
            return @bitCast(c);
        }
    }.f;

    try std.testing.expectEqual(@as(u32, 0x898981FF), u(result.main.Text));
    try std.testing.expectEqual(@as(u32, 0), u(result.main.Button));
}

test "init loads embedded INI" {
    init();
    const u = struct {
        fn f(c: c_int) u32 {
            return @bitCast(c);
        }
    }.f;
    try std.testing.expect(u(theme.main.Text) != 0);
    try std.testing.expect(u(theme.config.Text) != 0);
    try std.testing.expect(u(theme.main.ActiveToggle) != 0);
}
