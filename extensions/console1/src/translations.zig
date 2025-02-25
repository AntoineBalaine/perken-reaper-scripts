const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers.zig");
const Mode = @import("statemachine.zig").Mode;
const CCs = @import("c1.zig").CCs;

pub const TranslationKey = enum(u16) {
    // FX Control Panel keys - mapping directly from CCs
    Comp_Attack,
    Comp_DryWet,
    Comp_Ratio,
    Comp_Release,
    Comp_Thresh,
    Comp_comp,
    Eq_HiFrq,
    Eq_HiGain,
    Eq_HiMidFrq,
    Eq_HiMidGain,
    Eq_HiMidQ,
    Eq_LoFrq,
    Eq_LoGain,
    Eq_LoMidFrq,
    Eq_LoMidGain,
    Eq_LoMidQ,
    Eq_eq,
    Eq_hp_shape,
    Eq_lp_shape,
    Inpt_Gain,
    Inpt_HiCut,
    Inpt_LoCut,
    Inpt_disp_mode,
    Inpt_disp_on,
    Inpt_filt_to_comp,
    Inpt_phase_inv,
    Inpt_preset,
    Out_Drive,
    Out_DriveChar,
    Out_Pan,
    Out_Vol,
    Out_mute,
    Out_solo,
    Shp_Gate,
    Shp_GateRelease,
    Shp_Punch,
    Shp_hard_gate,
    Shp_shape,
    Shp_sustain,
    Tr_ext_sidechain,
    Tr_order,

    // Additional non-CC keys for fx_ctrl
    fx_ctrl_title,
    fx_ctrl_reset,

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
};

const TranslationsData = struct {
    fx_ctrl: struct {
        // Direct mappings from CCs
        Comp_Attack: []const u8,
        Comp_DryWet: []const u8,
        Comp_Ratio: []const u8,
        Comp_Release: []const u8,
        Comp_Thresh: []const u8,
        Comp_comp: []const u8,
        Eq_HiFrq: []const u8,
        Eq_HiGain: []const u8,
        Eq_HiMidFrq: []const u8,
        Eq_HiMidGain: []const u8,
        Eq_HiMidQ: []const u8,
        Eq_LoFrq: []const u8,
        Eq_LoGain: []const u8,
        Eq_LoMidFrq: []const u8,
        Eq_LoMidGain: []const u8,
        Eq_LoMidQ: []const u8,
        Eq_eq: []const u8,
        Eq_hp_shape: []const u8,
        Eq_lp_shape: []const u8,
        Inpt_Gain: []const u8,
        Inpt_HiCut: []const u8,
        Inpt_LoCut: []const u8,
        Inpt_disp_mode: []const u8,
        Inpt_disp_on: []const u8,
        Inpt_filt_to_comp: []const u8,
        Inpt_phase_inv: []const u8,
        Inpt_preset: []const u8,
        Out_Drive: []const u8,
        Out_DriveChar: []const u8,
        Out_Pan: []const u8,
        Out_Vol: []const u8,
        Out_mute: []const u8,
        Out_solo: []const u8,
        Shp_Gate: []const u8,
        Shp_GateRelease: []const u8,
        Shp_Punch: []const u8,
        Shp_hard_gate: []const u8,
        Shp_shape: []const u8,
        Shp_sustain: []const u8,
        Tr_ext_sidechain: []const u8,
        Tr_order: []const u8,

        // Additional strings
        title: []const u8,
        reset: []const u8,
    },
    settings: struct {
        // UI Settings
        title: []const u8, // "Settings"
        show_startup_message: []const u8, // "Show Startup Message"
        show_feedback_window: []const u8, // "Show Feedback Window"
        show_plugin_ui: []const u8, // "Show Plugin UI"

        // Routing Settings
        manual_routing: []const u8, // "Manual Routing"

        // Logging Settings
        log_to_file: []const u8, // "Log to File"
        start_suspended: []const u8, // "Start extension suspended"

        // Default Channel Strip section
        default_channel_strip: []const u8, // "Default Channel Strip"
        none: []const u8, // "none" (used in combo boxes)

        // Buttons
        save: []const u8, // "Save"
        cancel: []const u8, // "Cancel"

        // Module names (used in combo boxes)
        input: []const u8, // "INPUT"
        gate: []const u8, // "GATE"
        eq: []const u8, // "EQ"
        comp: []const u8, // "COMP"
        output: []const u8, // "OUTPT"
    },
    track_list: struct {
        // Window title
        title: []const u8, // "Track List"

        // Page indicator
        page: []const u8, // "Page {d}"

        // Module browser labels (used when modifier is active)
        input_load: []const u8, // "Input Load"
        gate_load: []const u8, // "Gate Load"
        eq_load: []const u8, // "EQ Load"
        comp_load: []const u8, // "Comp Load"
        output_load: []const u8, // "Output Load"
        settings: []const u8, // "Settings"

        // Track format string
        track_format: []const u8, // "{d:>2}. {s}" - might want to make this configurable
    },

    fx_sel: struct {
        // Window and section titles
        title: []const u8, // "FX Browser"
        all_plugins: []const u8, // "all plugins"
        fx_chains: []const u8, // "fx chains"
        track_templates: []const u8, // "track templates"

        // Special items
        container: []const u8, // "Container"
        video_processor: []const u8, // "Video processor"
        recent: []const u8, // "recent: "

        // Buttons and controls
        rescan: []const u8, // "Rescan plugin list"
        done: []const u8, // "Done!"

        // Module types (might overlap with settings panel)
        input: []const u8, // "INPUT"
        gate: []const u8, // "GATE"
        eq: []const u8, // "EQ"
        comp: []const u8, // "COMP"
        output: []const u8, // "OUTPT"
    },

    mapping: struct {
        // Window and section titles
        title: []const u8, // "Mapping Panel"
        fx_parameters: []const u8, // "FX Parameters"
        console_controls: []const u8, // "Console Controls"

        // Status indicators
        mapped: []const u8, // "(Mapped)"
        param_mapped: []const u8, // "(-> Param {d})"
        module_prefix: []const u8, // "Module: {s}"

        // MIDI learn states
        midi_learn: []const u8, // "MIDI Learn"
        midi_learn_active: []const u8, // "MIDI Learn (Active)"

        // Buttons
        save: []const u8, // "Save Mapping"
        cancel: []const u8, // "Cancel"

        // Module names could be shared with other panels
        module_input: []const u8, // "INPUT"
        module_gate: []const u8, // "GATE"
        module_eq: []const u8, // "EQ"
        module_comp: []const u8, // "COMP"
        module_output: []const u8, // "OUTPT"
    },
};

