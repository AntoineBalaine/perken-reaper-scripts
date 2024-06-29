const std = @import("std");
const UserSettings = @import("userPrefs.zig").UserSettings;
const reaper = @import("../reaper.zig").reaper;
const ctr = @import("c1.zig");
const Mode = ctr.Mode;
const ActionId = ctr.ActionId;
const Btns = ctr.Btns;
const controller = ctr.controller;

/// State has to be called from control_surface.zig
/// Flow is : main.zig -> register Csurf -> Csurf forwards calls to control_surface.zig -> control_surface updates state
pub const State = struct {
    actionIds: std.AutoHashMap(c_int, ActionId) = undefined,
    controller: std.EnumArray(Mode, Btns) = controller,
    mode: Mode = .fx_ctrl,
    controller_dir: []const u8 = undefined,
    track: ?*reaper.MediaTrack = null,
    user_settings: UserSettings = undefined,

    pub fn init(allocator: std.mem.Allocator, controller_dir: []const u8, user_settings: UserSettings) !State {
        var self = State{
            .actionIds = std.AutoHashMap(c_int, ActionId).init(allocator),
            .controller_dir = controller_dir,
            .user_settings = user_settings,
        };
        errdefer {
            self.actionIds.deinit();
        }
        try self.registerButtonActions(allocator);
        return self;
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) !void {
        // var iterator = self.actionIds.iterator();
        // while (iterator.next()) |actionId| {
        //     allocator.free(actionId.value_ptr);
        // }
        allocator.free(self.controller_dir);
        self.actionIds.deinit();
    }

    ///there's 1 realearn instance per module,
    ///so query the three instances
    ///and store them.
    ///@return number|nil index
    fn getRealearnInstance() ?u8 {
        const master = reaper.GetMasterTrack(0);
        const inst = controller.c1;

        for (inst.modules) |module| {
            const idx = reaper.TrackFX_AddByName(master, module, true, 1);
            if (idx == -1) {
                reaper.MB("failed to load realearn instance", "Couldn't load the realearn instance", 2);
                return null;
            }
            if (module.idx == null or module.idx != idx) {
                module.idx = reaper.TrackFX_GetByName(master, module, false);
            }
        }
    }
    pub fn handleNewTrack(self: *State, trackid: *reaper.MediaTrack) void {
        // get realearn instances
        // update track
        // validate channel strip
        // load channel strip
        // load matching preset into realearn
        self.getRealearnInstance();
        self.track = trackid;
    }

    /// register the controller’s buttons as actions in reaper’s actions list
    /// and load them into state.actionIds’ map.
    ///
    /// If the registrations fail, return the error.
    /// It’s expected that the state catch the error, so that the program doesn’t crash.
    fn registerButtonActions(self: *State, allocator: std.mem.Allocator) !void {
        std.debug.print("registering\n", .{});
        for (std.enums.values(ActionId)) |action_id| {
            const btn_name = @tagName(action_id);
            const id_str = try std.fmt.allocPrintZ(allocator, "{s}{s}", .{ "_PRKN_", btn_name });
            defer allocator.free(id_str);
            const name_str = try std.fmt.allocPrintZ(allocator, "{s}{s}", .{ "perken controller: ", btn_name });
            defer allocator.free(name_str);
            const btn_action = reaper.custom_action_register_t{
                //
                .section = 0,
                .id_str = id_str,
                .name = name_str,
            };
            const id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&btn_action)));
            self.actionIds.put(id, action_id) catch {};
        }
        return;
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
};
