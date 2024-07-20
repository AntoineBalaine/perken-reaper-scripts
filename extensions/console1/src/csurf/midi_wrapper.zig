const std = @import("std");
const midi_Input = @import("../reaper.zig").reaper.midi_Input;
const midi_Output = @import("../reaper.zig").reaper.midi_Output;
const MIDI_event_t = @import("../reaper.zig").reaper.MIDI_event_t;
const MIDI_eventlist = @import("../reaper.zig").reaper.MIDI_eventlist;

pub extern fn MidiIn_start(midi_in: midi_Input) void;
pub extern fn MidiIn_stop(midi_in: midi_Input) void;
pub extern fn MidiIn_SwapBufs(midi_in: midi_Input, timestamp: c_uint) void;
pub extern fn MidiIn_GetReadBuf(midi_in: midi_Input) *MIDI_eventlist;
pub extern fn MidiIn_SwapBufsPrecise(midi_in: midi_Input, coarsetimestamp: c_uint, precisetimestamp: f64) void;
pub extern fn MidiIn_Destroy(midi_in: midi_Input) void;

pub extern fn MidiOut_Create() midi_Output;
pub extern fn MidiOut_Destroy(midi_out: midi_Output) void;
pub extern fn MidiOut_BeginBlock(midi_out: midi_Output) void;
pub extern fn MidiOut_EndBlock(midi_out: midi_Output, length: c_int, srate: f64, curtempo: f64) void;
pub extern fn MidiOut_SendMsg(midi_out: midi_Output, msg: *MIDI_event_t, frame_offset: c_int) void;
pub extern fn MidiOut_Send(midi_out: midi_Output, status: u8, d1: u8, d2: u8, frame_offset: c_int) void;
