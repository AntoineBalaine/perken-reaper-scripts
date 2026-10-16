/// Global model state
pub var g_session: ?*Session = null;

pub fn setupTestModel(allocator: std.mem.Allocator, trck_count: ?usize, prealloc_tracks: ?usize) struct {
    orig_funcs: Mocks,
    model_ptr: *Session,

    pub fn teardown(self: *@This()) void {
        restoreMockReaperAPI(self.orig_funcs);
    }
} {
    const model = allocator.create(Session) catch @panic("Failed to initialize model");
    model.* = Session.init(
        allocator,
        if (trck_count) |count| count else 0,
        if (prealloc_tracks) |prealloc| prealloc else 4,
    ) catch @panic("Failed to initialize model");
    const origFuncs = setupMockReaperAPI(model);

    return .{
        .orig_funcs = origFuncs,
        .model_ptr = model,
    };
}

// Helper to set the current model for testing
pub fn setCurrentModel(model: *Session) void {
    g_session = model;
}
const Mocks = struct {
    InsertTrackAtIndex: @TypeOf(reaper.InsertTrackAtIndex),
    DeleteTrack: @TypeOf(reaper.DeleteTrack),
    TrackFX_AddByName: @TypeOf(reaper.TrackFX_AddByName),
    TrackFX_Delete: @TypeOf(reaper.TrackFX_Delete),
    TrackFX_GetCount: @TypeOf(reaper.TrackFX_GetCount),
    TrackFX_GetFXName: @TypeOf(reaper.TrackFX_GetFXName),
    TrackFX_GetNamedConfigParm: @TypeOf(reaper.TrackFX_GetNamedConfigParm),
    TrackFX_SetNamedConfigParm: @TypeOf(reaper.TrackFX_SetNamedConfigParm),
    TrackFX_GetFXGUID: @TypeOf(reaper.TrackFX_GetFXGUID),
    TrackFX_CopyToTrack: @TypeOf(reaper.TrackFX_CopyToTrack),
    TrackFX_GetEnabled: @TypeOf(reaper.TrackFX_GetEnabled),
    TrackFX_SetEnabled: @TypeOf(reaper.TrackFX_SetEnabled),
    TrackFX_GetNumParams: @TypeOf(reaper.TrackFX_GetNumParams),
    TrackFX_GetParamName: @TypeOf(reaper.TrackFX_GetParamName),
    TrackFX_GetFormattedParamValue: @TypeOf(reaper.TrackFX_GetFormattedParamValue),
    TrackFX_GetParameterStepSizes: @TypeOf(reaper.TrackFX_GetParameterStepSizes),
    GetNumTracks: @TypeOf(reaper.GetNumTracks),
    CountTracks: @TypeOf(reaper.CountTracks),
    GetTrack: @TypeOf(reaper.GetTrack),
    GetMasterTrack: @TypeOf(reaper.GetMasterTrack),
    GetTrackName: @TypeOf(reaper.GetTrackName),
    SetMediaTrackInfo_Value: @TypeOf(reaper.SetMediaTrackInfo_Value),
    GetMediaTrackInfo_Value: @TypeOf(reaper.GetMediaTrackInfo_Value),
    SetTrackSelected: @TypeOf(reaper.SetTrackSelected),
    GetSelectedTrack: @TypeOf(reaper.GetSelectedTrack),
    TrackFX_GetParamNormalized: @TypeOf(reaper.TrackFX_GetParamNormalized),
    TrackFX_SetParamNormalized: @TypeOf(reaper.TrackFX_SetParamNormalized),
    TrackFX_GetParamEx: @TypeOf(reaper.TrackFX_GetParamEx),
    TrackFX_SetParam: @TypeOf(reaper.TrackFX_SetParam),
    CSurf_TrackFromID: @TypeOf(reaper.CSurf_TrackFromID),
    CSurf_TrackToID: @TypeOf(reaper.CSurf_TrackToID),
    // Transport-related mocks
    Main_OnCommand: @TypeOf(reaper.Main_OnCommand),
    CSurf_OnPlay: @TypeOf(reaper.CSurf_OnPlay),
    CSurf_OnRecord: @TypeOf(reaper.CSurf_OnRecord),
    CSurf_OnStop: @TypeOf(reaper.CSurf_OnStop),
    CSurf_OnRewFwd: @TypeOf(reaper.CSurf_OnRewFwd),
    CSurf_OnZoom: @TypeOf(reaper.CSurf_OnZoom),
    CSurf_OnPlayRateChange: @TypeOf(reaper.CSurf_OnPlayRateChange),
    CSurf_OnRecArmChange: @TypeOf(reaper.CSurf_OnRecArmChange),
    GetToggleCommandState: @TypeOf(reaper.GetToggleCommandState),
    SetAutomationMode: @TypeOf(reaper.SetAutomationMode),
    PreventUIRefresh: @TypeOf(reaper.PreventUIRefresh),
    GetCursorPosition: @TypeOf(reaper.GetCursorPosition),
    SetEditCurPos: @TypeOf(reaper.SetEditCurPos),
    GetSetProjectGrid: @TypeOf(reaper.GetSetProjectGrid),
    CountTempoTimeSigMarkers: @TypeOf(reaper.CountTempoTimeSigMarkers),
    FindTempoTimeSigMarker: @TypeOf(reaper.FindTempoTimeSigMarker),
    GetTempoTimeSigMarker: @TypeOf(reaper.GetTempoTimeSigMarker),
    Master_GetTempo: @TypeOf(reaper.Master_GetTempo),
    Master_GetPlayRate: @TypeOf(reaper.Master_GetPlayRate),
    Master_NormalizePlayRate: @TypeOf(reaper.Master_NormalizePlayRate),
    SnapToGrid: @TypeOf(reaper.SnapToGrid),
    NamedCommandLookup: @TypeOf(reaper.NamedCommandLookup),
    TimeMap_curFrameRate: @TypeOf(reaper.TimeMap_curFrameRate),
    TrackFX_Show: @TypeOf(reaper.TrackFX_Show),
    // FX control panel_input special CC mocks
    CSurf_OnMuteChange: @TypeOf(reaper.CSurf_OnMuteChange),
    CSurf_OnSoloChange: @TypeOf(reaper.CSurf_OnSoloChange),
    CSurf_OnVolumeChange: @TypeOf(reaper.CSurf_OnVolumeChange),
    CSurf_OnPanChange: @TypeOf(reaper.CSurf_OnPanChange),
    CSurf_SetSurfaceMute: @TypeOf(reaper.CSurf_SetSurfaceMute),
    CSurf_SetSurfaceSolo: @TypeOf(reaper.CSurf_SetSurfaceSolo),
    CSurf_SetSurfaceVolume: @TypeOf(reaper.CSurf_SetSurfaceVolume),
    CSurf_SetSurfacePan: @TypeOf(reaper.CSurf_SetSurfacePan),
    SetMixerScroll: @TypeOf(reaper.SetMixerScroll),
    TrackList_AdjustWindows: @TypeOf(reaper.TrackList_AdjustWindows),
    TrackFX_GetParamFromIdent: @TypeOf(reaper.TrackFX_GetParamFromIdent),
    GetResourcePath: @TypeOf(reaper.GetResourcePath),
};

