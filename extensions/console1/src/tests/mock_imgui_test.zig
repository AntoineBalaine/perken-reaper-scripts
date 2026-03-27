const std = @import("std");
const testing = std.testing;
const imgui = @import("reaper_imgui");
const MockImGui = @import("../models/mock_imgui.zig").MockImGui;

test "mock install sets getError to mockGetError" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    // getError should be non-null and return null (no error)
    try testing.expect(imgui.getError != null);
    const err = imgui.getError.?();
    try testing.expect(err == null);
}

test "mock Button records trace entry" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    _ = try imgui.Button(.{ null, "Save" });

    try testing.expect(mock.containsWidget(.button, "Save"));
    try testing.expectEqual(@as(usize, 1), mock.trace_list.items.len);
}

test "mock Button returns false by default" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    const clicked = try imgui.Button(.{ null, "Save" });
    try testing.expect(!clicked);
}

test "mock Button returns true for click target" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.click("Save");
    const clicked = try imgui.Button(.{ null, "Save" });
    try testing.expect(clicked);
}

test "click target is consumed after one use" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.click("Save");
    const first = try imgui.Button(.{ null, "Save" });
    const second = try imgui.Button(.{ null, "Save" });
    try testing.expect(first);
    try testing.expect(!second);
}

test "mock Text records label" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.Text(.{ null, "hello" });

    try testing.expect(mock.containsText("hello"));
}

test "mock Begin always returns true" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    const opened = try imgui.Begin(.{ null, "TestWindow" });
    try testing.expect(opened);
    try testing.expect(mock.containsWidget(.begin_window, "TestWindow"));
}

test "mock Checkbox with override changes value" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.setCheckbox("Enable", true);
    var value: bool = false;
    const changed = try imgui.Checkbox(.{ null, "Enable", &value });
    try testing.expect(changed);
    try testing.expect(value);
}

test "mock Checkbox without override does not change value" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var value: bool = false;
    const changed = try imgui.Checkbox(.{ null, "Enable", &value });
    try testing.expect(!changed);
    try testing.expect(!value);
}

test "resetTrace clears all entries" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.Text(.{ null, "hello" });
    try testing.expectEqual(@as(usize, 1), mock.trace_list.items.len);

    mock.resetTrace();
    try testing.expectEqual(@as(usize, 0), mock.trace_list.items.len);
}

test "containsWidget finds correct entries" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.Text(.{ null, "label1" });
    _ = try imgui.Button(.{ null, "label2" });
    try imgui.Text(.{ null, "label3" });

    try testing.expect(mock.containsText("label1"));
    try testing.expect(mock.containsText("label3"));
    try testing.expect(!mock.containsText("label2")); // Button, not Text
    try testing.expect(mock.containsWidget(.button, "label2"));
    try testing.expect(!mock.containsWidget(.button, "label1")); // Text, not Button
}

test "widgetCount counts correctly" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.Text(.{ null, "a" });
    try imgui.Text(.{ null, "b" });
    _ = try imgui.Button(.{ null, "c" });

    try testing.expectEqual(@as(usize, 2), mock.widgetCount(.text));
    try testing.expectEqual(@as(usize, 1), mock.widgetCount(.button));
    try testing.expectEqual(@as(usize, 0), mock.widgetCount(.checkbox));
}

test "mock Selectable with target returns true and consumes" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.selectItem("ReaEQ");
    const first = try imgui.Selectable(.{ null, "ReaEQ" });
    const second = try imgui.Selectable(.{ null, "ReaEQ" });
    try testing.expect(first);
    try testing.expect(!second);
}

test "mock BeginCombo with target returns true" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.openCombo("##combo");
    const opened = try imgui.BeginCombo(.{ null, "##combo", "preview" });
    try testing.expect(opened);
}

test "mock BeginCombo without target returns false" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    const opened = try imgui.BeginCombo(.{ null, "##combo", "preview" });
    try testing.expect(!opened);
}

test "mock SmallButton records trace and handles click" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.click("X");
    const clicked = try imgui.SmallButton(.{ null, "X" });
    try testing.expect(clicked);
    try testing.expect(mock.containsWidget(.small_button, "X"));
}

test "mock TextColored records label" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.TextColored(.{ null, 0xFF0000FF, "Error!" });
    try testing.expect(mock.containsText("Error!"));
    try testing.expect(mock.containsWidget(.text_colored, "Error!"));
}

test "assertBalanced detects missing PopFont" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.PushFont(.{ null, null });
    // No PopFont — the stack is unbalanced.
    try testing.expectError(error.TestUnexpectedResult, mock.assertBalanced());

    // Clean up so deinit doesn't see stale state
    mock.pair_depths.getPtr(.font).* = 0;
}

test "assertBalanced passes when pairs are balanced" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    try imgui.PushFont(.{ null, null });
    try imgui.PopFont(.{null});
    try imgui.PushStyleColor(.{ null, 0, 0 });
    try imgui.PopStyleColor(.{null});

    try mock.assertBalanced();
}

test "assertBalanced detects missing End after Begin" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    _ = try imgui.Begin(.{ null, "TestWindow" });
    // No End — the stack is unbalanced.
    try testing.expectError(error.TestUnexpectedResult, mock.assertBalanced());

    mock.pair_depths.getPtr(.window).* = 0;
}

test "resetInteractions clears all targets" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    mock.click("Save");
    mock.selectItem("ReaEQ");
    mock.openCombo("##combo");
    mock.setCheckbox("Enable", true);

    mock.resetInteractions();

    const btn = try imgui.Button(.{ null, "Save" });
    const sel = try imgui.Selectable(.{ null, "ReaEQ" });
    const combo = try imgui.BeginCombo(.{ null, "##combo", "preview" });
    var val: bool = false;
    const chk = try imgui.Checkbox(.{ null, "Enable", &val });

    try testing.expect(!btn);
    try testing.expect(!sel);
    try testing.expect(!combo);
    try testing.expect(!chk);
}
