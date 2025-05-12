//! Main entry point for the models library
//! This file exports all models and testing utilities

const std = @import("std");

// Core models
pub const track_model = @import("track_model.zig");
pub const fx_model = @import("fx_model.zig");

// Testing utilities
pub const mock = struct {
    pub usingnamespace @import("midi_wrapper_mock.zig");
    pub usingnamespace @import("reaper_mock.zig");
};

// Commonly used types
pub const Track = track_model.Track;
pub const Session = @import("session.zig");
pub const FX = fx_model.FX;
pub const Param = fx_model.Param;
pub const Globals = @import("globals_model.zig");
pub const C1Model = @import("c1_model.zig");

// Initialization helpers
pub const initMinimalGlobals = Globals.initMinimalGlobals;

test {
    // Run all tests in the models
    std.testing.refAllDecls(@This());
}