// Helper functions to set up and tear down the mock API
pub fn setupMockReaperAPI(model: *Session) Mocks {
    setCurrentModel(model);

    // Create a Mocks struct to store original functions
    var origFuncs: Mocks = undefined;

    inline for (std.meta.fields(Mocks)) |field| {
        const name = field.name;
        // Store the original function
        @field(origFuncs, name) = @field(reaper, name);

        if (@hasDecl(@This(), name)) {
            @constCast(&@field(reaper, name)).* = @constCast(&@field(@This(), name));
        } else {
            @compileError("No mock implementation found for " ++ name);
        }
    }

    return origFuncs;
}

pub fn restoreMockReaperAPI(origFuncs: anytype) void {
    inline for (std.meta.fields(Mocks)) |field| {
        const name = field.name;
        @constCast(&@field(reaper, name)).* = @constCast(&@field(origFuncs, name)).*;
    }

    g_session = null;
}

/// Generic setup: given a custom MockSet struct and a type with mock function
/// declarations, saves the current reaper API pointers and replaces them with
/// the mocks. The caller restores them with restoreGenericMockAPI.
pub fn setupGenericMockAPI(comptime MockSet: type, comptime mock_source: type) MockSet {
    var originals: MockSet = undefined;
    inline for (std.meta.fields(MockSet)) |field| {
        const name = field.name;
        @field(originals, name) = @field(reaper, name);
        if (@hasDecl(mock_source, name)) {
            @constCast(&@field(reaper, name)).* = @constCast(&@field(mock_source, name));
        } else {
            @compileError("No mock implementation found for " ++ name);
        }
    }
    return originals;
}

/// Generic restore: given original function pointers saved by setupGenericMockAPI,
/// restores them back onto the reaper API.
pub fn restoreGenericMockAPI(comptime MockSet: type, originals: MockSet) void {
    inline for (std.meta.fields(MockSet)) |field| {
        const name = field.name;
        @constCast(&@field(reaper, name)).* = @field(originals, name);
    }
}

// Mock REAPER API functions with the same signatures as the real API
fn InsertTrackAtIndex(idx: c_int, wantDefaults: bool) callconv(.C) void {
    _ = wantDefaults;
    const model = g_session.?;
    const gpa = model.arena_alloc;

    // Determine the actual index in our tracks array (accounting for master track at index 0)
    const actual_idx = if (idx < 0) model.tracks.items.len else @as(usize, @intCast(idx)) + 1;

    const track: Track = .default;

    if (actual_idx >= model.tracks.items.len) {
        // Append to the end
        model.tracks.append(gpa, track) catch return;
    } else {
        // Insert at the specified position
        model.tracks.insert(gpa, actual_idx, track) catch return;
    }
}

