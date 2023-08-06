-- @noindex
---@meta

---@class Compartment
---@field version string
---@field value MainCompartment

---@class MainCompartment
---@field groups Group[]
---@field mappings Mapping[]

---@class Bank
---@field id string
---@field name string
---@field activation_condition {kind: string, parameter: integer, bank_index: integer|nil} | nil

---@class Mapping
---@field control_enabled boolean|nil
---@field enabled boolean|nil
---@field feedback_enabled boolean|nil
---@field glue Glue
---@field group string|nil group name
---@field id string id is a unique identifier for the mapping
---@field name string name is not the same as id
---@field on_activate OnActivate|nil
---@field on_deactivate OnActivate|nil
---@field source Source|nil
---@field tags string[]|nil tags are used to find mappings, can be used to group mappings without a dedicated Group
---@field target Target
---@field visible_in_projection boolean|nil
---@field activation_condition { bank_index: number, parameter: number, kind: string } | nil


---@class Group mapping group, such as "BANK1"
---@field activation_condition table|nil
---@field id string
---@field name string

---@class OnActivate activation actions, such as sending MIDI feedback
---@field send_midi_feedback {kind: string, message: string}[] | nil

---@class Source --- typically a virtual control, if you're using a preset from the controller compartment, or a CC message
---@field character string | nil such as "Multi"
---@field id number | string | nil
---@field kind string

---@class Glue
---@field absolute_mode  "Normal" | "ToggleButton" | "IncrementalButton" | nil
---@field control_transformation  "" | nil
---@field feedback  { kind : "Numeric",transformation : "",} | nil
---@field fire_mode  { kind: string, press_duration_interval : { number: number, number: number }} | nil
---@field jump_interval  { number: number, number:number } |nil
---@field out_of_range_behavior  "MinOrMax" | "Min" | "Ignore" | nil
---@field relative_mode  "Normal" | nil
---@field reverse  boolean | nil
---@field round_target_value  boolean | nil
---@field source_interval  { number: integer, number: integer } | nil
---@field step_factor_interval { number:number, number:number } | nil typically step_factor_interval = { 1, 3000 }
---@field step_size_interval { number:number, number:number } | nil  typically step_size_interval = { 0.01, 0.05 }
---@field takeover_mode  "Off" |nil
---@field target_interval  { number: integer, number: integer } | nil
---@field target_value_sequence  "" | nil
---@field wrap  boolean | nil

---@class Target
---@field kind string
---@field id string | number | nil
---@field parameter Parameter | nil
---@field poll_for_feedback boolean|nil

---@class Parameter
---@field address string
---@field fx Fx|nil
---@field index number

---@class Fx
---@field address string
---@field chain Chain
---@field id string | nil

---@class Chain
---@field address string