const default_translations: TranslationsData = .{
    .mapping = .{
        .title = "Mapping Panel",
        .fx_parameters = "FX Parameters",
        .console_controls = "Console Controls",
        .mapped = "(Mapped)",
        .param_mapped = "(-> Param {d})",
        .module_prefix = "Module: {s}",
        .midi_learn = "MIDI Learn",
        .midi_learn_active = "MIDI Learn (Active)",
        .save = "Save Mapping",
        .cancel = "Cancel",
        .module_input = "INPUT",
        .module_gate = "GATE",
        .module_eq = "EQ",
        .module_comp = "COMP",
        .module_output = "OUTPT",
    },
    .fx_sel = .{
        .title = "FX Browser",
        .all_plugins = "all plugins",
        .fx_chains = "fx chains",
        .track_templates = "track templates",
        .container = "Container",
        .video_processor = "Video processor",
        .recent = "recent: ",
        .rescan = "Rescan plugin list",
        .done = "Done!",
        .input = "INPUT",
        .gate = "GATE",
        .eq = "EQ",
        .comp = "COMP",
        .output = "OUTPT",
    },
    .track_list = .{
        .title = "Track List",
        .page = "Page {d}",
        .input_load = "Input Load",
        .gate_load = "Gate Load",
        .eq_load = "EQ Load",
        .comp_load = "Comp Load",
        .output_load = "Output Load",
        .settings = "Settings",
        .track_format = "{d:>2}. {s}",
    },
    .fx_ctrl = .{
        .Comp_Attack = "Attack",
        .Comp_DryWet = "Dry/Wet",
        .Comp_Ratio = "Ratio",
        .Comp_Release = "Release",
        .Comp_Thresh = "Threshold",
        .Comp_comp = "Compressor",
        .Eq_HiFrq = "High Freq",
        .Eq_HiGain = "High Gain",
        .Eq_HiMidFrq = "High Mid Freq",
        .Eq_HiMidGain = "High Mid Gain",
        .Eq_HiMidQ = "High Mid Q",
        .Eq_LoFrq = "Low Freq",
        .Eq_LoGain = "Low Gain",
        .Eq_LoMidFrq = "Low Mid Freq",
        .Eq_LoMidGain = "Low Mid Gain",
        .Eq_LoMidQ = "Low Mid Q",
        .Eq_eq = "EQ",
        .Eq_hp_shape = "High Shape",
        .Eq_lp_shape = "Low Shape",
        .Inpt_Gain = "Gain",
        .Inpt_HiCut = "High Cut",
        .Inpt_LoCut = "Low Cut",
        .Inpt_disp_mode = "Display Mode",
        .Inpt_disp_on = "Display On",
        .Inpt_filt_to_comp = "Filter to Comp",
        .Inpt_phase_inv = "Phase Invert",
        .Inpt_preset = "Preset",
        .Out_Drive = "Drive",
        .Out_DriveChar = "Character",
        .Out_Pan = "Pan",
        .Out_Vol = "Volume",
        .Out_mute = "Mute",
        .Out_solo = "Solo",
        .Shp_Gate = "Gate",
        .Shp_GateRelease = "Gate Release",
        .Shp_Punch = "Punch",
        .Shp_hard_gate = "Hard Gate",
        .Shp_shape = "Shape",
        .Shp_sustain = "Sustain",
        .Tr_ext_sidechain = "Sidechain",
        .Tr_order = "Order",

        .title = "FX Control",
        .reset = "Reset",
    },
    .settings = .{
        .title = "Settings",
        .show_startup_message = "Show Startup Message",
        .show_feedback_window = "Show Feedback Window",
        .show_plugin_ui = "Show Plugin UI",
        .manual_routing = "Manual Routing",
        .log_to_file = "Log to File",
        .start_suspended = "Start extension suspended",
        .default_channel_strip = "Default Channel Strip",
        .none = "none",
        .save = "Save",
        .cancel = "Cancel",
        .input = "INPUT",
        .gate = "GATE",
        .eq = "EQ",
        .comp = "COMP",
        .output = "OUTPT",
    },
};

