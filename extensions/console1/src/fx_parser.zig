const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const ini = @import("ini");
const FxType = enum {
    VST,
    VSTi,
    VST3,
    VST3i,
    JS,
    AU,
    AUi,
    CLAP,
    CLAPi,
    LV2,
    LV2i,
    Container,
    VideoProcessor,
};

/// Use this context to sort a string array hashmap
const StrArrHshMpCtx = struct {
    keys: [][]const u8,

    pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
        return std.ascii.lessThanIgnoreCase(ctx.keys[a_index], ctx.keys[b_index]);
    }
};

/// Use this context to sort a DirectoryList
const SubdirsCtx = struct {
    subdirs: *DirectoryList,
    pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
        const aDir = ctx.subdirs.*.values()[a_index].name;
        const bDir = ctx.subdirs.*.values()[b_index].name;
        return std.ascii.lessThanIgnoreCase(aDir, bDir);
    }
};

/// FxBrowser-facing, sorted FX list
const PluginsList = std.StringArrayHashMapUnmanaged(FxType);
pub const FxList = std.StringArrayHashMapUnmanaged(void);
/// List of categories that each contain a list of plugins
const TagList = std.StringArrayHashMapUnmanaged(FxList);
/// FxBrowser-facing, sorted plugin list, by type
const FxByType = std.EnumArray(FxType, FxList);
const FxTags = struct {
    category: TagList,
    developer: TagList,
};

pub var pluginList: PluginsList = undefined;
pub var fx_tags: FxTags = undefined;
pub var fx_chains: Directory = undefined;
pub var track_templates: Directory = undefined;
pub var pluginsByType: FxByType = undefined;

/// used to parse fxChains and trackTemplates
const DirectoryList = std.AutoArrayHashMapUnmanaged(c_int, Directory);
/// used to parse fxChains and trackTemplates
pub const Directory = struct {
    path: [:0]const u8,
    name: [:0]const u8,
    subdirs: ?DirectoryList,
    files: ?std.StringArrayHashMapUnmanaged(void),
};
///sort plugins by type, such as {VST = {plugin1, plugin2}, JS = {plugin3}}
fn toPluginsByType(allocator: std.mem.Allocator, plugin_list: PluginsList) !FxByType {
    var pluginsbytype: FxByType = FxByType.init(.{
        .VST = FxList{},
        .VSTi = FxList{},
        .VST3 = FxList{},
        .VST3i = FxList{},
        .JS = FxList{},
        .AU = FxList{},
        .AUi = FxList{},
        .CLAP = FxList{},
        .CLAPi = FxList{},
        .LV2 = FxList{},
        .LV2i = FxList{},
        .Container = FxList{},
        .VideoProcessor = FxList{},
    });

    // expect the plugin_list to be sorted by name.
    var iterator = plugin_list.iterator();
    while (iterator.next()) |plugin| {
        const fxName = plugin.key_ptr.*;
        const fxType = plugin.value_ptr.*;
        var list = pluginsbytype.getPtr(fxType);
        try list.put(allocator, fxName, {});
    }
    return pluginsbytype;
}

fn parseFX(name: [:0]const u8) ?FxType {
    var fxtype: ?FxType = null;
    if (std.mem.startsWith(u8, name, "VST:")) {
        fxtype = FxType.VST;
    } else if (std.mem.startsWith(u8, name, "VSTi:")) {
        fxtype = FxType.VSTi;
    } else if (std.mem.startsWith(u8, name, "VST3:")) {
        fxtype = FxType.VST3;
    } else if (std.mem.startsWith(u8, name, "VST3i:")) {
        fxtype = FxType.VST3i;
    } else if (std.mem.startsWith(u8, name, "JS:")) {
        fxtype = FxType.JS;
    } else if (std.mem.startsWith(u8, name, "AU:")) {
        fxtype = FxType.AU;
    } else if (std.mem.startsWith(u8, name, "AUi:")) {
        fxtype = FxType.AUi;
    } else if (std.mem.startsWith(u8, name, "CLAP:")) {
        fxtype = FxType.CLAP;
    } else if (std.mem.startsWith(u8, name, "CLAPi:")) {
        fxtype = FxType.CLAPi;
    } else if (std.mem.startsWith(u8, name, "LV2:")) {
        fxtype = FxType.LV2;
    } else if (std.mem.startsWith(u8, name, "LV2i:")) {
        fxtype = FxType.LV2i;
    } else if (std.mem.startsWith(u8, name, "Container")) {
        fxtype = FxType.Container;
    } else if (std.mem.startsWith(u8, name, "Video processor")) {
        fxtype = FxType.VideoProcessor;
    }
    return fxtype;
}

