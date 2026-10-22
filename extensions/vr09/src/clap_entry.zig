//! The library's entry point: the symbol a CLAP host looks for, and the
//! factories behind it.
const std = @import("std");
const clap = @import("clap.zig");
const c = clap.c;
const plugin = @import("plugin.zig");
const discovery = @import("discovery.zig");
const debug_api = @import("debug_api.zig");

/// The log goes to the default destination and to a ring that `VR09_Command`
/// can read.
pub const std_options: std.Options = .{ .logFn = debug_api.logFn };

var init_count: u32 = 0;

fn entryInit(path: [*c]const u8) callconv(.C) bool {
    _ = path;
    init_count += 1;
    return true;
}

fn entryDeinit() callconv(.C) void {
    if (init_count == 0) return;
    init_count -= 1;
    if (init_count == 0) plugin.shutdown();
}

fn factoryCount(factory: [*c]const c.clap_plugin_factory_t) callconv(.C) u32 {
    _ = factory;
    return 1;
}

fn factoryDescriptor(factory: [*c]const c.clap_plugin_factory_t, index: u32) callconv(.C) [*c]const c.clap_plugin_descriptor_t {
    _ = factory;
    if (index != 0) return null;
    return &plugin.descriptor;
}

fn factoryCreate(factory: [*c]const c.clap_plugin_factory_t, host: [*c]const c.clap_host_t, plugin_id: [*c]const u8) callconv(.C) [*c]const c.clap_plugin_t {
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

fn getFactory(factory_id: [*c]const u8) callconv(.C) ?*const anyopaque {
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
