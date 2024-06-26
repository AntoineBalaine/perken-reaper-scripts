const std = @import("std");

pub fn containsSubstring(substring: []const u8, ref_str: []u8) bool {
    var i: usize = 0;
    const titleSize = ref_str.len;
    const findLen = substring.len;
    if (titleSize >= findLen) {
        while (i + findLen <= titleSize) : (i += 1) {
            const isEql = std.ascii.eqlIgnoreCase(ref_str[i .. findLen + i], substring[0..findLen]);
            if (isEql) {
                return true;
            }
        }
    }

    return false;
}

test containsSubstring {
    try std.testing.expect(containsSubstring("hello", "hello") == true);
    try std.testing.expect(containsSubstring("hello", "wow hello there") == true);
    try std.testing.expect(containsSubstring("hello", "nothing here") == false);
}
