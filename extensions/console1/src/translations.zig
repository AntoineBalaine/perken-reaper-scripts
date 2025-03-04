const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers.zig");
const Mode = @import("statemachine.zig").Mode;
const CCs = @import("c1.zig").CCs;
const log = std.log.scoped(.translations);

pub const TranslationKey = enum {

    // Additional non-CC keys for fx_ctrl
    fx_ctrl_title,
    fx_ctrl_reset,
    fx_ctrl_Comp_Attack,
    fx_ctrl_Comp_Release,
    fx_ctrl_Comp_DryWet,
    fx_ctrl_Comp_Ratio,
    fx_ctrl_Comp_Thresh,
    fx_ctrl_Comp_comp,
    fx_ctrl_Eq_HiFrq,
    fx_ctrl_Eq_HiGain,
    fx_ctrl_Eq_HiMidFrq,
    fx_ctrl_Eq_HiMidGain,
    fx_ctrl_Eq_HiMidQ,
    fx_ctrl_Eq_LoFrq,
    fx_ctrl_Eq_LoGain,
    fx_ctrl_Eq_LoMidFrq,
    fx_ctrl_Eq_LoMidGain,
    fx_ctrl_Eq_LoMidQ,
    fx_ctrl_Eq_eq,
    fx_ctrl_Eq_hp_shape,
    fx_ctrl_Eq_lp_shape,
    fx_ctrl_Inpt_Gain,
    fx_ctrl_Inpt_HiCut,
    fx_ctrl_Inpt_LoCut,
    fx_ctrl_Inpt_disp_mode,
    fx_ctrl_Inpt_disp_on,
    fx_ctrl_Inpt_filt_to_comp,
    fx_ctrl_Inpt_phase_inv,
    fx_ctrl_Inpt_preset,
    fx_ctrl_Inpt_MtrLft,
    fx_ctrl_Inpt_MtrRgt,
    fx_ctrl_Out_MtrLft,
    fx_ctrl_Out_MtrRgt,
    fx_ctrl_Shp_Mtr,
    fx_ctrl_Comp_Mtr,
    fx_ctrl_Out_Drive,
    fx_ctrl_Out_DriveChar,
    fx_ctrl_Out_Pan,
    fx_ctrl_Out_Vol,
    fx_ctrl_Out_mute,
    fx_ctrl_Out_solo,
    fx_ctrl_Shp_Gate,
    fx_ctrl_Shp_GateRelease,
    fx_ctrl_Shp_Punch,
    fx_ctrl_Shp_hard_gate,
    fx_ctrl_Shp_shape,
    fx_ctrl_Shp_sustain,
    fx_ctrl_Tr_ext_sidechain,
    fx_ctrl_Tr_order,
    fx_ctrl_Tr_pg_dn,
    fx_ctrl_Tr_pg_up,
    fx_ctrl_Tr_tr1,
    fx_ctrl_Tr_tr10,
    fx_ctrl_Tr_tr11,
    fx_ctrl_Tr_tr12,
    fx_ctrl_Tr_tr13,
    fx_ctrl_Tr_tr14,
    fx_ctrl_Tr_tr15,
    fx_ctrl_Tr_tr16,
    fx_ctrl_Tr_tr17,
    fx_ctrl_Tr_tr18,
    fx_ctrl_Tr_tr19,
    fx_ctrl_Tr_tr2,
    fx_ctrl_Tr_tr20,
    fx_ctrl_Tr_tr3,
    fx_ctrl_Tr_tr4,
    fx_ctrl_Tr_tr5,
    fx_ctrl_Tr_tr6,
    fx_ctrl_Tr_tr7,
    fx_ctrl_Tr_tr8,
    fx_ctrl_Tr_tr9,
    fx_ctrl_Tr_tr_copy,
    fx_ctrl_Tr_tr_grp,
    // Settings panel translations
    settings_title,
    settings_show_startup_message,
    settings_show_feedback_window,
    settings_show_plugin_ui,
    settings_manual_routing,
    settings_log_to_file,
    settings_start_suspended,
    settings_default_channel_strip,
    settings_none,
    settings_save,
    settings_cancel,
    settings_input,
    settings_gate,
    settings_eq,
    settings_comp,
    settings_output,
    settings_language_restart,
    settings_language,

    // Track List panel translations
    track_list_title,
    track_list_page,
    track_list_input_load,
    track_list_gate_load,
    track_list_eq_load,
    track_list_comp_load,
    track_list_output_load,
    track_list_settings,
    track_list_track_format,

    // FX Selection panel translations
    fx_sel_title,
    fx_sel_all_plugins,
    fx_sel_fx_chains,
    fx_sel_track_templates,
    fx_sel_container,
    fx_sel_video_processor,
    fx_sel_recent,
    fx_sel_rescan,
    fx_sel_done,
    fx_sel_Tr_tr1,
    fx_sel_Tr_tr2,
    fx_sel_Tr_tr3,
    fx_sel_Tr_tr4,
    fx_sel_Tr_tr5,
    fx_sel_Out_Vol,
    fx_sel_Out_solo,
    fx_sel_Out_mute,
    // Note: module type translations (input, gate, etc.) could be shared
    // with the settings panel if we want to avoid duplication

    // Mapping panel translations
    mapping_title,
    mapping_fx_parameters,
    mapping_console_controls,
    mapping_mapped,
    mapping_param_mapped,
    mapping_module_prefix,
    mapping_midi_learn,
    mapping_midi_learn_active,
    mapping_save,
    mapping_cancel,

    trsprt_Inpt_disp_mode,
    trsprt_Inpt_disp_on,
    trsprt_Inpt_HiCut,
    trsprt_Eq_eq,
    trsprt_Eq_lp_shape,
    trsprt_Eq_hp_shape,
    trsprt_Eq_LoGain,
    trsprt_Eq_LoMidGain,
    trsprt_Eq_HiMidGain,
    trsprt_Eq_HiGain,
    trsprt_Comp_comp,
    trsprt_Tr_tr1,
    trsprt_Tr_tr2,
    trsprt_Tr_tr3,
    trsprt_Tr_tr4,
    trsprt_Tr_tr5,
    trsprt_Tr_tr6,
    trsprt_Tr_tr7,
    trsprt_Tr_tr8,
    trsprt_Tr_tr9,
    trsprt_Tr_tr10,
    trsprt_Tr_tr17,
    trsprt_Tr_tr18,
    trsprt_Tr_tr19,
    trsprt_Tr_tr20,
    trsprt_Out_Vol,
    trsprt_Out_Drive,
    trsprt_Out_DriveChar,
    trsprt_Out_Pan,
    trsprt_Out_solo,
};

