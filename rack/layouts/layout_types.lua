---@meta

--[[
Data shape in which layouts should be stored in the layouts folder.
]]

---@class LayoutTrackFX
---@field display_name string name of fx, or preset, or renamed name, or fx instance name.
---@field displaySettings LayoutFxDisplaySettings
---@field display_params LayoutParamData[]
---@field name string|nil

---@class LayoutParamData
---@field details LayoutParameter|nil
---@field display boolean = true
---@field index integer
---@field name string

---@class LayoutFxDisplaySettings
---@field background integer
---@field borderColor integer
---@field buttons_layout ButtonsLayout
---@field custom_Title string|nil
---@field title_display Title_Display_Style
---@field window_width integer = 280
---@field decorations? Decoration[] drawn in the fx_box, in background drawlist, instantiated only on demand of the layoutEditor or of a saved layout

---@class LayoutParameter
---@field display_settings KnobDisplaySettings|HorizontalSliderDisplaySettings|VerticalSliderDisplaySettings|CycleButtonDisplaySettings
---@field ident string
---@field index number
---@field name string
