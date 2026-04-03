/// Generic REAPER API mock infrastructure.
///
/// Because the `reaper` API struct exposes function pointers as mutable globals,
/// tests can swap individual pointers with mock implementations and restore
/// them afterwards. This module provides helpers that automate the
/// save-swap-restore cycle so that each consumer only needs to define a
/// "MockSet" struct whose field names match the `reaper` API names, together
/// with the corresponding mock function implementations.
const std = @import("std");
const reaper = @import("reaper").reaper;

/// Given a struct type `MockSet` whose fields mirror a subset of the `reaper`
/// API (same field names, same function-pointer types), this function:
///   1. Saves the current value of each `reaper.<name>` into a returned
///      `MockSet` instance (the "originals").
///   2. Replaces each `reaper.<name>` with the declaration of the same name
///      found in `mock_source` (a type that `@hasDecl` the mock functions).
///
/// The caller is responsible for passing the returned struct to
/// `restoreMockReaperAPI` when the test is done.
pub fn setupMockReaperAPI(comptime MockSet: type, comptime mock_source: type) MockSet {
    var originals: MockSet = undefined;

    inline for (std.meta.fields(MockSet)) |field| {
        const name = field.name;
        @field(originals, name) = @field(reaper, name);

        if (@hasDecl(mock_source, name)) {
            @constCast(&@field(reaper, name)).* = @constCast(&@field(mock_source, name));
        } else {
            @compileError("No mock implementation found for " ++ name);
        }
    }

    return originals;
}

/// Restores the original function pointers that were saved by a previous call
/// to `setupMockReaperAPI`.
pub fn restoreMockReaperAPI(comptime MockSet: type, originals: MockSet) void {
    inline for (std.meta.fields(MockSet)) |field| {
        const name = field.name;
        @constCast(&@field(reaper, name)).* = @field(originals, name);
    }
}
