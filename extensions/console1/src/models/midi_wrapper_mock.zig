const std = @import("std");
const c1 = @import("../c1.zig");
const C1Model = @import("c1_model.zig");

// Define the types needed for the MIDI wrapper
pub const midi_Input_w = ?*anyopaque;
pub const midi_Output_w = ?*anyopaque;
pub const MIDI_eventlist_w = ?*anyopaque;
pub const MIDI_event_t = extern struct {
    frame_offset: c_int,
    size: c_int,
    midi_message: [3]u8,
};

// Dummy MIDI input/output objects and event list
var dummy_midi_input: u8 = 0;
var dummy_midi_output: u8 = 0;
var dummy_eventlist: u8 = 0;
var dummy_event = MIDI_event_t{
    .frame_offset = 0,
    .size = 3,
    .midi_message = [3]u8{ 0, 0, 0 },
};

// Get or create the C1Model instance
fn getModelInstance() *C1Model {
    if (C1Model.instance == null) {
        C1Model.instance = C1Model.init();
    }
    return &C1Model.instance.?;
}

// Mock implementation of MidiOut_Send - exported with the exact same name as the C function
pub export fn MidiOut_Send(midi_out: midi_Output_w, status: u8, d1: u8, d2: u8, frame_offset: c_int) void {
    std.debug.print("Mock MidiOut_Send called: status={}, d1={}, d2={}\n", .{ status, d1, d2 });
    _ = midi_out;
    _ = frame_offset;

    // Only handle CC messages (status 0xB0)
    if (status == 0xB0) {
        // Try to convert the d1 value to a CCs enum
        for (std.enums.values(c1.CCs)) |cc| {
            if (@intFromEnum(cc) == d1) {
                getModelInstance().updateValue(cc, d2);
                break;
            }
        }
    }
}

// Mock implementation of CreateThreadedMIDIOutput - exported with the exact same name as the C function
pub export fn CreateThreadedMIDIOutput(output: midi_Output_w) midi_Output_w {
    std.debug.print("Mock CreateThreadedMIDIOutput called\n", .{});
    _ = output;
    // Return a dummy pointer that will be used as the midi_out object
    return @as(midi_Output_w, @ptrCast(&dummy_midi_output));
}

// Mock implementation of MidiOut_SendMsg
pub export fn MidiOut_SendMsg(midi_out: midi_Output_w, msg: ?*MIDI_event_t, frame_offset: c_int) void {
    _ = midi_out;
    _ = msg;
    _ = frame_offset;
    // No implementation needed for tests
}

// Mock implementation of MidiOut_BeginBlock
pub export fn MidiOut_BeginBlock(midi_out: midi_Output_w) void {
    _ = midi_out;
    // No implementation needed for tests
}

// Mock implementation of MidiOut_EndBlock
pub export fn MidiOut_EndBlock(midi_out: midi_Output_w, length: c_int, srate: f64, curtempo: f64) void {
    _ = midi_out;
    _ = length;
    _ = srate;
    _ = curtempo;
    // No implementation needed for tests
}

// Mock implementation of MidiOut_Destroy
pub export fn MidiOut_Destroy(midi_out: midi_Output_w) void {
    _ = midi_out;
    // No implementation needed for tests
}

// Mock implementation of MidiIn functions
pub export fn MidiIn_start(midi_in: midi_Input_w) void {
    _ = midi_in;
    // No implementation needed for tests
}

pub export fn MidiIn_stop(midi_in: midi_Input_w) void {
    _ = midi_in;
    // No implementation needed for tests
}

pub export fn MidiIn_SwapBufs(midi_in: midi_Input_w, timestamp: c_uint) void {
    _ = midi_in;
    _ = timestamp;
    // No implementation needed for tests
}

pub export fn MidiIn_GetReadBuf(midi_in: midi_Input_w) MIDI_eventlist_w {
    _ = midi_in;
    // Return a dummy event list
    return @as(MIDI_eventlist_w, @ptrCast(&dummy_eventlist));
}

pub export fn MidiIn_SwapBufsPrecise(midi_in: midi_Input_w, coarsetimestamp: c_uint, precisetimestamp: f64) void {
    _ = midi_in;
    _ = coarsetimestamp;
    _ = precisetimestamp;
    // No implementation needed for tests
}

pub export fn MidiIn_Destroy(midi_in: midi_Input_w) void {
    _ = midi_in;
    // No implementation needed for tests
}

// Mock implementation of MIDI_eventlist functions
pub export fn MDEvtLs_AddItem(mdEvtLs: MIDI_eventlist_w, evt: ?*MIDI_event_t) void {
    _ = mdEvtLs;
    _ = evt;
    // No implementation needed for tests
}

pub export fn MDEvtLs_EnumItems(mdEvtLs: MIDI_eventlist_w, bpos: ?*c_int) ?*MIDI_event_t {
    _ = mdEvtLs;
    if (bpos != null) {
        bpos.?.* = -1; // Indicate no more events
    }
    return null; // Return null to indicate no events
}

pub export fn MDEvtLs_DeleteItem(mdEvtLs: MIDI_eventlist_w, bpos: c_int) void {
    _ = mdEvtLs;
    _ = bpos;
    // No implementation needed for tests
}

pub export fn MDEvtLs_GetSize(mdEvtLs: MIDI_eventlist_w) c_int {
    _ = mdEvtLs;
    return 0; // Return 0 to indicate empty list
}

pub export fn MDEvtLs_Empty(mdEvtLs: MIDI_eventlist_w) void {
    _ = mdEvtLs;
    // No implementation needed for tests
}

pub export fn MIDI_event_size(evt: ?*MIDI_event_t) c_int {
    _ = evt;
    return 3; // Return a fixed size for MIDI events
}

pub export fn MIDI_event_message(evt: ?*MIDI_event_t) ?[*]u8 {
    if (evt == null) return null;
    return &evt.?.midi_message;
}
