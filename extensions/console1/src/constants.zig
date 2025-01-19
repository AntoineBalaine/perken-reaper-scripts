const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const reaper = @import("reaper.zig").reaper;
const Theme = @import("theme/Theme.zig");
const fxParser = @import("fx_parser.zig");
const styles = @import("styles.zig");

pub const window_height: c_int = 240;
pub const window_width: c_int = 280;
pub const title_Clr: c_int = 0x000000FF;
pub const title_Width: c_int = 220 - 80;
pub const button_size: c_int = 20;
pub const custom_Title: ?[:0]const u8 = null;
pub const minval: f64 = 0.0;
pub const maxval: f64 = 1.0;

pub const param_text_color: c_int = 0xFFFFFFFF;

pub const g_csurf_mcpmode = false;
