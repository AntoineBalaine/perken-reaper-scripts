const std = @import("std");
const reaper = @import("reaper").reaper;
const fs_helpers = @import("fs_helpers");
const MftState = @import("mft_state.zig").MftState;
const MftMapStore = @import("mft_map_store.zig").MftMapStore;
const WizardState = @import("mft_wizard.zig").WizardState;

pub const MftGlobals = struct {
    m_midi_in: ?*reaper.midi_Input = null,
    m_midi_out: ?reaper.midi_Output = null,
    m_midi_in_dev: ?c_int = null,
    m_midi_out_dev: ?c_int = null,
    mft: MftState = .{},

    arena: std.heap.ArenaAllocator = undefined,
    resource_path: [:0]const u8 = "",
    map_store: MftMapStore = undefined,
    // The track whose FX the encoders currently drive. Follows REAPER's
    // last-touched track (see the SETLASTTOUCHEDTRACK csurf callback).
    current_track: reaper.MediaTrack = null,
    wizard: WizardState = .{},

    pub var instance: MftGlobals = .{};

    pub fn get() *MftGlobals {
        return &instance;
    }

    pub fn init(self: *MftGlobals) void {
        self.arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const alloc = self.arena.allocator();

        const reaper_path = std.mem.sliceTo(reaper.GetResourcePath(), 0);
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const joined = fs_helpers.joinStrings(&path_buf, &.{
            reaper_path, std.fs.path.sep_str, "Data", std.fs.path.sep_str, "Perken", std.fs.path.sep_str, "MFT",
        });
        self.resource_path = alloc.dupeZ(u8, joined) catch "";
        self.map_store = MftMapStore.init(alloc, self.resource_path);
    }

    pub fn deinit(self: *MftGlobals) void {
        self.arena.deinit();
    }
};
