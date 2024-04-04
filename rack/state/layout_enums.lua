local tableHelpers = require("helpers.table")
--[[
Data types for the FX parameter’s layout.
]]

local layout_enums = {}

---@enum EditLayoutCloseAction
layout_enums.EditLayoutCloseAction = {
    save = "save",
    close = "close",
    discard = "discard"
}

---@enum Param_Display_Type
layout_enums.Param_Display_Type = {
    Slider = 1,
    Knob = 2,
    vSlider = 3,
    Drag = 4,
    CycleButton = 5,
    selection = 6,
}

layout_enums.Param_Display_Type_Length = 6

---Adding this assert here so that the two Param_Display_Type and its corresponding Length variable
--are kept in sync. This just so we don't have to keep querying the length of Param_Display_Type at
--every frame when we're opening the `layoutEditor:ParamInfo()`
assert(tableHelpers.namedTableLength(layout_enums.Param_Display_Type) == layout_enums.Param_Display_Type_Length,
    "Maintenance BUG! In layout_enums, Param_Display_Type's should equal Param_Display_Type_Length")

---@enum Title_Display_Style
layout_enums.Title_Display_Style = {
    fx_name = 1,
    preset_name = 2,
    custom_title = 3,
    fx_instance_name = 4
}

---@enum ButtonsLayout
---If horizontal, then display the buttons' bar horizontally,
---else vertically
layout_enums.buttons_layout = {
    horizontal = 1,
    vertical = 2
}


---List of flags that you can pass into the draw method
---@enum KnobFlags
layout_enums.KnobFlags = {
    NoTitle = 1, --- Hide the top title.
    NoInput = 2, --- Make the control un-controllable. Dunno why you'd do that, though…
    NoValue = 4,
    NoEdit = 8,  --- Not Editable means: no re-positioning, not selectable when layoutEditor is editing the param
    None = 0,
}

---@enum DecorationType
layout_enums.DecorationType = {
    line = 1,
    rectangle = 2,
    text = 3,
    background_image = 4,
}

layout_enums.DecorationLabel = {
    "line",
    "rectangle",
    "text",
    "background_image",
}

layout_enums.Decoration_Display_Type_Length = 4

---Adding this assert here so that the two Decoration_Display_Type and its corresponding Length variable
--are kept in sync. This just so we don't have to keep querying the length of Decoration_Display_Type at
--every frame when we're opening the `layoutEditor:DecorationInfo()`.
assert(
    tableHelpers.namedTableLength(layout_enums.DecorationType) == layout_enums.Decoration_Display_Type_Length,
    "Maintenance BUG! In layout_enums, Decoration_Display_Type's should equal Decoration_Display_Type_Length")


---@class deco_text
---@field type DecorationType
---@field _selected boolean
---@field Pos_X number
---@field Pos_Y number
---@field guid string
---@field color integer
---@field font_size number
---@field weight integer

---@class deco_line
---@field type DecorationType
---@field _selected boolean
---@field Pos_X number
---@field Pos_Y number
---@field guid string
---@field color integer
---@field thickness number
---@field length number

---@class deco_rectangle
---@field type DecorationType
---@field _selected boolean
---@field Pos_X number
---@field Pos_Y number
---@field guid string
---@field color integer
---@field width number
---@field height number

---@class deco_image
---@field type DecorationType
---@field _selected boolean
---@field Pos_X number
---@field Pos_Y number
---@field guid string
---@field path string
---@field keep_ratio boolean
---@field width number
---@field height number

---@alias Decoration deco_text | deco_line | deco_rectangle | deco_image

---@enum DragDirection
local DragDirection = {
    left = "left",
    right = "right",
    left_right = "left-right",
}

---@enum KnobTrackStart
---Assigns whether the knob’s colored-track starts from the left, right or center.
--
---e.g. when displaying a «pan» knob, the colored track should start from the center
---to represent the pan’s position going left or right.
---
---Also keep in mind this is used in a combo, and thus the values are 0-indexed
layout_enums.KnobWiperStart = {
    left = 0,
    right = 1,
    center = 2
}

-- 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
---@enum AutomationMode
layout_enums.AutomationMode = {
    trim = 0,
    read = 1,
    touch = 2,
    write = 3,
    latch = 4,
    preview = 5
}

---@enum PositionType = {
local PositionType = {
    default = "default",
    free = "free"
}

---@class Common
---@field type Param_Display_Type
---@field Pos_X number -- x-axis position in fx box
---@field Pos_Y number -- y-axis position in fx box
---@field Width number -- fx param’s width, be it knob|slider|etc.
---@field Height number -- Height in pixels of Fx param, be it slider|knob|etc.
---@field Color number -- param’s color, i.e. color of knob|slider|etc.
---@field Custom_Label string -- custom label for an FX, set in «Label» input
---@field label Label
---@field Custom_Image Image -- custom image for an FX, set in «Add custom image»
---@field Font_Size number
---@field Name string
---@field Number string
---@field BackgroundColor number -- BgClr in FXD

---@class Misc_common
---@field Left unknown
---@field Bottom unknown
---@field Height_VA unknown
---@field Height_VA_GR unknown
---@field V_Clr unknown
---@field Right unknown
---@field Round unknown
---@field Text unknown
---@field Thick unknown
---@field Top unknown

---@class Slider
---@field Height number
---@field dragDirection DragDirection
---@field GrbClr number -- grab’s color: the grab is the dot in a slider, or the indicator in knob

---@class Knob
---@field dragDirection DragDirection
---@field GrbClr number -- grab’s color: the grab is the dot in a slider, or the indicator in knob

---@class vSlider

---@class Drag

---@class switch
---@field Switch_Base_Value unknown
---@field Switch_Target_Value unknown
---@field Switch_type unknown

---@class selection

---@class Image
---@field ImagePath string -- save image path when user adds custom image
---@field KeepImgRatio boolean

---@class Label
---@field Label_Font_Size number -- lable’s font size
---@field Label_Free_Pos_X number -- If label’s not in default position, such as inside the slider or below the knob
---@field Label_Free_Pos_Y number -- If label’s not in default position, such as inside the slider or below the knob
---@field Label_Pos PositionType -- default or free. Slider: left|bottom|free, Top|bottom|free,
---@field Label_Clr number -- label color

---can attach drawings to the fxparam,
---with params as
---xoffset, yoffset, width, height, repeat (number), gap (btw repeats), Xgap, Ygap, last repeat’s color…
---@class Drawing
---@field X_Offset number -- attached drawing
---@field Y_Offset_Value_Affect number -- attached drawing
---@field Y_offset number -- attached drawing
---@field Number_of_attached_drawings number  -- attached drawing
---@field xoffset? number
---@field yoffset? number
---@field width? number
---@field height? number
---@field repeat? number (number)
---@field gap? number (btw repeats)
---@field Xgap? number
---@field Ygap? number
---@field last_repeat_color? number

---@class ConditionParam
---@field Condition_Param_Norm unknown
---@field Condition_Param_Norm2 unknown
---@field Condition_Param2 unknown
---@field Condition_Param3 unknown
---@field Condition_Param4 unknown
---@field Condition_Param5 unknown

---@class misc
---@field Decimal_Rounding unknown
---@field Style unknown -- ? maybe some pre-saved styles of the user?
---@field Value_Font_Size unknown
---@field Value_Free_Pos_X unknown -- if free, x-axis position
---@field Value_Free_Pos_Y unknown -- if free y-axis position
---@field Value_Pos PositionType -- Free | Default
---@field Value_Thickness unknown
---@field Value_to_Note_Length boolean -- boolean, triggers snapping values ?


return layout_enums

