const std = @import("std");
const testing = std.testing;
const c1 = @import("../c1.zig");
const CCs = c1.CCs;
const TrackState = @import("../track_state.zig");
const LabelPool = TrackState.LabelPool;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const statemachine = @import("../statemachine.zig");
const PhysicalModule = statemachine.PhysicalModule;

// Set up a track with 5 FX (one per module), each having 6 params with
// known names and formatted values. Returns the track pointer.
fn setupTrackWithFx(reaper_teardown: anytype, alloc: std.mem.Allocator) !void {
    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const module_configs = [_]struct { param_names: []const [:0]const u8, fmt_values: []const [:0]const u8 }{
        .{ // INPUT (fx_index 0)
            .param_names = &.{ "Input Gain (dB)", "High Cut (Hz)", "Low Cut (Hz)", "p3", "p4", "p5" },
            .fmt_values = &.{ "0.0 dB", "20000 Hz", "20 Hz", "-", "-", "-" },
        },
        .{ // GATE (fx_index 1)
            .param_names = &.{ "Gate Threshold", "Gate Release (ms)", "Punch Amount", "Sustain Level", "Shape On", "Hard Gate" },
            .fmt_values = &.{ "-40.0 dB", "50 ms", "25%", "80%", "On", "Off" },
        },
        .{ // EQ (fx_index 2)
            .param_names = &.{ "Hi Freq (kHz)", "Hi Gain (dB)", "Lo Freq (Hz)", "Lo Gain (dB)", "EQ On", "p5" },
            .fmt_values = &.{ "8.0 kHz", "+3.0 dB", "100 Hz", "-2.0 dB", "On", "-" },
        },
        .{ // COMP (fx_index 3)
            .param_names = &.{ "Attack (ms)", "Ratio", "Threshold (dB)", "Release (ms)", "Dry/Wet", "Comp On" },
            .fmt_values = &.{ "10 ms", "4:1", "-18.0 dB", "100 ms", "100%", "On" },
        },
        .{ // OUTPT (fx_index 4)
            .param_names = &.{ "Drive Amount", "Character", "p2", "p3", "p4", "p5" },
            .fmt_values = &.{ "50%", "Warm", "-", "-", "-", "-" },
        },
    };

    for (module_configs) |config| {
        const params = try alloc.alloc(models.Param, 6);
        for (params, 0..) |*p, i| {
            p.* = .{
                .name = config.param_names[i],
                .normalized_value = 0.5,
                .formatted_value = config.fmt_values[i],
            };
        }
        try track_ptr.fx_list.append(alloc, .{
            .guid = std.mem.zeroes(@import("utils").Guid),
            .enabled = true,
            .params = params,
            .named_configs = .{ .original_name = "Test FX", .renamed_name = "Test FX" },
        });
    }
}

// Set up module locations and populate forward/reverse maps, matching the
// same mapping layout used in fx_ctrl_pbt.
fn setupMapsForTrack(track_state: *TrackState, alloc: std.mem.Allocator) void {
    track_state.mode = .{ .multi_fx = TrackState.ModuleLocations.initFill(null) };
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        const module_idx: c_int = @intCast(@intFromEnum(module));
        track_state.mode.multi_fx.set(module, .{
            .fx_index = module_idx,
            .mapping = switch (module) {
                .INPUT => .{ .INPUT = .{ .Inpt_Gain = 0, .Inpt_HiCut = 1, .Inpt_LoCut = 2 } },
                .GATE => .{ .GATE = .{ .Shp_Gate = 0, .Shp_GateRelease = 1, .Shp_Punch = 2, .Shp_sustain = 3, .Shp_shape = 4, .Shp_hard_gate = 5 } },
                .EQ => .{ .EQ = .{ .Eq_HiFrq = 0, .Eq_HiGain = 1, .Eq_LoFrq = 2, .Eq_LoGain = 3, .Eq_eq = 4 } },
                .COMP => .{ .COMP = .{ .Comp_Attack = 0, .Comp_Ratio = 1, .Comp_Thresh = 2, .Comp_Release = 3, .Comp_DryWet = 4, .Comp_comp = 5 } },
                .OUTPT => .{ .OUTPT = .{ .Out_Drive = 0, .Out_DriveChar = 1 } },
            },
        });
    }

    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        if (track_state.mode.multi_fx.get(module)) |loc| {
            if (loc.mapping) |mapping| {
                TrackState.populateMapsFromMapping(
                    &track_state.reverse_map,
                    &track_state.forward_map,
                    alloc,
                    mapping,
                    loc.fx_index,
                );
            }
        }
    }
}

