//! The levels of the browser of plugins. The first level has the plugins that have a mapping for the module, and then the
//! menus: the FX chains, the track templates, all the plugins by type, the tags, and three plugins that have no list. A menu
//! opens a level of its own, whose entries are menus again or things to insert. The window draws the level that is open, and
//! the controller moves a cursor in it, enters a menu and leaves it, so both need the same entries in the same order.
const std = @import("std");
const types = @import("fx_parser_types");

/// How many menus can be inside one another. The folders of the FX chains are the only ones that have no fixed depth.
pub const max_depth = 8;

/// The menus after the plugins that have a mapping, in the order that the window shows them.
pub const RootMenu = enum(u8) {
    fx_chains,
    track_templates,
    all_plugins,
    tags_category,
    tags_developer,
    container,
    video_processor,
    recent,
};

pub const root_menu_count = std.enums.values(RootMenu).len;

/// The data that the levels are made of.
pub const Source = struct {
    /// How many plugins have a mapping for the module, which are the first entries of the first level.
    mapped_count: usize,
    fx_chains: *const types.Directory,
    track_templates: *const types.Directory,
    plugins_by_type: *const types.FxByType,
    tags: *const types.FxTags,
};

/// One level of the browser.
pub const Level = union(enum) {
    /// The plugins that have a mapping, and the menus.
    root,
    /// A folder of FX chains or of track templates: its folders first, and then its files.
    directory: struct { directory: *const types.Directory, is_chain: bool },
    /// The types of plugins (VST, JS, ...), each with its list.
    plugin_types,
    /// The tags of a kind (the category or the developer), each with its list.
    tag_list: *const types.TagList,
    /// A list of plugins, which has nothing to open.
    fx_list: *const types.FxList,
};

/// What confirming an entry does.
pub const Activation = union(enum) {
    /// The entry is a menu: its level opens.
    enter,
    /// A plugin that has a mapping: the index among them.
    mapped: usize,
    /// A plugin that is inserted without a mapping.
    plugin: [:0]const u8,
    fx_chain: []const u8,
    track_template: [:0]const u8,
    /// One of the entries of the first level that is a plugin by its name and has no list.
    root_leaf: RootMenu,
    none,
};

fn asSentinel(name: []const u8) [:0]const u8 {
    return @ptrCast(name);
}

/// The wrapper shells list the plugins that they hold, and are not listed themselves.
pub fn isListed(name: []const u8) bool {
    return !std.mem.startsWith(u8, name, "WaveShell");
}

fn listedCount(list: *const types.FxList) usize {
    var count: usize = 0;
    for (list.keys()) |name| {
        if (isListed(name)) count += 1;
    }
    return count;
}

/// The name of the n-th plugin of a list that is listed.
pub fn listedName(list: *const types.FxList, n: usize) ?[:0]const u8 {
    var seen: usize = 0;
    for (list.keys()) |name| {
        if (!isListed(name)) continue;
        if (seen == n) return asSentinel(name);
        seen += 1;
    }
    return null;
}

fn subdirCount(directory: *const types.Directory) usize {
    return if (directory.subdirs) |subdirs| subdirs.count() else 0;
}

fn fileCount(directory: *const types.Directory) usize {
    return if (directory.files) |files| files.count() else 0;
}

/// The root menu of an entry of the first level, or null for one of the plugins that have a mapping.
pub fn rootMenuOf(source: Source, index: usize) ?RootMenu {
    if (index < source.mapped_count) return null;
    const menu = index - source.mapped_count;
    if (menu >= root_menu_count) return null;
    return @fromBackingInt(@intCast(menu));
}

/// The level that an entry of a level opens, or null when the entry is not a menu.
pub fn enter(source: Source, level: Level, index: usize) ?Level {
    switch (level) {
        .root => {
            const menu = rootMenuOf(source, index) orelse return null;
            return switch (menu) {
                .fx_chains => .{ .directory = .{ .directory = source.fx_chains, .is_chain = true } },
                .track_templates => .{ .directory = .{ .directory = source.track_templates, .is_chain = false } },
                .all_plugins => .plugin_types,
                .tags_category => .{ .tag_list = &source.tags.category },
                .tags_developer => .{ .tag_list = &source.tags.developer },
                .container, .video_processor, .recent => null,
            };
        },
        .directory => |folder| {
            const subdirs = folder.directory.subdirs orelse return null;
            if (index >= subdirs.count()) return null;
            return .{ .directory = .{ .directory = &subdirs.values()[index], .is_chain = folder.is_chain } };
        },
        .plugin_types => {
            if (index >= source.plugins_by_type.values.len) return null;
            return .{ .fx_list = &source.plugins_by_type.values[index] };
        },
        .tag_list => |tags| {
            if (index >= tags.count()) return null;
            return .{ .fx_list = &tags.values()[index] };
        },
        .fx_list => return null,
    }
}

