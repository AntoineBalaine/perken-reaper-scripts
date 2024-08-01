const std = @import("std");
const UserSettings = @import("userPrefs.zig").UserSettings;
const reaper = @import("../reaper.zig").reaper;
const ctr = @import("c1.zig");
const Mode = ctr.Mode;
const ActionId = ctr.ActionId;
const Btns = ctr.Btns;
const controller = ctr.controller;
const Track = @import("track.zig").Track;

pub const State = @This();

/// State has to be called from control_surface.zig
/// Flow is : main.zig -> register Csurf -> Csurf forwards calls to control_surface.zig -> control_surface updates state
actionIds: std.AutoHashMap(c_int, ActionId),
controller: @TypeOf(controller) = controller,
mode: Mode = .fx_ctrl,
track: ?Track = null,

pub fn init(allocator: std.mem.Allocator) !State {
    var self: State = .{
        .actionIds = std.AutoHashMap(c_int, ActionId).init(allocator),
    };

    errdefer {
        self.actionIds.deinit();
    }
    return self;
}

pub fn deinit(self: *State) void {
    self.actionIds.deinit();
}

pub fn updateTrack(
    self: *State,
    trackid: reaper.MediaTrack,
) void {
    // update track
    // validate channel strip
    // load channel strip

    if (self.track) |*tr| {
        tr.deinit();
    }

    self.track = Track.init();
    // NOTE: track validation is meant to fail silently.

    self.track.?.checkTrackState(
        null,
        trackid,
    ) catch {
        std.debug.print("checkTrackState(): had error\n", .{});
    };
}
