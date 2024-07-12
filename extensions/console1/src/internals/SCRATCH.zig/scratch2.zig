const std = @import("std");

fn parseParms(str: [*]const c_char, parms: *[4]c_int) !void {
    parms[0] = 0;
    parms[1] = 9;
    parms[2] = -1;
    parms[3] = -1;

    var p = str;
    var x: u8 = 0;
    while (x < 4) {
        while (p[0] == ' ') p += 1;
        if ((p[0] < '0' or p[0] > '9') and p[0] != '-') break;

        x += 1;
        const cast: [*:0]const u8 = @ptrCast(p);
        parms[x] = try std.fmt.parseInt(i32, std.mem.span(cast), 10);
        while (p[0] and p[0] != ' ') p += 1;
    }
    // parms[0]=0;
    // parms[1]=9;
    // parms[2]=parms[3]=-1;
    //
    // const char *p=str;
    // if (p)
    // {
    //   int x=0;
    //   while (x<4)
    //   {
    //     while (*p == ' ') p++;
    //     if ((*p < '0' || *p > '9') && *p != '-') break;
    //     parms[x++]=atoi(p);
    //     while (*p && *p != ' ') p++;
    //   }
    // }
}

test parseParms {
    const expect = std.testing.expect;

    var parms: [4]c_int = undefined;
    var my_arr = [5]c_char{ '1', ' ', '2', ' ', '3' };
    const str: [*]const c_char = &my_arr;
    try parseParms(str, &parms);
    try expect(str[1] == 1);
    try expect(str[2] == 2);
    // try expect(str[3] == 3);
}
