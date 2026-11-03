const std = @import("std");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const ModulesList = statemachine.ModulesList;
const c1 = @import("c1.zig");
const reentrancy = @import("reentrancy.zig");
pub const debug_window_active = @import("builtin").mode == .debug;

// pub var debug_window_active = debugconfig.@"test";
pub var log_file: ?*std.Io.File = null; // Just need the file handle

pub const EventType = enum {
    state_change,
    midi_input,
    parameter_update,
    // etc.
};

pub const Event = union(EventType) {
    state_change: struct {
        old_mode: Mode,
        new_mode: Mode,
    },
    midi_input: struct {
        cc: c1.CCs,
        value: u8,
    },
    parameter_update: struct {
        module: ModulesList,
        param: u32,
        value: f64,
    },

    pub fn format(
        self: Event,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .state_change => |state| {
                try writer.print("State: {s} -> {s}", .{
                    @tagName(state.old_mode),
                    @tagName(state.new_mode),
                });
            },
            .midi_input => |midi| {
                try writer.print("MIDI CC {s}: {d}", .{
                    @tagName(midi.cc),
                    midi.value,
                });
            },
            .parameter_update => |param| {
                try writer.print("Parameter {s}.{d}: {d}", .{
                    @tagName(param.module),
                    param.param,
                    param.value,
                });
            },
        }
    }
};

const Color = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    const green = "\x1b[0;32m";
    // Add more colors as needed
};

test {
    std.testing.refAllDecls(@This());
}

// FIXME: set as main app log level
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Check if any argument is an Event
    {
        if (scope == .reentrancy) {
            const Args = @TypeOf(args);
            const args_type_info = @typeInfo(Args);
            if (args_type_info == .@"struct") {
                inline for (args_type_info.@"struct".field_names, args_type_info.@"struct".field_types) |field_name, field_type| {
                    if (field_type == reentrancy.ReentrancyMessage) {
                        if (reentrancy.current_test) |test_| {
                            switch (@field(args, field_name)) {
                                .notification => |notif| test_.notifications.append(test_.allocator, notif) catch return,
                                .api_call => {
                                    // Optionally handle logging of API calls
                                    // This might be useful for debugging/verification
                                },
                            }
                        }
                    }
                }
            }
        }
    }

    const scope_prefix = "(" ++ switch (scope) {
        .gpa, // general purpose allocator
        .DebugAllocator, // the debug allocator's own scope since Zig 0.14
        .csurf,
        .dispatch,
        .extension,
        .fx_sel_actions,
        .imgui_loop,
        .mapping_actions,
        .mapping_list,
        .mappings,
        .midi_input,
        .parameters,
        .preferences,
        .save_preset_dialog,
        .settings,
        .presets,
        .unit,
        .fx_presets,
        .track_list,
        .midi_output,
        .fs_helpers,
        .hooks,
        .validation,
        .globals,
        .transport,
        .default_fx_sel_actions,
        .fx_sel_panel,
        .sws,
        .tests,
        .test_api,
        => @tagName(scope),
        .default => @tagName(scope),
        .reentrancy => "",
        .translations => @tagName(scope),
        .hotreload => @tagName(scope),
        else => @compileError("Unknown scope type: " ++ @tagName(scope)),
    } ++ "): ";

    const color = switch (level) {
        .debug => Color.blue,
        .info => Color.green,
        .warn => Color.yellow,
        .err => Color.red,
    };

    const prefix = color ++ "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    // Because the locked stderr writer is buffered, unlockStderr flushes what the print left in the buffer.
    var buffer: [256]u8 = undefined;
    const locked = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    const stderr = &locked.file_writer.interface;
    stderr.print(prefix ++ format ++ Color.reset ++ "\n", args) catch return;

    // File logging
    if (log_file) |file| {
        const message = std.fmt.allocPrint(
            logging_allocator,
            "[{s}]{s}" ++ format ++ "\n",
            .{ @tagName(level), scope_prefix } ++ args,
        ) catch return;
        defer logging_allocator.free(message);
        // Because the log function has no io parameter, it writes with the extension's.
        file.writeStreamingAll(@import("globals.zig").hostIo(), message) catch {};
    }
}

var arena: std.heap.ArenaAllocator = undefined;
var logging_allocator: std.mem.Allocator = undefined;

pub fn init() void {
    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    logging_allocator = arena.allocator();
}

pub fn deinit() void {
    arena.deinit();
}