/// Insert plugins from fxtag into the FxList hashmap
/// `reaper-fxtags.ini` has KVs as `<plugin> = <category1|category2 or developer>``
/// FxList has KVs as `<category or developer> = <sortableSet(plugins)>`
/// So, this function swaps the KVs, placing each plugin in a sortable set.
fn readToFxTags(fxtags: *FxTags, parser: anytype, allocator: std.mem.Allocator) !void {
    var cur_section: ?[]const u8 = null;

    var categoryNames = std.ArrayList([]const u8).init(allocator);
    parseLoop: while (try parser.*.next()) |record| {
        switch (record) {
            .section => |heading| {
                inline for (@typeInfo(@TypeOf(fxtags.*)).Struct.fields) |field| {
                    if (std.mem.eql(u8, heading, field.name)) {
                        cur_section = field.name;
                        continue :parseLoop;
                    }
                }
                cur_section = null;
            },
            .property => |kv| {
                if (cur_section) |section| {
                    std.debug.assert(std.mem.eql(u8, section, "category") or std.mem.eql(u8, section, "developer"));
                    const catStr = kv.value; // category or developer name
                    var iterator = std.mem.splitScalar(u8, catStr, '|');
                    while (iterator.next()) |tag| {
                        std.debug.assert(!std.mem.eql(u8, tag, "")); // assume there's never two '|' next to each other in cat
                        try categoryNames.append(tag);
                    }
                    for (categoryNames.items) |tag| {
                        const isCategory = std.mem.eql(u8, section, "category"); // category or dev
                        // List of categories which contain lists of plugins
                        var tagList = if (isCategory) &fxtags.category else &fxtags.developer;
                        // NOTE: this does have the disadvantage of duplicating fx names across developers and categories;
                        // maybe in the future it would be an option to store pointers instead.
                        const plugin = try allocator.dupeZ(u8, kv.key);

                        var pluginslist = tagList.getPtr(tag); // does this category already exist?
                        if (pluginslist) |*pluginsList| {
                            std.debug.assert(pluginsList.*.get(plugin) == null); // assume plugin name doesn't appear multiple times in the section
                            try pluginsList.*.put(allocator, plugin, {});
                        } else {
                            // if this category tag is not in the list yet, create an entry
                            var newPluginslist: ?FxList = FxList{};
                            try newPluginslist.?.put(allocator, plugin, {});
                            // if the entry's not in yet, create its key by allocating a copy
                            try tagList.put(allocator, try allocator.dupeZ(u8, tag), newPluginslist.?);
                        }
                    }
                    categoryNames.clearRetainingCapacity();
                }
            },
            .enumeration => {},
        }
    }
    categoryNames.deinit();
}

fn parseFXTags(allocator: std.mem.Allocator) !FxTags {
    const path = try std.fs.path.resolve(allocator, &.{ std.mem.span(reaper.GetResourcePath()), "./reaper-fxtags.ini" });
    defer allocator.free(path);
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    var fxtags = FxTags{
        .category = TagList{},
        .developer = TagList{},
    };

    try readToFxTags(&fxtags, &parser, allocator);
    inline for (std.meta.fields(@TypeOf(fxtags))) |field| {
        var tagList = &@field(fxtags, field.name);
        var iterator = tagList.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.*.sort(StrArrHshMpCtx{ .keys = entry.value_ptr.*.keys() });
        }
        tagList.sort(StrArrHshMpCtx{ .keys = tagList.keys() });
    }

    return fxtags;
}

fn deinitFXTags(self: *FxTags, allocator: std.mem.Allocator) void {
    inline for (@typeInfo(@TypeOf(self.*)).Struct.fields) |field| {
        // categories or devs
        var taglist = @field(self, field.name);

        var tagListIt = taglist.iterator();
        while (tagListIt.next()) |entry| {
            var fxList = entry.value_ptr.*;
            var fxIterator = fxList.iterator();

            while (fxIterator.next()) |fxName| {
                allocator.free(@as([:0]const u8, @ptrCast(fxName.key_ptr.*)));
            }
            fxList.deinit(allocator);
            const tagName = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            allocator.free(tagName);
        }
        taglist.deinit(allocator);
    }
}

/// get installedFX from reaper, put them into a list.
/// sort them by name.
fn initPluginList(allocator: std.mem.Allocator) !PluginsList {
    var plugin_list = PluginsList{};
    errdefer {
        plugin_list.deinit(allocator);
    }
    var index: c_int = 0;
    var nameOut: [*:0]u8 = undefined;
    var identOut: [*:0]u8 = undefined;
    // FIXME: why is there nothing printing to the buffer?
    while (reaper.EnumInstalledFX(index, &nameOut, &identOut)) : (index += 1) {
        const fxtype = parseFX(std.mem.span(nameOut));
        if (fxtype) |fxType| {
            const namecopy = try allocator.dupeZ(u8, std.mem.span(nameOut));
            try plugin_list.put(allocator, namecopy, fxType);
        }
    }
    plugin_list.sort(StrArrHshMpCtx{ .keys = plugin_list.keys() });
    return plugin_list;
}

