const std = @import("std");
const testing = std.testing;
const c1 = @import("../c1.zig");
const C1Model = @import("../models/c1_model.zig");
const midi_wrapper_mock = @import("../models/midi_wrapper_mock.zig");

// Test basic C1Model functionality
test "C1Model basic operations" {
    var model: C1Model = .default;

    // Test initial state
    try testing.expectEqual(@as(u8, 0), model.getValue(c1.CCs.Out_Vol));

    // Test updating a knob value
    model.updateValue(c1.CCs.Out_Vol, 64);
    try testing.expectEqual(@as(u8, 64), model.getValue(c1.CCs.Out_Vol));

    // Test updating a button value (should be either 0 or 127)
    model.updateValue(c1.CCs.Out_mute, 1);
    try testing.expectEqual(@as(u8, 127), model.getValue(c1.CCs.Out_mute));

    model.updateValue(c1.CCs.Out_mute, 0);
    try testing.expectEqual(@as(u8, 0), model.getValue(c1.CCs.Out_mute));

    // Test reset
    model.reset();
    try testing.expectEqual(@as(u8, 0), model.getValue(c1.CCs.Out_Vol));
    try testing.expectEqual(@as(u8, 0), model.getValue(c1.CCs.Out_mute));
}

// Test singleton pattern
test "C1Model singleton" {
    // Reset the singleton instance
    if (C1Model.instance != null) {
        C1Model.instance.?.reset();
    } else {
        C1Model.instance = C1Model.init();
    }

    // Get the singleton instance
    var model1 = &C1Model.instance.?;

    // Update a value
    model1.updateValue(c1.CCs.Out_Vol, 100);
    try testing.expectEqual(@as(u8, 100), model1.getValue(c1.CCs.Out_Vol));

    // Get the singleton instance again, should be the same instance
    var model2 = &C1Model.instance.?;
    try testing.expectEqual(@as(u8, 100), model2.getValue(c1.CCs.Out_Vol));

    // Reset the model
    model2.reset();
    try testing.expectEqual(@as(u8, 0), model1.getValue(c1.CCs.Out_Vol));
}

// Test MIDI wrapper mock
test "MIDI wrapper mock" {
    // Reset the singleton instance
    if (C1Model.instance != null) {
        C1Model.instance.?.reset();
    } else {
        C1Model.instance = C1Model.init();
    }
    // _ = midi_wrapper_mock.setupMidiMocks(@import("../reaper.zig").reaper);

    // Create a dummy MIDI output
    const midi_out: midi_wrapper_mock.midi_Output_w = @alignCast(@ptrCast(&midi_wrapper_mock.dummy_midi_output));

    // Test sending MIDI messages through the mock
    midi_wrapper_mock.MidiOut_Send(midi_out, 0xB0, @intFromEnum(c1.CCs.Out_Vol), 100, -1);

    // Verify the model was updated
    try testing.expectEqual(@as(u8, 100), C1Model.instance.?.getValue(c1.CCs.Out_Vol));

    // Test sending a button message
    midi_wrapper_mock.MidiOut_Send(midi_out, 0xB0, @intFromEnum(c1.CCs.Out_mute), 127, -1);

    // Verify the model was updated
    try testing.expectEqual(@as(u8, 127), C1Model.instance.?.getValue(c1.CCs.Out_mute));

    // Test sending a non-CC message (should not update the model)
    C1Model.instance.?.reset();
    midi_wrapper_mock.MidiOut_Send(midi_out, 0x90, @intFromEnum(c1.CCs.Out_Vol), 100, -1);

    // Verify the model was not updated
    try testing.expectEqual(@as(u8, 0), C1Model.instance.?.getValue(c1.CCs.Out_Vol));
}

// Test button validation
test "C1Model button validation" {
    var model = C1Model.init();

    // Test button values (should be either 0 or 127)
    model.updateValue(c1.CCs.Out_mute, 1);
    try testing.expectEqual(@as(u8, 127), model.getValue(c1.CCs.Out_mute));

    model.updateValue(c1.CCs.Out_mute, 50);
    try testing.expectEqual(@as(u8, 127), model.getValue(c1.CCs.Out_mute));

    model.updateValue(c1.CCs.Out_mute, 0);
    try testing.expectEqual(@as(u8, 0), model.getValue(c1.CCs.Out_mute));
}

// Test knob validation
test "C1Model knob validation" {
    var model = C1Model.init();

    // Test knob values (should be clamped to 0-127)
    model.updateValue(c1.CCs.Out_Vol, 64);
    try testing.expectEqual(@as(u8, 64), model.getValue(c1.CCs.Out_Vol));

    model.updateValue(c1.CCs.Out_Vol, 200);
    try testing.expectEqual(@as(u8, 127), model.getValue(c1.CCs.Out_Vol));

    model.updateValue(c1.CCs.Out_Vol, 0);
    try testing.expectEqual(@as(u8, 0), model.getValue(c1.CCs.Out_Vol));
}

// Test CreateThreadedMIDIOutput
// test "CreateThreadedMIDIOutput mock" {
//     // Create a dummy MIDI output
//     var dummy_output: u8 = 0;
//     const midi_out: midi_wrapper_mock.midi_Output_w = @ptrCast(@alignCast(&dummy_output));

//     // Test CreateThreadedMIDIOutput
//     const threaded_output = midi_wrapper_mock.CreateThreadedMIDIOutput(midi_out);

//     // Verify it returns a non-null pointer
//     try testing.expect(threaded_output != null);
// }

// TODO: add input tests