// Mock FX manipulation functions
// NOTE: there is the case in which we try to add an fx which
// doesn't exist on the user's system, in which case reaper returns -1
// TODO: implement model fx library
fn TrackFX_AddByName(track: reaper.MediaTrack, fxname: [*:0]const u8, recFX: bool, instantiate: c_int) callconv(.C) c_int {
    _ = recFX;
    const session = g_session.?;

    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    const arena_alloc = session.arena_alloc;
    const fx_name = std.mem.span(fxname);

    var guid: Guid = .{ .bytes = undefined };
    std.crypto.random.bytes(&guid.bytes);

    // Create a new FX
    const name = arena_alloc.dupeZ(u8, fx_name) catch return -1;
    const new_fx = FX{
        .guid = guid,
        .enabled = true,
        .params = &[_]Param{},
        .named_configs = .{
            .renamed_name = name,
            .original_name = name,
        },
    };
    var tr: *Track = track_ptr.?;

    // Determine insertion position from the instantiate parameter.
    // REAPER convention: -1 = always add at end, < -999 = insert at position -(instantiate + 1000)
    const insert_pos: usize = if (instantiate == -1)
        tr.fx_list.items.len
    else if (instantiate < -999)
        @intCast(-(instantiate + 1000))
    else
        tr.fx_list.items.len;

    tr.fx_list.insert(arena_alloc, insert_pos, new_fx) catch return -1;

    return @intCast(insert_pos);
}

fn TrackFX_Delete(track: reaper.MediaTrack, fx: c_int) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *Track = track_ptr.?;
    const idx: usize = @intCast(fx);
    if (idx >= tr.fx_list.items.len) return false;

    _ = tr.fx_list.orderedRemove(idx);
    return true;
}

fn TrackFX_GetCount(track: reaper.MediaTrack) callconv(.C) c_int {
    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    // Access the track's fx_list directly
    const tr: *const Track = track_ptr.?;
    return @intCast(tr.fx_list.items.len);
}

fn TrackFX_GetFXName(track: reaper.MediaTrack, fx: c_int, bufOut: [*:0]u8, bufOut_sz: c_int) callconv(.C) bool {
    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    // Access the track's fx_list directly
    const tr: *const Track = track_ptr.?;

    // Check if FX index is valid
    if (fx < 0 or fx >= tr.fx_list.items.len) return false;

    // Copy the FX name to the buffer
    const name = tr.fx_list.items[@intCast(fx)].named_configs.renamed_name;
    const len = @min(@as(usize, @intCast(bufOut_sz)) - 1, name.len);
    @memcpy(bufOut[0..len], name[0..len]);
    bufOut[len] = 0; // Null terminate
    return true;
}

fn TrackFX_GetNamedConfigParm(track: reaper.MediaTrack, fx: c_int, parmname: [*:0]const u8, bufOut: [*:0]u8, bufOut_sz: c_int) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *const Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) return false;

    const param_name = std.mem.span(parmname);
    const fx_item = tr.fx_list.items[@intCast(fx)];

    if (std.mem.eql(u8, param_name, "parallel")) {
        bufOut[0] = '0' + fx_item.named_configs.parallel;
        bufOut[1] = 0;
        return true;
    }

    const name = if (std.mem.eql(u8, param_name, "renamed_name"))
        fx_item.named_configs.renamed_name
    else if (std.mem.eql(u8, param_name, "original_name"))
        fx_item.named_configs.original_name
    else if (std.mem.eql(u8, param_name, "fx_type"))
        fx_item.named_configs.fx_type
    else
        return false;

    const len = @min(@as(usize, @intCast(bufOut_sz)) - 1, name.len);
    @memcpy(bufOut[0..len], name[0..len]);
    bufOut[len] = 0;
    return true;
}

fn TrackFX_SetNamedConfigParm(track: reaper.MediaTrack, fx: c_int, parmname: [*:0]const u8, value: [*:0]const u8) callconv(.C) bool {
    const session = g_session.?;
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) return false;

    const param_name = std.mem.span(parmname);
    const new_value = std.mem.span(value);
    const fx_item = &tr.fx_list.items[@intCast(fx)];

    const gpa = session.arena_alloc;

    if (std.mem.eql(u8, param_name, "renamed_name")) {
        fx_item.named_configs.renamed_name = gpa.dupeZ(u8, new_value) catch return false;
        return true;
    } else if (std.mem.eql(u8, param_name, "original_name")) {
        const old_original = fx_item.named_configs.original_name;
        fx_item.named_configs.original_name = gpa.dupeZ(u8, new_value) catch return false;

        // If renamed_name was pointing to old original_name, update it too
        if (@intFromPtr(fx_item.named_configs.renamed_name.ptr) == @intFromPtr(old_original.ptr)) {
            fx_item.named_configs.renamed_name = fx_item.named_configs.original_name;
        }

        return true;
    }

    return false;
}

fn TrackFX_GetFXGUID(track: reaper.MediaTrack, fx: c_int) callconv(.C) *reaper.GUID {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) @panic("Invalid track pointer");

    const tr: *Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) @panic("Invalid FX index");

    const fx_item = &tr.fx_list.items[@intCast(fx)];
    return @ptrCast(@alignCast(&fx_item.guid.bytes));
}