/// TODO: move default translations into an INI or zon file,
/// and embed into the code base.
const default_translations = std.StaticStringMap([:0]const u8).initComptime(.{
    .{ "mapping_title", "Mapping Panel" },
    .{ "mapping_fx_parameters", "FX Parameters" },
    .{ "mapping_console_controls", "Console Controls" },
    .{ "mapping_mapped", "(Mapped)" },
    .{ "mapping_param_mapped", "(-> Param {d})" },
    .{ "mapping_module_prefix", "Module: {s}" },
    .{ "mapping_midi_learn", "MIDI Learn" },
    .{ "mapping_midi_learn_active", "MIDI Learn (Active)" },
    .{ "mapping_save", "Save Mapping" },
    .{ "mapping_cancel", "Cancel" },
    .{ "mapping_module_input", "INPUT" },
    .{ "mapping_module_gate", "GATE" },
    .{ "mapping_module_eq", "EQ" },
    .{ "mapping_module_comp", "COMP" },
    .{ "mapping_module_output", "OUTPT" },
    .{ "fx_sel_title", "FX Browser" },
    .{ "fx_sel_all_plugins", "all plugins" },
    .{ "fx_sel_fx_chains", "fx chains" },
    .{ "fx_sel_track_templates", "track templates" },
    .{ "fx_sel_container", "Container" },
    .{ "fx_sel_video_processor", "Video processor" },
    .{ "fx_sel_recent", "recent: " },
    .{ "fx_sel_rescan", "Rescan plugin list" },
    .{ "fx_sel_done", "Done!" },
    .{ "fx_sel_Tr_tr1", "Input" },
    .{ "fx_sel_Tr_tr2", "Gate" },
    .{ "fx_sel_Tr_tr3", "Eq" },
    .{ "fx_sel_Tr_tr4", "Comp" },
    .{ "fx_sel_Tr_tr5", "Outpt" },
    .{ "fx_sel_Out_Vol", "Scroll" },
    .{ "fx_sel_Out_solo", "Select" },
    .{ "fx_sel_Out_mute", "Cancel" },
    .{ "track_list_title", "Track List" },
    .{ "track_list_page", "Page {d}" },
    .{ "track_list_input_load", "Input Load" },
    .{ "track_list_gate_load", "Gate Load" },
    .{ "track_list_eq_load", "EQ Load" },
    .{ "track_list_comp_load", "Comp Load" },
    .{ "track_list_output_load", "Output Load" },
    .{ "track_list_settings", "Settings" },
    .{ "track_list_track_format", "{d:>2}. {s}" },
    .{ "fx_ctrl_title", "FX Control" },
    .{ "fx_ctrl_reset", "Reset" },
    .{ "fx_ctrl_Comp_Attack", "Attack" },
    .{ "fx_ctrl_Comp_Release", "Release" },
    .{ "fx_ctrl_Comp_DryWet", "DryWet" },
    .{ "fx_ctrl_Comp_Ratio", "Ratio" },
    .{ "fx_ctrl_Comp_Thresh", "Thresh" },
    .{ "fx_ctrl_Comp_comp", "Compressor" },
    .{ "fx_ctrl_Eq_HiFrq", "HiFrq" },
    .{ "fx_ctrl_Eq_HiGain", "HiGain" },
    .{ "fx_ctrl_Eq_HiMidFrq", "HiMidFrq" },
    .{ "fx_ctrl_Eq_HiMidGain", "HiMidGain" },
    .{ "fx_ctrl_Eq_HiMidQ", "HiMidQ" },
    .{ "fx_ctrl_Eq_LoFrq", "LoFrq" },
    .{ "fx_ctrl_Eq_LoGain", "LoGain" },
    .{ "fx_ctrl_Eq_LoMidFrq", "LoMidFrq" },
    .{ "fx_ctrl_Eq_LoMidGain", "LoMidGain" },
    .{ "fx_ctrl_Eq_LoMidQ", "LoMidQ" },
    .{ "fx_ctrl_Eq_eq", "EQ" },
    .{ "fx_ctrl_Eq_hp_shape", "Hi Shape" },
    .{ "fx_ctrl_Eq_lp_shape", "Lo Shape" },
    .{ "fx_ctrl_Inpt_Gain", "Gain" },
    .{ "fx_ctrl_Inpt_HiCut", "HiCut" },
    .{ "fx_ctrl_Inpt_LoCut", "LoCut" },
    .{ "fx_ctrl_Inpt_disp_mode", "Mode" },
    .{ "fx_ctrl_Inpt_disp_on", "On" },
    .{ "fx_ctrl_Inpt_filt_to_comp", "Filters to Comp" },
    .{ "fx_ctrl_Inpt_phase_inv", "Phase Inv." },
    .{ "fx_ctrl_Inpt_preset", "Preset" },
    .{ "fx_ctrl_Inpt_MtrLft", "MtrLft" },
    .{ "fx_ctrl_Inpt_MtrRgt", "MtrRgt" },
    .{ "fx_ctrl_Out_MtrLft", "MtrLft" },
    .{ "fx_ctrl_Out_MtrRgt", "MtrRgt" },
    .{ "fx_ctrl_Shp_Mtr", "Mtr" },
    .{ "fx_ctrl_Comp_Mtr", "Mtr" },
    .{ "fx_ctrl_Out_Drive", "Drive" },
    .{ "fx_ctrl_Out_DriveChar", "Character" },
    .{ "fx_ctrl_Out_Pan", "Pan" },
    .{ "fx_ctrl_Out_Vol", "Vol" },
    .{ "fx_ctrl_Out_mute", "Mute" },
    .{ "fx_ctrl_Out_solo", "Solo" },
    .{ "fx_ctrl_Shp_Gate", "Gate" },
    .{ "fx_ctrl_Shp_GateRelease", "Release" },
    .{ "fx_ctrl_Shp_Punch", "Punch" },
    .{ "fx_ctrl_Shp_hard_gate", "Hard Gate" },
    .{ "fx_ctrl_Shp_shape", "SHAPE" },
    .{ "fx_ctrl_Shp_sustain", "sustain" },
    .{ "fx_ctrl_Tr_ext_sidechain", "SC" },
    .{ "fx_ctrl_Tr_order", "Order" },
    .{ "fx_ctrl_Tr_pg_dn", "Pg Dn" },
    .{ "fx_ctrl_Tr_pg_up", "Pg Up" },
    .{ "fx_ctrl_Tr_tr1", "Tr1" },
    .{ "fx_ctrl_Tr_tr10", "Tr10" },
    .{ "fx_ctrl_Tr_tr11", "Tr11" },
    .{ "fx_ctrl_Tr_tr12", "Tr12" },
    .{ "fx_ctrl_Tr_tr13", "Tr13" },
    .{ "fx_ctrl_Tr_tr14", "Tr14" },
    .{ "fx_ctrl_Tr_tr15", "Tr15" },
    .{ "fx_ctrl_Tr_tr16", "Tr16" },
    .{ "fx_ctrl_Tr_tr17", "Tr17" },
    .{ "fx_ctrl_Tr_tr18", "Tr18" },
    .{ "fx_ctrl_Tr_tr19", "Tr19" },
    .{ "fx_ctrl_Tr_tr2", "Tr2" },
    .{ "fx_ctrl_Tr_tr20", "Tr20" },
    .{ "fx_ctrl_Tr_tr3", "Tr3" },
    .{ "fx_ctrl_Tr_tr4", "Tr4" },
    .{ "fx_ctrl_Tr_tr5", "Tr5" },
    .{ "fx_ctrl_Tr_tr6", "Tr6" },
    .{ "fx_ctrl_Tr_tr7", "Tr7" },
    .{ "fx_ctrl_Tr_tr8", "Tr8" },
    .{ "fx_ctrl_Tr_tr9", "Tr9" },
    .{ "fx_ctrl_Tr_tr_copy", "Copy" },
    .{ "fx_ctrl_Tr_tr_grp", "Grp" },
    .{ "settings_title", "Settings" },
    .{ "settings_show_startup_message", "Show Startup Message" },
    .{ "settings_show_feedback_window", "Show Feedback Window" },
    .{ "settings_show_plugin_ui", "Show Plugin UI" },
    .{ "settings_manual_routing", "Manual Routing" },
    .{ "settings_log_to_file", "Log to File" },
    .{ "settings_start_suspended", "Start extension suspended" },
    .{ "settings_default_channel_strip", "Default Channel Strip" },
    .{ "settings_none", "none" },
    .{ "settings_save", "Save" },
    .{ "settings_cancel", "Cancel" },
    .{ "settings_input", "INPUT" },
    .{ "settings_gate", "GATE" },
    .{ "settings_eq", "EQ" },
    .{ "settings_comp", "COMP" },
    .{ "settings_output", "OUTPT" },
    .{ "settings_language_restart", "Language change requires restart" },
    .{ "settings_language", "Language" },
    .{ "trsprt_Inpt_disp_mode", "Mode" },
    .{ "trsprt_Inpt_disp_on", "Hide" },
    .{ "trsprt_Inpt_HiCut", "Rate" },
    .{ "trsprt_Eq_eq", "Loop" },
    .{ "trsprt_Eq_lp_shape", "Loop Strt" },
    .{ "trsprt_Eq_hp_shape", "Loop End" },
    .{ "trsprt_Eq_LoGain", "Scrub" },
    .{ "trsprt_Eq_LoMidGain", "Jog" },
    .{ "trsprt_Eq_HiMidGain", "Jog Mrkr" },
    .{ "trsprt_Eq_HiGain", "Jog Itm" },
    .{ "trsprt_Comp_comp", "Mrkr Set" },
    .{ "trsprt_Tr_tr1", "Input" },
    .{ "trsprt_Tr_tr2", "Gate" },
    .{ "trsprt_Tr_tr3", "Eq" },
    .{ "trsprt_Tr_tr4", "Comp" },
    .{ "trsprt_Tr_tr5", "Outpt" },
    .{ "trsprt_Tr_tr6", "Auto Trim" },
    .{ "trsprt_Tr_tr7", "Auto Read" },
    .{ "trsprt_Tr_tr8", "Auto Latch" },
    .{ "trsprt_Tr_tr9", "Auto Preview" },
    .{ "trsprt_Tr_tr10", "Auto Write" },
    .{ "trsprt_Tr_tr17", "Play" },
    .{ "trsprt_Tr_tr18", "Stop" },
    .{ "trsprt_Tr_tr19", "Rec" },
    .{ "trsprt_Tr_tr20", "Settings" },
    .{ "trsprt_Out_Vol", "Tr slct" },
    .{ "trsprt_Out_Drive", "Zoom H" },
    .{ "trsprt_Out_DriveChar", "Zoom V" },
    .{ "trsprt_Out_Pan", "Grid" },
    .{ "trsprt_Out_solo", "Snap" },
});

