//! The components of the windows of the Console 1 that other extensions of this package use: the cards, the rows and the headings of a window that
//! has the look of the panel, and the fonts that they are drawn in.
//!
//! Because a module can only import files inside its own folder, and these files import each other and the theme, the module is rooted here, in the
//! folder of the Console 1, and the extensions import it by name (`c1_components`). The Console 1 itself imports the files directly and is not
//! changed by it.
pub const panel_card = @import("components/panel_card.zig");
pub const module_plate = @import("components/module_plate.zig");
pub const c1_theme = @import("theme/c1_theme.zig");
