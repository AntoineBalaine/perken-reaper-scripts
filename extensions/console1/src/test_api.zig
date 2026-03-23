// Lua-callable API functions exposed to REAPER in test mode.
// Because the UI library is hot-reloadable and crashes don't bring down
// REAPER, we need a way to trigger mode transitions and inspect state
// from Lua scripts (via the TCP server) for headless end-to-end testing.
//
// REAPER requires three registrations per Lua-accessible function:
//   plugin_register("API_<name>", fn_ptr)        -- the C function
//   plugin_register("APIvararg_<name>", vararg)   -- vararg wrapper for Lua/EEL
//   plugin_register("APIdef_<name>", def_str)     -- signature string
//
// The vararg wrapper has the signature: void* fn(void** arglist, int numparms)
// It unpacks the arglist and calls the real function.

const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const actions = @import("actions.zig");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;
const imgui_loop = @import("imgui_loop.zig");
const getGlobals = @import("console1_extension.zig").getGlobals;
const log = std.log.scoped(.test_api);

// -- C1_GetMode: returns the current mode name as a string --

fn apiGetMode() callconv(.C) [*:0]const u8 {
    const globals = getGlobals();
    return @tagName(globals.state.current_mode);
}

fn varargGetMode(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = .{ arglist, numparms };
    const result = apiGetMode();
    return @ptrCast(@constCast(result));
}

const apidef_GetMode: [*:0]const u8 = "const char*\x00\x00\x00Console1: Returns the current mode name.\x00";

// -- C1_ChangeMode: triggers a mode transition by name --

fn apiChangeMode(mode_name: [*:0]const u8) callconv(.C) bool {
    const name = std.mem.span(mode_name);
    const mode = std.meta.stringToEnum(Mode, name) orelse {
        log.err("C1_ChangeMode: unknown mode '{s}'", .{name});
        return false;
    };
    log.info("C1_ChangeMode: switching to '{s}'", .{name});
    actions.dispatch(getGlobals(), .{ .change_mode = mode });
    return true;
}

fn varargChangeMode(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = numparms;
    const args = arglist orelse return null;
    const mode_name: [*:0]const u8 = @ptrCast(args.* orelse return null);
    const result = apiChangeMode(mode_name);
    // Because REAPER expects a void* return for bool, we return 1 or 0 cast to pointer.
    return if (result) @ptrFromInt(1) else @ptrFromInt(0);
}

const apidef_ChangeMode: [*:0]const u8 = "bool\x00const char*\x00mode_name\x00Console1: Triggers a mode transition. Valid modes: fx_ctrl, fx_sel, transport, mapping_panel, settings, suspended.\x00";

// -- C1_FxSelScroll: sends a scroll value to the FX selection panel --

fn apiFxSelScroll(value: c_int) callconv(.C) bool {
    if (value < 0 or value > 127) {
        log.err("C1_FxSelScroll: value {d} out of range 0-127", .{value});
        return false;
    }
    const globals = getGlobals();
    if (globals.state.current_mode != .fx_sel) {
        log.err("C1_FxSelScroll: not in fx_sel mode (current: {s})", .{@tagName(globals.state.current_mode)});
        return false;
    }
    actions.dispatch(globals, .{ .fx_sel = .{ .scroll = @intCast(value) } });
    return true;
}

fn varargFxSelScroll(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = numparms;
    const args = arglist orelse return null;
    // Because REAPER passes integer arguments as the pointer value itself
    // (not as a pointer to an integer), we reinterpret the pointer as an int.
    const value: c_int = @intCast(@intFromPtr(args.*));
    const result = apiFxSelScroll(value);
    return if (result) @ptrFromInt(1) else @ptrFromInt(0);
}

const apidef_FxSelScroll: [*:0]const u8 = "bool\x00int\x00value\x00Console1: Sends a scroll value (0-127) to the FX selection browser.\x00";

// -- C1_EnableUI: enables the ImGui render loop in test mode --

fn apiEnableUI() callconv(.C) bool {
    log.info("C1_EnableUI: enabling ImGui render loop", .{});
    imgui_loop.registerForTest();
    return true;
}

fn varargEnableUI(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = .{ arglist, numparms };
    const result = apiEnableUI();
    return if (result) @ptrFromInt(1) else @ptrFromInt(0);
}

