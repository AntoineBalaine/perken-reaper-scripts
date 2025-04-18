const std = @import("std");
const rapidcheck = @cImport({
    @cInclude("tests/rapidcheck/rapidcheck_wrapper.h");
});

// Example Zig function
fn testProperty() callconv(.C) c_int {
    // Your property test
    return 1; // 1 for success, 0 for failure
}

pub fn main() void {
    const ctx = rapidcheck.rc_create_context();
    defer rapidcheck.rc_destroy_context(ctx);

    const result = rapidcheck.rc_check_prop(ctx, testProperty);
    if (!result) {
        const reason = rapidcheck.rc_get_failure_reason(ctx);
        std.debug.print("Test failed: {s}\n", .{reason});
    }
}

test "basic rapidcheck property" {
    const ctx = rapidcheck.rc_create_context();
    defer rapidcheck.rc_destroy_context(ctx);

    const result = rapidcheck.rc_check_prop(ctx, testProperty);
    try std.testing.expect(result);
}