test "getLabels populates pool from REAPER param names" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    try setupTrackWithFx(&reaper_teardown, alloc);

    var track_state = TrackState{};
    setupMapsForTrack(&track_state, alloc);

    const media_track = reaper.CSurf_TrackFromID(1, false);
    track_state.getLabels(media_track);

    // Verify mapped CCs have REAPER param names
    try testing.expectEqualStrings("Input Gain (dB)", track_state.label_pool.getPrmLabel(.Inpt_Gain));
    try testing.expectEqualStrings("0.0 dB", track_state.label_pool.getFmtValue(.Inpt_Gain));

    try testing.expectEqualStrings("Attack (ms)", track_state.label_pool.getPrmLabel(.Comp_Attack));
    try testing.expectEqualStrings("10 ms", track_state.label_pool.getFmtValue(.Comp_Attack));

    try testing.expectEqualStrings("Threshold (dB)", track_state.label_pool.getPrmLabel(.Comp_Thresh));
    try testing.expectEqualStrings("-18.0 dB", track_state.label_pool.getFmtValue(.Comp_Thresh));

    try testing.expectEqualStrings("Drive Amount", track_state.label_pool.getPrmLabel(.Out_Drive));
    try testing.expectEqualStrings("50%", track_state.label_pool.getFmtValue(.Out_Drive));
}

test "getLabels fills defaults for unmapped CCs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    try setupTrackWithFx(&reaper_teardown, alloc);

    var track_state = TrackState{};
    setupMapsForTrack(&track_state, alloc);

    const media_track = reaper.CSurf_TrackFromID(1, false);
    track_state.getLabels(media_track);

    // Out_Pan and Out_Vol are not in the OUTPT mapping (only Out_Drive and Out_DriveChar are),
    // so they should get "-" defaults.
    try testing.expectEqualStrings("-", track_state.label_pool.getPrmLabel(.Out_Pan));
    try testing.expectEqualStrings("-", track_state.label_pool.getFmtValue(.Out_Pan));

    try testing.expectEqualStrings("-", track_state.label_pool.getPrmLabel(.Out_Vol));
    try testing.expectEqualStrings("-", track_state.label_pool.getFmtValue(.Out_Vol));
}

test "getLabels with empty forward map fills all defaults" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    // No FX on the track, empty forward map
    var track_state = TrackState{};
    const media_track = reaper.CSurf_TrackFromID(1, false);
    track_state.getLabels(media_track);

    // Every assignable CC should have "-" for both label and value
    try testing.expectEqualStrings("-", track_state.label_pool.getPrmLabel(.Comp_Attack));
    try testing.expectEqualStrings("-", track_state.label_pool.getFmtValue(.Comp_Attack));

    try testing.expectEqualStrings("-", track_state.label_pool.getPrmLabel(.Eq_HiFrq));
    try testing.expectEqualStrings("-", track_state.label_pool.getFmtValue(.Eq_HiFrq));

    try testing.expectEqualStrings("-", track_state.label_pool.getPrmLabel(.Inpt_Gain));
    try testing.expectEqualStrings("-", track_state.label_pool.getFmtValue(.Inpt_Gain));
}

test "pool/forward map consistency: mapped CCs have real names, unmapped have defaults" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    try setupTrackWithFx(&reaper_teardown, alloc);

    var track_state = TrackState{};
    setupMapsForTrack(&track_state, alloc);

    const media_track = reaper.CSurf_TrackFromID(1, false);
    track_state.getLabels(media_track);

    // Verify the property: every assignable CC is either in the forward map (with a
    // real param name) or has "-" as its label.
    inline for (comptime std.enums.values(CCs)) |cc| {
        if (LabelPool.indexOf(cc) != null) {
            const label = track_state.label_pool.getPrmLabel(cc);
            const fmt_val = track_state.label_pool.getFmtValue(cc);
            if (track_state.forward_map.get(cc) != null) {
                // Mapped CC: label should not be "-" because REAPER returned a real name
                try testing.expect(!std.mem.eql(u8, label, "-"));
            } else {
                // Unmapped CC: both label and fmt_val should be "-"
                try testing.expectEqualStrings("-", label);
                try testing.expectEqualStrings("-", fmt_val);
            }
        }
    }
}
