---@enum Param_Display_Type
local Param_Display_Type = {
    Slider = "Slider",
    Knob = "Knob",
    vSlider = "vSlider",
    Drag = "Drag",
    switch = "switch",
    selection = "selection",
}

---@enum DragDirection
local DragDirection = {
    left = "left",
    right = "right",
    left_right = "left-right",
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
