const std = @import("std");
const UserSettings = @import("userPrefs.zig").UserSettings;
const reaper = @import("../reaper.zig").reaper;
const ctr = @import("c1.zig");
const Mode = ctr.Mode;
const ActionId = ctr.ActionId;
const Btns = ctr.Btns;
const controller = ctr.controller;
const Track = @import("track.zig").Track;

const State = @This();

/// State has to be called from control_surface.zig
/// Flow is : main.zig -> register Csurf -> Csurf forwards calls to control_surface.zig -> control_surface updates state
actionIds: std.AutoHashMap(c_int, ActionId),
controller: std.EnumArray(Mode, Btns) = controller,
mode: Mode = .fx_ctrl,
track: ?Track = null,
user_settings: UserSettings,

pub fn init(allocator: std.mem.Allocator, user_settings: UserSettings) !State {
    var self: State = .{
        .actionIds = std.AutoHashMap(c_int, ActionId).init(allocator),
        .user_settings = user_settings,
    };

    errdefer {
        self.actionIds.deinit();
    }
    return self;
}

pub fn deinit(self: *State) void {
    self.actionIds.deinit();
}

pub fn handleNewTrack(self: *State, trackid: reaper.MediaTrack) void {
    // update track
    // validate channel strip
    // load channel strip

    if (self.track) |tr| {
        tr.deinit();
    }
    self.track = Track.init(trackid);
    @panic("new_track logic not implemented yet");
}

pub fn hookCommand(self: *State, id: c_int) bool {
    const btn_name = self.actionIds.get(id) orelse return false;
    const cur_mode = controller.get(self.mode);
    const callback = cur_mode.get(btn_name);
    if (callback != null) {
        // callback();
        std.debug.print("found action\n", .{});
    } else {
        std.debug.print("UNFOUND action\n", .{});
    }

    return true;
}
