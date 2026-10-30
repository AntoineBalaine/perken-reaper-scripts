const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const reaper_mock = @import("reaper_mock");
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const actions = @import("../actions.zig");
const midi_events = @import("../csurf/midi_events.zig");
const preset_store = @import("../preset_store.zig");

const chunk_with_vst =
    \\<TRACK
    \\<FXCHAIN
    \\SHOW 0
    \\<VST "VST: ReaComp (Cockos)" reacomp.vst.so 0 "" 1919247213<5653> ""
    \\AAEC
    \\AwQF
    \\UHJvZw==
    \\>
    \\>
    \\>
;

const chunk_with_clap =
    \\<TRACK
    \\<FXCHAIN
    \\<CLAP "CLAP: Something" x 0 ""
    \\AAAA
    \\>
    \\>
    \\>
;

const Harness = struct {
    arena: std.heap.ArenaAllocator,
    reaper_teardown: @typeInfo(@TypeOf(models.reaper.setupTestModel)).@"fn".return_type.?,
    midi_teardown: @typeInfo(@TypeOf(models.midi.setupMidiMocks)).@"fn".return_type.?,
    globals: *Globals,
    tmp: std.testing.TmpDir,
    preset_path: [:0]u8,

    fn init() !*Harness {
        const self = try testing.allocator.create(Harness);
        self.arena = std.heap.ArenaAllocator.init(testing.allocator);
        self.reaper_teardown = models.reaper.setupTestModel(self.arena.allocator(), null, null);
        self.midi_teardown = models.midi.setupMidiMocks(reaper);
        Globals.instance = try .defaults(testing.allocator);
        self.globals = &Globals.instance;
        self.globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
        self.globals.state.current_mode = .fx_ctrl;

        reaper.InsertTrackAtIndex(0, false);
        const track = reaper.CSurf_TrackFromID(1, false).?;
        _ = reaper.TrackFX_AddByName(track, "VST: ReaComp (Cockos)", false, -1);
        self.globals.state.current_tr_id = 1;
        self.globals.state.fx_ctrl.track_state.mode.multi_fx.set(.COMP, .{ .fx_index = 0, .mapping = null });

        self.tmp = std.testing.tmpDir(.{});
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const directory = path_buffer[0..try self.tmp.dir.realPathFile(testing.io, ".", &path_buffer)];
        self.preset_path = try std.fmt.allocPrintSentinel(testing.allocator, "{s}/vst-reacomp.ini", .{directory}, 0);
        reaper_mock.user_preset_path = self.preset_path;
        reaper_mock.track_chunk = chunk_with_vst;
        reaper_mock.current_preset_name = "";
        reaper_mock.activated_preset_len = 0;
        return self;
    }

    fn deinit(self: *Harness) void {
        reaper_mock.user_preset_path = "";
        reaper_mock.track_chunk = "";
        testing.allocator.free(self.preset_path);
        self.tmp.cleanup();
        self.globals.deinit();
        self.midi_teardown.teardown();
        self.reaper_teardown.teardown();
        self.arena.deinit();
        testing.allocator.destroy(self);
    }

    fn presets(self: *Harness) *statemachine.PresetsState {
        return &self.globals.state.presets;
    }

    fn send(self: *Harness, action: @import("../action_types.zig").PresetsAction) void {
        actions.dispatch(self.globals, .{ .presets = action });
    }

    fn writePresetFile(self: *Harness, content: []const u8) !void {
        const file = try self.tmp.dir.createFile(testing.io, "vst-reacomp.ini", .{});
        defer file.close(testing.io);
        try file.writeStreamingAll(testing.io, content);
    }

    fn readPresetFile(self: *Harness) ![]u8 {
        return self.tmp.dir.readFileAlloc(testing.io, "vst-reacomp.ini", testing.allocator, .limited(1 << 20));
    }

    fn activated(self: *Harness) []const u8 {
        _ = self;
        return reaper_mock.activated_preset[0..reaper_mock.activated_preset_len];
    }
};