pub const StringStore = struct {
    strings: std.ArrayListUnmanaged(u8),
    entries: std.enums.DirectEnumArray(TranslationKey, Entry, 0, .{}),

    const Entry = struct {
        offset: u32,
        length: u16,
    };

    pub fn init() StringStore {
        return .{
            .strings = .{},
            .entries = std.enums.DirectEnumArray(TranslationKey, Entry, 0, .{}).init(.{}),
        };
    }

    pub fn getString(self: *const StringStore, key: TranslationKey) []const u8 {
        const entry = self.entries.get(key);
        return self.strings.items[entry.offset .. entry.offset + entry.length];
    }

    fn loadDefaults(self: *StringStore, g_arena: std.mem.Allocator) !void {
        inline for (@typeInfo(TranslationsData).Struct.fields) |field| {
            const section = @field(default_translations, field.name);
            inline for (@typeInfo(@TypeOf(section)).Struct.fields) |subfield| {
                const value = @field(section, subfield.name);
                const key = comptime if (std.mem.eql(u8, field.name, "fx_ctrl"))
                    @field(TranslationKey, subfield.name)
                else
                    @field(TranslationKey, field.name ++ "_" ++ subfield.name);
                try self.addString(g_arena, key, value);
            }
        }
    }

    fn addString(self: *StringStore, g_arena: std.mem.Allocator, key: TranslationKey, value: []const u8) !void {
        const offset = self.strings.items.len;
        try self.strings.appendSlice(g_arena, value);
        self.entries.set(key, .{
            .offset = @intCast(offset),
            .length = @intCast(value.len),
        });
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
                        const key_str = if (std.mem.eql(u8, section, "fx_ctrl"))
                            kv.key
                        else
                            section ++ "_" ++ kv.key;

                        if (std.meta.stringToEnum(TranslationKey, key_str)) |key| {
                            try self.addString(g_arena, key, kv.value);
                        }
                    }
                },
                .enumeration => {},
            }
        }
    }
};

pub const TranslationStore = struct {
    store: StringStore,
    current_language: []const u8,

    pub fn init(g_arena: std.mem.Allocator, resource_path: []const u8, language: []const u8) !TranslationStore {
        var store = StringStore.init();

        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const lang_file_path = fs_helpers.joinStrings(&path_buffer, &.{
            resource_path,
            "langPacks",
            language,
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
            .current_language = language,
        };
    }

    pub fn getString(self: *const TranslationStore, key: TranslationKey) []const u8 {
        return self.store.getString(key);
    }
};

// Helper function
pub fn tr(store: *const TranslationStore, key: TranslationKey) []const u8 {
    return store.getString(key);
}