fn deinitPluginList(plugList: *PluginsList, fxbytype: *FxByType, allocator: std.mem.Allocator) void {
    var iterator = plugList.iterator();
    while (iterator.next()) |kv| {
        // PluginsList = std.StringArrayHashMapUnmanaged(FxType);
        // the key_ptr points to fx.name
        allocator.free(@as([:0]const u8, @ptrCast(kv.key_ptr.*)));
    }
    plugList.deinit(allocator);

    var fxTypeIt = fxbytype.iterator();
    while (fxTypeIt.next()) |entry| {
        entry.value.deinit(allocator);
    }
}

fn directoryInit(allocator: std.mem.Allocator, path: [:0]const u8, fileExtension: [:0]const u8) !Directory {
    var dir: Directory = .{
        .path = path,
        .name = try allocator.dupeZ(u8, std.fs.path.basename(path)),
        .subdirs = null,
        .files = null,
    };
    var dirIdx: c_int = 0;
    while (reaper.EnumerateSubdirectories(path, dirIdx)) |subdir| : (dirIdx += 1) {
        const subdirPath = try std.fs.path.joinZ(allocator, &[_][]const u8{ path, std.mem.span(subdir) });
        if (dir.subdirs == null) {
            dir.subdirs = DirectoryList{};
        }
        try dir.subdirs.?.put(
            allocator,
            dirIdx,
            try directoryInit(allocator, subdirPath, fileExtension),
        );
    }

    if (dir.subdirs) |*subdirs| {
        // NOTE: it would perhaps be possible to switch the Directory struct to use a multipleArrayList instead
        // that way it'd be possible to iterate a little quicker on these.
        subdirs.sort(SubdirsCtx{ .subdirs = subdirs });
    }
    var fileIdx: c_int = 0;

    while (reaper.EnumerateFiles(path, fileIdx)) |file| : (fileIdx += 1) {
        const fileSpan = std.mem.span(file);
        if (std.mem.eql(u8, std.fs.path.extension(fileSpan), fileExtension)) {
            const fileSlice: [:0]const u8 = try allocator.dupeZ(u8, fileSpan);
            if (dir.files == null) {
                dir.files = std.StringArrayHashMapUnmanaged(void){};
            }
            try dir.files.?.put(allocator, fileSlice, {});
        }
    }
    if (dir.files) |*files| {
        files.sort(StrArrHshMpCtx{ .keys = files.keys() });
    }
    return dir;
}

fn directoryDeinit(self: *Directory, allocator: std.mem.Allocator) void {
    if (self.subdirs) |*subdirs| {
        var subdirIt = subdirs.iterator();
        while (subdirIt.next()) |*subdir| {
            directoryDeinit(subdir.value_ptr, allocator);
        }
        subdirs.deinit(allocator);
    }
    if (self.files) |*files| {
        var filesIterator = files.iterator();
        while (filesIterator.next()) |entry| {
            const fileName = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            allocator.free(fileName);
        }
        files.deinit(allocator);
    }
    allocator.free(self.path);
    allocator.free(self.name);
}

fn parseFxChains(allocator: std.mem.Allocator) !Directory {
    const span: [:0]const u8 = std.mem.span(reaper.GetResourcePath());
    const fxChainsPath = try std.fs.path.joinZ(allocator, &[_][]const u8{ span, "FXChains" });
    return try directoryInit(allocator, fxChainsPath, ".RfxChain");
}

fn parseTrackTemplates(allocator: std.mem.Allocator) !Directory {
    const span: [:0]const u8 = std.mem.span(reaper.GetResourcePath());
    const fxChainsPath = try std.fs.path.joinZ(allocator, &[_][]const u8{ span, "TrackTemplates" });
    return try directoryInit(allocator, fxChainsPath, ".RTrackTemplate");
}

pub fn init(allocator: std.mem.Allocator) !void {
    pluginList = try initPluginList(allocator);
    pluginsByType = try toPluginsByType(allocator, pluginList);
    fx_tags = try parseFXTags(allocator);
    // TODO: implement parseCustomCategories - this is really tricky to do
    // const custom_categories = try parseCustomCategories();
    const fxChains = try parseFxChains(allocator);
    fx_chains = fxChains;
    const trackT = try parseTrackTemplates(allocator);
    track_templates = trackT;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    deinitPluginList(&pluginList, &pluginsByType, allocator);
    deinitFXTags(&fx_tags, allocator);
    directoryDeinit(&fx_chains, allocator);
    directoryDeinit(&track_templates, allocator);
}
