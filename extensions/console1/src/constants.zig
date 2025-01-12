const std = @import("std");
const imgui = @import("../reaper_imgui.zig");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("../theme/Theme.zig");
const fxParser = @import("../lib/fxparser.zig");
const styles = @import("../lib/styles.zig");

pub const window_height: c_int = 240;
pub const window_width: c_int = 280;
pub const title_Clr: c_int = 0x000000FF;
pub const title_Width: c_int = 220 - 80;
pub const button_size: c_int = 20;
pub const custom_Title: ?[:0]const u8 = null;
pub const minval: f64 = 0.0;
pub const maxval: f64 = 1.0;

pub const param_text_color: c_int = 0xFFFFFFFF;