/// The level that a path of entries leads to, from the first level.
pub fn levelAt(source: Source, path: []const usize) ?Level {
    var level: Level = .root;
    for (path) |index| level = enter(source, level, index) orelse return null;
    return level;
}

/// How many entries a level has.
pub fn entryCount(source: Source, level: Level) usize {
    return switch (level) {
        .root => source.mapped_count + root_menu_count,
        .directory => |folder| subdirCount(folder.directory) + fileCount(folder.directory),
        .plugin_types => source.plugins_by_type.values.len,
        .tag_list => |tags| tags.count(),
        .fx_list => |list| listedCount(list),
    };
}

/// What confirming the entry `index` of a level does. The path of an FX chain or of a track template is written in `buf`.
pub fn activate(source: Source, level: Level, index: usize, buf: *[std.fs.max_path_bytes:0]u8) Activation {
    if (index >= entryCount(source, level)) return .none;
    switch (level) {
        .root => {
            if (index < source.mapped_count) return .{ .mapped = index };
            const menu = rootMenuOf(source, index) orelse return .none;
            return switch (menu) {
                .container, .video_processor, .recent => .{ .root_leaf = menu },
                else => .enter,
            };
        },
        .directory => |folder| {
            const subdirs = subdirCount(folder.directory);
            if (index < subdirs) return .enter;
            const files = folder.directory.files orelse return .none;
            const name = files.keys()[index - subdirs];
            const path = std.fmt.bufPrintSentinel(buf, "{s}/{s}", .{ folder.directory.path, name }, 0) catch return .none;
            return if (folder.is_chain) .{ .fx_chain = path } else .{ .track_template = path };
        },
        .plugin_types, .tag_list => return .enter,
        .fx_list => |list| {
            const name = listedName(list, index) orelse return .none;
            return .{ .plugin = name };
        },
    }
}

/// The name that the window shows for an entry of a level that is not the first one. The first level has the names of the
/// plugins that have a mapping, which it reads from the mappings, and the names of the menus, which are translated.
pub fn entryName(source: Source, level: Level, index: usize) ?[:0]const u8 {
    switch (level) {
        .root => return null,
        .directory => |folder| {
            const subdirs = subdirCount(folder.directory);
            if (index < subdirs) return folder.directory.subdirs.?.values()[index].name;
            const files = folder.directory.files orelse return null;
            if (index - subdirs >= files.count()) return null;
            return asSentinel(files.keys()[index - subdirs]);
        },
        .plugin_types => {
            if (index >= source.plugins_by_type.values.len) return null;
            const plugin_type: types.FxType = @fromBackingInt(@intCast(index));
            return @tagName(plugin_type);
        },
        .tag_list => |tags| {
            if (index >= tags.count()) return null;
            return asSentinel(tags.keys()[index]);
        },
        .fx_list => |list| return listedName(list, index),
    }
}

/// The index of the first entry of a level that is not a menu, for the levels where the menus come before the rest. The
/// first level is not one of them, because its plugins come first.
pub fn leafStart(level: Level) usize {
    return switch (level) {
        .root => 0,
        .directory => |folder| subdirCount(folder.directory),
        .plugin_types, .tag_list => std.math.maxInt(usize),
        .fx_list => 0,
    };
}

/// Whether the entry `index` of a level is a menu, which the window marks with an arrow.
pub fn isMenu(source: Source, level: Level, index: usize) bool {
    var buf: [std.fs.max_path_bytes:0]u8 = undefined;
    return activate(source, level, index, &buf) == .enter;
}

fn testSource(allocator: std.mem.Allocator, chains: *types.Directory, templates: *types.Directory, by_type: *types.FxByType, tags: *types.FxTags, mapped: usize) Source {
    _ = allocator;
    return .{ .mapped_count = mapped, .fx_chains = chains, .track_templates = templates, .plugins_by_type = by_type, .tags = tags };
}

