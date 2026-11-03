const std = @import("std");
const testing = std.testing;
const MockImGui = @import("mock_imgui").MockImGui;
const Knobs = @import("knob");
const imgui = @import("reaper_imgui");

fn setupMock(allocator: std.mem.Allocator) !*MockImGui {
    const mock = try allocator.create(MockImGui);
    mock.* = MockImGui.init(allocator);
    mock.install();
    return mock;
}

fn teardownMock(mock: *MockImGui, allocator: std.mem.Allocator) void {
    mock.restore();
    mock.deinit();
    allocator.destroy(mock);
}

fn callDrawWidget(edit_mode: Knobs.EditMode) !?Knobs.KnobResult {
    var value: f64 = 0.5;
    const label_id = Knobs.LabelId{
        .label = "TestKnob",
        .id = "test_knob_id",
        .value_text = "0.50",
    };
    return Knobs.drawWidget(
        null,
        &value,
        label_id,
        .{},
        null,
        edit_mode,
    );
}

test "knob in normal mode renders value text via DrawList_AddText" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    const result = try callDrawWidget(null);

    try testing.expectEqual(@as(?Knobs.KnobResult, null), result);

    var found_add_text = false;
    var found_input_text = false;
    for (mock.trace_list.items) |entry| {
        if (entry.kind == .draw_list_add_text) found_add_text = true;
        if (entry.kind == .input_text) found_input_text = true;
    }
    try testing.expect(found_add_text);
    try testing.expect(!found_input_text);
}

test "knob in edit mode renders InputText" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    var buf: [24]u8 = std.mem.zeroes([24]u8);
    @memcpy(buf[0..4], "0.50");
    const result = try callDrawWidget(&buf);

    try testing.expectEqual(@as(?Knobs.KnobResult, null), result);

    var found_input_text = false;
    for (mock.trace_list.items) |entry| {
        if (entry.kind == .input_text) found_input_text = true;
    }
    try testing.expect(found_input_text);
}

test "knob in edit mode returns value_submit on Enter with valid float" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    var buf: [24]u8 = std.mem.zeroes([24]u8);
    @memcpy(buf[0..4], "0.75");

    mock.setInputTextEnter("##val_edit_test_knob_id");

    const result = try callDrawWidget(&buf);

    if (result) |res| switch (res) {
        .value_submit => |val| try testing.expectApproxEqAbs(0.75, val, 0.001),
        else => return error.TestUnexpectedResult,
    } else return error.TestUnexpectedResult;
}

test "knob in edit mode returns value_cancel on Escape" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    var buf: [24]u8 = std.mem.zeroes([24]u8);
    @memcpy(buf[0..4], "0.50");

    mock.pressKey(imgui.Key_Escape);

    const result = try callDrawWidget(&buf);

    try testing.expectEqual(@as(?Knobs.KnobResult, .value_cancel), result);
}

test "knob in edit mode returns value_cancel on invalid input" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    var buf: [24]u8 = std.mem.zeroes([24]u8);
    @memcpy(buf[0..3], "abc");

    mock.setInputTextEnter("##val_edit_test_knob_id");

    const result = try callDrawWidget(&buf);

    try testing.expectEqual(@as(?Knobs.KnobResult, .value_cancel), result);
}

test "knob in edit mode clamps out-of-range input" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    var buf: [24]u8 = std.mem.zeroes([24]u8);
    @memcpy(buf[0..3], "1.5");

    mock.setInputTextEnter("##val_edit_test_knob_id");

    const result = try callDrawWidget(&buf);

    if (result) |res| switch (res) {
        .value_submit => |val| try testing.expectApproxEqAbs(1.0, val, 0.001),
        else => return error.TestUnexpectedResult,
    } else return error.TestUnexpectedResult;
}

test "right click on the knob returns value_dclick, which opens the edit box" {
    const mock = try setupMock(testing.allocator);
    defer teardownMock(mock, testing.allocator);

    mock.rightClick("test_knob_id");

    const result = try callDrawWidget(null);

    try testing.expectEqual(@as(?Knobs.KnobResult, .value_dclick), result);
}
