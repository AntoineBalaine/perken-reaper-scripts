//! The data that the browser of plugins shows: the plugins installed in REAPER by type and by tag, read by the plugin parser of reaziglib, which
//! the Console 1 uses too.
//!
//! Because reading the lists of plugins takes a moment, and most sessions never open the browser, they are read the first time that the browser is
//! asked for, and kept for the rest of the session.
const std = @import("std");
const builtin = @import("builtin");
const fx_parser = @import("fx_parser");
const fx_browser = @import("fx_browser");
const mft_fxsel = @import("mft_fxsel.zig");
const mft_globals = @import("mft_globals.zig");
const log = std.log.scoped(.mft_browser);

const Reading = enum { not_read, ready, failed };
var reading: Reading = .not_read;

/// The source of the levels of the browser, with `mapped_count` plugins that have a map at the top of the first level, or null when the plugins could
/// not be read. The unit tests have no REAPER to read them from, so they get null.
pub fn get(globals: *mft_globals.MftGlobals, mapped_count: usize) ?fx_browser.Source {
    if (comptime builtin.is_test) return null;
    if (reading == .not_read) {
        fx_parser.init(globals.arena.allocator(), mft_globals.hostIo()) catch |err| {
            log.err("the plugins could not be read: {s}", .{@errorName(err)});
            reading = .failed;
            return null;
        };
        reading = .ready;
    }
    if (reading == .failed) return null;
    return .{
        .mapped_count = mapped_count,
        .fx_chains = &fx_parser.fx_chains,
        .track_templates = &fx_parser.track_templates,
        .plugins_by_type = &fx_parser.pluginsByType,
        .tags = &fx_parser.fx_tags,
        .hidden_menus = mft_fxsel.hidden_menus,
    };
}
