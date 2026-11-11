//! The text of a parameter value as the user reads it ("-12.0 dB", "1.5:1", "2.3 kHz"), turned into the normalized value
//! that REAPER takes. REAPER can write the text of a normalized value but cannot read one, so the normalized value of a
//! typed text is the one whose own text has the number that was typed.
const std = @import("std");

/// How the text of a normalized value is asked for. The host answers with the formatted value of the parameter, and the
/// tests with a function of their own. It returns false when there is no text.
pub const Formatter = struct {
    context: ?*anyopaque,
    format: *const fn (context: ?*anyopaque, normalized: f64, buf: *[64:0]u8) bool,
};

/// The factor that the unit of a number gives it: "kHz" and "k" are thousands, and "ms" are thousandths of a second.
fn unitFactor(unit: []const u8) f64 {
    if (std.ascii.eqlIgnoreCase(unit, "ms")) return 0.001;
    if (unit.len > 0 and (unit[0] == 'k' or unit[0] == 'K')) return 1000.0;
    return 1.0;
}

/// The number at the start of a text, with its unit applied, or null when the text does not start with one.
pub fn scaledNumber(text: []const u8) ?f64 {
    const trimmed = std.mem.trim(u8, text, " \t");
    var end: usize = 0;
    if (end < trimmed.len and (trimmed[end] == '-' or trimmed[end] == '+')) end += 1;
    const sign_end = end;
    const rest = trimmed[sign_end..];
    // Because a parameter at its lowest can read "-inf dB", the infinity is a number here.
    if (rest.len >= 3 and std.ascii.eqlIgnoreCase(rest[0..3], "inf")) {
        const negative = sign_end > 0 and trimmed[0] == '-';
        return if (negative) -std.math.inf(f64) else std.math.inf(f64);
    }
    var digits: usize = 0;
    while (end < trimmed.len and std.ascii.isDigit(trimmed[end])) : (end += 1) digits += 1;
    if (end < trimmed.len and trimmed[end] == '.') {
        end += 1;
        while (end < trimmed.len and std.ascii.isDigit(trimmed[end])) : (end += 1) digits += 1;
    }
    if (digits == 0) return null;
    const number = std.fmt.parseFloat(f64, trimmed[0..end]) catch return null;
    const unit = std.mem.trim(u8, trimmed[end..], " \t");
    return number * unitFactor(unit);
}

/// The number of the text that the formatter gives for a normalized value, or null when it gives none or no number.
fn numberAt(formatter: Formatter, normalized: f64) ?f64 {
    var buf: [64:0]u8 = undefined;
    buf[0] = 0;
    if (!formatter.format(formatter.context, normalized, &buf)) return null;
    return scaledNumber(std.mem.sliceTo(&buf, 0));
}

/// The normalized value whose text has the number that `text` has, found by halving the range, which needs the numbers to
/// go one way from the lowest value to the highest. A number outside of what the parameter reads gives its nearest end.
/// It is null when the text has no number, or when the parameter has no numbers.
pub fn solve(text: []const u8, formatter: Formatter) ?f64 {
    const target = scaledNumber(text) orelse return null;
    if (std.math.isNan(target)) return null;
    const low_number = numberAt(formatter, 0.0) orelse return null;
    const high_number = numberAt(formatter, 1.0) orelse return null;
    if (low_number == high_number) return null;
    const ascending = high_number > low_number;
    if (ascending) {
        if (target <= low_number) return 0.0;
        if (target >= high_number) return 1.0;
    } else {
        if (target >= low_number) return 0.0;
        if (target <= high_number) return 1.0;
    }
    var low: f64 = 0.0;
    var high: f64 = 1.0;
    for (0..40) |_| {
        const middle = (low + high) / 2.0;
        const number = numberAt(formatter, middle) orelse return null;
        if ((number < target) == ascending) low = middle else high = middle;
    }
    return (low + high) / 2.0;
}

const TestCurve = struct {
    /// What the formatted text of the normalized value is, for the tests: a gain from -24 to 12 dB, and a frequency.
    kind: enum { gain, frequency, descending },

    fn format(context: ?*anyopaque, normalized: f64, buf: *[64:0]u8) bool {
        const curve: *const TestCurve = @ptrCast(@alignCast(context.?));
        const text = switch (curve.kind) {
            .gain => std.fmt.bufPrintSentinel(buf, "{d:.1} dB", .{-24.0 + 36.0 * normalized}, 0),
            .descending => std.fmt.bufPrintSentinel(buf, "{d:.1}", .{100.0 - 80.0 * normalized}, 0),
            .frequency => blk: {
                const hertz = 20.0 * std.math.pow(f64, 1000.0, normalized);
                break :blk if (hertz >= 1000.0)
                    std.fmt.bufPrintSentinel(buf, "{d:.2} kHz", .{hertz / 1000.0}, 0)
                else
                    std.fmt.bufPrintSentinel(buf, "{d:.1} Hz", .{hertz}, 0);
            },
        };
        _ = text catch return false;
        return true;
    }

    fn formatter(self: *const TestCurve) Formatter {
        return .{ .context = @constCast(self), .format = format };
    }
};

test "a number is read with its unit" {
    try std.testing.expectEqual(@as(?f64, -12.0), scaledNumber("-12.0 dB"));
    try std.testing.expectEqual(@as(?f64, 2300.0), scaledNumber("2.3 kHz"));
    try std.testing.expectEqual(@as(?f64, 2500.0), scaledNumber("2.5k"));
    try std.testing.expectEqual(@as(?f64, 0.5), scaledNumber("500 ms"));
    try std.testing.expectEqual(@as(?f64, 4.0), scaledNumber("4:1"));
    try std.testing.expectEqual(@as(?f64, null), scaledNumber("Off"));
    try std.testing.expect(std.math.isNegativeInf(scaledNumber("-inf dB").?));
}

test "the normalized value of a typed gain is the one that reads that gain" {
    const curve: TestCurve = .{ .kind = .gain };
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), solve("-6 dB", curve.formatter()).?, 5e-3);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), solve("-6", curve.formatter()).?, 5e-3);
    try std.testing.expectEqual(@as(?f64, 1.0), solve("40 dB", curve.formatter()));
    try std.testing.expectEqual(@as(?f64, 0.0), solve("-60", curve.formatter()));
}

test "a frequency typed in kilohertz or in hertz finds the same place on the knob" {
    const curve: TestCurve = .{ .kind = .frequency };
    const from_hertz = solve("2000", curve.formatter()).?;
    const from_kilohertz = solve("2 kHz", curve.formatter()).?;
    try std.testing.expectApproxEqAbs(from_hertz, from_kilohertz, 5e-3);
    try std.testing.expectApproxEqAbs(@as(f64, std.math.log(f64, 1000.0, 100.0)), from_hertz, 5e-3);
}

test "a parameter whose numbers go down is found as well, and text that is not a number finds nothing" {
    const curve: TestCurve = .{ .kind = .descending };
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), solve("60", curve.formatter()).?, 5e-3);
    try std.testing.expectEqual(@as(?f64, null), solve("loud", curve.formatter()));
}
