//! The panel's fonts, which travel inside the plugin.
//!
//! Because the plugin is a single file that users install, the fonts are embedded in it and loaded
//! from memory, so that nothing has to be installed beside it. Saira Condensed draws the text, the
//! labels and the card titles, and Librestile Extended Bold draws the tab names. Both are under the
//! SIL Open Font License, whose texts are in the `fonts` folder and in the release.
const imgui = @import("reaper_imgui");

const saira_regular: [:0]const u8 = @embedFile("font_saira_regular");
const saira_bold: [:0]const u8 = @embedFile("font_saira_bold");
const librestile: [:0]const u8 = @embedFile("font_librestile");

/// The generic family that ReaImGui resolves to a font of the system.
const system_family = "sans-serif";

pub const text_size: c_int = 15;
pub const label_size: c_int = 14;
pub const title_size: c_int = 18;
pub const tab_size: c_int = 13;

/// The fonts of a window. A font is null until `create` makes it.
pub const Fonts = struct {
    /// The text that no other font claims: the notes, the buttons and the tables.
    text: imgui.FontPtr = null,
    /// The labels, and the numbers of the controls.
    label: imgui.FontPtr = null,
    /// The titles of the cards.
    title: imgui.FontPtr = null,
    /// The names of the tabs.
    tab: imgui.FontPtr = null,
};

/// Makes one font from the bytes of a font file. Because loading from memory can fail, the system's
/// sans-serif is made instead, so that the panel always has a font.
pub fn load(data: [:0]const u8, size: c_int) imgui.FontPtr {
    const font = imgui.api.CreateFontFromMem(data.ptr, @intCast(data.len), size, null);
    if (font != null) return font;
    return imgui.api.CreateFont(system_family, size, null);
}

/// Attaches a font to a context, when the font exists. ReaImGui needs every font attached before the
/// context's first frame.
pub fn attach(ctx: imgui.ContextPtr, font: imgui.FontPtr) void {
    if (font != null) imgui.api.Attach(ctx, @ptrCast(font));
}

/// Makes the four fonts of a window and attaches them to its context.
pub fn create(ctx: imgui.ContextPtr) Fonts {
    const fonts = Fonts{
        .text = load(saira_regular, text_size),
        .label = load(saira_bold, label_size),
        .title = load(saira_bold, title_size),
        .tab = load(librestile, tab_size),
    };
    attach(ctx, fonts.text);
    attach(ctx, fonts.label);
    attach(ctx, fonts.title);
    attach(ctx, fonts.tab);
    return fonts;
}

test "every declaration compiles" {
    @import("std").testing.refAllDecls(@This());
}