const apidef_EnableUI: [*:0]const u8 = "bool\x00\x00\x00Console1: Enables the ImGui UI render loop (for headless testing).\x00";

// -- C1_GetUIStatus: returns whether the UI render loop is active --

fn apiGetUIStatus() callconv(.C) [*:0]const u8 {
    if (imgui_loop.ctx != null) {
        return "running";
    }
    return "stopped";
}

fn varargGetUIStatus(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = .{ arglist, numparms };
    const result = apiGetUIStatus();
    return @ptrCast(@constCast(result));
}

const apidef_GetUIStatus: [*:0]const u8 = "const char*\x00\x00\x00Console1: Returns the UI status: 'running' or 'stopped'.\x00";

// -- C1_FxSelSwap: triggers an FX swap for the given module and plugin name --

fn apiFxSelSwap(module_name: [*:0]const u8, plugin_name: [*:0]const u8) callconv(.C) bool {
    const mod_str = std.mem.span(module_name);
    const ModulesList = statemachine.ModulesList;
    const module = std.meta.stringToEnum(ModulesList, mod_str) orelse {
        log.err("C1_FxSelSwap: unknown module '{s}'", .{mod_str});
        return false;
    };
    const globals = getGlobals();
    globals.state.fx_sel.current_category = module;
    globals.state.current_mode = .fx_sel;
    const fx_sel_actions = @import("fx_sel_actions.zig");
    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{
        .name = std.mem.span(plugin_name),
        .mapping_name = null,
    } });
    return true;
}

fn varargFxSelSwap(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = numparms;
    const args: [*]?*anyopaque = @ptrCast(arglist orelse return null);
    const module_name: [*:0]const u8 = @ptrCast(args[0] orelse return null);
    const plugin_name: [*:0]const u8 = @ptrCast(args[1] orelse return null);
    const result = apiFxSelSwap(module_name, plugin_name);
    return if (result) @ptrFromInt(1) else @ptrFromInt(0);
}

const apidef_FxSelSwap: [*:0]const u8 = "bool\x00const char*,const char*\x00module_name,plugin_name\x00Console1: Triggers an FX swap for the given module (INPUT/GATE/EQ/COMP/OUTPT) with the named plugin.\x00";

// -- C1_GetModuleOrder: returns the current module order label --

fn apiGetModuleOrder() callconv(.C) [*:0]const u8 {
    const globals = getGlobals();
    return @tagName(globals.state.fx_ctrl.track_state.getModulesOrder());
}

fn varargGetModuleOrder(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = .{ arglist, numparms };
    return @ptrCast(@constCast(apiGetModuleOrder()));
}

const apidef_GetModuleOrder: [*:0]const u8 = "const char*\x00\x00\x00Console1: Returns current module order (EQ-S-C, S-C-EQ, or S-EQ-C).\x00";

// -- C1_GetModuleLocations: returns fx_index for each module --

fn apiGetModuleLocations() callconv(.C) [*:0]const u8 {
    const globals = getGlobals();
    const locs = globals.state.fx_ctrl.track_state.getModuleLocations() orelse return "no locations";
    const PhysicalModule = statemachine.PhysicalModule;

    const buf = struct {
        var data: [256]u8 = undefined;
    };

    var pos: usize = 0;
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        const name = @tagName(module);
        if (locs.get(module)) |loc| {
            const written = std.fmt.bufPrint(buf.data[pos..], "{s}={d} ", .{ name, loc.fx_index }) catch break;
            pos += written.len;
        } else {
            const written = std.fmt.bufPrint(buf.data[pos..], "{s}=null ", .{name}) catch break;
            pos += written.len;
        }
    }
    if (pos > 0) pos -= 1; // trim trailing space
    buf.data[pos] = 0;
    return @ptrCast(&buf.data);
}

fn varargGetModuleLocations(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = .{ arglist, numparms };
    return @ptrCast(@constCast(apiGetModuleLocations()));
}

const apidef_GetModuleLocations: [*:0]const u8 = "const char*\x00\x00\x00Console1: Returns fx_index for each module (INPUT=0 GATE=1 etc).\x00";

// -- C1_SetModuleOrder: triggers a module reorder --

