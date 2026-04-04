const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers");
const log = std.log.scoped(.translations);

pub const LanguageInfo = struct {
    code: [:0]const u8, // "en", "fr", etc.
    display_name: [:0]const u8, // "English", "Français", etc.
};

/// Because Zig's std.fmt requires comptime format strings, this function provides
/// runtime substitution of the first `{s}` placeholder in a translated template string.
/// If `{s}` is not found or the result would overflow the buffer, the template is returned unchanged.
pub fn substituteFirst(buf: [:0]u8, template: [:0]const u8, replacement: []const u8) [:0]const u8 {
    const placeholder = "{s}";
    const idx = std.mem.indexOf(u8, template, placeholder) orelse return template;
    const before = template[0..idx];
    const after = template[idx + placeholder.len ..];
    const total = before.len + replacement.len + after.len;
    if (total >= buf.len) return template;
    @memcpy(buf[0..before.len], before);
    @memcpy(buf[before.len .. before.len + replacement.len], replacement);
    @memcpy(buf[before.len + replacement.len .. total], after);
    buf[total] = 0;
    return buf[0..total :0];
}

fn getLanguageDisplayNameFromFile(allocator: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8) ![:0]const u8 {
    const file = try dir.openFile(filename, .{});
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var parser = ini.parse(arena.allocator(), file.reader());
    defer parser.deinit();

    while (try parser.next()) |record| {
        switch (record) {
            .section => |section| {
                if (std.mem.eql(u8, section, "metadata")) {
                    while (try parser.next()) |meta_record| {
                        switch (meta_record) {
                            .property => |kv| {
                                if (std.mem.eql(u8, kv.key, "language_name")) {
                                    return allocator.dupeZ(u8, kv.value);
                                }
                            },
                            .section => break,
                            .enumeration => {},
                        }
                    }
                }
            },
            else => {},
        }
    }

    // Fallback to using the code if no display name found
    const code = filename[0 .. filename.len - 4];
    return allocator.dupeZ(u8, code);
}

pub fn getAvailableLanguages(g_arena: std.mem.Allocator, resource_path: []const u8) ![]LanguageInfo {
    var languages = std.ArrayList(LanguageInfo).init(g_arena);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const lang_dir = fs_helpers.joinStrings(&path_buffer, &.{
        resource_path,
        std.fs.path.sep_str,
        "langPacks",
    });

    var dir = std.fs.openDirAbsolute(lang_dir, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            std.fs.makeDirAbsolute(lang_dir) catch |make_err| {
                log.warn("Failed to create language directory: {s}, error: {s}", .{ lang_dir, @errorName(make_err) });
            };
            return try languages.toOwnedSlice();
        }
        log.warn("Failed to open language directory: {s}, error: {s}", .{ lang_dir, @errorName(err) });
        return try languages.toOwnedSlice();
    };
    defer dir.close();

    var iter = dir.iterate();
    iter_blk: {
        while (iter.next() catch |err| {
            log.warn("Error during directory iteration: {s}", .{@errorName(err)});
            break :iter_blk;
        }) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".ini")) continue;

            const display_name = getLanguageDisplayNameFromFile(g_arena, dir, entry.name) catch continue;
            const code = g_arena.dupeZ(u8, entry.name[0 .. entry.name.len - 4]) catch {
                log.warn("Failed to allocate memory for language code: {s}", .{entry.name});
                continue;
            };

            languages.append(.{
                .code = code,
                .display_name = display_name,
            }) catch |err| {
                log.warn("Failed to add language to list: {s}, error: {s}", .{ code, @errorName(err) });
                continue;
            };
        }
    }

    return try languages.toOwnedSlice();
}

