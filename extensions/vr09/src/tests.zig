//! The test root: every file that carries tests.
comptime {
    _ = @import("roland.zig");
    _ = @import("dump.zig");
    _ = @import("engine.zig");
    _ = @import("audio.zig");
    _ = @import("spsc.zig");
    _ = @import("outbuf.zig");
    _ = @import("fileio.zig");
    _ = @import("state.zig");
    _ = @import("registrations.zig");
    _ = @import("scenes.zig");
    _ = @import("actions.zig");
    _ = @import("split.zig");
    _ = @import("placement.zig");
    _ = @import("reaper_glue.zig");
    _ = @import("catalog.zig");
    _ = @import("debug_api.zig");
    _ = @import("host_test.zig");
    _ = @import("extras.zig");
    _ = @import("tones.zig");
    _ = @import("controls_panel.zig");
    _ = @import("tone_picker.zig");
    _ = @import("patches_panel.zig");
    _ = @import("scenes_panel.zig");
    _ = @import("scene_lane.zig");
    _ = @import("action_types.zig");
    _ = @import("library.zig");
    _ = @import("dispatch.zig");
}