const three_presets = "[General]\nNbPresets=3\n\n[Preset0]\nData=00\nName=Warm\nLen=1\n\n[Preset1]\nData=00\nName=Bright\nLen=1\n\n[Preset2]\nData=00\nName=Crushed\nLen=1\n";

test "the screen opens on the modules, with the FX that each one has, and the cursor on one that has an FX" {
    const h = try Harness.init();
    defer h.deinit();
    h.send(.{ .enter = .load });
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);
    try testing.expectEqual(statemachine.PresetsStage.modules, h.presets().stage);
    try testing.expectEqual(@as(usize, 5), h.presets().rows.len);
    try testing.expectEqual(statemachine.ModulesList.COMP, h.presets().rows[h.presets().module_cursor].module);
    try testing.expect(h.presets().rows[h.presets().module_cursor].fx_index != null);
    try testing.expect(h.presets().rows[0].fx_index == null);
}

test "the cursor of the modules skips the modules without an FX" {
    const h = try Harness.init();
    defer h.deinit();
    h.globals.state.fx_ctrl.track_state.mode.multi_fx.set(.INPUT, .{ .fx_index = 0, .mapping = null });
    h.send(.{ .enter = .load });
    try testing.expectEqual(statemachine.ModulesList.INPUT, h.presets().rows[h.presets().module_cursor].module);
    h.send(.{ .scroll_by = 1 });
    try testing.expectEqual(statemachine.ModulesList.COMP, h.presets().rows[h.presets().module_cursor].module);
    h.send(.{ .scroll_by = 1 });
    try testing.expectEqual(statemachine.ModulesList.INPUT, h.presets().rows[h.presets().module_cursor].module);
}

test "loading: the presets of the FX are listed, scrolled and loaded by name" {
    const h = try Harness.init();
    defer h.deinit();
    try h.writePresetFile(three_presets);
    h.send(.{ .enter = .load });
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsStage.presets, h.presets().stage);
    try testing.expectEqual(@as(usize, 3), h.presets().names.len);
    try testing.expectEqualStrings("Warm", h.presets().names[0]);
    h.send(.{ .scroll_by = 1 });
    h.send(.{ .scroll_by = 1 });
    try testing.expectEqual(@as(usize, 2), h.presets().preset_cursor);
    h.send(.{ .scroll_by = 1 });
    try testing.expectEqual(@as(usize, 0), h.presets().preset_cursor);
    h.send(.{ .pick = 1 });
    try testing.expectEqualStrings("Bright", h.activated());
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
}

test "loading: an FX without user presets says so and stays on the modules" {
    const h = try Harness.init();
    defer h.deinit();
    h.send(.{ .enter = .load });
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsStage.modules, h.presets().stage);
    try testing.expectEqual(statemachine.PresetsMessage.no_presets, h.presets().message);
}

test "cancel steps back one stage, and leaves the screen from the modules" {
    const h = try Harness.init();
    defer h.deinit();
    try h.writePresetFile(three_presets);
    h.send(.{ .enter = .load });
    h.send(.confirm);
    h.send(.cancel);
    try testing.expectEqual(statemachine.PresetsStage.modules, h.presets().stage);
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);
    h.send(.cancel);
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
    try testing.expectEqualStrings("", h.activated());
}

test "saving: a new name writes the preset into the preset file of the FX and activates it" {
    const h = try Harness.init();
    defer h.deinit();
    try h.writePresetFile(three_presets);
    h.send(.{ .enter = .save });
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsStage.name, h.presets().stage);
    @memcpy(h.presets().name_buffer[0.."Mine".len], "Mine");
    h.send(.confirm);
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
    try testing.expectEqualStrings("Mine", h.activated());

    const content = try h.readPresetFile();
    defer testing.allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "NbPresets=4") != null);
    const names = try preset_store.presetNames(testing.allocator, content);
    defer testing.allocator.free(names);
    try testing.expectEqual(@as(usize, 4), names.len);
    try testing.expectEqualStrings("Mine", names[3]);
    // The chunk "AAEC", "AwQF" and the name in place of the last line.
    try testing.expect(std.mem.indexOf(u8, content, "Data=00010203040500" ++ "4D696E65" ++ "0010000000") != null);
}

