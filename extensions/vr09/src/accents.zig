//! The accents of the VR-09 panel: the color of each part of the instrument and of each effect's card. They
//! tint the cards and the lit parts of the controls inside them. The rest of the look is in reaziglib's
//! `panel_theme`.
const palette = @import("ui_palette");

const rgba = palette.rgba;

/// The accent of each effect's card. It takes the place of the amber on the lit parts of the controls
/// inside the card.
pub const fx = struct {
    pub const reverb = rgba(0x4FB0E8FF);
    pub const chorus = rgba(0x4FD6A8FF);
    pub const mfx = rgba(0xB67CF0FF);
    pub const delay = rgba(0xF07A5AFF);
    pub const compressor = rgba(0xE86AA8FF);
};

/// The accent of each part of the instrument, in the cards of the Synth, Mixer and Controllers tabs.
pub const part = struct {
    pub const upper = rgba(0x5AC8F0FF);
    pub const lower = rgba(0xF08C5AFF);
    pub const backing = rgba(0xF0B840FF);
    pub const master = rgba(0xC8C4B8FF);
    /// The organ keeps the amber that the lit parts of the controls have by default.
    pub const organ = rgba(0xF0B840FF);
    /// The ivory of a piano's keys.
    pub const piano = rgba(0xF2EBD3FF);
};
