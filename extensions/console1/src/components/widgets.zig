const std = @import("std");
const imgui = @import("reaper_imgui");
const button = @import("button.zig");
const vertical_separator = @import("vertical_separator.zig");
const roundButtonWidget = button.roundButton;
const vSeparatorWidget = vertical_separator.vSeparator;

/// ```zig
/// ctx: imgui.ContextPtr,
/// label: [:0]const u8,
/// id: [:0]const u8,
/// tooltip: ?[:0]const u8,
/// provided_radius: ?f64,
/// text_pos: ?TextPosition,
/// disabled: ?bool,
/// color: ?c_int,
pub const roundButton = function(&roundButtonWidget, 3, &.{
    imgui.ContextPtr,
    [:0]const u8,
    [:0]const u8,
    ?[:0]const u8,
    ?f64,
    ?button.TextPosition,
    ?bool,
    ?c_int,
});

/// ```zig
/// ctx: imgui.ContextPtr,
/// color: c_int,
/// thickness: ?f64,
pub const vSeparator = function(&vSeparatorWidget, 2, &.{
    imgui.ContextPtr,
    c_int,
    ?f64,
});

fn funcType(comptime func: anytype) type {
    return switch (@typeInfo(@TypeOf(func))) {
        .@"fn" => @TypeOf(func),
        .pointer => |ptr| ptr.child,
        else => @compileError("Expected function or function pointer"),
    };
}

fn returnType(comptime func: anytype) type {
    return @typeInfo(funcType(func)).@"fn".return_type.?;
}

fn function(comptime func: anytype, min_argc: comptime_int, comptime arg_types: []const type) fn (args: anytype) callconv(.@"inline") returnType(func) {
    return struct {
        inline fn wrapper(args: anytype) returnType(func) {
            var cast_args: @Tuple(arg_types) = undefined;
            if (args.len < min_argc) {
                @compileError(std.fmt.comptimePrint("{s}: expected {}..{} arguments, got {}", .{ @typeName(@TypeOf(func.*)), min_argc, cast_args.len, args.len }));
            }

            inline for (0..cast_args.len) |i| {
                if (i >= args.len) {
                    cast_args[i] = null;
                    continue;
                }
                const arg_type = @typeInfo(@TypeOf(args[i]));
                comptime var cast_arg_type = @typeInfo(@TypeOf(cast_args[i]));
                if (cast_arg_type == .optional)
                    cast_arg_type = @typeInfo(cast_arg_type.optional.child);
                cast_args[i] = if (cast_arg_type == .int and
                    ((arg_type == .comptime_int and args[i] > std.math.maxInt(c_int)) or
                        (arg_type == .int and arg_type.int.signedness == .unsigned)))
                    @bitCast(@as(c_uint, args[i]))
                else
                    args[i];
            }

            var call_args: std.meta.ArgsTuple(funcType(func)) = undefined;
            inline for (0..call_args.len) |i| {
                const cast_arg_type = @typeInfo(@TypeOf(cast_args[i]));
                call_args[i] =
                    if (cast_arg_type == .optional)
                        if (cast_args[i]) |*arg_val|
                            if (@typeInfo(cast_arg_type.optional.child) == .pointer)
                                arg_val.*
                            else
                                arg_val.*
                        else
                            null
                    else
                        cast_args[i];
            }

            const rv = @call(.auto, func.*, call_args);
            return rv;
        }
    }.wrapper;
}