/// Comptime-generic translation engine. Instantiate with a concrete key enum
/// and a StaticStringMap of default translations to get a complete translation
/// system (StringStore, TranslationStore, tr helper).
pub fn TranslationEngine(
    comptime Key: type,
    comptime default_strings: std.StaticStringMap([:0]const u8),
) type {
    return struct {
        pub const StringStore = struct {
            strings: std.ArrayListUnmanaged(u8),
            entries: [std.enums.directEnumArrayLen(Key, 1000)]Entry,

            const Entry = struct {
                offset: u32 = 0,
            };

            pub fn init() StringStore {
                return .{
                    .strings = .{},
                    .entries = std.enums.directEnumArrayDefault(Key, Entry, Entry{}, 1000, .{}),
                };
            }

            pub fn getString(self: *const StringStore, key: Key) [:0]const u8 {
                const index = @intFromEnum(key);
                const entry = self.entries[index];
                const start_slice = self.strings.items[entry.offset..];
                return start_slice[0..std.mem.indexOfScalar(u8, start_slice, 0).? :0];
            }

            pub fn loadDefaults(self: *StringStore, g_arena: std.mem.Allocator) !void {
                inline for (std.meta.fields(Key)) |field| {
                    const key = @field(Key, field.name);
                    if (default_strings.get(field.name)) |value| {
                        try self.addString(g_arena, key, value);
                    }
                }
            }

            pub fn addString(self: *StringStore, g_arena: std.mem.Allocator, key: Key, value: [:0]const u8) !void {
                const offset = self.strings.items.len;
                try self.strings.appendSlice(g_arena, value);
                try self.strings.append(g_arena, '\x00');
                const index = @intFromEnum(key);
                self.entries[index] = .{
                    .offset = @intCast(offset),
                };
            }

            pub fn loadFromFile(self: *StringStore, g_arena: std.mem.Allocator, path: []const u8) !void {
                var loaded_keys = std.enums.EnumArray(Key, bool).initFill(false);

                const file = try std.fs.openFileAbsolute(path, .{});
                defer file.close();

                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();

                var parser = ini.parse(arena.allocator(), file.reader());
                defer parser.deinit();

                var current_section: ?[]const u8 = null;
                var section_buf: [256:0]u8 = undefined;
                var buf: [256:0]u8 = undefined;
                while (try parser.next()) |record| {
                    switch (record) {
                        .section => |section| {
                            current_section = try std.fmt.bufPrintZ(&section_buf, "{s}", .{section});
                        },
                        .property => |kv| {
                            if (current_section) |section| {
                                const key_str = try std.fmt.bufPrintZ(&buf, "{s}_{s}", .{ section, kv.key });

                                if (std.meta.stringToEnum(Key, key_str)) |enum_key| {
                                    try self.addString(g_arena, enum_key, kv.value);
                                    loaded_keys.set(enum_key, true);
                                }
                            }
                        },
                        .enumeration => {},
                    }
                }

                // Fill missing keys from defaults
                var it = loaded_keys.iterator();
                while (it.next()) |entry| {
                    if (!entry.value.*) {
                        const missing_key = entry.key;
                        const key_name = @tagName(missing_key);
                        log.warn("Missing translation key: {s}", .{key_name});
                        if (default_strings.get(key_name)) |default_value| {
                            try self.addString(g_arena, missing_key, default_value);
                        }
                    }
                }
            }

            pub fn writeToFile(self: *const StringStore, writer: anytype) !void {
                var current_section: ?[]const u8 = null;

                var keys: [std.meta.fields(Key).len]Key = undefined;
                for (&keys, 0..) |*key, i| {
                    key.* = @enumFromInt(i);
                }
                std.sort.heap(Key, &keys, {}, struct {
                    fn lessThan(_: void, a: Key, b: Key) bool {
                        return std.mem.lessThan(u8, @tagName(a), @tagName(b));
                    }
                }.lessThan);

                for (keys) |key| {
                    const key_name = @tagName(key);
                    if (std.mem.indexOf(u8, key_name, "_")) |underscore_pos| {
                        const section = key_name[0..underscore_pos];

                        if (current_section == null or !std.mem.eql(u8, current_section.?, section)) {
                            if (current_section != null) try writer.writeByte('\n');
                            try writer.print("[{s}]\n", .{section});
                            current_section = section;
                        }

                        const value = self.getString(key);
                        const property = key_name[underscore_pos + 1 ..];
                        try writer.print("{s}={s}\n", .{ property, value });
                    }
                }
            }
        };

        pub const TranslationStore = struct {
            store: StringStore,
            current_language: []const u8,
            available_languages: []LanguageInfo,

            pub const empty: @This() = .{
                .store = .init(),
                .current_language = "en",
                .available_languages = &[_]LanguageInfo{},
            };

            pub fn defaults(arena: std.mem.Allocator) !@This() {
                var self: @This() = .empty;
                try self.store.loadDefaults(arena);
                return self;
            }

            pub fn init(g_arena: std.mem.Allocator, resource_path: []const u8, language: []const u8) !TranslationStore {
                const languages = try getAvailableLanguages(g_arena, resource_path);

                const requested_lang = blk: {
                    for (languages) |lang| {
                        if (std.mem.eql(u8, lang.code, language)) {
                            break :blk language;
                        }
                    }
                    log.warn("Language {s} not found, falling back to English", .{language});
                    break :blk "en";
                };

                var store = StringStore.init();

                var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
                const lang_file_path = fs_helpers.joinStrings(&path_buffer, &.{
                    resource_path,
                    std.fs.path.sep_str,
                    "langPacks",
                    std.fs.path.sep_str,
                    requested_lang,
                    ".ini",
                });

                store.loadFromFile(g_arena, lang_file_path) catch {
                    try store.loadDefaults(g_arena);
                };

                return .{
                    .store = store,
                    .current_language = requested_lang,
                    .available_languages = languages,
                };
            }

            pub fn getString(self: *const TranslationStore, key: Key) [:0]const u8 {
                return self.store.getString(key);
            }

            pub fn getLanguages(self: *const TranslationStore) []const LanguageInfo {
                return self.available_languages;
            }
        };

        pub fn tr(store: *const TranslationStore, key: Key) [:0]const u8 {
            return store.getString(key);
        }

        pub fn exportDefaultTranslations(allocator: std.mem.Allocator, path: []const u8) !void {
            var store = StringStore.init();
            try store.loadDefaults(allocator);

            const file = try std.fs.createFileAbsolute(path, .{});
            defer file.close();

            try file.writer().writeAll("[metadata]\nlanguage_name=Default\n\n");
            try store.writeToFile(file.writer());
        }
    };
}
