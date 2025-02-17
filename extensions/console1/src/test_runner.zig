const std = @import("std");
const log = std.log.scoped(.tests);
const reaper = @import("reaper.zig").reaper;
const RprCmds = @import("reaper_cmds.zig");

const TestRunner = @This();

pub const TestCase = struct {
    name: []const u8,
    setup: ?*const fn () anyerror!void = null,
    run: *const fn () TestError!void,
};
pub const TestError = error{
    TrackNotFound,
    FxNotFound,
    ValidationFailed,
    TestExpectedEqual,
};

pub const TestResult = struct {
    name: []const u8,
    passed: bool,
    err: ?TestError,
};

results: std.ArrayList(TestResult),
project: ?*reaper.ReaProject,

pub fn init(allocator: std.mem.Allocator) TestRunner {
    log.debug("Initializing test runner", .{});
    return .{
        .results = std.ArrayList(TestResult).init(allocator),
        .project = reaper.EnumProjects(-1, null),
    };
}

pub fn deinit(self: *TestRunner) void {
    self.results.deinit();
    reaper.Main_OnCommand(RprCmds.IDC_EDIT_UNDO, 0);
}

pub fn runTest(self: *@This(), test_case: TestCase) !void {
    log.debug("Running test: {s}", .{test_case.name});
    const start_time = std.time.nanoTimestamp();

    if (self.project) |proj| {
        reaper.Undo_BeginBlock2(proj);
    }

    // Run test
    if (test_case.setup) |setup| {
        setup() catch |err| {
            log.err("Test setup failed: {s} - {s}", .{
                test_case.name,
                @errorName(err),
            });

            if (self.project) |proj| {
                reaper.Undo_EndBlock2(proj, "Test Setup Failed", -1);
            }
            return err;
        };
    }

    test_case.run() catch |err| {
        log.err("Test failed: {s} - {s}", .{
            test_case.name,
            @errorName(err),
        });

        try self.results.append(.{
            .name = test_case.name,
            .passed = false,
            .err = err,
        });

        if (self.project) |proj| {
            reaper.Undo_EndBlock2(proj, "Test Failed", -1);
        }
        return;
    };

    if (self.project) |proj| {
        reaper.Undo_EndBlock2(proj, "Test Completed", -1);
    }

    log.debug("Test passed: {s} ({d}ns)", .{
        test_case.name,
        std.time.nanoTimestamp() - start_time,
    });

    try self.results.append(.{
        .name = test_case.name,
        .passed = true,
        .err = null,
    });
}

pub fn reportResults(self: *const @This()) void {
    var passed: usize = 0;
    for (self.results.items) |result| {
        if (result.passed) {
            passed += 1;
        }
    }

    if (passed == self.results.items.len) {
        log.info("All tests passed ({}/{})", .{
            passed,
            self.results.items.len,
        });
    } else {
        log.warn("Some tests failed ({}/{})", .{
            passed,
            self.results.items.len,
        });

        // Log details of failed tests
        for (self.results.items) |result| {
            if (!result.passed) {
                log.err("{s}: {s}", .{
                    result.name,
                    @errorName(result.err.?),
                });
            }
        }
    }
}