test "the first level has the mapped plugins and then the menus, and a menu opens a level of its own" {
    const allocator = std.testing.allocator;
    var chains: types.Directory = .{ .path = "/chains", .name = "chains", .subdirs = null, .files = null };
    var templates: types.Directory = .{ .path = "/templates", .name = "templates", .subdirs = null, .files = null };
    var by_type = types.FxByType.initFill(.{});
    defer for (&by_type.values) |*list| list.deinit(allocator);
    var tags: types.FxTags = .{ .category = .{}, .developer = .{} };
    try by_type.getPtr(.VST).put(allocator, "ReaEQ", {});
    try by_type.getPtr(.VST).put(allocator, "WaveShell1", {});
    try by_type.getPtr(.VST).put(allocator, "ReaComp", {});

    const source = testSource(allocator, &chains, &templates, &by_type, &tags, 2);
    try std.testing.expectEqual(@as(usize, 2 + root_menu_count), entryCount(source, .root));

    var buf: [std.fs.max_path_bytes:0]u8 = undefined;
    try std.testing.expectEqual(Activation{ .mapped = 1 }, activate(source, .root, 1, &buf));
    try std.testing.expectEqual(Activation.enter, activate(source, .root, 2 + @backingInt(RootMenu.all_plugins), &buf));
    try std.testing.expectEqual(Activation{ .root_leaf = .recent }, activate(source, .root, 2 + @backingInt(RootMenu.recent), &buf));

    const types_level = enter(source, .root, 2 + @backingInt(RootMenu.all_plugins)).?;
    try std.testing.expectEqual(@as(usize, std.enums.values(types.FxType).len), entryCount(source, types_level));

    const vst_level = enter(source, types_level, @backingInt(types.FxType.VST)).?;
    // Because the wrapper shells are not listed, the VST list has two entries, and the second one is the compressor.
    try std.testing.expectEqual(@as(usize, 2), entryCount(source, vst_level));
    const second = activate(source, vst_level, 1, &buf);
    try std.testing.expectEqualStrings("ReaComp", second.plugin);
    try std.testing.expectEqual(@as(?Level, null), enter(source, vst_level, 0));
}

test "a folder lists its folders and then its files, and a file gives its path" {
    const allocator = std.testing.allocator;
    var inner: types.Directory = .{ .path = "/chains/inner", .name = "inner", .subdirs = null, .files = .{} };
    defer inner.files.?.deinit(allocator);
    try inner.files.?.put(allocator, "deep.RfxChain", {});
    var subdirs: types.DirectoryList = .{};
    defer subdirs.deinit(allocator);
    try subdirs.put(allocator, 1, inner);
    var chains: types.Directory = .{ .path = "/chains", .name = "chains", .subdirs = subdirs, .files = .{} };
    defer chains.files.?.deinit(allocator);
    try chains.files.?.put(allocator, "top.RfxChain", {});
    var templates: types.Directory = .{ .path = "/templates", .name = "templates", .subdirs = null, .files = null };
    var by_type = types.FxByType.initFill(.{});
    var tags: types.FxTags = .{ .category = .{}, .developer = .{} };

    const source = testSource(allocator, &chains, &templates, &by_type, &tags, 0);
    const folder = enter(source, .root, @backingInt(RootMenu.fx_chains)).?;
    try std.testing.expectEqual(@as(usize, 2), entryCount(source, folder));
    var buf: [std.fs.max_path_bytes:0]u8 = undefined;
    try std.testing.expectEqual(Activation.enter, activate(source, folder, 0, &buf));
    try std.testing.expectEqualStrings("/chains/top.RfxChain", activate(source, folder, 1, &buf).fx_chain);

    const inside = levelAt(source, &.{ @backingInt(RootMenu.fx_chains), 0 }).?;
    try std.testing.expectEqualStrings("/chains/inner/deep.RfxChain", activate(source, inside, 0, &buf).fx_chain);
}

test "a path that leaves the levels leads nowhere" {
    var chains: types.Directory = .{ .path = "/chains", .name = "chains", .subdirs = null, .files = null };
    var templates: types.Directory = .{ .path = "/templates", .name = "templates", .subdirs = null, .files = null };
    var by_type = types.FxByType.initFill(.{});
    var tags: types.FxTags = .{ .category = .{}, .developer = .{} };
    const source = testSource(std.testing.allocator, &chains, &templates, &by_type, &tags, 0);
    try std.testing.expectEqual(@as(?Level, null), levelAt(source, &.{ @backingInt(RootMenu.recent), 0 }));
    try std.testing.expectEqual(@as(?Level, null), levelAt(source, &.{99}));
}