fn TrackFX_CopyToTrack(source_track: reaper.MediaTrack, source_fx: c_int, dest_track: reaper.MediaTrack, dest_fx: c_int, is_move: bool) callconv(.C) void {
    const session = g_session.?;
    const src_ptr: ?*Track = @ptrCast(@alignCast(source_track));
    const dst_ptr: ?*Track = @ptrCast(@alignCast(dest_track));

    if (src_ptr == null or dst_ptr == null) return;
    if (source_fx < 0 or source_fx >= src_ptr.?.fx_list.items.len) return;

    const gpa = session.arena_alloc;
    const src = src_ptr.?;
    const dst = dst_ptr.?;

    if (is_move) {
        // REAPER's TrackFX_CopyToTrack destination is the final position after
        // the move. We remove first, then insert at dest_fx.
        const removed_fx = src.fx_list.orderedRemove(@intCast(source_fx));
        dst.fx_list.insert(gpa, @intCast(dest_fx), removed_fx) catch return;
    } else {
        // Copy: clone the FX and insert at destination
        // Note: This requires deep copying all strings and params
        // For now, we'll implement move only since that's what track validation uses
        unreachable;
    }
}

fn TrackFX_GetEnabled(track: reaper.MediaTrack, fx: c_int) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *const Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) return false;

    const fx_item = tr.fx_list.items[@intCast(fx)];
    return fx_item.enabled;
}

fn TrackFX_SetEnabled(track: reaper.MediaTrack, fx: c_int, enabled: bool) callconv(.C) void {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return;

    const tr: *Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) return;

    tr.fx_list.items[@intCast(fx)].enabled = enabled;
}

fn TrackFX_GetNumParams(track: reaper.MediaTrack, fx_idx: c_int) callconv(.C) c_int {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return 0;

    const tr: *const Track = track_ptr.?;

    if (fx_idx < 0 or fx_idx >= tr.fx_list.items.len) return 0;

    const fx = tr.fx_list.items[@intCast(fx_idx)];
    return @intCast(fx.params.len);
}

fn TrackFX_GetParamName(track: reaper.MediaTrack, fx_idx: c_int, param_idx: c_int, buf_out: [*:0]const u8, buf_size: c_int) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *const Track = track_ptr.?;

    if (fx_idx < 0 or fx_idx >= tr.fx_list.items.len) return false;
    const fx = tr.fx_list.items[@intCast(fx_idx)];

    if (param_idx < 0 or param_idx >= fx.params.len) return false;
    const param = fx.params[@intCast(param_idx)];

    // Cast away const since we need to write to the buffer
    const buf: [*:0]u8 = @constCast(buf_out);
    const name_len = @min(param.name.len, @as(usize, @intCast(buf_size)) - 1);
    @memcpy(buf[0..name_len], param.name[0..name_len]);
    buf[name_len] = 0;
    return true;
}

fn TrackFX_GetFormattedParamValue(track: reaper.MediaTrack, fx_idx: c_int, param_idx: c_int, buf_out: [*:0]u8, buf_size: c_int) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *const Track = track_ptr.?;

    if (fx_idx < 0 or fx_idx >= tr.fx_list.items.len) return false;
    const fx = tr.fx_list.items[@intCast(fx_idx)];

    if (param_idx < 0 or param_idx >= fx.params.len) return false;
    const param = fx.params[@intCast(param_idx)];

    const val_len = @min(param.formatted_value.len, @as(usize, @intCast(buf_size)) - 1);
    @memcpy(buf_out[0..val_len], param.formatted_value[0..val_len]);
    buf_out[val_len] = 0;
    return true;
}

fn TrackFX_GetParameterStepSizes(track: reaper.MediaTrack, fx_idx: c_int, param_idx: c_int, step_out: *f64, small_step_out: *f64, large_step_out: *f64, is_toggle_out: *bool) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *const Track = track_ptr.?;

    if (fx_idx < 0 or fx_idx >= tr.fx_list.items.len) return false;
    const fx = tr.fx_list.items[@intCast(fx_idx)];

    if (param_idx < 0 or param_idx >= fx.params.len) return false;
    const p = fx.params[@intCast(param_idx)];

    step_out.* = p.step_size;
    small_step_out.* = 0.0;
    large_step_out.* = 0.0;
    is_toggle_out.* = p.is_toggle;
    return true;
}

fn TrackFX_GetParamNormalized(track: reaper.MediaTrack, fx: c_int, param: c_int) callconv(.C) f64 {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1.0;

    const tr: *const Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) return -1.0;
    const fx_item = tr.fx_list.items[@intCast(fx)];

    if (param < 0 or param >= fx_item.params.len) return -1.0;
    return fx_item.params[@intCast(param)].normalized_value;
}

fn TrackFX_SetParamNormalized(track: reaper.MediaTrack, fx: c_int, param: c_int, value: f64) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *Track = track_ptr.?;

    if (fx < 0 or fx >= tr.fx_list.items.len) return false;
    var fx_item = &tr.fx_list.items[@intCast(fx)];

    if (param < 0 or param >= fx_item.params.len) return false;
    fx_item.params[@intCast(param)].normalized_value = value;
    return true;
}

