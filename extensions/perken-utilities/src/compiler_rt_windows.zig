//! A helper of the compiler that the Windows tests provide themselves. Because libhegel, a Rust library, brings its own copy of the helpers of the
//! compiler, and COFF has no weak symbols to let two copies share a name, the Windows tests do not bundle Zig's compiler_rt (see build.zig). The copy of
//! Rust has every helper that the tests need but one: __extendxftf2, which turns an 80-bit float into a 128-bit one. It is exported here, on Windows only.
//!
//! The conversion is exact and needs no float arithmetic, which would call the helper itself: both formats have a sign, the same 15-bit exponent with the
//! same bias, and a fraction. The 80-bit format writes the integer bit of the significand and 63 bits of fraction, and the 128-bit format leaves the
//! integer bit out and has 112 bits of fraction, so the 63 bits move up by 49. The zeros, the subnormals, the infinities and the NaNs keep their meaning.
const std = @import("std");
const builtin = @import("builtin");

/// The bits of the 128-bit float that has the value of the 80-bit float with these bits.
pub fn extendBits(bits: u80) u128 {
    const sign_and_exponent: u128 = bits >> 64;
    const fraction: u128 = bits & ((@as(u80, 1) << 63) - 1);
    return (sign_and_exponent << 112) | (fraction << 49);
}

/// The helper as the compiler calls it. Because the C calling convention of some systems (aarch64) has no 80-bit float, it is only analyzed on Windows,
/// where it is exported.
fn extendxftf2(a: f80) callconv(.c) f128 {
    return @bitCast(extendBits(@bitCast(a)));
}

comptime {
    if (builtin.os.tag == .windows) @export(&extendxftf2, .{ .name = "__extendxftf2", .linkage = .strong });
}

test "extendBits gives the value that the conversion of Zig gives, for normal and subnormal numbers, the zeros and the infinities" {
    // On the other systems compiler_rt is bundled, so the conversion of Zig is the reference.
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const values = [_]f80{ 0.0, -0.0, 1.0, -2.5, 3.0e300, 1.0e-4930, std.math.floatMin(f80), std.math.floatTrueMin(f80), std.math.floatMax(f80), std.math.inf(f80), -std.math.inf(f80) };
    for (values) |value| {
        const expected: f128 = @floatCast(value);
        try std.testing.expectEqual(@as(u128, @bitCast(expected)), extendBits(@bitCast(value)));
    }
    const nan: f128 = @bitCast(extendBits(@bitCast(std.math.nan(f80))));
    try std.testing.expect(std.math.isNan(nan));
}
