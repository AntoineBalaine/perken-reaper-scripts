//! Minimal Zig bindings for libhegel's C ABI (see build.zig's addHegel for
//! how the static archive gets here) — only the subset rhythm_simplify's
//! property tests actually use: a settings/run/test-case lifecycle, integer
//! and boolean draws, and a variable-length collection for building a
//! random bar's worth of events. Hand-written against hegel.h 0.48.0's
//! documented ABI rather than generated, since the subset is small and
//! fetching/parsing the header at build time is its own separate task.
//!
//! Every call takes a Context first and returns a Result; HEGEL_OK is 0,
//! every error is negative — see hegel.h's "Calling convention".

const std = @import("std");

pub const Result = enum(c_int) {
    ok = 0,
    stop_test = -1,
    e_invalid_handle = -2,
    e_invalid_arg = -3,
    e_not_complete = -4,
    e_already_complete = -5,
    e_concurrent_use = -6,
    e_retry = -7,
    _,
};

pub const Status = enum(u32) {
    valid = 0,
    invalid = 1,
    overrun = 2,
    interesting = 3,
};

pub const RunStatus = enum(u32) {
    passed = 0,
    failed = 1,
    err = 2,
};

pub const String = extern struct {
    data: ?[*]const u8 = null,
    len: usize = 0,

    pub fn fromSlice(s: []const u8) String {
        return .{ .data = s.ptr, .len = s.len };
    }
};

pub const Context = opaque {};
pub const Settings = opaque {};
pub const Run = opaque {};
pub const RunResult = opaque {};
pub const TestCase = opaque {};
pub const Collection = opaque {};

extern fn hegel_context_new() ?*Context;
extern fn hegel_context_free(ctx: ?*Context) Result;
extern fn hegel_context_last_error(ctx: ?*const Context) String;

extern fn hegel_settings_new(ctx: ?*Context, out_settings: **Settings) Result;
extern fn hegel_settings_free(ctx: ?*Context, s: ?*Settings) Result;
extern fn hegel_settings_set_test_cases(ctx: ?*Context, s: ?*Settings, n: u64) Result;

extern fn hegel_run_start(
    ctx: ?*Context,
    settings: ?*const Settings,
    callback: ?*const fn (?*anyopaque, [*c]const u8, usize) callconv(.C) void,
    user_data: ?*anyopaque,
    out_run: **Run,
) Result;
extern fn hegel_next_test_case(ctx: ?*Context, run: ?*Run, out_test_case: *?*TestCase) Result;
extern fn hegel_run_result(ctx: ?*Context, run: ?*Run, out_result: **RunResult) Result;
extern fn hegel_run_result_status(ctx: ?*Context, r: ?*const RunResult, out_status: *RunStatus) Result;
extern fn hegel_run_result_free(ctx: ?*Context, r: ?*RunResult) Result;
extern fn hegel_run_free(ctx: ?*Context, run: ?*Run) Result;

extern fn hegel_test_case_free(ctx: ?*Context, tc: ?*TestCase) Result;
extern fn hegel_mark_complete(ctx: ?*Context, tc: ?*TestCase, status: Status, origin: ?*const String) Result;

extern fn hegel_generate_integer(ctx: ?*Context, tc: ?*TestCase, min_value: i64, max_value: i64, out_value: *i64) Result;
extern fn hegel_generate_boolean(ctx: ?*Context, tc: ?*TestCase, p: f64, forced: bool, has_forced: bool, out_value: *bool) Result;

extern fn hegel_new_collection(ctx: ?*Context, tc: ?*TestCase, min_size: u64, max_size: u64, out_collection: **Collection) Result;
extern fn hegel_collection_more(ctx: ?*Context, tc: ?*TestCase, collection: ?*Collection, out_more: *bool) Result;
extern fn hegel_collection_free(ctx: ?*Context, collection: ?*Collection) Result;

