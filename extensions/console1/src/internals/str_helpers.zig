const std = @import("std");

pub fn containsSubstring(substring: [*:0]u8, ref_str: [*:0]u8) bool {
    var i: usize = 0;
    const titleSize = std.mem.len(ref_str);
    const findLen = std.mem.len(substring);
    if (titleSize >= findLen) {
        while (i + findLen <= titleSize) : (i += 1) {
            if (std.mem.eql(u8, ref_str[i .. findLen + i], substring[0..findLen])) {
                return true;
            }
        }
    }

    return false;
}

test containsSubstring {
    const search_str = "hello";
    const ref_str = "wow hello there";
    const result = containsSubstring(@constCast(search_str), @constCast(ref_str));
    try std.testing.expect(result == true);
    const fail_str = "nothing here";
    const failing_result = containsSubstring(@constCast(search_str), @constCast(fail_str));
    try std.testing.expect(failing_result == false);
}
