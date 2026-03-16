const std = @import("std");
const testing = std.testing;
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const StatefulConfig = zlowcheck.StatefulConfig;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;
const pReaper = @import("../pReaper.zig");

const models = @import("../models/models.zig");
const TrackState = @import("../track_state.zig");
const reaper = @import("../reaper.zig").reaper;
const DefaultFx = @import("../settings.zig").DefaultFx;
const Preferences = @import("../settings.zig").Preferences;
const ModulesList = @import("../statemachine.zig").ModulesList;
const MapStore = @import("../mappings.zig");

/// used in tests
fn getTestConfigPath(allocator: std.mem.Allocator) ![*:0]const u8 {
    var path_mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &path_mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    return try allocator.dupeZ(u8, config_path);
}

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
    track: *models.Track,
    map_store: MapStore,

    pub fn init(session: *models.Session) !@This() {
        // Get first track (index 1, since 0 is master)
        const track = &session.tracks.items[1];

        return .{
            .session = session,
            .track = track,
            .map_store = .empty(testing.allocator, "test_resources/mappings"),
        };
    }

    pub fn reset(self: *@This()) void {
        // Clear all FX from the track
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

        var track_state: TrackState = .{};
        _ = track_state.validateTrack(media_track, model.default_fx, &sut.map_store, .empty);

        // Verify all 5 modules exist after validation
        const fx_count = reaper.TrackFX_GetCount(media_track);

        // After validation, we should have at least 5 FX (the required modules)
        // We may have more if there were non-module FX
        return fx_count >= 5;
    }
};

test "track validation - empty track gets all modules" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    var track_state: TrackState = .{};
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store, .empty);

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
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    // Add two FX with same module suffix
    _ = reaper.TrackFX_AddByName(media_track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)");

    _ = reaper.TrackFX_AddByName(media_track, "VST: ReaEQ (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 1, "renamed_name", "VST: ReaEQ (Cockos) (C1-I)");

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    var track_state: TrackState = .{};
    _ = track_state.validateTrack(media_track, default_fx, &map_store, .empty);

    const fx_count = reaper.TrackFX_GetCount(media_track);

    // validation adds 4 missing modules (GATE, EQ, COMP, OUTPT) to the existing 2 FX,
    // so we should have 6 total
    try testing.expectEqual(@as(c_int, 6), fx_count);

    // reordering moves Console1 modules but may interleave non-module FX,
    // so let's verify the non-module ReaEQ exists somewhere in the chain without its suffix
    var found_non_module_eq = false;
    var i: c_int = 0;
    while (i < fx_count) : (i += 1) {
        var buf: [512:0]u8 = undefined;
        _ = reaper.TrackFX_GetNamedConfigParm(media_track, i, "renamed_name", &buf, buf.len);
        const name = std.mem.span(@as([*:0]const u8, &buf));
        if (std.mem.eql(u8, name, "VST: ReaEQ (Cockos)")) {
            found_non_module_eq = true;
            break;
        }
    }
    try testing.expect(found_non_module_eq);
}

test "track validation - missing modules inserted in correct positions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    // Add only INPUT and OUTPT
    _ = reaper.TrackFX_AddByName(media_track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)");

    _ = reaper.TrackFX_AddByName(media_track, "JS: Volume Adjustment", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(media_track, 1, "renamed_name", "JS: Volume Adjustment (C1-O)");

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    var track_state: TrackState = .{};
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store, .empty);

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
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
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

    var seed_prng = std.Random.DefaultPrng.init(0x8BBE022C870AF654);
    var random_bytes: [256]u8 = undefined;
    seed_prng.random().bytes(&random_bytes);

    var prng = FinitePrng.init(&random_bytes);
    var random = prng.random();

    // Create command sequence
    var cmd_seq = try CommandList(Model, System).init(&commands, &random, 50, testing.allocator);
    defer cmd_seq.deinit(testing.allocator);

    // Run the test
    const rv = try assertStateful(Model, System, &cmd_seq, &model, &sut, config);
    try testing.expect(rv != null);
}

test "auto_insert_modules disabled prevents module insertion" {
    // Because auto_insert_modules is disabled, validateTrack should not insert missing modules
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    const default_fx: DefaultFx = .initFill(null);

    var prefs = Preferences.empty;
    prefs.auto_insert_modules = false;

    var track_state: TrackState = .{};
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store, prefs);

    // Because no modules were present initially and insertion is disabled, all modules should be null
    try testing.expect(coverage.INPUT == null);
    try testing.expect(coverage.GATE == null);
    try testing.expect(coverage.COMP == null);
    try testing.expect(coverage.EQ == null);
    try testing.expect(coverage.OUTPT == null);
}

