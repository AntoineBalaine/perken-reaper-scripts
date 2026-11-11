const std = @import("std");
const testing = std.testing;
const imgui = @import("reaper_imgui");
const mock_imgui = @import("mock_imgui");

test "mock imgui install and restore round-trips" {
    var mock = mock_imgui.MockImGui.init(testing.allocator);
    defer mock.deinit();

    mock.install();
    defer mock.restore();

    // After install, imgui API functions point to mock implementations.
    // Calling them records traces instead of talking to REAPER.
}

test "mock imgui traces widget calls" {
    var mock = mock_imgui.MockImGui.init(testing.allocator);
    defer mock.deinit();

    mock.install();
    defer mock.restore();

    // The raw api fields are C function pointers, no error unions.
    _ = imgui.api.Button(null, "Click me", null, null);
    imgui.api.Text(null, "Hello world");

    try testing.expect(mock.containsButton("Click me"));
    try testing.expect(mock.containsText("Hello world"));
    try testing.expect(!mock.containsButton("Nonexistent"));
}

test "mock imgui counts widgets by kind" {
    var mock = mock_imgui.MockImGui.init(testing.allocator);
    defer mock.deinit();

    mock.install();
    defer mock.restore();

    _ = imgui.api.Button(null, "A", null, null);
    _ = imgui.api.Button(null, "B", null, null);
    imgui.api.Text(null, "Some text");

    try testing.expectEqual(@as(usize, 2), mock.widgetCount(.button));
    try testing.expectEqual(@as(usize, 1), mock.widgetCount(.text));
    try testing.expectEqual(@as(usize, 0), mock.widgetCount(.checkbox));
}

test "mock imgui resetTrace clears recorded calls" {
    var mock = mock_imgui.MockImGui.init(testing.allocator);
    defer mock.deinit();

    mock.install();
    defer mock.restore();

    _ = imgui.api.Button(null, "Temp", null, null);
    try testing.expectEqual(@as(usize, 1), mock.widgetCount(.button));

    mock.resetTraceUnchecked();
    try testing.expectEqual(@as(usize, 0), mock.widgetCount(.button));
}

test "mock imgui detects balanced push/pop pairs" {
    var mock = mock_imgui.MockImGui.init(testing.allocator);
    defer mock.deinit();

    mock.install();
    defer mock.restore();

    // A balanced BeginGroup/EndGroup sequence should pass.
    imgui.api.BeginGroup(null);
    imgui.api.EndGroup(null);

    try mock.assertBalanced();
}
