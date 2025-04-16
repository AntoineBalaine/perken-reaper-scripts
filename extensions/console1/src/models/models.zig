//! Main entry point for the models library
//! This file exports all models and testing utilities

const std = @import("std");

// Core models
pub const track_model = @import("track_model.zig");
pub const fx_model = @import("fx_model.zig");
pub const globals_model = @import("globals_model.zig");

// Controller specific models
pub const c1_model = @import("c1_model.zig");

// Testing utilities
pub const mock = struct {
    pub const midi = @import("midi_wrapper_mock.zig");
    pub const reaper = @import("reaper_mock.zig");
};

// Commonly used types
pub const Track = track_model.Track;
pub const Session = track_model.Session;
pub const FX = fx_model.FX;
pub const Param = fx_model.Param;
pub const Globals = globals_model;
pub const C1Model = c1_model;

// Initialization helpers
pub const initializeTestState = track_model.initializeTestState;
pub const initMinimalGlobals = globals_model.initMinimalGlobals;

test {
    // Run all tests in the models
    std.testing.refAllDecls(@This());
}
