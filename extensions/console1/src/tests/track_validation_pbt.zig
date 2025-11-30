const std = @import("std");
const testing = std.testing;
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const StatefulConfig = zlowcheck.StatefulConfig;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

const models = @import("../models/models.zig");
const test_helpers = @import("mode_switch_tests.zig");
const TrackState = @import("../track_state.zig");
const reaper = @import("../reaper.zig").reaper;
const DefaultFx = @import("../settings.zig").DefaultFx;
const ModulesList = @import("../statemachine.zig").ModulesList;
const MapStore = @import("../mappings.zig");
const Guid = @import("../utils.zig").Guid;

// Model tracks the expected state of FX chain
const Model = struct {
    // List of FX with their names and module assignments
    fx_chain: std.ArrayListUnmanaged(FxEntry),
    // Default FX configuration for each module
    default_fx: DefaultFx,
    allocator: std.mem.Allocator,

    const FxEntry = struct {
        original_name: []const u8,
        renamed_name: []const u8,
        module: ?ModulesList,
    };

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .fx_chain = std.ArrayListUnmanaged(FxEntry){},
            .default_fx = DefaultFx.init(.{
                .INPUT = "VST: ReaComp (Cockos)",
                .GATE = "VST: ReaGate (Cockos)",
                .EQ = "VST: ReaEQ (Cockos)",
                .COMP = "VST: ReaComp (Cockos)",
                .OUTPT = "JS: Volume Adjustment",
            }),
            .allocator = allocator,
        };
    }

    pub fn reset(self: *@This()) void {
        for (self.fx_chain.items) |entry| {
            self.allocator.free(entry.original_name);
            if (entry.original_name.ptr != entry.renamed_name.ptr) {
                self.allocator.free(entry.renamed_name);
            }
        }
        self.fx_chain.clearRetainingCapacity();
    }

    pub fn deinit(self: *@This()) void {
        self.reset();
        self.fx_chain.deinit(self.allocator);
    }
};

// System wraps the mock REAPER session
const System = struct {
    session: *models.Session,
    track: *models.Track.Track,
    map_store: MapStore,

    pub fn init(session: *models.Session) !@This() {
        // Get first track (index 1, since 0 is master)
        const track = &session.tracks.items[1];

        // Initialize map_store
        var map_store = MapStore{};
        map_store.init(testing.allocator, "test_resources/mappings");

        return .{
            .session = session,
            .track = track,
            .map_store = map_store,
        };
    }

    pub fn reset(self: *@This()) void {
        // Clear all FX from the track
        for (self.track.fx_list.items) |*fx| {
            fx.deinit(self.session.gpa);
        }
        self.track.fx_list.clearRetainingCapacity();
    }

    pub fn deinit(self: *@This()) void {
        self.map_store.deinit();
    }
};

// Commands

const AddFxCmd = struct {
    fx_name: []const u8,
    module_suffix: ?ModulesList,

    pub const name = "AddFx";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can always add FX (up to reasonable limit)
        return model.fx_chain.items.len < 20;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        const original_name = model.allocator.dupe(u8, self.fx_name) catch return;
        const renamed_name = if (self.module_suffix) |module| blk: {
            const suffix = moduleToSuffix(module);
            const full_name = std.fmt.allocPrint(model.allocator, "{s} (C1-{s})", .{ self.fx_name, suffix }) catch return;
            break :blk full_name;
        } else model.allocator.dupe(u8, self.fx_name) catch return;

        model.fx_chain.append(model.allocator, .{
            .original_name = original_name,
            .renamed_name = renamed_name,
            .module = self.module_suffix,
        }) catch return;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        const media_track: reaper.MediaTrack = @ptrCast(sut.track);

        // Add FX to system
        const fx_name_z = testing.allocator.dupeZ(u8, self.fx_name) catch return false;
        defer testing.allocator.free(fx_name_z);

        const fx_idx = reaper.TrackFX_AddByName(media_track, fx_name_z.ptr, false, -1);
        if (fx_idx < 0) return false;

        // Set renamed name if module suffix specified
        if (self.module_suffix) |module| {
            const suffix = moduleToSuffix(module);
            const renamed = std.fmt.allocPrintZ(testing.allocator, "{s} (C1-{s})", .{ self.fx_name, suffix }) catch return false;
            defer testing.allocator.free(renamed);

            _ = reaper.TrackFX_SetNamedConfigParm(media_track, fx_idx, "renamed_name", renamed.ptr);
        }

        // Update model
        self.onModelOnly(model);

        // Verify FX count matches
        // NOTE: should we be more thorough here and check for the actual matches between the fx chains?
        // Don't we expect the model and the sut here to have not only the same fx count, but also the same fx names in the same order?
        const system_fx_count = reaper.TrackFX_GetCount(media_track);
        return system_fx_count == model.fx_chain.items.len;
    }

    fn moduleToSuffix(module: ModulesList) []const u8 {
        return switch (module) {
            .INPUT => "I",
            .GATE => "S",
            .EQ => "E",
            .COMP => "C",
            .OUTPT => "O",
        };
    }
};

