//! Exact rational arithmetic in units of whole notes, so that musical
//! positions and durations are never approximate: a quarter note is exactly
//! 1/4, a triplet eighth exactly 1/12, and positions add and compare without
//! the drift f64 would introduce over a long selection. This is the time
//! representation shared by the meter map and the notation simplifier.

const std = @import("std");

pub const Rational = struct {
    num: i64,
    den: i64, // always > 0; fraction kept in lowest terms.

    pub fn of(num: i64, den: i64) Rational {
        std.debug.assert(den != 0);
        var n = num;
        var d = den;
        if (d < 0) {
            n = -n;
            d = -d;
        }
        const g = gcd(if (n < 0) -n else n, d);
        if (g != 0) {
            n = @divExact(n, g);
            d = @divExact(d, g);
        }
        return .{ .num = n, .den = d };
    }

    fn gcd(a: i64, b: i64) i64 {
        var x = a;
        var y = b;
        while (y != 0) {
            const t = y;
            y = @mod(x, y);
            x = t;
        }
        return x;
    }

    pub fn add(a: Rational, b: Rational) Rational {
        return of(a.num * b.den + b.num * a.den, a.den * b.den);
    }

    pub fn sub(a: Rational, b: Rational) Rational {
        return a.add(.{ .num = -b.num, .den = b.den });
    }

    pub fn divInt(a: Rational, n: i64) Rational {
        return of(a.num, a.den * n);
    }

    pub fn mulInt(a: Rational, n: i64) Rational {
        return of(a.num * n, a.den);
    }

    pub fn eq(a: Rational, b: Rational) bool {
        return a.num == b.num and a.den == b.den;
    }

    pub fn lt(a: Rational, b: Rational) bool {
        return a.num * b.den < b.num * a.den;
    }

    pub fn lte(a: Rational, b: Rational) bool {
        return a.lt(b) or a.eq(b);
    }

    pub fn min(a: Rational, b: Rational) Rational {
        return if (a.lt(b)) a else b;
    }

    pub fn max(a: Rational, b: Rational) Rational {
        return if (a.lt(b)) b else a;
    }

    pub fn zero() Rational {
        return .{ .num = 0, .den = 1 };
    }

    /// True if `a` is an exact whole multiple of `unit` — the alignment
    /// test for whether a dotted value may sit at a given onset.
    pub fn isMultipleOf(a: Rational, unit: Rational) bool {
        // a / unit = (a.num * unit.den) / (a.den * unit.num)
        const n = a.num * unit.den;
        const d = a.den * unit.num;
        return @rem(n, d) == 0;
    }
};