fn TrackFX_GetParamEx(track: reaper.MediaTrack, fx_idx: c_int, param_idx: c_int, min_out: *f64, max_out: *f64, mid_out: *f64) callconv(.C) f64 {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return 0.0;

    const tr: *const Track = track_ptr.?;

    if (fx_idx < 0 or fx_idx >= tr.fx_list.items.len) return 0.0;
    const fx = tr.fx_list.items[@intCast(fx_idx)];

    if (param_idx < 0 or param_idx >= fx.params.len) return 0.0;
    const p = fx.params[@intCast(param_idx)];

    min_out.* = p.min_val;
    max_out.* = p.max_val;
    mid_out.* = (p.min_val + p.max_val) / 2.0;
    // Return the current value in native range
    return p.normalized_value * (p.max_val - p.min_val) + p.min_val;
}

fn TrackFX_SetParam(track: reaper.MediaTrack, fx_idx: c_int, param_idx: c_int, val: f64) callconv(.C) bool {
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    const tr: *Track = track_ptr.?;

    if (fx_idx < 0 or fx_idx >= tr.fx_list.items.len) return false;
    var fx_item = &tr.fx_list.items[@intCast(fx_idx)];

    if (param_idx < 0 or param_idx >= fx_item.params.len) return false;
    const p = &fx_item.params[@intCast(param_idx)];
    const range = p.max_val - p.min_val;
    if (range == 0.0) return false;
    p.normalized_value = (val - p.min_val) / range;
    return true;
}

fn CSurf_TrackFromID(idx: c_int, mcpView: bool) callconv(.C) MediaTrack {
    _ = mcpView;
    const session = g_session.?;
    if (idx < 0 or idx >= session.tracks.items.len) return null;
    return @ptrCast(&session.tracks.items[@intCast(idx)]);
}

// Transport and control surface no-op/default mocks.
// These exist so that transport_actions and fx_ctrl panel_input special CCs
// can execute without crashing. They do not simulate REAPER behavior.
fn Main_OnCommand(command: c_int, flag: c_int) callconv(.C) void {
    _ = command;
    _ = flag;
}
fn CSurf_OnPlay() callconv(.C) void {}
fn CSurf_OnRecord() callconv(.C) void {}
fn CSurf_OnStop() callconv(.C) void {}
fn CSurf_OnRewFwd(seekplay: c_int, dir: c_int) callconv(.C) void {
    _ = seekplay;
    _ = dir;
}
fn CSurf_OnZoom(xdir: c_int, ydir: c_int) callconv(.C) void {
    _ = xdir;
    _ = ydir;
}
fn CSurf_OnPlayRateChange(playrate: f64) callconv(.C) void {
    _ = playrate;
}
fn CSurf_OnRecArmChange(trackid: MediaTrack, recarm: c_int) callconv(.C) bool {
    _ = trackid;
    _ = recarm;
    return true;
}
fn GetToggleCommandState(command_id: c_int) callconv(.C) c_int {
    _ = command_id;
    return 0;
}
fn SetAutomationMode(mode: c_int, onlySel: bool) callconv(.C) void {
    _ = mode;
    _ = onlySel;
}
fn PreventUIRefresh(prevent_count: c_int) callconv(.C) void {
    _ = prevent_count;
}
fn GetCursorPosition() callconv(.C) f64 {
    return g_session.?.cursor_position;
}
fn SetEditCurPos(time: f64, moveview: bool, seekplay: bool) callconv(.C) void {
    _ = moveview;
    _ = seekplay;
    g_session.?.cursor_position = time;
}
fn GetSetProjectGrid(project: ReaProject, set: bool, divisionInOutOptional: ?*f64, swingmodeInOutOptional: ?*c_int, swingamtInOutOptional: ?*f64) callconv(.C) c_int {
    _ = project;
    _ = set;
    if (divisionInOutOptional) |d| d.* = 0.25; // quarter note
    if (swingmodeInOutOptional) |s| s.* = 0;
    if (swingamtInOutOptional) |s| s.* = 0.0;
    return 0;
}
fn CountTempoTimeSigMarkers(proj: ReaProject) callconv(.C) c_int {
    _ = proj;
    return 0;
}
fn FindTempoTimeSigMarker(project: ReaProject, time: f64) callconv(.C) c_int {
    _ = project;
    _ = time;
    return 0;
}
fn GetTempoTimeSigMarker(proj: ReaProject, ptidx: c_int, timeposOut: *f64, measureposOut: *c_int, beatposOut: *f64, bpmOut: *f64, timesig_numOut: *c_int, timesig_denomOut: *c_int, lineartempoOut: *bool) callconv(.C) bool {
    _ = proj;
    _ = ptidx;
    timeposOut.* = 0.0;
    measureposOut.* = 0;
    beatposOut.* = 0.0;
    bpmOut.* = 120.0;
    timesig_numOut.* = 4;
    timesig_denomOut.* = 4;
    lineartempoOut.* = false;
    return true;
}
fn Master_GetTempo() callconv(.C) f64 {
    return 120.0;
}
fn Master_GetPlayRate(project: ReaProject) callconv(.C) f64 {
    _ = project;
    return 1.0;
}
fn Master_NormalizePlayRate(playrate: f64, isnormalized: bool) callconv(.C) f64 {
    _ = isnormalized;
    return playrate;
}
fn SnapToGrid(project: ReaProject, time_pos: f64) callconv(.C) f64 {
    _ = project;
    return time_pos;
}
fn NamedCommandLookup(command_name: [*:0]const u8) callconv(.C) c_int {
    _ = command_name;
    return 0;
}
fn TimeMap_curFrameRate(proj: ReaProject, dropFrameOut: *bool) callconv(.C) f64 {
    _ = proj;
    dropFrameOut.* = false;
    return 30.0;
}
fn TrackFX_Show(track: MediaTrack, index: c_int, showFlag: c_int) callconv(.C) void {
    _ = track;
    _ = index;
    _ = showFlag;
}
fn CSurf_OnMuteChange(trackid: MediaTrack, mute: c_int) callconv(.C) bool {
    _ = trackid;
    _ = mute;
    return true;
}
fn CSurf_OnSoloChange(trackid: MediaTrack, solo: c_int) callconv(.C) bool {
    _ = trackid;
    _ = solo;
    return true;
}
fn CSurf_OnVolumeChange(trackid: MediaTrack, volume: f64, relative: bool) callconv(.C) f64 {
    _ = trackid;
    _ = relative;
    return volume;
}
fn CSurf_OnPanChange(trackid: MediaTrack, pan: f64, relative: bool) callconv(.C) f64 {
    _ = trackid;
    _ = relative;
    return pan;
}
fn CSurf_SetSurfaceMute(trackid: MediaTrack, mute: bool, ignoresurf: ?reaper.IReaperControlSurface) callconv(.C) void {
    _ = trackid;
    _ = mute;
    _ = ignoresurf;
}
fn CSurf_SetSurfaceSolo(trackid: MediaTrack, solo: bool, ignoresurf: ?reaper.IReaperControlSurface) callconv(.C) void {
    _ = trackid;
    _ = solo;
    _ = ignoresurf;
}
fn CSurf_SetSurfaceVolume(trackid: MediaTrack, volume: f64, ignoresurf: ?reaper.IReaperControlSurface) callconv(.C) void {
    _ = trackid;
    _ = volume;
    _ = ignoresurf;
}
fn CSurf_SetSurfacePan(trackid: MediaTrack, pan: f64, ignoresurf: ?reaper.IReaperControlSurface) callconv(.C) void {
    _ = trackid;
    _ = pan;
    _ = ignoresurf;
}
fn SetMixerScroll(leftmosttrack: reaper.MediaTrack) callconv(.C) *reaper.MediaTrack {
    _ = leftmosttrack;
    return @constCast(&@as(reaper.MediaTrack, null));
}
fn TrackList_AdjustWindows(isMinor: bool) callconv(.C) void {
    _ = isMinor;
}

