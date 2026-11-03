//! The library's entry point: the symbol a CLAP host looks for, and the
//! factories behind it.
const std = @import("std");
const clap = @import("clap.zig");
const c = clap.c;
const plugin = @import("plugin.zig");
const host_io = @import("host_io");
const discovery = @import("discovery.zig");
const build_options = @import("build_options");
const debug_api = if (build_options.debug_api) @import("debug_api.zig") else @import("debug_api_off.zig");

/// The log goes to the default destination, and in a development build also to a ring that `VR09_Command` can
/// read.
pub const std_options: std.Options = .{ .logFn = debug_api.logFn };

var init_count: u32 = 0;

fn entryInit(path: [*c]const u8) callconv(.c) bool {
    _ = path;
    if (init_count == 0) plugin.io_threaded = host_io.create();
    init_count += 1;
    return true;
}

fn entryDeinit() callconv(.c) void {
    if (init_count == 0) return;
    init_count -= 1;
    if (init_count == 0) {
        plugin.shutdown();
        plugin.io_threaded.deinit();
        // Because a freed instance must not be used again, the single-threaded default takes its place.
        plugin.io_threaded = .init_single_threaded;
    }
}

fn factoryCount(factory: [*c]const c.clap_plugin_factory_t) callconv(.c) u32 {
    _ = factory;
    return 1;
}

fn factoryDescriptor(factory: [*c]const c.clap_plugin_factory_t, index: u32) callconv(.c) [*c]const c.clap_plugin_descriptor_t {
    _ = factory;
    if (index != 0) return null;
    return &plugin.descriptor;
}

fn factoryCreate(factory: [*c]const c.clap_plugin_factory_t, host: [*c]const c.clap_host_t, plugin_id: [*c]const u8) callconv(.c) [*c]const c.clap_plugin_t {
    _ = factory;
    if (!std.mem.eql(u8, std.mem.span(plugin_id), plugin.plugin_id)) return null;
    if (!clap.isCompatible(host.*.clap_version)) return null;
    const p = plugin.Plugin.create(host) orelse return null;
    return &p.clap;
}

const plugin_factory = c.clap_plugin_factory_t{
    .get_plugin_count = factoryCount,
    .get_plugin_descriptor = factoryDescriptor,
    .create_plugin = factoryCreate,
};

fn getFactory(factory_id: [*c]const u8) callconv(.c) ?*const anyopaque {
    const id = std.mem.span(factory_id);
    std.log.scoped(.entry).info("the host asks for the factory {s}", .{id});
    if (std.mem.eql(u8, id, clap.s(c.CLAP_PLUGIN_FACTORY_ID))) return &plugin_factory;
    if (std.mem.eql(u8, id, clap.s(c.CLAP_PRESET_DISCOVERY_FACTORY_ID)) or
        std.mem.eql(u8, id, clap.s(c.CLAP_PRESET_DISCOVERY_FACTORY_ID_COMPAT)))
    {
        return &discovery.factory;
    }
    return null;
}

pub export const clap_entry: c.clap_plugin_entry_t = .{
    .clap_version = .{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
    .init = entryInit,
    .deinit = entryDeinit,
    .get_factory = getFactory,
};
