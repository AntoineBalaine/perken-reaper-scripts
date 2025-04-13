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

const std = @import("std");
const utils = @import("../utils.zig");