fn TrackFX_GetParamFromIdent(_: MediaTrack, _: c_int, _: [*:0]const u8) callconv(.C) c_int {
    return -1;
}

pub var resource_path: [:0]const u8 = "";

fn GetResourcePath() callconv(.C) [*:0]const u8 {
    return resource_path.ptr;
}

fn CSurf_TrackToID(track: MediaTrack, mcpView: bool) callconv(.C) c_int {
    _ = mcpView;
    const session = g_session.?;
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    for (session.tracks.items, 0..) |*t, i| {
        if (t == track_ptr.?) return @intCast(i);
    }
    return -1;
}

fn DeleteTrack(tr: reaper.MediaTrack) callconv(.C) void {
    const model = g_session.?;

    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(tr));
    if (track_ptr == null) return;

    // We still need to find the track index for deletion and updating selected tracks
    var track_idx: ?usize = null;
    for (model.tracks.items, 0..) |*t, i| {
        if (t == track_ptr.?) {
            track_idx = i;
            break;
        }
    }

    if (track_idx == null) return;

    // Don't allow deleting the master track
    if (track_idx.? == 0) return;

    // Remove the track
    _ = model.tracks.orderedRemove(track_idx.?);

    // Update selected track indices
    var i: usize = 0;
    while (i < model.selected_tracks.items.len) {
        if (model.selected_tracks.items[i] == track_idx.?) {
            _ = model.selected_tracks.orderedRemove(i);
        } else if (model.selected_tracks.items[i] > track_idx.?) {
            model.selected_tracks.items[i] -= 1;
            i += 1;
        } else {
            i += 1;
        }
    }

    // Update last touched track index if needed
    if (model.last_touched_track_index) |*last_touched| {
        if (last_touched.* == track_idx.?) {
            model.last_touched_track_index = null;
        } else if (last_touched.* > track_idx.?) {
            last_touched.* -= 1;
        }
    }
}

// Mock REAPER API functions
fn GetNumTracks() callconv(.C) c_int {
    return @intCast(g_session.?.tracks.items.len - 1); // Don't count master track
}

fn CountTracks(project: ReaProject) callconv(.C) c_int {
    _ = project;
    return @intCast(g_session.?.tracks.items.len); // Count all tracks including master
}

fn GetTrack(project: ReaProject, trackidx: c_int) callconv(.C) MediaTrack {
    _ = project;
    if (trackidx < 0 or trackidx >= g_session.?.tracks.items.len - 1) return null;
    const track = &g_session.?.tracks.items[@as(usize, @intCast(trackidx)) + 1];
    return @ptrCast(track);
}

