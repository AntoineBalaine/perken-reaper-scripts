//! Main entry point for the models library
//! This file exports all models and testing utilities

const std = @import("std");

// Core models
pub const track_model = @import("track_model.zig");
pub const fx_model = @import("fx_model.zig");

// Commonly used types
pub const Track = track_model.Track;
pub const Session = @import("session.zig");
pub const FX = fx_model.FX;
pub const Param = fx_model.Param;
pub const C1Model = @import("c1_model.zig");

pub const midi = @import("midi_wrapper_mock.zig");
pub const reaper = @import("reaper_mock.zig");

test {
    // Run all tests in the models
    std.testing.refAllDecls(@This());
}
