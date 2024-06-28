const std = @import("std");
const UserSettings = @import("userPrefs.zig").UserSettings;
const reaper = @import("../reaper.zig").reaper;
const controller = @import("c1.zig");

/// State has to be called from control_surface.zig
/// Flow is : main.zig -> register Csurf -> Csurf forwards calls to control_surface.zig -> control_surface updates state
pub const State = struct {
    actionIds: std.AutoHashMap(u8, []const u8) = undefined,
    controller: @TypeOf(controller.c1) = controller.c1,
    mode: std.meta.FieldEnum(@TypeOf(controller.c1)) = undefined,
    controller_dir: []const u8 = undefined,
    track: ?*reaper.MediaTrack = null,
    user_settings: UserSettings = undefined,

    pub fn init(allocator: std.mem.Allocator, controller_dir: []const u8, user_settings: UserSettings) State {
        var self = State{
            .actionIds = std.AutoHashMap(u8, []const u8).init(allocator),
            .mode = .fx_ctrl,
            .controller_dir = controller_dir,
            .user_settings = user_settings,
        };
        errdefer {
            self.actionIds.deinit();
        }
        self.registerButtonActions(allocator) catch {};
        return self;
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) !void {
        for (self.actionIds.items) |actionId| {
            allocator.free(actionId);
        }
        allocator.free(self.actionIds);
        allocator.free(self);
        self.* = undefined;
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
        var buttons_list = std.ArrayList([]const u8).init(allocator);

        inline for (std.meta.fields(@TypeOf(controller.c1.fx_ctrl))) |ns_info| {
            const name = ns_info.name;
            try buttons_list.append(name);
        }

        for (buttons_list.items) |button_field| {
            const action_id_str = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ "PRKN_", "c1", "_", button_field }, 0);
            const btn_name = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{
                //
                "[c1] [button_press] ", button_field,
            }, 0);
            // PRKN_C1_BtnNumber
            const btn_action = reaper.custom_action_register_t{
                //
                .section = 0,
                .id_str = action_id_str,
                .name = btn_name,
            };
            const action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&btn_action)));
            const cast_id: u8 = @intCast(action_id);
            try self.actionIds.put(cast_id, action_id_str);
        }
        return;
    }

    pub fn hookCommand(self: *State, id: u8) !void {
        const btn_name = self.actionIds.get(id) orelse return;
        const field = @field(self.controller[self.mode], btn_name);
        @call(.auto, field.?, .{});
    }
};