fn GetMasterTrack(project: ReaProject) callconv(.C) MediaTrack {
    _ = project;
    const track = &g_session.?.tracks.items[0];
    return @ptrCast(track);
}

fn GetTrackName(tr: MediaTrack, buf: [*:0]u8, bufsz: c_int) callconv(.C) bool {
    var track: ?*Track = @ptrCast(@alignCast(tr));
    _ = &track;
    if (track == null or bufsz <= 0) return false;
    const name = g_session.?.getTrackName(track.?.*);
    if (name == null) return false;
    const len = @min(@as(usize, @intCast(bufsz)) - 1, name.?.len);
    @memcpy(buf[0..len], name.?[0..len]);
    buf[len] = 0; // Null terminate
    return true;
}

fn SetMediaTrackInfo_Value(tr: MediaTrack, parmname: [*:0]const u8, newvalue: f64) callconv(.C) bool {
    var track: ?*Track = @ptrCast(@alignCast(tr));
    _ = &track;
    if (track == null) return false;

    const param = std.mem.span(parmname);
    if (std.mem.eql(u8, param, "D_VOL")) {
        track.?.info.volume = newvalue;
        return true;
    } else if (std.mem.eql(u8, param, "D_PAN")) {
        track.?.info.pan = newvalue;
        return true;
    } else if (std.mem.eql(u8, param, "B_MUTE")) {
        track.?.info.mute = newvalue > 0.5;
        return true;
    } else if (std.mem.eql(u8, param, "I_SOLO")) {
        track.?.info.solo = @intFromFloat(newvalue);
        return true;
    } else if (std.mem.eql(u8, param, "B_PHASE")) {
        track.?.info.phase = newvalue > 0.5;
        return true;
    } else if (std.mem.eql(u8, param, "I_FXEN")) {
        track.?.info.fx_enabled = newvalue > 0.5;
        return true;
    } else if (std.mem.eql(u8, param, "I_AUTOMODE")) {
        track.?.automation_mode = @enumFromInt(@as(c_int, @intFromFloat(newvalue)));
        return true;
    }

    return false;
}

fn GetMediaTrackInfo_Value(tr: MediaTrack, parmname: [*:0]const u8) callconv(.C) f64 {
    var track: ?*Track = @ptrCast(@alignCast(tr));
    _ = &track;
    if (track == null) return 0;

    const param = std.mem.span(parmname);
    if (std.mem.eql(u8, param, "D_VOL")) {
        return track.?.info.volume;
    } else if (std.mem.eql(u8, param, "D_PAN")) {
        return track.?.info.pan;
    } else if (std.mem.eql(u8, param, "B_MUTE")) {
        return if (track.?.info.mute) 1.0 else 0.0;
    } else if (std.mem.eql(u8, param, "I_SOLO")) {
        return @floatFromInt(track.?.info.solo);
    } else if (std.mem.eql(u8, param, "B_PHASE")) {
        return if (track.?.info.phase) 1.0 else 0.0;
    } else if (std.mem.eql(u8, param, "I_FXEN")) {
        return if (track.?.info.fx_enabled) 1.0 else 0.0;
    } else if (std.mem.eql(u8, param, "I_AUTOMODE")) {
        return @floatFromInt(@intFromEnum(track.?.automation_mode));
    }

    return 0;
}

fn SetTrackSelected(tr: MediaTrack, selected: bool) callconv(.C) void {
    var track: ?*Track = @ptrCast(@alignCast(tr));
    _ = &track;
    if (track == null) return;

    // Find track index
    const track_ptr: *const Track = track.?;
    for (g_session.?.tracks.items, 0..) |*t, i| {
        if (t == track_ptr) {
            if (selected) {
                // Check if already selected
                for (g_session.?.selected_tracks.items) |idx| {
                    if (idx == i) return;
                }
                g_session.?.selected_tracks.append(g_session.?.arena_alloc, @intCast(i)) catch return;
            } else {
                // Remove from selection if present
                var j: usize = 0;
                while (j < g_session.?.selected_tracks.items.len) {
                    if (g_session.?.selected_tracks.items[j] == i) {
                        _ = g_session.?.selected_tracks.orderedRemove(j);
                    } else {
                        j += 1;
                    }
                }
            }
            return;
        }
    }
}

fn GetSelectedTrack(proj: ReaProject, seltrackidx: c_int) callconv(.C) MediaTrack {
    _ = proj;
    if (seltrackidx < 0 or seltrackidx >= g_session.?.selected_tracks.items.len) return null;

    const track_idx = g_session.?.selected_tracks.items[@intCast(seltrackidx)];
    const track = &g_session.?.tracks.items[track_idx];
    return @ptrCast(track);
}

