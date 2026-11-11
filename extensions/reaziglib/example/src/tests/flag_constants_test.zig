const imgui = @import("reaper_imgui");

// These flag constants used to live inside the API struct and were re-exported
// via `usingnamespace`. They now live at file scope. This test verifies that
// they are addressable as `imgui.<name>` without call-site changes.

test "flag constants are accessible at file scope" {
    _ = &imgui.Dir_Down;
    _ = &imgui.Dir_Up;
    _ = &imgui.Dir_Left;
    _ = &imgui.Dir_Right;
    _ = &imgui.WindowFlags_NoScrollbar;
    _ = &imgui.WindowFlags_NoDecoration;
    _ = &imgui.Col_Text;
    _ = &imgui.Col_Button;
    _ = &imgui.StyleVar_FramePadding;
    _ = &imgui.HoveredFlags_None;
    _ = &imgui.TableFlags_Borders;
    _ = &imgui.TreeNodeFlags_DefaultOpen;
}