const RemoveFxCmd = struct {
    fx_index: usize,

    pub const name = "RemoveFx";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        return self.fx_index < model.fx_chain.items.len;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        if (self.fx_index >= model.fx_chain.items.len) return;

        const entry = model.fx_chain.orderedRemove(self.fx_index);
        model.allocator.free(entry.original_name);
        if (entry.original_name.ptr != entry.renamed_name.ptr) {
            model.allocator.free(entry.renamed_name);
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        const media_track: reaper.MediaTrack = @ptrCast(sut.track);

        // Remove from system by removing from fx_list
        // Note: There's no TrackFX_Delete in mock yet, so we manipulate directly
        if (self.fx_index >= sut.track.fx_list.items.len) return false;

        var removed_fx = sut.track.fx_list.orderedRemove(self.fx_index);
        removed_fx.deinit(sut.session.gpa);

        // Update model
        self.onModelOnly(model);

        // Verify counts match
        const system_fx_count = reaper.TrackFX_GetCount(media_track);
        return system_fx_count == model.fx_chain.items.len;
    }
};

const RenameFxCmd = struct {
    fx_index: usize,
    new_name: []const u8,

    pub const name = "RenameFx";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        return self.fx_index < model.fx_chain.items.len;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        if (self.fx_index >= model.fx_chain.items.len) return;

        const entry = &model.fx_chain.items[self.fx_index];

        // Free old renamed_name if different from original
        if (entry.original_name.ptr != entry.renamed_name.ptr) {
            model.allocator.free(entry.renamed_name);
        }

        entry.renamed_name = model.allocator.dupe(u8, self.new_name) catch return;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        const media_track: reaper.MediaTrack = @ptrCast(sut.track);

        // Rename in system
        const new_name_z = testing.allocator.dupeZ(u8, self.new_name) catch return false;
        defer testing.allocator.free(new_name_z);

        _ = reaper.TrackFX_SetNamedConfigParm(media_track, @intCast(self.fx_index), "renamed_name", new_name_z.ptr);

        // Update model
        self.onModelOnly(model);

        // Verify rename worked
        var buf: [512:0]u8 = undefined;
        _ = reaper.TrackFX_GetNamedConfigParm(media_track, @intCast(self.fx_index), "renamed_name", &buf, buf.len);

        return std.mem.eql(u8, self.new_name, std.mem.span(@as([*:0]const u8, &buf)));
    }
};

const SetDefaultFxCmd = struct {
    module: ModulesList,
    fx_name: []const u8,

    pub const name = "SetDefaultFx";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        _ = model;
        // Can always change default FX
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        model.default_fx.set(self.module, self.fx_name);
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        _ = sut;
        // Update model
        self.onModelOnly(model);
        // Always succeeds
        return true;
    }
};

const ValidateTrackCmd = struct {
    pub const name = "ValidateTrack";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        _ = model;
        // Can always validate
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
        // Model doesn't simulate full validation logic
        // We just verify system behavior matches expectations
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        _ = self;
        const media_track: reaper.MediaTrack = @ptrCast(sut.track);

        var track_state: TrackState = undefined;
        _ = track_state.validateTrack(media_track, model.default_fx, &sut.map_store);

        // Verify all 5 modules exist after validation
        const fx_count = reaper.TrackFX_GetCount(media_track);

        // After validation, we should have at least 5 FX (the required modules)
        // We may have more if there were non-module FX
        return fx_count >= 5;
    }
};

test "track validation - empty track gets all modules" {
    const reaper_teardown = models.reaper.setupTestModel(testing.allocator, 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    var map_store = MapStore{};
    map_store.init(testing.allocator, "test_resources/mappings");
    defer map_store.deinit();

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    var track_state: TrackState = undefined;
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store);

    // Verify all modules were added
    try testing.expect(coverage.INPUT != null);
    try testing.expect(coverage.GATE != null);
    try testing.expect(coverage.EQ != null);
    try testing.expect(coverage.COMP != null);
    try testing.expect(coverage.OUTPT != null);

    // Verify they're in correct order
    try testing.expectEqual(@as(i32, 0), coverage.INPUT.?.index);
    try testing.expectEqual(@as(i32, 1), coverage.GATE.?.index);
    try testing.expectEqual(@as(i32, 2), coverage.EQ.?.index);
    try testing.expectEqual(@as(i32, 3), coverage.COMP.?.index);
    try testing.expectEqual(@as(i32, 4), coverage.OUTPT.?.index);

    // Verify total FX count
    const fx_count = reaper.TrackFX_GetCount(media_track);
    try testing.expectEqual(@as(c_int, 5), fx_count);
}

