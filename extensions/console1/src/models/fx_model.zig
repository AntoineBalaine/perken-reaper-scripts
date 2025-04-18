pub const Param = struct {
    name: [:0]const u8,
    normalized_value: f64 = 0.0,
    formatted_value: [:0]const u8,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.formatted_value);
    }
};

// Input/output pin routing data
const PinMappings = struct {};
const NamedConfigs = struct {
    original_name: [:0]const u8,
    renamed_name: [:0]const u8,
    gain_reduction_db: ?f64 = null,
};

pub const FX = struct {
    guid: utils.Guid,
    enabled: bool = true,
    params: []Param,
    named_configs: NamedConfigs,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        if (@intFromPtr(self.named_configs.original_name.ptr) != @intFromPtr(self.named_configs.renamed_name.ptr)) {
            allocator.free(self.named_configs.renamed_name);
        }
        allocator.free(self.named_configs.original_name);
        for (self.params) |*param| {
            param.deinit(allocator);
        }
        allocator.free(self.params);
    }
};

pub fn deinitCParam(param: *cFxModel.RC_Param, allocator: std.mem.Allocator) void {
    allocator.free(std.mem.span(param.name));
    allocator.free(std.mem.span(param.formatted_value));
}

pub fn deinitCFX(fx: *cFxModel.RC_FX, allocator: std.mem.Allocator) void {
    // Free the original and renamed names
    allocator.free(std.mem.span(fx.named_configs.original_name));

    // Only free renamed_name if it's different from original_name
    if (@intFromPtr(fx.named_configs.original_name) != @intFromPtr(fx.named_configs.renamed_name)) {
        allocator.free(std.mem.span(fx.named_configs.renamed_name));
    }

    // Free each parameter and the parameters array if they exist
    if (fx.params_count > 0) {
        for (0..fx.params_count) |i| {
            var prm = fx.params[i];
            deinitCParam(&prm, allocator);
        }
        allocator.free(fx.params[0..fx.params_count]);
    }
}

const std = @import("std");
const utils = @import("../utils.zig");
const cFxModel = @cImport({
    @cInclude("tests/rapidcheck/types/fx_model.h");
});