test "saving into a file that does not exist yet creates it" {
    const h = try Harness.init();
    defer h.deinit();
    h.send(.{ .enter = .save });
    h.send(.confirm);
    @memcpy(h.presets().name_buffer[0.."First".len], "First");
    h.send(.confirm);
    const content = try h.readPresetFile();
    defer testing.allocator.free(content);
    try testing.expect(std.mem.startsWith(u8, content, "[General]\nNbPresets=1\n"));
}

test "saving: the name of a preset that exists asks before it replaces it" {
    const h = try Harness.init();
    defer h.deinit();
    try h.writePresetFile(three_presets);
    h.send(.{ .enter = .save });
    h.send(.confirm);
    @memcpy(h.presets().name_buffer[0.."Bright".len], "Bright");
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsStage.overwrite, h.presets().stage);
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);

    // No goes back to the name and changes nothing.
    h.send(.cancel);
    try testing.expectEqual(statemachine.PresetsStage.name, h.presets().stage);
    const unchanged = try h.readPresetFile();
    defer testing.allocator.free(unchanged);
    try testing.expectEqualStrings(three_presets, unchanged);

    // Yes replaces the preset in place, and the count stays.
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsStage.overwrite, h.presets().stage);
    h.send(.confirm);
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
    const content = try h.readPresetFile();
    defer testing.allocator.free(content);
    try testing.expect(std.mem.indexOf(u8, content, "NbPresets=3") != null);
    const names = try preset_store.presetNames(testing.allocator, content);
    defer testing.allocator.free(names);
    try testing.expectEqual(@as(usize, 3), names.len);
    try testing.expect(std.mem.indexOf(u8, content, "Data=00\nName=Bright") == null);
}

test "saving the current preset's name is where the name starts" {
    const h = try Harness.init();
    defer h.deinit();
    reaper_mock.current_preset_name = "Warm";
    h.send(.{ .enter = .save });
    h.send(.confirm);
    try testing.expectEqualStrings("Warm", h.presets().nameSlice());
}

test "an empty name is not saved" {
    const h = try Harness.init();
    defer h.deinit();
    h.send(.{ .enter = .save });
    h.send(.confirm);
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsStage.name, h.presets().stage);
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);
}

test "saving the preset of a kind of FX that is not known says so" {
    const h = try Harness.init();
    defer h.deinit();
    reaper_mock.track_chunk = chunk_with_clap;
    h.send(.{ .enter = .save });
    h.send(.confirm);
    @memcpy(h.presets().name_buffer[0.."X".len], "X");
    h.send(.confirm);
    try testing.expectEqual(statemachine.PresetsMessage.unsupported_fx, h.presets().message);
    try testing.expectEqual(statemachine.PresetsStage.name, h.presets().stage);
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);
}

test "the unit: Preset loads, shift and Preset saves, and Solo and Mute confirm and cancel" {
    const h = try Harness.init();
    defer h.deinit();
    try h.writePresetFile(three_presets);
    h.globals.unit.link = .ready;
    h.globals.unit.backend = .sysex;

    midi_events.onUnitEvent(h.globals, .{ .press = .Inpt_preset });
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);
    try testing.expectEqual(statemachine.PresetsPurpose.load, h.presets().purpose);
    midi_events.onUnitEvent(h.globals, .{ .press = .Out_solo });
    try testing.expectEqual(statemachine.PresetsStage.presets, h.presets().stage);
    midi_events.onUnitEvent(h.globals, .{ .tick = .{ .cc = .Out_Vol, .delta = 1, .fine = false } });
    try testing.expectEqual(@as(usize, 1), h.presets().preset_cursor);
    midi_events.onUnitEvent(h.globals, .{ .press = .Out_mute });
    midi_events.onUnitEvent(h.globals, .{ .press = .Out_mute });
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);

    h.globals.unit.input.shift_held = true;
    midi_events.onUnitEvent(h.globals, .{ .press = .Inpt_preset });
    try testing.expectEqual(statemachine.Mode.presets, h.globals.state.current_mode);
    try testing.expectEqual(statemachine.PresetsPurpose.save, h.presets().purpose);
}
