// Test aggregator for the MFT extension's pure-logic modules. The csurf and
// MIDI-out modules are excluded because their @cImport needs libc and the C++
// headers, which the plain test exe does not link; their logic paths depend on
// the REAPER runtime and are exercised in the app rather than in unit tests.
test {
    _ = @import("mft.zig");
    _ = @import("mft_state.zig");
    _ = @import("mft_mappings.zig");
    _ = @import("mft_map_store.zig");
    _ = @import("mft_fx.zig");
    _ = @import("mft_wizard.zig");
}