test "track validation - duplicate module suffixes removed" {
    const reaper_teardown = models.reaper.setupTestModel(testing.allocator, 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    // Add two FX with same module suffix
    _ = reaper.TrackFX_AddByName(media_track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)");

    _ = reaper.TrackFX_AddByName(media_track, "VST: ReaEQ (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 1, "renamed_name", "VST: ReaEQ (Cockos) (C1-I)");

    var map_store = MapStore{};
    map_store.init(testing.allocator, "test_resources/mappings");
    defer map_store.deinit();

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    var track_state: TrackState = undefined;
    _ = track_state.validateTrack(media_track, default_fx, &map_store);

    // Verify second FX had its suffix removed
    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(media_track, 1, "renamed_name", &buf, buf.len);
    try testing.expectEqualStrings("VST: ReaEQ (Cockos)", std.mem.span(@as([*:0]const u8, &buf)));

    // Both FX should still exist
    const fx_count = reaper.TrackFX_GetCount(media_track);
    try testing.expect(fx_count >= 5); // At least 5 after validation adds missing
}

test "track validation - missing modules inserted in correct positions" {
    const reaper_teardown = models.reaper.setupTestModel(testing.allocator, 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    // Add only INPUT and OUTPT
    _ = reaper.TrackFX_AddByName(media_track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)");

    _ = reaper.TrackFX_AddByName(media_track, "JS: Volume Adjustment", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 1, "renamed_name", "JS: Volume Adjustment (C1-O)");

    var map_store = MapStore{};
    map_store.init(testing.allocator, "test_resources/mappings");
    defer map_store.deinit();

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    var track_state: TrackState = undefined;
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store);

    // Verify all modules exist and are in correct order
    try testing.expectEqual(@as(i32, 0), coverage.INPUT.?.index);
    try testing.expectEqual(@as(i32, 1), coverage.GATE.?.index);
    try testing.expectEqual(@as(i32, 2), coverage.EQ.?.index);
    try testing.expectEqual(@as(i32, 3), coverage.COMP.?.index);
    try testing.expectEqual(@as(i32, 4), coverage.OUTPT.?.index);

    // Verify names
    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(media_track, 0, "renamed_name", &buf, buf.len);
    try testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-I)", std.mem.span(@as([*:0]const u8, &buf)));

    _ = reaper.TrackFX_GetNamedConfigParm(media_track, 4, "renamed_name", &buf, buf.len);
    try testing.expectEqualStrings("JS: Volume Adjustment (C1-O)", std.mem.span(@as([*:0]const u8, &buf)));
}

test "track validation property-based test" {
    const reaper_teardown = models.reaper.setupTestModel(testing.allocator, 1, 4);
    defer reaper_teardown.teardown();

    var model = try Model.init(testing.allocator);
    defer model.deinit();

    var sut = try System.init(reaper_teardown.model_ptr);
    defer sut.deinit();

    // Create commands
    var add_input = AddFxCmd{ .fx_name = "VST: ReaComp (Cockos)", .module_suffix = .INPUT };
    var add_gate = AddFxCmd{ .fx_name = "VST: ReaGate (Cockos)", .module_suffix = .GATE };
    var add_eq = AddFxCmd{ .fx_name = "VST: ReaEQ (Cockos)", .module_suffix = .EQ };
    var add_no_module = AddFxCmd{ .fx_name = "VST: SomePlugin", .module_suffix = null };
    var validate = ValidateTrackCmd{};

    const commands = [_]Command(Model, System){
        Command(Model, System).init(&add_input),
        Command(Model, System).init(&add_gate),
        Command(Model, System).init(&add_eq),
        Command(Model, System).init(&add_no_module),
        Command(Model, System).init(&validate),
    };

    // Create configuration
    const config: StatefulConfig = .{ .verbose = false };

    // Create random source
    var random_bytes = [_]u8{
        0x8B, 0xBE, 0x02, 0x2C, 0x87, 0x0A, 0xF6, 0x54, 0x4A, 0x59, 0x73, 0xA8, 0x12, 0xF7, 0x2B, 0x85,
        0xAD, 0x95, 0x90, 0x8A, 0x21, 0xF1, 0xAC, 0x64, 0x42, 0x32, 0xA5, 0x0D, 0x10, 0x1F, 0xBA, 0xE7,
        0x0F, 0xEE, 0xF9, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62,
    };
    var prng = FinitePrng.init(&random_bytes);
    var random = prng.random();

    // Create command sequence
    var cmd_seq = try CommandList(Model, System).init(&commands, &random, 50, testing.allocator);
    defer cmd_seq.deinit(testing.allocator);

    // Run the test
    const rv = try assertStateful(Model, System, &cmd_seq, &model, &sut, config);
    try testing.expect(rv != null);
}
