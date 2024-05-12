---@class C1Types
local types = {}


types.namespace = "prkn_c1"
types.fields = {
    userConfig = "user_config",
    actionStack = "action_stack",
}

---@class ExtState
---@field namespace string
---@field actionId ActionId


---This is the barebones trackFx info,
---Without the class functions that can be found in
---@see TrackFX
--This type is used for testing and for passing data when instantiating `TrackFX`
---@class FxData
---@field enabled boolean
---@field guid string
---@field name string
---@field number integer
---@field param? table
---@field index integer


---@class Track
---@field fx_by_guid table<string, TrackFX> --- all fx in the track, using GUID as key. Duplicate of fx_list for easier access.
---@field fx_list TrackFX[] --- array of fx in the track. duplicate of fx_by_guid for easier iteration.
---@field fx_count integer
---@field guid string
---@field name string
---@field number integer --- 0-indexed track index (0 is for master track)
---@field track MediaTrack
---@field bypass boolean --- is the fx chain bypassed
---@field fx_chain_enabled boolean
---@field automation_mode  AutomationMode



---@class Parameter
---@field defaultval number
---@field editSelected boolean = false
---@field fmt_val string|nil
---@field guid string
---@field ident string
---@field index number
---@field istoggle boolean
---@field largestep number
---@field maxval number
---@field midval number
---@field minval number
---@field name string
---@field new fun( state: State, param_index: number, parent_fx: TrackFX, guid: string): self
---@field parent_fx TrackFX
---@field query_value fun(self):self
---@field setValue fun(self, value :number)
---@field smallstep number
---@field state State
---@field step number normalized step
---@field value number
---@field steps_count? number Used for params that have a limited number of steps (like a dropdown)


---ParamData is an intermediary datum for a param that's not being displayed.
--
--Basically we don't need to query the param's values if it's not displayed
--so we only need its name and guid.
---@class ParamData
---@field details Parameter|nil
---@field display boolean = false
---@field guid string
---@field index integer
---@field name string

---@class TrackFX
---@field createParamDetails fun(self: TrackFX, param: ParamData, addToDisplayParams?: boolean): ParamData
---@field createParams fun(self: TrackFX): params_list: ParamData[] , params_by_guid:table<string, ParamData>
---@field display_name string name of fx, or preset, or renamed name, or fx instance name.
---@field enabled boolean|nil
---@field guid string
---@field index integer
---@field name string|nil
---@field new fun(state: State, index: integer, number: integer, guid: string): TrackFX
---@field number integer
---@field params_by_guid table<string, ParamData>
---@field params_list ParamData[]
---@field presetname string|nil
---@field renamed_name string|nil
---@field state State
---@field update fun(self: TrackFX)
---@field DryWetParam ParamData


---@class ControllerConfig
---@field paramData ParamData[]
---@field Modes string[] list of modes (fx ctrl, settings)
---@field channelStripPath string
---@field realearnPath string

-- 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
---@enum AutomationMode
types.AutomationMode = {
    trim = 0,
    read = 1,
    touch = 2,
    write = 3,
    latch = 4,
    preview = 5
}

return types