test "auto_insert_bypassed causes new modules to be bypassed" {
    // Because auto_insert_bypassed is enabled, newly inserted modules should have bypass state set
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    // Because we need default FX names for insertion, set them up
    var default_fx: DefaultFx = .initFill(null);
    default_fx.set(.INPUT, "ReaComp");
    default_fx.set(.GATE, "ReaGate");
    default_fx.set(.COMP, "ReaComp");
    default_fx.set(.EQ, "ReaEQ");
    default_fx.set(.OUTPT, "ReaComp");

    var prefs = Preferences.empty;
    prefs.auto_insert_bypassed = true;

    var track_state: TrackState = .{};
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store, prefs);

    try testing.expect(coverage.INPUT != null);
    try testing.expect(coverage.GATE != null);
    try testing.expect(coverage.COMP != null);
    try testing.expect(coverage.EQ != null);
    try testing.expect(coverage.OUTPT != null);

    const input_enabled = pReaper.TrackFX_GetEnabled(.{ media_track, coverage.INPUT.?.index });
    const gate_enabled = pReaper.TrackFX_GetEnabled(.{ media_track, coverage.GATE.?.index });
    const comp_enabled = pReaper.TrackFX_GetEnabled(.{ media_track, coverage.COMP.?.index });
    const eq_enabled = pReaper.TrackFX_GetEnabled(.{ media_track, coverage.EQ.?.index });
    const outpt_enabled = pReaper.TrackFX_GetEnabled(.{ media_track, coverage.OUTPT.?.index });

    try testing.expect(input_enabled == false);
    try testing.expect(gate_enabled == false);
    try testing.expect(comp_enabled == false);
    try testing.expect(eq_enabled == false);
    try testing.expect(outpt_enabled == false);
}

test "auto_reorder_modules disabled preserves existing module positions" {
    // Because auto_reorder_modules is disabled, existing modules should not be moved
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    // Because we need to test reordering behavior, first add modules in non-canonical order
    var default_fx: DefaultFx = .initFill(null);
    default_fx.set(.INPUT, "ReaComp");
    default_fx.set(.GATE, "ReaGate");
    default_fx.set(.COMP, "ReaComp");
    default_fx.set(.EQ, "ReaEQ");
    default_fx.set(.OUTPT, "ReaComp");

    // Add modules in reverse order: OUTPT, EQ, COMP, GATE, INPUT
    _ = pReaper.TrackFX_AddByName(.{ media_track, "ReaComp", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, 0, "renamed_name", "ReaComp (C1-O)" });

    _ = pReaper.TrackFX_AddByName(.{ media_track, "ReaEQ", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, 1, "renamed_name", "ReaEQ (C1-E)" });

    _ = pReaper.TrackFX_AddByName(.{ media_track, "ReaComp", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, 2, "renamed_name", "ReaComp (C1-C)" });

    _ = pReaper.TrackFX_AddByName(.{ media_track, "ReaGate", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, 3, "renamed_name", "ReaGate (C1-S)" });

    _ = pReaper.TrackFX_AddByName(.{ media_track, "ReaComp", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, 4, "renamed_name", "ReaComp (C1-I)" });

    var prefs = Preferences.empty;
    prefs.auto_insert_modules = false; // Don't insert any new modules
    prefs.auto_reorder_modules = false; // Don't reorder existing modules

    var track_state: TrackState = .{};
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store, prefs);

    // Because reordering is disabled, modules should remain in their original positions
    try testing.expect(coverage.OUTPT.?.index == 0);
    try testing.expect(coverage.EQ.?.index == 1);
    try testing.expect(coverage.COMP.?.index == 2);
    try testing.expect(coverage.GATE.?.index == 3);
    try testing.expect(coverage.INPUT.?.index == 4);
}

test "preferred_module_order affects insertion positions" {
    // Because preferred_module_order is set to EQ-S-C, modules should be inserted in that order
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(arena.allocator(), 1, 4);
    defer reaper_teardown.teardown();

    const track = &reaper_teardown.model_ptr.tracks.items[1];
    const media_track: reaper.MediaTrack = @ptrCast(track);

    const config_path = try getTestConfigPath(arena.allocator());
    var map_store: MapStore = .empty(arena.allocator(), config_path);
    defer map_store.deinit();

    var default_fx: DefaultFx = .initFill(null);
    default_fx.set(.INPUT, "ReaComp");
    default_fx.set(.GATE, "ReaGate");
    default_fx.set(.COMP, "ReaComp");
    default_fx.set(.EQ, "ReaEQ");
    default_fx.set(.OUTPT, "ReaComp");

    var prefs = Preferences.empty;
    prefs.preferred_module_order = .@"EQ-S-C";

    var track_state: TrackState = .{};
    const coverage = track_state.validateTrack(media_track, default_fx, &map_store, prefs);

    // Because modules are inserted in EQ-S-C order, verify the final order is INPUT, EQ, GATE, COMP, OUTPT
    try testing.expect(coverage.INPUT != null);
    try testing.expect(coverage.EQ != null);
    try testing.expect(coverage.GATE != null);
    try testing.expect(coverage.COMP != null);
    try testing.expect(coverage.OUTPT != null);

    try testing.expect(coverage.INPUT.?.index == 0);
    try testing.expect(coverage.EQ.?.index == 1);
    try testing.expect(coverage.GATE.?.index == 2);
    try testing.expect(coverage.COMP.?.index == 3);
    try testing.expect(coverage.OUTPT.?.index == 4);
}
