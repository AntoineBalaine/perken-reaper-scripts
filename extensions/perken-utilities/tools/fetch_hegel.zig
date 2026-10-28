//! Downloads one file over HTTP and verifies it against a published sha256
//! sidecar, the workaround for `zig fetch` rejecting GitHub's raw release
//! asset Content-Disposition header (see build.zig's addHegel). Run by
//! build.zig as a build-time tool, not shipped in the extension.
const std = @import("std");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const allocator = arena_state.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 4) {
        std.debug.print("usage: fetch_hegel <url> <sha256-sidecar-url> <output-path>\n", .{});
        return error.InvalidArgs;
    }
    const url = args[1];
    const sha_url = args[2];
    const out_path = args[3];

    // Already there: nothing to do, and nothing to ask the network for.
    // The hash was checked when it was written; delete the file to force a
    // fresh download.
    if (std.fs.cwd().access(out_path, .{})) |_| {
        return;
    } else |_| {}

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const body = try fetchAll(allocator, &client, url, 64 * 1024 * 1024);
    const sha_body = try fetchAll(allocator, &client, sha_url, 1024);

    // Sidecar format is the usual sha256sum one: "<hex>  <filename>".
    var it = std.mem.tokenizeAny(u8, sha_body, " \t\r\n");
    const expected_hex = it.next() orelse return error.BadShaFile;

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
    const actual_hex = std.fmt.bytesToHex(digest, .lower);

    if (!std.ascii.eqlIgnoreCase(expected_hex, &actual_hex)) {
        std.debug.print("hegel download hash mismatch for {s}: expected {s}, got {s}\n", .{ url, expected_hex, actual_hex });
        return error.HashMismatch;
    }

    if (std.fs.path.dirname(out_path)) |dir| try std.fs.cwd().makePath(dir);
    try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = body });
}

fn fetchAll(allocator: std.mem.Allocator, client: *std.http.Client, url: []const u8, max_size: usize) ![]u8 {
    var body: std.ArrayList(u8) = .empty;
    const result = try client.fetch(.{
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &body },
        .max_append_size = max_size,
    });
    if (result.status != .ok) {
        std.debug.print("GET {s} -> {d}\n", .{ url, @backingInt(result.status) });
        return error.FetchFailed;
    }
    return body.toOwnedSlice(allocator);
}
