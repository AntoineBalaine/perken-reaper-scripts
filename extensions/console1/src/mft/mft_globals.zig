const reaper = @import("reaper").reaper;
const MftState = @import("mft_state.zig").MftState;

pub const MftGlobals = struct {
    m_midi_in: ?*reaper.midi_Input = null,
    m_midi_out: ?reaper.midi_Output = null,
    m_midi_in_dev: ?c_int = null,
    m_midi_out_dev: ?c_int = null,
    mft: MftState = .{},

    pub var instance: MftGlobals = .{};

    pub fn get() *MftGlobals {
        return &instance;
    }
};
