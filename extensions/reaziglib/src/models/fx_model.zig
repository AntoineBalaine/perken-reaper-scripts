pub const Param = struct {
    name: [:0]const u8,
    normalized_value: f64 = 0.0,
    formatted_value: [:0]const u8,
    step_size: f64 = 0.0,
    is_toggle: bool = false,
    min_val: f64 = 0.0,
    max_val: f64 = 1.0,
};

// Input/output pin routing data
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
};

const utils = @import("utils");