/// Thin, allocator-friendly wrapper: owns the context and surfaces its last
/// error message as a Zig error, since the raw ABI reports failure as a
/// Result code plus an out-of-band message on the context.
pub const Ctx = struct {
    ptr: *Context,

    pub fn init() Ctx {
        return .{ .ptr = hegel_context_new().? };
    }

    pub fn deinit(self: Ctx) void {
        _ = hegel_context_free(self.ptr);
    }

    pub fn lastError(self: Ctx) []const u8 {
        const s = hegel_context_last_error(self.ptr);
        return if (s.data) |d| d[0..s.len] else "";
    }

    fn check(self: Ctx, r: Result) !void {
        if (r != .ok) {
            std.log.err("hegel: {s}", .{self.lastError()});
            return error.HegelCallFailed;
        }
    }

    pub fn settingsNew(self: Ctx, test_cases: u64) !*Settings {
        var s: *Settings = undefined;
        try self.check(hegel_settings_new(self.ptr, &s));
        try self.check(hegel_settings_set_test_cases(self.ptr, s, test_cases));
        return s;
    }

    pub fn settingsFree(self: Ctx, s: *Settings) void {
        _ = hegel_settings_free(self.ptr, s);
    }

    pub fn runStart(self: Ctx, settings: *const Settings) !*Run {
        var run: *Run = undefined;
        try self.check(hegel_run_start(self.ptr, settings, null, null, &run));
        return run;
    }

    pub fn runFree(self: Ctx, run: *Run) void {
        _ = hegel_run_free(self.ptr, run);
    }

    /// Null once the run is done generating test cases.
    pub fn nextTestCase(self: Ctx, run: *Run) !?*TestCase {
        var tc: ?*TestCase = null;
        try self.check(hegel_next_test_case(self.ptr, run, &tc));
        return tc;
    }

    pub fn markComplete(self: Ctx, tc: *TestCase, status: Status) !void {
        try self.check(hegel_mark_complete(self.ptr, tc, status, null));
    }

    pub fn testCaseFree(self: Ctx, tc: *TestCase) void {
        _ = hegel_test_case_free(self.ptr, tc);
    }

    pub fn runResultStatus(self: Ctx, run: *Run) !RunStatus {
        var result: *RunResult = undefined;
        try self.check(hegel_run_result(self.ptr, run, &result));
        defer _ = hegel_run_result_free(self.ptr, result);
        var status: RunStatus = undefined;
        try self.check(hegel_run_result_status(self.ptr, result, &status));
        return status;
    }

    /// Inclusive range, like all of libhegel's integer draws.
    pub fn drawInt(self: Ctx, tc: *TestCase, min_value: i64, max_value: i64) !i64 {
        var v: i64 = undefined;
        try self.check(hegel_generate_integer(self.ptr, tc, min_value, max_value, &v));
        return v;
    }

    pub fn drawBool(self: Ctx, tc: *TestCase, p: f64) !bool {
        var v: bool = undefined;
        try self.check(hegel_generate_boolean(self.ptr, tc, p, false, false, &v));
        return v;
    }

    pub fn newCollection(self: Ctx, tc: *TestCase, min_size: u64, max_size: u64) !*Collection {
        var c: *Collection = undefined;
        try self.check(hegel_new_collection(self.ptr, tc, min_size, max_size, &c));
        return c;
    }

    pub fn collectionMore(self: Ctx, tc: *TestCase, collection: *Collection) !bool {
        var more: bool = undefined;
        try self.check(hegel_collection_more(self.ptr, tc, collection, &more));
        return more;
    }

    pub fn collectionFree(self: Ctx, collection: *Collection) void {
        _ = hegel_collection_free(self.ptr, collection);
    }
};

test "a trivial run with one integer draw passes" {
    const ctx = Ctx.init();
    defer ctx.deinit();
    const settings = try ctx.settingsNew(20);
    defer ctx.settingsFree(settings);
    const run = try ctx.runStart(settings);
    defer ctx.runFree(run);

    while (try ctx.nextTestCase(run)) |tc| {
        defer ctx.testCaseFree(tc);
        const v = try ctx.drawInt(tc, 0, 100);
        try std.testing.expect(v >= 0 and v <= 100);
        try ctx.markComplete(tc, .valid);
    }
    try std.testing.expectEqual(RunStatus.passed, try ctx.runResultStatus(run));
}