test "track creation and deletion with mock API" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var test_ctx = setupTestModel(arena.allocator(), 3, 4);
    defer test_ctx.teardown();

    // Initial track count
    try testing.expectEqual(@as(c_int, 4), reaper.CountTracks(0)); // 3 regular + master

    // Test track creation
    reaper.InsertTrackAtIndex(1, true);
    try testing.expectEqual(@as(c_int, 5), reaper.CountTracks(0)); // 4 regular + master

    // Get the newly created track
    const new_track = @as(?*Track, @ptrCast(@alignCast(reaper.GetTrack(0, 1))));
    try testing.expect(new_track.?.name == null);

    // Test track deletion
    reaper.DeleteTrack(@ptrCast(new_track.?));
    try testing.expectEqual(@as(c_int, 4), reaper.CountTracks(0)); // Back to 3 regular + master

    // Verify track numbering was updated
    for (0..3) |i| {
        const track = @as(?*Track, @ptrCast(@alignCast(reaper.GetTrack(0, @intCast(i)))));
        try testing.expect(track != null);
    }
}

test "fx operations with mock API" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var test_ctx = setupTestModel(arena.allocator(), 3, 4);
    defer test_ctx.teardown();

    // Get a track to work with
    const track = @as(?*Track, @ptrCast(@alignCast(GetTrack(0, 0))));
    try testing.expect(track != null);

    // Initially no FX
    try testing.expectEqual(@as(c_int, 0), reaper.TrackFX_GetCount(@ptrCast(track.?)));

    // Add an FX
    const fx_idx = reaper.TrackFX_AddByName(@ptrCast(track.?), "ReaEQ", false, 0);
    try testing.expectEqual(@as(c_int, 0), fx_idx); // First FX should be at index 0
    try testing.expectEqual(@as(c_int, 1), reaper.TrackFX_GetCount(@ptrCast(track.?)));

    // Add another FX
    const fx_idx2 = reaper.TrackFX_AddByName(@ptrCast(track.?), "ReaComp", false, 0);
    try testing.expectEqual(@as(c_int, 1), fx_idx2); // Second FX should be at index 1
    try testing.expectEqual(@as(c_int, 2), reaper.TrackFX_GetCount(@ptrCast(track.?)));

    // Get FX name
    var buf: [128:0]u8 = undefined;
    const got_name = reaper.TrackFX_GetFXName(@ptrCast(track.?), 0, &buf, buf.len);
    try testing.expect(got_name);
    try testing.expectEqualStrings("ReaEQ", std.mem.span(@as([*:0]const u8, &buf)));

    // Get second FX name
    const got_name2 = reaper.TrackFX_GetFXName(@ptrCast(track.?), 1, &buf, buf.len);
    try testing.expect(got_name2);
    try testing.expectEqualStrings("ReaComp", std.mem.span(@as([*:0]const u8, &buf)));

    // Invalid FX index should return false
    const got_name3 = reaper.TrackFX_GetFXName(@ptrCast(track.?), 2, &buf, buf.len);
    try testing.expect(!got_name3);
}

test "mock reaper API track operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var test_ctx = setupTestModel(arena.allocator(), 3, 4);
    defer test_ctx.teardown();

    const model = g_session.?;

    // Test track count via mock API
    const num_tracks = GetNumTracks();
    try testing.expectEqual(@as(c_int, 3), num_tracks); // Regular tracks only
    const total_tracks = CountTracks(0);
    try testing.expectEqual(@as(c_int, 4), total_tracks); // Including master

    // Test track retrieval via mock API
    const track1 = @as(?*Track, @ptrCast(@alignCast(GetTrack(0, 0))));
    try testing.expect(track1 != null);
    try testing.expectEqualStrings("Track 1", model.string_pool.getString(track1.?.name.?));

    const master = @as(?*Track, @ptrCast(@alignCast(GetMasterTrack(0))));
    try testing.expect(master != null);
    try testing.expectEqualStrings("Master", model.string_pool.getString(master.?.name.?));

    // Test track selection via mock API
    SetTrackSelected(@ptrCast(track1), true);
    try testing.expectEqual(@as(usize, 1), model.selected_tracks.items.len);

    const selected = @as(?*Track, @ptrCast(@alignCast(GetSelectedTrack(0, 0))));
    try testing.expect(selected != null);
    try testing.expectEqualStrings("Track 1", model.string_pool.getString(selected.?.name.?));

    // Test track parameters via mock API
    _ = SetMediaTrackInfo_Value(@ptrCast(track1), "D_VOL", 0.5);
    try testing.expectEqual(@as(f64, 0.5), GetMediaTrackInfo_Value(@ptrCast(track1), "D_VOL"));

    _ = SetMediaTrackInfo_Value(@ptrCast(track1), "B_MUTE", 1.0);
    try testing.expectEqual(@as(f64, 1.0), GetMediaTrackInfo_Value(@ptrCast(track1), "B_MUTE"));

    _ = SetMediaTrackInfo_Value(@ptrCast(track1), "I_SOLO", 1.0);
    try testing.expectEqual(@as(f64, 1.0), GetMediaTrackInfo_Value(@ptrCast(track1), "I_SOLO"));

    // Test track deselection via mock API
    SetTrackSelected(@ptrCast(track1), false);
    try testing.expectEqual(@as(usize, 0), model.selected_tracks.items.len);
}

const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const Guid = @import("utils").Guid;
const fx_model = @import("fx_model");
const Param = fx_model.Param;
const FX = fx_model.FX;
const track_model = @import("track_model");
const Track = track_model.Track;
const Session = @import("session");
const ReaProject = reaper.ReaProject;
const MediaTrack = reaper.MediaTrack;