fn apiSetModuleOrder(order_name: [*:0]const u8) callconv(.C) bool {
    const name = std.mem.span(order_name);
    const order = std.meta.stringToEnum(ModulesOrder, name) orelse {
        log.err("C1_SetModuleOrder: unknown order '{s}'", .{name});
        return false;
    };
    const globals = getGlobals();
    actions.dispatch(globals, .{ .fx_ctrl = .{ .panel_input = .{
        .cc = .Tr_order,
        .value = @as(f64, @floatFromInt(@intFromEnum(order))),
    } } });
    return true;
}

fn varargSetModuleOrder(arglist: ?*?*anyopaque, numparms: c_int) callconv(.C) ?*anyopaque {
    _ = numparms;
    const args = arglist orelse return null;
    const order_name: [*:0]const u8 = @ptrCast(args.* orelse return null);
    const result = apiSetModuleOrder(order_name);
    return if (result) @ptrFromInt(1) else @ptrFromInt(0);
}

const apidef_SetModuleOrder: [*:0]const u8 = "bool\x00const char*\x00order_name\x00Console1: Triggers a module reorder. Valid orders: EQ-S-C, S-C-EQ, S-EQ-C.\x00";

// -- Registration --

fn reg(
    comptime api_name: [*:0]const u8,
    func: *anyopaque,
    comptime vararg_name: [*:0]const u8,
    vararg_func: *anyopaque,
    comptime def_name: [*:0]const u8,
    def: *anyopaque,
) void {
    _ = reaper.plugin_register(api_name, func);
    _ = reaper.plugin_register(vararg_name, vararg_func);
    _ = reaper.plugin_register(def_name, def);
}

pub fn registerTestApis() void {
    log.info("Registering Console1 test APIs", .{});
    reg("API_C1_GetMode", @ptrCast(@constCast(&apiGetMode)), "APIvararg_C1_GetMode", @ptrCast(@constCast(&varargGetMode)), "APIdef_C1_GetMode", @ptrCast(@constCast(apidef_GetMode)));
    reg("API_C1_ChangeMode", @ptrCast(@constCast(&apiChangeMode)), "APIvararg_C1_ChangeMode", @ptrCast(@constCast(&varargChangeMode)), "APIdef_C1_ChangeMode", @ptrCast(@constCast(apidef_ChangeMode)));
    reg("API_C1_FxSelScroll", @ptrCast(@constCast(&apiFxSelScroll)), "APIvararg_C1_FxSelScroll", @ptrCast(@constCast(&varargFxSelScroll)), "APIdef_C1_FxSelScroll", @ptrCast(@constCast(apidef_FxSelScroll)));
    reg("API_C1_EnableUI", @ptrCast(@constCast(&apiEnableUI)), "APIvararg_C1_EnableUI", @ptrCast(@constCast(&varargEnableUI)), "APIdef_C1_EnableUI", @ptrCast(@constCast(apidef_EnableUI)));
    reg("API_C1_GetUIStatus", @ptrCast(@constCast(&apiGetUIStatus)), "APIvararg_C1_GetUIStatus", @ptrCast(@constCast(&varargGetUIStatus)), "APIdef_C1_GetUIStatus", @ptrCast(@constCast(apidef_GetUIStatus)));
    reg("API_C1_FxSelSwap", @ptrCast(@constCast(&apiFxSelSwap)), "APIvararg_C1_FxSelSwap", @ptrCast(@constCast(&varargFxSelSwap)), "APIdef_C1_FxSelSwap", @ptrCast(@constCast(apidef_FxSelSwap)));
    reg("API_C1_GetModuleOrder", @ptrCast(@constCast(&apiGetModuleOrder)), "APIvararg_C1_GetModuleOrder", @ptrCast(@constCast(&varargGetModuleOrder)), "APIdef_C1_GetModuleOrder", @ptrCast(@constCast(apidef_GetModuleOrder)));
    reg("API_C1_GetModuleLocations", @ptrCast(@constCast(&apiGetModuleLocations)), "APIvararg_C1_GetModuleLocations", @ptrCast(@constCast(&varargGetModuleLocations)), "APIdef_C1_GetModuleLocations", @ptrCast(@constCast(apidef_GetModuleLocations)));
    reg("API_C1_SetModuleOrder", @ptrCast(@constCast(&apiSetModuleOrder)), "APIvararg_C1_SetModuleOrder", @ptrCast(@constCast(&varargSetModuleOrder)), "APIdef_C1_SetModuleOrder", @ptrCast(@constCast(apidef_SetModuleOrder)));
}
