const std = @import("std");
const types = @import("types.zig");
const reaper = @import("../reaper.zig").reaper;
const controller = @import("controller.zig");

/// State has to be called from control_surface.zig
/// Flow is : main.zig -> register Csurf -> Csurf forwards calls to control_surface.zig -> control_surface updates state
const State = struct {
    project_directory: [*:0]const u8,
    user_settings: types.UserSettings,
    Track: ?types.Track,
    pub fn init(self: *State, project_directory: [*:0]const u8, user_settings: types.UserSettings) *State {
        self.project_directory = project_directory;
        self.user_settings = user_settings;
        // toggle state ON
        reaper.set_action_options(4);
        self.getRealarnInstances();
        // start update loop, query track fx, etc.
        return self;
    }

    pub fn getRealernInstances(self: *State) ?u8 {
        _ = self;
    }

    ///there's 1 realearn instance per module,
    ///so query the three instances
    ///and store them.
    ///@return number|nil index
    pub fn getRealearnInstance() ?u8 {
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
    pub fn handleNewTrack() void {
        // get realearn instances
        // update track
        // validate channel strip
        // load channel strip
        // load matching preset into realearn
    }
};