pub const StringStore = struct {
    strings: std.ArrayListUnmanaged(u8),
    entries: [std.enums.directEnumArrayLen(TranslationKey, 1000)]Entry,

    const Entry = struct {
        offset: u32 = 0,
        length: u16 = 0,
    };

    pub fn init() StringStore {
        return .{
            .strings = .{},
            .entries = std.enums.directEnumArrayDefault(TranslationKey, Entry, Entry{}, 1000, .{}),
        };
    }

    pub fn getString(self: *const StringStore, key: TranslationKey) [:0]const u8 {
        const index = @intFromEnum(key);
        const entry = self.entries[index];
        // Convert the string to a sentinel-terminated string
        return @ptrCast(self.strings.items[entry.offset .. entry.offset + entry.length]);
    }

    fn loadDefaults(self: *StringStore, g_arena: std.mem.Allocator) !void {
        // Iterate over all possible translation keys
        inline for (std.meta.fields(TranslationKey)) |field| {
            const key = @field(TranslationKey, field.name);
            if (default_translations.get(field.name)) |value| {
                try self.addString(g_arena, key, value);
            }
        }
    }

    fn addString(self: *StringStore, g_arena: std.mem.Allocator, key: TranslationKey, value: []const u8) !void {
        const offset = self.strings.items.len;
        try self.strings.appendSlice(g_arena, value);
        const index = @intFromEnum(key);
        self.entries[index] = .{
            .offset = @intCast(offset),
            .length = @intCast(value.len),
        };
    }

    fn loadFromFile(self: *StringStore, g_arena: std.mem.Allocator, path: []const u8) !void {
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        var parser = ini.parse(arena.allocator(), file.reader());
        defer parser.deinit();

        var current_section: ?[]const u8 = null;

        while (try parser.next()) |record| {
            switch (record) {
                .section => |section| {
                    current_section = section;
                },
                .property => |kv| {
                    if (current_section) |section| {
                        // Construct key string
                        const key_str = try std.fmt.allocPrint(arena.allocator(), "{s}_{s}", .{ section, kv.key });

                        // Try to convert to enum
                        if (std.meta.stringToEnum(TranslationKey, key_str)) |enum_key| {
                            try self.addString(g_arena, enum_key, kv.value);
                        }
                    }
                },
                .enumeration => {},
            }
        }
    }

    pub fn writeToFile(self: *const StringStore, writer: anytype) !void {
        var current_section: ?[]const u8 = null;

        // Pre-sort the keys to ensure consistent output
        var keys: [std.meta.fields(TranslationKey).len]TranslationKey = undefined;
        for (&keys, 0..) |*key, i| {
            key.* = @enumFromInt(i);
        }
        std.sort.heap(TranslationKey, &keys, {}, struct {
            fn lessThan(_: void, a: TranslationKey, b: TranslationKey) bool {
                return std.mem.lessThan(u8, @tagName(a), @tagName(b));
            }
        }.lessThan);

        // Write sorted keys
        for (keys) |key| {
            const key_name = @tagName(key);
            if (std.mem.indexOf(u8, key_name, "_")) |underscore_pos| {
                const section = key_name[0..underscore_pos];

                // Write section header if needed
                if (current_section == null or !std.mem.eql(u8, current_section.?, section)) {
                    if (current_section != null) try writer.writeByte('\n');
                    try writer.print("[{s}]\n", .{section});
                    current_section = section;
                }

                // Write key-value pair
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

    pub fn init(g_arena: std.mem.Allocator, resource_path: []const u8, language: []const u8) !TranslationStore {
        // First get available languages
        const languages = try getAvailableLanguages(g_arena, resource_path);

        // Verify the requested language exists, fallback to "en" if not
        const requested_lang = blk: {
            for (languages) |lang| {
                if (std.mem.eql(u8, lang.code, language)) {
                    break :blk language;
                }
            }
            // Language not found, fallback to English
            log.warn("Language {s} not found, falling back to English", .{language});
            break :blk "en";
        };

        var store = StringStore.init();

        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const lang_file_path = fs_helpers.joinStrings(&path_buffer, &.{
            resource_path,
            "langPacks",
            requested_lang,
            ".ini",
        });

        store.loadFromFile(g_arena, lang_file_path) catch |err| {
            if (!std.mem.eql(u8, language, "en")) {
                try store.loadDefaults(g_arena);
            } else {
                return err;
            }
        };

        return .{
            .store = store,
            .current_language = requested_lang,
            .available_languages = languages,
        };
    }

    pub fn getString(self: *const TranslationStore, key: TranslationKey) [:0]const u8 {
        return self.store.getString(key);
    }

    pub fn getLanguages(self: *const TranslationStore) []const LanguageInfo {
        return self.available_languages;
    }
};

// Helper function
pub fn tr(store: *const TranslationStore, key: TranslationKey) [:0]const u8 {
    return store.getString(key);
}

/// Utility function to export default translations to an INI file
/// This is useful for creating new language packs
pub fn exportDefaultTranslations(allocator: std.mem.Allocator, path: []const u8) !void {
    var store = StringStore.init();
    try store.loadDefaults(allocator);

    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();

    // Add metadata section
    try file.writer().writeAll("[metadata]\nlanguage_name=Default\n\n");

    // Write all translations
    try store.writeToFile(file.writer());
}

pub const LanguageInfo = struct {
    code: [:0]const u8, // "en", "fr", etc.
    display_name: [:0]const u8, // "English", "Français", etc.
};

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

pub fn getAvailableLanguages(g_allocator: std.mem.Allocator, resource_path: []const u8) ![]LanguageInfo {
    var languages = std.ArrayList(LanguageInfo).init(g_allocator);
    errdefer languages.deinit();

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const lang_dir = fs_helpers.joinStrings(&path_buffer, &.{
        resource_path,
        "langPacks",
    });

    var dir = try std.fs.openDirAbsolute(lang_dir, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".ini")) continue;

        const code = try g_allocator.dupeZ(u8, entry.name[0 .. entry.name.len - 4]);
        const display_name = try getLanguageDisplayNameFromFile(g_allocator, dir, entry.name);

        try languages.append(.{
            .code = code,
            .display_name = display_name,
        });
    }

    return languages.toOwnedSlice();
}
