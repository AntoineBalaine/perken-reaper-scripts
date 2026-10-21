//! Preset discovery: the factory that tells the host where the plugin's
//! presets are, so that its preset browser can list them without loading the
//! plugin first.
//!
//! The host calls this before any REAPER function is reachable, so the
//! folder comes from the operating system's usual location for REAPER's
//! resource folder (or `REAPER_RESOURCE_PATH`), the same one the plugin's
//! window saves into.
const std = @import("std");
const clap = @import("clap.zig");
const c = clap.c;
const state = @import("state.zig");
const fileio = @import("fileio.zig");
const plugin = @import("plugin.zig");

const log = std.log.scoped(.discovery);

const provider_id = "com.perken.vr09.presets";

const provider_descriptor = c.clap_preset_discovery_provider_descriptor_t{
    .clap_version = .{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
    .id = provider_id,
    .name = "VR-09 presets",
    .vendor = "Perken",
};

/// Lives as long as the library, because the host keeps the pointer to the
/// location string it was given.
var folder_storage: [fileio.max_path:0]u8 = [_:0]u8{0} ** fileio.max_path;

fn count(_: [*c]const c.clap_preset_discovery_factory_t) callconv(.C) u32 {
    log.info("the host counts the providers", .{});
    return 1;
}

fn getDescriptor(_: [*c]const c.clap_preset_discovery_factory_t, index: u32) callconv(.C) [*c]const c.clap_preset_discovery_provider_descriptor_t {
    log.info("the host asks for the descriptor {d}", .{index});
    if (index != 0) return null;
    return &provider_descriptor;
}

fn create(_: [*c]const c.clap_preset_discovery_factory_t, indexer: [*c]const c.clap_preset_discovery_indexer_t, id: [*c]const u8) callconv(.C) [*c]const c.clap_preset_discovery_provider_t {
    log.info("the host creates the provider {s}", .{std.mem.span(id)});
    if (!std.mem.eql(u8, std.mem.span(id), provider_id)) return null;
    provider.provider_data = @constCast(@ptrCast(indexer));
    return &provider;
}

fn providerInit(p: [*c]const c.clap_preset_discovery_provider_t) callconv(.C) bool {
    const indexer: [*c]const c.clap_preset_discovery_indexer_t = @ptrCast(@alignCast(p.*.provider_data));
    var resource_buf: [fileio.max_path]u8 = undefined;
    const resource = state.defaultResourcePath(&resource_buf) orelse return false;
    const folder = state.presetFolder(&folder_storage, resource) catch return false;
    folder_storage[folder.len] = 0;
    log.info("declaring the preset folder {s}", .{folder});

    const filetype = c.clap_preset_discovery_filetype_t{
        .name = "VR-09 preset",
        .description = "A dump of the keyboard's parameters",
        .file_extension = "vr09",
    };
    const declare_filetype = indexer.*.declare_filetype orelse return false;
    if (!declare_filetype(indexer, &filetype)) return false;

    const location = c.clap_preset_discovery_location_t{
        .flags = c.CLAP_PRESET_DISCOVERY_IS_USER_CONTENT,
        .name = "VR-09 presets",
        .kind = c.CLAP_PRESET_DISCOVERY_LOCATION_FILE,
        .location = &folder_storage,
    };
    const declare_location = indexer.*.declare_location orelse return false;
    return declare_location(indexer, &location);
}

fn providerDestroy(p: [*c]const c.clap_preset_discovery_provider_t) callconv(.C) void {
    _ = p;
}

fn providerGetMetadata(
    p: [*c]const c.clap_preset_discovery_provider_t,
    kind: u32,
    location: [*c]const u8,
    receiver: [*c]const c.clap_preset_discovery_metadata_receiver_t,
) callconv(.C) bool {
    _ = p;
    if (kind != c.CLAP_PRESET_DISCOVERY_LOCATION_FILE) return false;
    const path = std.mem.span(location);
    log.info("metadata asked for {s}", .{path});
    const name = state.displayName(std.fs.path.basename(path));
    var name_buf: [128:0]u8 = [_:0]u8{0} ** 128;
    const n = @min(name.len, name_buf.len - 1);
    @memcpy(name_buf[0..n], name[0..n]);

    const begin = receiver.*.begin_preset orelse return false;
    if (!begin(receiver, &name_buf, null)) return false;
    if (receiver.*.add_plugin_id) |add| {
        const id = c.clap_universal_plugin_id_t{ .abi = "clap", .id = plugin.plugin_id };
        add(receiver, &id);
    }
    if (receiver.*.set_flags) |set| set(receiver, c.CLAP_PRESET_DISCOVERY_IS_USER_CONTENT);
    return true;
}

fn providerGetExtension(p: [*c]const c.clap_preset_discovery_provider_t, id: [*c]const u8) callconv(.C) ?*const anyopaque {
    _ = p;
    _ = id;
    return null;
}

var provider = c.clap_preset_discovery_provider_t{
    .desc = &provider_descriptor,
    .provider_data = null,
    .init = providerInit,
    .destroy = providerDestroy,
    .get_metadata = providerGetMetadata,
    .get_extension = providerGetExtension,
};

pub const factory = c.clap_preset_discovery_factory_t{
    .count = count,
    .get_descriptor = getDescriptor,
    .create = create,
};
