// Generated for ReaImGui v0.9.1-2-g0e2706a

const std = @import("std");

pub const api_version = "0.9.1";

pub const ContextPtr = ?*opaque {};
pub const DrawListPtr = ?*opaque {};
pub const DrawListSplitterPtr = ?*opaque {};
pub const FontPtr = ?*opaque {};
pub const FunctionPtr = ?*opaque {};
pub const ImagePtr = ?*opaque {};
pub const ImageSetPtr = ?*opaque {};
pub const ListClipperPtr = ?*opaque {};
pub const ResourcePtr = ?*opaque {};
pub const TextFilterPtr = ?*opaque {};
pub const ViewportPtr = ?*opaque {};
pub const reaper_array = anyopaque;

pub const Error = error{ImGui};
pub var last_error: ?[*:0]const u8 = null;

const API = struct {
    ArrowButton: *fn (ContextPtr, [*:0]const u8, c_int) callconv(.C) bool,
    Button: *fn (ContextPtr, [*:0]const u8, ?*f64, ?*f64) callconv(.C) bool,
    Checkbox: *fn (ContextPtr, [*:0]const u8, *bool) callconv(.C) bool,
    CheckboxFlags: *fn (ContextPtr, [*:0]const u8, *c_int, c_int) callconv(.C) bool,
    InvisibleButton: *fn (ContextPtr, [*:0]const u8, f64, f64, ?*c_int) callconv(.C) bool,
    PopButtonRepeat: *fn (ContextPtr) callconv(.C) void,
    PushButtonRepeat: *fn (ContextPtr, bool) callconv(.C) void,
    RadioButton: *fn (ContextPtr, [*:0]const u8, bool) callconv(.C) bool,
    RadioButtonEx: *fn (ContextPtr, [*:0]const u8, *c_int, c_int) callconv(.C) bool,
    SmallButton: *fn (ContextPtr, [*:0]const u8) callconv(.C) bool,
    ColorButton: *fn (ContextPtr, [*:0]const u8, c_int, ?*c_int, ?*f64, ?*f64) callconv(.C) bool,
    ColorEdit3: *fn (ContextPtr, [*:0]const u8, *c_int, ?*c_int) callconv(.C) bool,
    ColorEdit4: *fn (ContextPtr, [*:0]const u8, *c_int, ?*c_int) callconv(.C) bool,
    ColorPicker3: *fn (ContextPtr, [*:0]const u8, *c_int, ?*c_int) callconv(.C) bool,
    ColorPicker4: *fn (ContextPtr, [*:0]const u8, *c_int, ?*c_int, ?*c_int) callconv(.C) bool,
    SetColorEditOptions: *fn (ContextPtr, c_int) callconv(.C) void,
    BeginCombo: *fn (ContextPtr, [*:0]const u8, [*:0]const u8, ?*c_int) callconv(.C) bool,
    Combo: *fn (ContextPtr, [*:0]const u8, *c_int, [*:0]const u8, c_int, ?*c_int) callconv(.C) bool,
    EndCombo: *fn (ContextPtr) callconv(.C) void,
    BeginListBox: *fn (ContextPtr, [*:0]const u8, ?*f64, ?*f64) callconv(.C) bool,
    EndListBox: *fn (ContextPtr) callconv(.C) void,
    ListBox: *fn (ContextPtr, [*:0]const u8, *c_int, [*:0]const u8, c_int, ?*c_int) callconv(.C) bool,
    Selectable: *fn (ContextPtr, [*:0]const u8, ?*bool, ?*c_int, ?*f64, ?*f64) callconv(.C) bool,
    Attach: *fn (ContextPtr, ResourcePtr) callconv(.C) void,
    CreateContext: *fn ([*:0]const u8, ?*c_int) callconv(.C) ContextPtr,
    Detach: *fn (ContextPtr, ResourcePtr) callconv(.C) void,
    GetDeltaTime: *fn (ContextPtr) callconv(.C) f64,
    GetFrameCount: *fn (ContextPtr) callconv(.C) c_int,
    GetFramerate: *fn (ContextPtr) callconv(.C) f64,
    GetTime: *fn (ContextPtr) callconv(.C) f64,
    GetConfigVar: *fn (ContextPtr, c_int) callconv(.C) f64,
    SetConfigVar: *fn (ContextPtr, c_int, f64) callconv(.C) void,
    AcceptDragDropPayload: *fn (ContextPtr, [*:0]const u8, [*]u8, c_int, ?*c_int) callconv(.C) bool,
    AcceptDragDropPayloadFiles: *fn (ContextPtr, *c_int, ?*c_int) callconv(.C) bool,
    AcceptDragDropPayloadRGB: *fn (ContextPtr, *c_int, ?*c_int) callconv(.C) bool,
    AcceptDragDropPayloadRGBA: *fn (ContextPtr, *c_int, ?*c_int) callconv(.C) bool,
    BeginDragDropSource: *fn (ContextPtr, ?*c_int) callconv(.C) bool,
    BeginDragDropTarget: *fn (ContextPtr) callconv(.C) bool,
    EndDragDropSource: *fn (ContextPtr) callconv(.C) void,
    EndDragDropTarget: *fn (ContextPtr) callconv(.C) void,
    GetDragDropPayload: *fn (ContextPtr, [*]u8, c_int, [*]u8, c_int, *bool, *bool) callconv(.C) bool,
    GetDragDropPayloadFile: *fn (ContextPtr, c_int, [*]u8, c_int) callconv(.C) bool,
    SetDragDropPayload: *fn (ContextPtr, [*:0]const u8, [*:0]const u8, ?*c_int) callconv(.C) bool,
    DragDouble: *fn (ContextPtr, [*:0]const u8, *f64, ?*f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragDouble2: *fn (ContextPtr, [*:0]const u8, *f64, *f64, ?*f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragDouble3: *fn (ContextPtr, [*:0]const u8, *f64, *f64, *f64, ?*f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragDouble4: *fn (ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, ?*f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragDoubleN: *fn (ContextPtr, [*:0]const u8, *reaper_array, ?*f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragFloatRange2: *fn (ContextPtr, [*:0]const u8, *f64, *f64, ?*f64, ?*f64, ?*f64, ?[*:0]const u8, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragInt: *fn (ContextPtr, [*:0]const u8, *c_int, ?*f64, ?*c_int, ?*c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragInt2: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, ?*f64, ?*c_int, ?*c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragInt3: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, ?*f64, ?*c_int, ?*c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragInt4: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, ?*f64, ?*c_int, ?*c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DragIntRange2: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, ?*f64, ?*c_int, ?*c_int, ?[*:0]const u8, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderAngle: *fn (ContextPtr, [*:0]const u8, *f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderDouble: *fn (ContextPtr, [*:0]const u8, *f64, f64, f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderDouble2: *fn (ContextPtr, [*:0]const u8, *f64, *f64, f64, f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderDouble3: *fn (ContextPtr, [*:0]const u8, *f64, *f64, *f64, f64, f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderDouble4: *fn (ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, f64, f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderDoubleN: *fn (ContextPtr, [*:0]const u8, *reaper_array, f64, f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderInt: *fn (ContextPtr, [*:0]const u8, *c_int, c_int, c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderInt2: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderInt3: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    SliderInt4: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    VSliderDouble: *fn (ContextPtr, [*:0]const u8, f64, f64, *f64, f64, f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    VSliderInt: *fn (ContextPtr, [*:0]const u8, f64, f64, *c_int, c_int, c_int, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    DrawList_PopClipRect: *fn (DrawListPtr) callconv(.C) void,
    DrawList_PushClipRect: *fn (DrawListPtr, f64, f64, f64, f64, ?*bool) callconv(.C) void,
    DrawList_PushClipRectFullScreen: *fn (DrawListPtr) callconv(.C) void,
    GetBackgroundDrawList: *fn (ContextPtr) callconv(.C) DrawListPtr,
    GetForegroundDrawList: *fn (ContextPtr) callconv(.C) DrawListPtr,
    GetWindowDrawList: *fn (ContextPtr) callconv(.C) DrawListPtr,
    DrawList_AddBezierCubic: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, f64, ?*c_int) callconv(.C) void,
    DrawList_AddBezierQuadratic: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, f64, ?*c_int) callconv(.C) void,
    DrawList_AddCircle: *fn (DrawListPtr, f64, f64, f64, c_int, ?*c_int, ?*f64) callconv(.C) void,
    DrawList_AddCircleFilled: *fn (DrawListPtr, f64, f64, f64, c_int, ?*c_int) callconv(.C) void,
    DrawList_AddConcavePolyFilled: *fn (DrawListPtr, *reaper_array, c_int) callconv(.C) void,
    DrawList_AddConvexPolyFilled: *fn (DrawListPtr, *reaper_array, c_int) callconv(.C) void,
    DrawList_AddEllipse: *fn (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64, ?*c_int, ?*f64) callconv(.C) void,
    DrawList_AddEllipseFilled: *fn (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64, ?*c_int) callconv(.C) void,
    DrawList_AddImage: *fn (DrawListPtr, ImagePtr, f64, f64, f64, f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*c_int) callconv(.C) void,
    DrawList_AddImageQuad: *fn (DrawListPtr, ImagePtr, f64, f64, f64, f64, f64, f64, f64, f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*c_int) callconv(.C) void,
    DrawList_AddImageRounded: *fn (DrawListPtr, ImagePtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, f64, ?*c_int) callconv(.C) void,
    DrawList_AddLine: *fn (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64) callconv(.C) void,
    DrawList_AddNgon: *fn (DrawListPtr, f64, f64, f64, c_int, c_int, ?*f64) callconv(.C) void,
    DrawList_AddNgonFilled: *fn (DrawListPtr, f64, f64, f64, c_int, c_int) callconv(.C) void,
    DrawList_AddPolyline: *fn (DrawListPtr, *reaper_array, c_int, c_int, f64) callconv(.C) void,
    DrawList_AddQuad: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, ?*f64) callconv(.C) void,
    DrawList_AddQuadFilled: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int) callconv(.C) void,
    DrawList_AddRect: *fn (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64, ?*c_int, ?*f64) callconv(.C) void,
    DrawList_AddRectFilled: *fn (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64, ?*c_int) callconv(.C) void,
    DrawList_AddRectFilledMultiColor: *fn (DrawListPtr, f64, f64, f64, f64, c_int, c_int, c_int, c_int) callconv(.C) void,
    DrawList_AddText: *fn (DrawListPtr, f64, f64, c_int, [*:0]const u8) callconv(.C) void,
    DrawList_AddTextEx: *fn (DrawListPtr, FontPtr, f64, f64, f64, c_int, [*:0]const u8, ?*f64, ?*f64, ?*f64, ?*f64, ?*f64) callconv(.C) void,
    DrawList_AddTriangle: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, ?*f64) callconv(.C) void,
    DrawList_AddTriangleFilled: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, c_int) callconv(.C) void,
    CreateDrawListSplitter: *fn (DrawListPtr) callconv(.C) DrawListSplitterPtr,
    DrawListSplitter_Clear: *fn (DrawListSplitterPtr) callconv(.C) void,
    DrawListSplitter_Merge: *fn (DrawListSplitterPtr) callconv(.C) void,
    DrawListSplitter_SetCurrentChannel: *fn (DrawListSplitterPtr, c_int) callconv(.C) void,
    DrawListSplitter_Split: *fn (DrawListSplitterPtr, c_int) callconv(.C) void,
    DrawList_PathArcTo: *fn (DrawListPtr, f64, f64, f64, f64, f64, ?*c_int) callconv(.C) void,
    DrawList_PathArcToFast: *fn (DrawListPtr, f64, f64, f64, c_int, c_int) callconv(.C) void,
    DrawList_PathBezierCubicCurveTo: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, ?*c_int) callconv(.C) void,
    DrawList_PathBezierQuadraticCurveTo: *fn (DrawListPtr, f64, f64, f64, f64, ?*c_int) callconv(.C) void,
    DrawList_PathClear: *fn (DrawListPtr) callconv(.C) void,
    DrawList_PathEllipticalArcTo: *fn (DrawListPtr, f64, f64, f64, f64, f64, f64, f64, ?*c_int) callconv(.C) void,
    DrawList_PathFillConcave: *fn (DrawListPtr, c_int) callconv(.C) void,
    DrawList_PathFillConvex: *fn (DrawListPtr, c_int) callconv(.C) void,
    DrawList_PathLineTo: *fn (DrawListPtr, f64, f64) callconv(.C) void,
    DrawList_PathRect: *fn (DrawListPtr, f64, f64, f64, f64, ?*f64, ?*c_int) callconv(.C) void,
    DrawList_PathStroke: *fn (DrawListPtr, c_int, ?*c_int, ?*f64) callconv(.C) void,
    CreateFont: *fn ([*:0]const u8, c_int, ?*c_int) callconv(.C) FontPtr,
    GetFont: *fn (ContextPtr) callconv(.C) FontPtr,
    GetFontSize: *fn (ContextPtr) callconv(.C) f64,
    PopFont: *fn (ContextPtr) callconv(.C) void,
    PushFont: *fn (ContextPtr, FontPtr) callconv(.C) void,
    CreateFunctionFromEEL: *fn ([*:0]const u8) callconv(.C) FunctionPtr,
    Function_Execute: *fn (FunctionPtr) callconv(.C) void,
    Function_GetValue: *fn (FunctionPtr, [*:0]const u8) callconv(.C) f64,
    Function_GetValue_Array: *fn (FunctionPtr, [*:0]const u8, *reaper_array) callconv(.C) void,
    Function_GetValue_String: *fn (FunctionPtr, [*:0]const u8, [*]u8, c_int) callconv(.C) void,
    Function_SetValue: *fn (FunctionPtr, [*:0]const u8, f64) callconv(.C) void,
    Function_SetValue_Array: *fn (FunctionPtr, [*:0]const u8, *reaper_array) callconv(.C) void,
    Function_SetValue_String: *fn (FunctionPtr, [*:0]const u8, [*:0]const u8, c_int) callconv(.C) void,
    CreateImage: *fn ([*:0]const u8, ?*c_int) callconv(.C) ImagePtr,
    CreateImageFromMem: *fn ([*:0]const u8, c_int) callconv(.C) ImagePtr,
    Image: *fn (ContextPtr, ImagePtr, f64, f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*c_int, ?*c_int) callconv(.C) void,
    ImageButton: *fn (ContextPtr, [*:0]const u8, ImagePtr, f64, f64, ?*f64, ?*f64, ?*f64, ?*f64, ?*c_int, ?*c_int) callconv(.C) bool,
    Image_GetSize: *fn (ImagePtr, *f64, *f64) callconv(.C) void,
    CreateImageSet: *fn () callconv(.C) ImageSetPtr,
    ImageSet_Add: *fn (ImageSetPtr, f64, ImagePtr) callconv(.C) void,
    BeginDisabled: *fn (ContextPtr, ?*bool) callconv(.C) void,
    DebugStartItemPicker: *fn (ContextPtr) callconv(.C) void,
    EndDisabled: *fn (ContextPtr) callconv(.C) void,
    SetNextItemAllowOverlap: *fn (ContextPtr) callconv(.C) void,
    CalcItemWidth: *fn (ContextPtr) callconv(.C) f64,
    GetItemRectMax: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetItemRectMin: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetItemRectSize: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    PopItemWidth: *fn (ContextPtr) callconv(.C) void,
    PushItemWidth: *fn (ContextPtr, f64) callconv(.C) void,
    SetNextItemWidth: *fn (ContextPtr, f64) callconv(.C) void,
    PopTabStop: *fn (ContextPtr) callconv(.C) void,
    PushTabStop: *fn (ContextPtr, bool) callconv(.C) void,
    SetItemDefaultFocus: *fn (ContextPtr) callconv(.C) void,
    SetKeyboardFocusHere: *fn (ContextPtr, ?*c_int) callconv(.C) void,
    IsAnyItemActive: *fn (ContextPtr) callconv(.C) bool,
    IsAnyItemFocused: *fn (ContextPtr) callconv(.C) bool,
    IsAnyItemHovered: *fn (ContextPtr) callconv(.C) bool,
    IsItemActivated: *fn (ContextPtr) callconv(.C) bool,
    IsItemActive: *fn (ContextPtr) callconv(.C) bool,
    IsItemClicked: *fn (ContextPtr, ?*c_int) callconv(.C) bool,
    IsItemDeactivated: *fn (ContextPtr) callconv(.C) bool,
    IsItemDeactivatedAfterEdit: *fn (ContextPtr) callconv(.C) bool,
    IsItemEdited: *fn (ContextPtr) callconv(.C) bool,
    IsItemFocused: *fn (ContextPtr) callconv(.C) bool,
    IsItemHovered: *fn (ContextPtr, ?*c_int) callconv(.C) bool,
    IsItemVisible: *fn (ContextPtr) callconv(.C) bool,
    GetInputQueueCharacter: *fn (ContextPtr, c_int, *c_int) callconv(.C) bool,
    GetKeyDownDuration: *fn (ContextPtr, c_int) callconv(.C) f64,
    GetKeyMods: *fn (ContextPtr) callconv(.C) c_int,
    GetKeyPressedAmount: *fn (ContextPtr, c_int, f64, f64) callconv(.C) c_int,
    IsKeyChordPressed: *fn (ContextPtr, c_int) callconv(.C) bool,
    IsKeyDown: *fn (ContextPtr, c_int) callconv(.C) bool,
    IsKeyPressed: *fn (ContextPtr, c_int, ?*bool) callconv(.C) bool,
    IsKeyReleased: *fn (ContextPtr, c_int) callconv(.C) bool,
    SetNextFrameWantCaptureKeyboard: *fn (ContextPtr, bool) callconv(.C) void,
    GetMouseClickedCount: *fn (ContextPtr, c_int) callconv(.C) c_int,
    GetMouseClickedPos: *fn (ContextPtr, c_int, *f64, *f64) callconv(.C) void,
    GetMouseDelta: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetMouseDownDuration: *fn (ContextPtr, c_int) callconv(.C) f64,
    GetMouseDragDelta: *fn (ContextPtr, *f64, *f64, ?*c_int, ?*f64) callconv(.C) void,
    GetMousePos: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetMousePosOnOpeningCurrentPopup: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetMouseWheel: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    IsAnyMouseDown: *fn (ContextPtr) callconv(.C) bool,
    IsMouseClicked: *fn (ContextPtr, c_int, ?*bool) callconv(.C) bool,
    IsMouseDoubleClicked: *fn (ContextPtr, c_int) callconv(.C) bool,
    IsMouseDown: *fn (ContextPtr, c_int) callconv(.C) bool,
    IsMouseDragging: *fn (ContextPtr, c_int, ?*f64) callconv(.C) bool,
    IsMouseHoveringRect: *fn (ContextPtr, f64, f64, f64, f64, ?*bool) callconv(.C) bool,
    IsMousePosValid: *fn (ContextPtr, ?*f64, ?*f64) callconv(.C) bool,
    IsMouseReleased: *fn (ContextPtr, c_int) callconv(.C) bool,
    ResetMouseDragDelta: *fn (ContextPtr, ?*c_int) callconv(.C) void,
    GetMouseCursor: *fn (ContextPtr) callconv(.C) c_int,
    SetMouseCursor: *fn (ContextPtr, c_int) callconv(.C) void,
    BeginGroup: *fn (ContextPtr) callconv(.C) void,
    Dummy: *fn (ContextPtr, f64, f64) callconv(.C) void,
    EndGroup: *fn (ContextPtr) callconv(.C) void,
    Indent: *fn (ContextPtr, ?*f64) callconv(.C) void,
    NewLine: *fn (ContextPtr) callconv(.C) void,
    SameLine: *fn (ContextPtr, ?*f64, ?*f64) callconv(.C) void,
    Separator: *fn (ContextPtr) callconv(.C) void,
    SeparatorText: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    Spacing: *fn (ContextPtr) callconv(.C) void,
    Unindent: *fn (ContextPtr, ?*f64) callconv(.C) void,
    IsRectVisible: *fn (ContextPtr, f64, f64) callconv(.C) bool,
    IsRectVisibleEx: *fn (ContextPtr, f64, f64, f64, f64) callconv(.C) bool,
    PopClipRect: *fn (ContextPtr) callconv(.C) void,
    PushClipRect: *fn (ContextPtr, f64, f64, f64, f64, bool) callconv(.C) void,
    GetCursorPos: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetCursorPosX: *fn (ContextPtr) callconv(.C) f64,
    GetCursorPosY: *fn (ContextPtr) callconv(.C) f64,
    GetCursorScreenPos: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetCursorStartPos: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    SetCursorPos: *fn (ContextPtr, f64, f64) callconv(.C) void,
    SetCursorPosX: *fn (ContextPtr, f64) callconv(.C) void,
    SetCursorPosY: *fn (ContextPtr, f64) callconv(.C) void,
    SetCursorScreenPos: *fn (ContextPtr, f64, f64) callconv(.C) void,
    CreateListClipper: *fn (ContextPtr) callconv(.C) ListClipperPtr,
    ListClipper_Begin: *fn (ListClipperPtr, c_int, ?*f64) callconv(.C) void,
    ListClipper_End: *fn (ListClipperPtr) callconv(.C) void,
    ListClipper_GetDisplayRange: *fn (ListClipperPtr, *c_int, *c_int) callconv(.C) void,
    ListClipper_IncludeItemByIndex: *fn (ListClipperPtr, c_int) callconv(.C) void,
    ListClipper_IncludeItemsByIndex: *fn (ListClipperPtr, c_int, c_int) callconv(.C) void,
    ListClipper_Step: *fn (ListClipperPtr) callconv(.C) bool,
    BeginMenu: *fn (ContextPtr, [*:0]const u8, ?*bool) callconv(.C) bool,
    BeginMenuBar: *fn (ContextPtr) callconv(.C) bool,
    EndMenu: *fn (ContextPtr) callconv(.C) void,
    EndMenuBar: *fn (ContextPtr) callconv(.C) void,
    MenuItem: *fn (ContextPtr, [*:0]const u8, ?[*:0]const u8, ?*bool, ?*bool) callconv(.C) bool,
    PlotHistogram: *fn (ContextPtr, [*:0]const u8, *reaper_array, ?*c_int, ?[*:0]const u8, ?*f64, ?*f64, ?*f64, ?*f64) callconv(.C) void,
    PlotLines: *fn (ContextPtr, [*:0]const u8, *reaper_array, ?*c_int, ?[*:0]const u8, ?*f64, ?*f64, ?*f64, ?*f64) callconv(.C) void,
    BeginPopup: *fn (ContextPtr, [*:0]const u8, ?*c_int) callconv(.C) bool,
    BeginPopupModal: *fn (ContextPtr, [*:0]const u8, ?*bool, ?*c_int) callconv(.C) bool,
    CloseCurrentPopup: *fn (ContextPtr) callconv(.C) void,
    EndPopup: *fn (ContextPtr) callconv(.C) void,
    IsPopupOpen: *fn (ContextPtr, [*:0]const u8, ?*c_int) callconv(.C) bool,
    OpenPopup: *fn (ContextPtr, [*:0]const u8, ?*c_int) callconv(.C) void,
    OpenPopupOnItemClick: *fn (ContextPtr, ?[*:0]const u8, ?*c_int) callconv(.C) void,
    BeginPopupContextItem: *fn (ContextPtr, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    BeginPopupContextWindow: *fn (ContextPtr, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    BeginItemTooltip: *fn (ContextPtr) callconv(.C) bool,
    BeginTooltip: *fn (ContextPtr) callconv(.C) bool,
    EndTooltip: *fn (ContextPtr) callconv(.C) void,
    SetItemTooltip: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    SetTooltip: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    DebugFlashStyleColor: *fn (ContextPtr, c_int) callconv(.C) void,
    GetColor: *fn (ContextPtr, c_int, ?*f64) callconv(.C) c_int,
    GetColorEx: *fn (ContextPtr, c_int, ?*f64) callconv(.C) c_int,
    GetStyleColor: *fn (ContextPtr, c_int) callconv(.C) c_int,
    PopStyleColor: *fn (ContextPtr, ?*c_int) callconv(.C) void,
    PushStyleColor: *fn (ContextPtr, c_int, c_int) callconv(.C) void,
    GetStyleVar: *fn (ContextPtr, c_int, *f64, *f64) callconv(.C) void,
    PopStyleVar: *fn (ContextPtr, ?*c_int) callconv(.C) void,
    PushStyleVar: *fn (ContextPtr, c_int, f64, ?*f64) callconv(.C) void,
    BeginTabBar: *fn (ContextPtr, [*:0]const u8, ?*c_int) callconv(.C) bool,
    EndTabBar: *fn (ContextPtr) callconv(.C) void,
    BeginTabItem: *fn (ContextPtr, [*:0]const u8, ?*bool, ?*c_int) callconv(.C) bool,
    EndTabItem: *fn (ContextPtr) callconv(.C) void,
    SetTabItemClosed: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    TabItemButton: *fn (ContextPtr, [*:0]const u8, ?*c_int) callconv(.C) bool,
    BeginTable: *fn (ContextPtr, [*:0]const u8, c_int, ?*c_int, ?*f64, ?*f64, ?*f64) callconv(.C) bool,
    EndTable: *fn (ContextPtr) callconv(.C) void,
    TableGetColumnCount: *fn (ContextPtr) callconv(.C) c_int,
    TableGetColumnIndex: *fn (ContextPtr) callconv(.C) c_int,
    TableGetRowIndex: *fn (ContextPtr) callconv(.C) c_int,
    TableNextColumn: *fn (ContextPtr) callconv(.C) bool,
    TableNextRow: *fn (ContextPtr, ?*c_int, ?*f64) callconv(.C) void,
    TableSetColumnIndex: *fn (ContextPtr, c_int) callconv(.C) bool,
    TableSetBgColor: *fn (ContextPtr, c_int, c_int, ?*c_int) callconv(.C) void,
    TableAngledHeadersRow: *fn (ContextPtr) callconv(.C) void,
    TableGetColumnFlags: *fn (ContextPtr, ?*c_int) callconv(.C) c_int,
    TableGetColumnName: *fn (ContextPtr, ?*c_int) callconv(.C) [*:0]const u8,
    TableHeader: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    TableHeadersRow: *fn (ContextPtr) callconv(.C) void,
    TableSetColumnEnabled: *fn (ContextPtr, c_int, bool) callconv(.C) void,
    TableSetupColumn: *fn (ContextPtr, [*:0]const u8, ?*c_int, ?*f64, ?*c_int) callconv(.C) void,
    TableSetupScrollFreeze: *fn (ContextPtr, c_int, c_int) callconv(.C) void,
    TableGetColumnSortSpecs: *fn (ContextPtr, c_int, *c_int, *c_int, *c_int) callconv(.C) bool,
    TableNeedSort: *fn (ContextPtr, *bool) callconv(.C) bool,
    AlignTextToFramePadding: *fn (ContextPtr) callconv(.C) void,
    Bullet: *fn (ContextPtr) callconv(.C) void,
    BulletText: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    CalcTextSize: *fn (ContextPtr, [*:0]const u8, *f64, *f64, ?*bool, ?*f64) callconv(.C) void,
    DebugTextEncoding: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    GetFrameHeight: *fn (ContextPtr) callconv(.C) f64,
    GetFrameHeightWithSpacing: *fn (ContextPtr) callconv(.C) f64,
    GetTextLineHeight: *fn (ContextPtr) callconv(.C) f64,
    GetTextLineHeightWithSpacing: *fn (ContextPtr) callconv(.C) f64,
    LabelText: *fn (ContextPtr, [*:0]const u8, [*:0]const u8) callconv(.C) void,
    PopTextWrapPos: *fn (ContextPtr) callconv(.C) void,
    PushTextWrapPos: *fn (ContextPtr, ?*f64) callconv(.C) void,
    Text: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    TextColored: *fn (ContextPtr, c_int, [*:0]const u8) callconv(.C) void,
    TextDisabled: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    TextWrapped: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    InputDouble: *fn (ContextPtr, [*:0]const u8, *f64, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    InputDouble2: *fn (ContextPtr, [*:0]const u8, *f64, *f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    InputDouble3: *fn (ContextPtr, [*:0]const u8, *f64, *f64, *f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    InputDouble4: *fn (ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    InputDoubleN: *fn (ContextPtr, [*:0]const u8, *reaper_array, ?*f64, ?*f64, ?[*:0]const u8, ?*c_int) callconv(.C) bool,
    InputInt: *fn (ContextPtr, [*:0]const u8, *c_int, ?*c_int, ?*c_int, ?*c_int) callconv(.C) bool,
    InputInt2: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, ?*c_int) callconv(.C) bool,
    InputInt3: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, ?*c_int) callconv(.C) bool,
    InputInt4: *fn (ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, ?*c_int) callconv(.C) bool,
    InputText: *fn (ContextPtr, [*:0]const u8, [*]u8, c_int, ?*c_int, FunctionPtr) callconv(.C) bool,
    InputTextMultiline: *fn (ContextPtr, [*:0]const u8, [*]u8, c_int, ?*f64, ?*f64, ?*c_int, FunctionPtr) callconv(.C) bool,
    InputTextWithHint: *fn (ContextPtr, [*:0]const u8, [*:0]const u8, [*]u8, c_int, ?*c_int, FunctionPtr) callconv(.C) bool,
    CreateTextFilter: *fn (?[*:0]const u8) callconv(.C) TextFilterPtr,
    TextFilter_Clear: *fn (TextFilterPtr) callconv(.C) void,
    TextFilter_Draw: *fn (TextFilterPtr, ContextPtr, ?[*:0]const u8, ?*f64) callconv(.C) bool,
    TextFilter_Get: *fn (TextFilterPtr) callconv(.C) [*:0]const u8,
    TextFilter_IsActive: *fn (TextFilterPtr) callconv(.C) bool,
    TextFilter_PassFilter: *fn (TextFilterPtr, [*:0]const u8) callconv(.C) bool,
    TextFilter_Set: *fn (TextFilterPtr, [*:0]const u8) callconv(.C) void,
    CollapsingHeader: *fn (ContextPtr, [*:0]const u8, ?*bool, ?*c_int) callconv(.C) bool,
    GetTreeNodeToLabelSpacing: *fn (ContextPtr) callconv(.C) f64,
    IsItemToggledOpen: *fn (ContextPtr) callconv(.C) bool,
    SetNextItemOpen: *fn (ContextPtr, bool, ?*c_int) callconv(.C) void,
    TreeNode: *fn (ContextPtr, [*:0]const u8, ?*c_int) callconv(.C) bool,
    TreeNodeEx: *fn (ContextPtr, [*:0]const u8, [*:0]const u8, ?*c_int) callconv(.C) bool,
    TreePop: *fn (ContextPtr) callconv(.C) void,
    TreePush: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    GetBuiltinPath: *fn () callconv(.C) [*:0]const u8,
    GetVersion: *fn ([*]u8, c_int, *c_int, [*]u8, c_int) callconv(.C) void,
    NumericLimits_Double: *fn (*f64, *f64) callconv(.C) void,
    NumericLimits_Float: *fn (*f64, *f64) callconv(.C) void,
    NumericLimits_Int: *fn (*c_int, *c_int) callconv(.C) void,
    PointConvertNative: *fn (ContextPtr, *f64, *f64, ?*bool) callconv(.C) void,
    ProgressBar: *fn (ContextPtr, f64, ?*f64, ?*f64, ?[*:0]const u8) callconv(.C) void,
    ValidatePtr: *fn (*anyopaque, [*:0]const u8) callconv(.C) bool,
    GetClipboardText: *fn (ContextPtr) callconv(.C) [*:0]const u8,
    SetClipboardText: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    ColorConvertDouble4ToU32: *fn (f64, f64, f64, f64) callconv(.C) c_int,
    ColorConvertHSVtoRGB: *fn (f64, f64, f64, *f64, *f64, *f64) callconv(.C) void,
    ColorConvertNative: *fn (c_int) callconv(.C) c_int,
    ColorConvertRGBtoHSV: *fn (f64, f64, f64, *f64, *f64, *f64) callconv(.C) void,
    ColorConvertU32ToDouble4: *fn (c_int, *f64, *f64, *f64, *f64) callconv(.C) void,
    PopID: *fn (ContextPtr) callconv(.C) void,
    PushID: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    LogFinish: *fn (ContextPtr) callconv(.C) void,
    LogText: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    LogToClipboard: *fn (ContextPtr, ?*c_int) callconv(.C) void,
    LogToFile: *fn (ContextPtr, ?*c_int, ?[*:0]const u8) callconv(.C) void,
    LogToTTY: *fn (ContextPtr, ?*c_int) callconv(.C) void,
    GetMainViewport: *fn (ContextPtr) callconv(.C) ViewportPtr,
    GetWindowViewport: *fn (ContextPtr) callconv(.C) ViewportPtr,
    Viewport_GetCenter: *fn (ViewportPtr, *f64, *f64) callconv(.C) void,
    Viewport_GetPos: *fn (ViewportPtr, *f64, *f64) callconv(.C) void,
    Viewport_GetSize: *fn (ViewportPtr, *f64, *f64) callconv(.C) void,
    Viewport_GetWorkCenter: *fn (ViewportPtr, *f64, *f64) callconv(.C) void,
    Viewport_GetWorkPos: *fn (ViewportPtr, *f64, *f64) callconv(.C) void,
    Viewport_GetWorkSize: *fn (ViewportPtr, *f64, *f64) callconv(.C) void,
    Begin: *fn (ContextPtr, [*:0]const u8, ?*bool, ?*c_int) callconv(.C) bool,
    End: *fn (ContextPtr) callconv(.C) void,
    BeginChild: *fn (ContextPtr, [*:0]const u8, ?*f64, ?*f64, ?*c_int, ?*c_int) callconv(.C) bool,
    EndChild: *fn (ContextPtr) callconv(.C) void,
    GetContentRegionAvail: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetContentRegionMax: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetWindowContentRegionMax: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetWindowContentRegionMin: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    ShowAboutWindow: *fn (ContextPtr, ?*bool) callconv(.C) void,
    ShowDebugLogWindow: *fn (ContextPtr, ?*bool) callconv(.C) void,
    ShowIDStackToolWindow: *fn (ContextPtr, ?*bool) callconv(.C) void,
    ShowMetricsWindow: *fn (ContextPtr, ?*bool) callconv(.C) void,
    GetWindowDockID: *fn (ContextPtr) callconv(.C) c_int,
    IsWindowDocked: *fn (ContextPtr) callconv(.C) bool,
    SetNextWindowDockID: *fn (ContextPtr, c_int, ?*c_int) callconv(.C) void,
    GetWindowDpiScale: *fn (ContextPtr) callconv(.C) f64,
    GetWindowHeight: *fn (ContextPtr) callconv(.C) f64,
    GetWindowPos: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetWindowSize: *fn (ContextPtr, *f64, *f64) callconv(.C) void,
    GetWindowWidth: *fn (ContextPtr) callconv(.C) f64,
    IsWindowAppearing: *fn (ContextPtr) callconv(.C) bool,
    IsWindowFocused: *fn (ContextPtr, ?*c_int) callconv(.C) bool,
    IsWindowHovered: *fn (ContextPtr, ?*c_int) callconv(.C) bool,
    SetNextWindowBgAlpha: *fn (ContextPtr, f64) callconv(.C) void,
    SetNextWindowCollapsed: *fn (ContextPtr, bool, ?*c_int) callconv(.C) void,
    SetNextWindowContentSize: *fn (ContextPtr, f64, f64) callconv(.C) void,
    SetNextWindowFocus: *fn (ContextPtr) callconv(.C) void,
    SetNextWindowPos: *fn (ContextPtr, f64, f64, ?*c_int, ?*f64, ?*f64) callconv(.C) void,
    SetNextWindowScroll: *fn (ContextPtr, f64, f64) callconv(.C) void,
    SetNextWindowSize: *fn (ContextPtr, f64, f64, ?*c_int) callconv(.C) void,
    SetNextWindowSizeConstraints: *fn (ContextPtr, f64, f64, f64, f64, FunctionPtr) callconv(.C) void,
    SetWindowCollapsed: *fn (ContextPtr, bool, ?*c_int) callconv(.C) void,
    SetWindowCollapsedEx: *fn (ContextPtr, [*:0]const u8, bool, ?*c_int) callconv(.C) void,
    SetWindowFocus: *fn (ContextPtr) callconv(.C) void,
    SetWindowFocusEx: *fn (ContextPtr, [*:0]const u8) callconv(.C) void,
    SetWindowPos: *fn (ContextPtr, f64, f64, ?*c_int) callconv(.C) void,
    SetWindowPosEx: *fn (ContextPtr, [*:0]const u8, f64, f64, ?*c_int) callconv(.C) void,
    SetWindowSize: *fn (ContextPtr, f64, f64, ?*c_int) callconv(.C) void,
    SetWindowSizeEx: *fn (ContextPtr, [*:0]const u8, f64, f64, ?*c_int) callconv(.C) void,
    GetScrollMaxX: *fn (ContextPtr) callconv(.C) f64,
    GetScrollMaxY: *fn (ContextPtr) callconv(.C) f64,
    GetScrollX: *fn (ContextPtr) callconv(.C) f64,
    GetScrollY: *fn (ContextPtr) callconv(.C) f64,
    SetScrollFromPosX: *fn (ContextPtr, f64, ?*f64) callconv(.C) void,
    SetScrollFromPosY: *fn (ContextPtr, f64, ?*f64) callconv(.C) void,
    SetScrollHereX: *fn (ContextPtr, ?*f64) callconv(.C) void,
    SetScrollHereY: *fn (ContextPtr, ?*f64) callconv(.C) void,
    SetScrollX: *fn (ContextPtr, f64) callconv(.C) void,
    SetScrollY: *fn (ContextPtr, f64) callconv(.C) void,

    pub var Dir_Down: c_int = undefined;
    pub var Dir_Left: c_int = undefined;
    pub var Dir_None: c_int = undefined;
    pub var Dir_Right: c_int = undefined;
    pub var Dir_Up: c_int = undefined;
    pub var ButtonFlags_MouseButtonLeft: c_int = undefined;
    pub var ButtonFlags_MouseButtonMiddle: c_int = undefined;
    pub var ButtonFlags_MouseButtonRight: c_int = undefined;
    pub var ButtonFlags_None: c_int = undefined;
    pub var ColorEditFlags_NoAlpha: c_int = undefined;
    pub var ColorEditFlags_NoBorder: c_int = undefined;
    pub var ColorEditFlags_NoDragDrop: c_int = undefined;
    pub var ColorEditFlags_NoInputs: c_int = undefined;
    pub var ColorEditFlags_NoLabel: c_int = undefined;
    pub var ColorEditFlags_NoOptions: c_int = undefined;
    pub var ColorEditFlags_NoPicker: c_int = undefined;
    pub var ColorEditFlags_NoSidePreview: c_int = undefined;
    pub var ColorEditFlags_NoSmallPreview: c_int = undefined;
    pub var ColorEditFlags_NoTooltip: c_int = undefined;
    pub var ColorEditFlags_None: c_int = undefined;
    pub var ColorEditFlags_AlphaBar: c_int = undefined;
    pub var ColorEditFlags_AlphaPreview: c_int = undefined;
    pub var ColorEditFlags_AlphaPreviewHalf: c_int = undefined;
    pub var ColorEditFlags_DisplayHSV: c_int = undefined;
    pub var ColorEditFlags_DisplayHex: c_int = undefined;
    pub var ColorEditFlags_DisplayRGB: c_int = undefined;
    pub var ColorEditFlags_Float: c_int = undefined;
    pub var ColorEditFlags_InputHSV: c_int = undefined;
    pub var ColorEditFlags_InputRGB: c_int = undefined;
    pub var ColorEditFlags_PickerHueBar: c_int = undefined;
    pub var ColorEditFlags_PickerHueWheel: c_int = undefined;
    pub var ColorEditFlags_Uint8: c_int = undefined;
    pub var ComboFlags_HeightLarge: c_int = undefined;
    pub var ComboFlags_HeightLargest: c_int = undefined;
    pub var ComboFlags_HeightRegular: c_int = undefined;
    pub var ComboFlags_HeightSmall: c_int = undefined;
    pub var ComboFlags_NoArrowButton: c_int = undefined;
    pub var ComboFlags_NoPreview: c_int = undefined;
    pub var ComboFlags_None: c_int = undefined;
    pub var ComboFlags_PopupAlignLeft: c_int = undefined;
    pub var ComboFlags_WidthFitPreview: c_int = undefined;
    pub var SelectableFlags_AllowDoubleClick: c_int = undefined;
    pub var SelectableFlags_AllowOverlap: c_int = undefined;
    pub var SelectableFlags_Disabled: c_int = undefined;
    pub var SelectableFlags_DontClosePopups: c_int = undefined;
    pub var SelectableFlags_None: c_int = undefined;
    pub var SelectableFlags_SpanAllColumns: c_int = undefined;
    pub var ConfigFlags_DockingEnable: c_int = undefined;
    pub var ConfigFlags_NavEnableKeyboard: c_int = undefined;
    pub var ConfigFlags_NavEnableSetMousePos: c_int = undefined;
    pub var ConfigFlags_NavNoCaptureKeyboard: c_int = undefined;
    pub var ConfigFlags_NoMouse: c_int = undefined;
    pub var ConfigFlags_NoMouseCursorChange: c_int = undefined;
    pub var ConfigFlags_NoSavedSettings: c_int = undefined;
    pub var ConfigFlags_None: c_int = undefined;
    pub var ConfigVar_DebugBeginReturnValueLoop: c_int = undefined;
    pub var ConfigVar_DebugBeginReturnValueOnce: c_int = undefined;
    pub var ConfigVar_DockingNoSplit: c_int = undefined;
    pub var ConfigVar_DockingTransparentPayload: c_int = undefined;
    pub var ConfigVar_DockingWithShift: c_int = undefined;
    pub var ConfigVar_DragClickToInputText: c_int = undefined;
    pub var ConfigVar_Flags: c_int = undefined;
    pub var ConfigVar_HoverDelayNormal: c_int = undefined;
    pub var ConfigVar_HoverDelayShort: c_int = undefined;
    pub var ConfigVar_HoverFlagsForTooltipMouse: c_int = undefined;
    pub var ConfigVar_HoverFlagsForTooltipNav: c_int = undefined;
    pub var ConfigVar_HoverStationaryDelay: c_int = undefined;
    pub var ConfigVar_InputTextCursorBlink: c_int = undefined;
    pub var ConfigVar_InputTextEnterKeepActive: c_int = undefined;
    pub var ConfigVar_InputTrickleEventQueue: c_int = undefined;
    pub var ConfigVar_KeyRepeatDelay: c_int = undefined;
    pub var ConfigVar_KeyRepeatRate: c_int = undefined;
    pub var ConfigVar_MacOSXBehaviors: c_int = undefined;
    pub var ConfigVar_MouseDoubleClickMaxDist: c_int = undefined;
    pub var ConfigVar_MouseDoubleClickTime: c_int = undefined;
    pub var ConfigVar_MouseDragThreshold: c_int = undefined;
    pub var ConfigVar_ViewportsNoDecoration: c_int = undefined;
    pub var ConfigVar_WindowsMoveFromTitleBarOnly: c_int = undefined;
    pub var ConfigVar_WindowsResizeFromEdges: c_int = undefined;
    pub var DragDropFlags_None: c_int = undefined;
    pub var DragDropFlags_AcceptBeforeDelivery: c_int = undefined;
    pub var DragDropFlags_AcceptNoDrawDefaultRect: c_int = undefined;
    pub var DragDropFlags_AcceptNoPreviewTooltip: c_int = undefined;
    pub var DragDropFlags_AcceptPeekOnly: c_int = undefined;
    pub var DragDropFlags_SourceAllowNullID: c_int = undefined;
    pub var DragDropFlags_SourceAutoExpirePayload: c_int = undefined;
    pub var DragDropFlags_SourceExtern: c_int = undefined;
    pub var DragDropFlags_SourceNoDisableHover: c_int = undefined;
    pub var DragDropFlags_SourceNoHoldToOpenOthers: c_int = undefined;
    pub var DragDropFlags_SourceNoPreviewTooltip: c_int = undefined;
    pub var SliderFlags_AlwaysClamp: c_int = undefined;
    pub var SliderFlags_Logarithmic: c_int = undefined;
    pub var SliderFlags_NoInput: c_int = undefined;
    pub var SliderFlags_NoRoundToFormat: c_int = undefined;
    pub var SliderFlags_None: c_int = undefined;
    pub var DrawFlags_Closed: c_int = undefined;
    pub var DrawFlags_None: c_int = undefined;
    pub var DrawFlags_RoundCornersAll: c_int = undefined;
    pub var DrawFlags_RoundCornersBottom: c_int = undefined;
    pub var DrawFlags_RoundCornersBottomLeft: c_int = undefined;
    pub var DrawFlags_RoundCornersBottomRight: c_int = undefined;
    pub var DrawFlags_RoundCornersLeft: c_int = undefined;
    pub var DrawFlags_RoundCornersNone: c_int = undefined;
    pub var DrawFlags_RoundCornersRight: c_int = undefined;
    pub var DrawFlags_RoundCornersTop: c_int = undefined;
    pub var DrawFlags_RoundCornersTopLeft: c_int = undefined;
    pub var DrawFlags_RoundCornersTopRight: c_int = undefined;
    pub var FontFlags_Bold: c_int = undefined;
    pub var FontFlags_Italic: c_int = undefined;
    pub var FontFlags_None: c_int = undefined;
    pub var HoveredFlags_AllowWhenBlockedByActiveItem: c_int = undefined;
    pub var HoveredFlags_AllowWhenBlockedByPopup: c_int = undefined;
    pub var HoveredFlags_ForTooltip: c_int = undefined;
    pub var HoveredFlags_NoNavOverride: c_int = undefined;
    pub var HoveredFlags_None: c_int = undefined;
    pub var HoveredFlags_Stationary: c_int = undefined;
    pub var HoveredFlags_AllowWhenDisabled: c_int = undefined;
    pub var HoveredFlags_AllowWhenOverlapped: c_int = undefined;
    pub var HoveredFlags_AllowWhenOverlappedByItem: c_int = undefined;
    pub var HoveredFlags_AllowWhenOverlappedByWindow: c_int = undefined;
    pub var HoveredFlags_RectOnly: c_int = undefined;
    pub var HoveredFlags_DelayNone: c_int = undefined;
    pub var HoveredFlags_DelayNormal: c_int = undefined;
    pub var HoveredFlags_DelayShort: c_int = undefined;
    pub var HoveredFlags_NoSharedDelay: c_int = undefined;
    pub var HoveredFlags_AnyWindow: c_int = undefined;
    pub var HoveredFlags_ChildWindows: c_int = undefined;
    pub var HoveredFlags_DockHierarchy: c_int = undefined;
    pub var HoveredFlags_NoPopupHierarchy: c_int = undefined;
    pub var HoveredFlags_RootAndChildWindows: c_int = undefined;
    pub var HoveredFlags_RootWindow: c_int = undefined;
    pub var Key_0: c_int = undefined;
    pub var Key_1: c_int = undefined;
    pub var Key_2: c_int = undefined;
    pub var Key_3: c_int = undefined;
    pub var Key_4: c_int = undefined;
    pub var Key_5: c_int = undefined;
    pub var Key_6: c_int = undefined;
    pub var Key_7: c_int = undefined;
    pub var Key_8: c_int = undefined;
    pub var Key_9: c_int = undefined;
    pub var Key_A: c_int = undefined;
    pub var Key_Apostrophe: c_int = undefined;
    pub var Key_AppBack: c_int = undefined;
    pub var Key_AppForward: c_int = undefined;
    pub var Key_B: c_int = undefined;
    pub var Key_Backslash: c_int = undefined;
    pub var Key_Backspace: c_int = undefined;
    pub var Key_C: c_int = undefined;
    pub var Key_CapsLock: c_int = undefined;
    pub var Key_Comma: c_int = undefined;
    pub var Key_D: c_int = undefined;
    pub var Key_Delete: c_int = undefined;
    pub var Key_DownArrow: c_int = undefined;
    pub var Key_E: c_int = undefined;
    pub var Key_End: c_int = undefined;
    pub var Key_Enter: c_int = undefined;
    pub var Key_Equal: c_int = undefined;
    pub var Key_Escape: c_int = undefined;
    pub var Key_F: c_int = undefined;
    pub var Key_F1: c_int = undefined;
    pub var Key_F10: c_int = undefined;
    pub var Key_F11: c_int = undefined;
    pub var Key_F12: c_int = undefined;
    pub var Key_F13: c_int = undefined;
    pub var Key_F14: c_int = undefined;
    pub var Key_F15: c_int = undefined;
    pub var Key_F16: c_int = undefined;
    pub var Key_F17: c_int = undefined;
    pub var Key_F18: c_int = undefined;
    pub var Key_F19: c_int = undefined;
    pub var Key_F2: c_int = undefined;
    pub var Key_F20: c_int = undefined;
    pub var Key_F21: c_int = undefined;
    pub var Key_F22: c_int = undefined;
    pub var Key_F23: c_int = undefined;
    pub var Key_F24: c_int = undefined;
    pub var Key_F3: c_int = undefined;
    pub var Key_F4: c_int = undefined;
    pub var Key_F5: c_int = undefined;
    pub var Key_F6: c_int = undefined;
    pub var Key_F7: c_int = undefined;
    pub var Key_F8: c_int = undefined;
    pub var Key_F9: c_int = undefined;
    pub var Key_G: c_int = undefined;
    pub var Key_GraveAccent: c_int = undefined;
    pub var Key_H: c_int = undefined;
    pub var Key_Home: c_int = undefined;
    pub var Key_I: c_int = undefined;
    pub var Key_Insert: c_int = undefined;
    pub var Key_J: c_int = undefined;
    pub var Key_K: c_int = undefined;
    pub var Key_Keypad0: c_int = undefined;
    pub var Key_Keypad1: c_int = undefined;
    pub var Key_Keypad2: c_int = undefined;
    pub var Key_Keypad3: c_int = undefined;
    pub var Key_Keypad4: c_int = undefined;
    pub var Key_Keypad5: c_int = undefined;
    pub var Key_Keypad6: c_int = undefined;
    pub var Key_Keypad7: c_int = undefined;
    pub var Key_Keypad8: c_int = undefined;
    pub var Key_Keypad9: c_int = undefined;
    pub var Key_KeypadAdd: c_int = undefined;
    pub var Key_KeypadDecimal: c_int = undefined;
    pub var Key_KeypadDivide: c_int = undefined;
    pub var Key_KeypadEnter: c_int = undefined;
    pub var Key_KeypadEqual: c_int = undefined;
    pub var Key_KeypadMultiply: c_int = undefined;
    pub var Key_KeypadSubtract: c_int = undefined;
    pub var Key_L: c_int = undefined;
    pub var Key_LeftAlt: c_int = undefined;
    pub var Key_LeftArrow: c_int = undefined;
    pub var Key_LeftBracket: c_int = undefined;
    pub var Key_LeftCtrl: c_int = undefined;
    pub var Key_LeftShift: c_int = undefined;
    pub var Key_LeftSuper: c_int = undefined;
    pub var Key_M: c_int = undefined;
    pub var Key_Menu: c_int = undefined;
    pub var Key_Minus: c_int = undefined;
    pub var Key_N: c_int = undefined;
    pub var Key_NumLock: c_int = undefined;
    pub var Key_O: c_int = undefined;
    pub var Key_P: c_int = undefined;
    pub var Key_PageDown: c_int = undefined;
    pub var Key_PageUp: c_int = undefined;
    pub var Key_Pause: c_int = undefined;
    pub var Key_Period: c_int = undefined;
    pub var Key_PrintScreen: c_int = undefined;
    pub var Key_Q: c_int = undefined;
    pub var Key_R: c_int = undefined;
    pub var Key_RightAlt: c_int = undefined;
    pub var Key_RightArrow: c_int = undefined;
    pub var Key_RightBracket: c_int = undefined;
    pub var Key_RightCtrl: c_int = undefined;
    pub var Key_RightShift: c_int = undefined;
    pub var Key_RightSuper: c_int = undefined;
    pub var Key_S: c_int = undefined;
    pub var Key_ScrollLock: c_int = undefined;
    pub var Key_Semicolon: c_int = undefined;
    pub var Key_Slash: c_int = undefined;
    pub var Key_Space: c_int = undefined;
    pub var Key_T: c_int = undefined;
    pub var Key_Tab: c_int = undefined;
    pub var Key_U: c_int = undefined;
    pub var Key_UpArrow: c_int = undefined;
    pub var Key_V: c_int = undefined;
    pub var Key_W: c_int = undefined;
    pub var Key_X: c_int = undefined;
    pub var Key_Y: c_int = undefined;
    pub var Key_Z: c_int = undefined;
    pub var Mod_Alt: c_int = undefined;
    pub var Mod_Ctrl: c_int = undefined;
    pub var Mod_None: c_int = undefined;
    pub var Mod_Shift: c_int = undefined;
    pub var Mod_Shortcut: c_int = undefined;
    pub var Mod_Super: c_int = undefined;
    pub var Key_MouseLeft: c_int = undefined;
    pub var Key_MouseMiddle: c_int = undefined;
    pub var Key_MouseRight: c_int = undefined;
    pub var Key_MouseWheelX: c_int = undefined;
    pub var Key_MouseWheelY: c_int = undefined;
    pub var Key_MouseX1: c_int = undefined;
    pub var Key_MouseX2: c_int = undefined;
    pub var MouseButton_Left: c_int = undefined;
    pub var MouseButton_Middle: c_int = undefined;
    pub var MouseButton_Right: c_int = undefined;
    pub var MouseCursor_Arrow: c_int = undefined;
    pub var MouseCursor_Hand: c_int = undefined;
    pub var MouseCursor_None: c_int = undefined;
    pub var MouseCursor_NotAllowed: c_int = undefined;
    pub var MouseCursor_ResizeAll: c_int = undefined;
    pub var MouseCursor_ResizeEW: c_int = undefined;
    pub var MouseCursor_ResizeNESW: c_int = undefined;
    pub var MouseCursor_ResizeNS: c_int = undefined;
    pub var MouseCursor_ResizeNWSE: c_int = undefined;
    pub var MouseCursor_TextInput: c_int = undefined;
    pub var PopupFlags_None: c_int = undefined;
    pub var PopupFlags_MouseButtonLeft: c_int = undefined;
    pub var PopupFlags_MouseButtonMiddle: c_int = undefined;
    pub var PopupFlags_MouseButtonRight: c_int = undefined;
    pub var PopupFlags_NoOpenOverItems: c_int = undefined;
    pub var PopupFlags_AnyPopup: c_int = undefined;
    pub var PopupFlags_AnyPopupId: c_int = undefined;
    pub var PopupFlags_AnyPopupLevel: c_int = undefined;
    pub var PopupFlags_NoOpenOverExistingPopup: c_int = undefined;
    pub var PopupFlags_NoReopen: c_int = undefined;
    pub var Col_Border: c_int = undefined;
    pub var Col_BorderShadow: c_int = undefined;
    pub var Col_Button: c_int = undefined;
    pub var Col_ButtonActive: c_int = undefined;
    pub var Col_ButtonHovered: c_int = undefined;
    pub var Col_CheckMark: c_int = undefined;
    pub var Col_ChildBg: c_int = undefined;
    pub var Col_DockingEmptyBg: c_int = undefined;
    pub var Col_DockingPreview: c_int = undefined;
    pub var Col_DragDropTarget: c_int = undefined;
    pub var Col_FrameBg: c_int = undefined;
    pub var Col_FrameBgActive: c_int = undefined;
    pub var Col_FrameBgHovered: c_int = undefined;
    pub var Col_Header: c_int = undefined;
    pub var Col_HeaderActive: c_int = undefined;
    pub var Col_HeaderHovered: c_int = undefined;
    pub var Col_MenuBarBg: c_int = undefined;
    pub var Col_ModalWindowDimBg: c_int = undefined;
    pub var Col_NavHighlight: c_int = undefined;
    pub var Col_NavWindowingDimBg: c_int = undefined;
    pub var Col_NavWindowingHighlight: c_int = undefined;
    pub var Col_PlotHistogram: c_int = undefined;
    pub var Col_PlotHistogramHovered: c_int = undefined;
    pub var Col_PlotLines: c_int = undefined;
    pub var Col_PlotLinesHovered: c_int = undefined;
    pub var Col_PopupBg: c_int = undefined;
    pub var Col_ResizeGrip: c_int = undefined;
    pub var Col_ResizeGripActive: c_int = undefined;
    pub var Col_ResizeGripHovered: c_int = undefined;
    pub var Col_ScrollbarBg: c_int = undefined;
    pub var Col_ScrollbarGrab: c_int = undefined;
    pub var Col_ScrollbarGrabActive: c_int = undefined;
    pub var Col_ScrollbarGrabHovered: c_int = undefined;
    pub var Col_Separator: c_int = undefined;
    pub var Col_SeparatorActive: c_int = undefined;
    pub var Col_SeparatorHovered: c_int = undefined;
    pub var Col_SliderGrab: c_int = undefined;
    pub var Col_SliderGrabActive: c_int = undefined;
    pub var Col_Tab: c_int = undefined;
    pub var Col_TabActive: c_int = undefined;
    pub var Col_TabHovered: c_int = undefined;
    pub var Col_TabUnfocused: c_int = undefined;
    pub var Col_TabUnfocusedActive: c_int = undefined;
    pub var Col_TableBorderLight: c_int = undefined;
    pub var Col_TableBorderStrong: c_int = undefined;
    pub var Col_TableHeaderBg: c_int = undefined;
    pub var Col_TableRowBg: c_int = undefined;
    pub var Col_TableRowBgAlt: c_int = undefined;
    pub var Col_Text: c_int = undefined;
    pub var Col_TextDisabled: c_int = undefined;
    pub var Col_TextSelectedBg: c_int = undefined;
    pub var Col_TitleBg: c_int = undefined;
    pub var Col_TitleBgActive: c_int = undefined;
    pub var Col_TitleBgCollapsed: c_int = undefined;
    pub var Col_WindowBg: c_int = undefined;
    pub var StyleVar_Alpha: c_int = undefined;
    pub var StyleVar_ButtonTextAlign: c_int = undefined;
    pub var StyleVar_CellPadding: c_int = undefined;
    pub var StyleVar_ChildBorderSize: c_int = undefined;
    pub var StyleVar_ChildRounding: c_int = undefined;
    pub var StyleVar_DisabledAlpha: c_int = undefined;
    pub var StyleVar_FrameBorderSize: c_int = undefined;
    pub var StyleVar_FramePadding: c_int = undefined;
    pub var StyleVar_FrameRounding: c_int = undefined;
    pub var StyleVar_GrabMinSize: c_int = undefined;
    pub var StyleVar_GrabRounding: c_int = undefined;
    pub var StyleVar_IndentSpacing: c_int = undefined;
    pub var StyleVar_ItemInnerSpacing: c_int = undefined;
    pub var StyleVar_ItemSpacing: c_int = undefined;
    pub var StyleVar_PopupBorderSize: c_int = undefined;
    pub var StyleVar_PopupRounding: c_int = undefined;
    pub var StyleVar_ScrollbarRounding: c_int = undefined;
    pub var StyleVar_ScrollbarSize: c_int = undefined;
    pub var StyleVar_SelectableTextAlign: c_int = undefined;
    pub var StyleVar_SeparatorTextAlign: c_int = undefined;
    pub var StyleVar_SeparatorTextBorderSize: c_int = undefined;
    pub var StyleVar_SeparatorTextPadding: c_int = undefined;
    pub var StyleVar_TabBarBorderSize: c_int = undefined;
    pub var StyleVar_TabBorderSize: c_int = undefined;
    pub var StyleVar_TabRounding: c_int = undefined;
    pub var StyleVar_TableAngledHeadersAngle: c_int = undefined;
    pub var StyleVar_TableAngledHeadersTextAlign: c_int = undefined;
    pub var StyleVar_WindowBorderSize: c_int = undefined;
    pub var StyleVar_WindowMinSize: c_int = undefined;
    pub var StyleVar_WindowPadding: c_int = undefined;
    pub var StyleVar_WindowRounding: c_int = undefined;
    pub var StyleVar_WindowTitleAlign: c_int = undefined;
    pub var TabBarFlags_AutoSelectNewTabs: c_int = undefined;
    pub var TabBarFlags_FittingPolicyResizeDown: c_int = undefined;
    pub var TabBarFlags_FittingPolicyScroll: c_int = undefined;
    pub var TabBarFlags_NoCloseWithMiddleMouseButton: c_int = undefined;
    pub var TabBarFlags_NoTabListScrollingButtons: c_int = undefined;
    pub var TabBarFlags_NoTooltip: c_int = undefined;
    pub var TabBarFlags_None: c_int = undefined;
    pub var TabBarFlags_Reorderable: c_int = undefined;
    pub var TabBarFlags_TabListPopupButton: c_int = undefined;
    pub var TabItemFlags_Leading: c_int = undefined;
    pub var TabItemFlags_NoAssumedClosure: c_int = undefined;
    pub var TabItemFlags_NoCloseWithMiddleMouseButton: c_int = undefined;
    pub var TabItemFlags_NoPushId: c_int = undefined;
    pub var TabItemFlags_NoReorder: c_int = undefined;
    pub var TabItemFlags_NoTooltip: c_int = undefined;
    pub var TabItemFlags_None: c_int = undefined;
    pub var TabItemFlags_SetSelected: c_int = undefined;
    pub var TabItemFlags_Trailing: c_int = undefined;
    pub var TabItemFlags_UnsavedDocument: c_int = undefined;
    pub var TableRowFlags_Headers: c_int = undefined;
    pub var TableRowFlags_None: c_int = undefined;
    pub var TableBgTarget_CellBg: c_int = undefined;
    pub var TableBgTarget_None: c_int = undefined;
    pub var TableBgTarget_RowBg0: c_int = undefined;
    pub var TableBgTarget_RowBg1: c_int = undefined;
    pub var TableColumnFlags_None: c_int = undefined;
    pub var TableColumnFlags_AngledHeader: c_int = undefined;
    pub var TableColumnFlags_DefaultHide: c_int = undefined;
    pub var TableColumnFlags_DefaultSort: c_int = undefined;
    pub var TableColumnFlags_Disabled: c_int = undefined;
    pub var TableColumnFlags_IndentDisable: c_int = undefined;
    pub var TableColumnFlags_IndentEnable: c_int = undefined;
    pub var TableColumnFlags_NoClip: c_int = undefined;
    pub var TableColumnFlags_NoHeaderLabel: c_int = undefined;
    pub var TableColumnFlags_NoHeaderWidth: c_int = undefined;
    pub var TableColumnFlags_NoHide: c_int = undefined;
    pub var TableColumnFlags_NoReorder: c_int = undefined;
    pub var TableColumnFlags_NoResize: c_int = undefined;
    pub var TableColumnFlags_NoSort: c_int = undefined;
    pub var TableColumnFlags_NoSortAscending: c_int = undefined;
    pub var TableColumnFlags_NoSortDescending: c_int = undefined;
    pub var TableColumnFlags_PreferSortAscending: c_int = undefined;
    pub var TableColumnFlags_PreferSortDescending: c_int = undefined;
    pub var TableColumnFlags_WidthFixed: c_int = undefined;
    pub var TableColumnFlags_WidthStretch: c_int = undefined;
    pub var TableColumnFlags_IsEnabled: c_int = undefined;
    pub var TableColumnFlags_IsHovered: c_int = undefined;
    pub var TableColumnFlags_IsSorted: c_int = undefined;
    pub var TableColumnFlags_IsVisible: c_int = undefined;
    pub var SortDirection_Ascending: c_int = undefined;
    pub var SortDirection_Descending: c_int = undefined;
    pub var SortDirection_None: c_int = undefined;
    pub var TableFlags_None: c_int = undefined;
    pub var TableFlags_NoClip: c_int = undefined;
    pub var TableFlags_Borders: c_int = undefined;
    pub var TableFlags_BordersH: c_int = undefined;
    pub var TableFlags_BordersInner: c_int = undefined;
    pub var TableFlags_BordersInnerH: c_int = undefined;
    pub var TableFlags_BordersInnerV: c_int = undefined;
    pub var TableFlags_BordersOuter: c_int = undefined;
    pub var TableFlags_BordersOuterH: c_int = undefined;
    pub var TableFlags_BordersOuterV: c_int = undefined;
    pub var TableFlags_BordersV: c_int = undefined;
    pub var TableFlags_RowBg: c_int = undefined;
    pub var TableFlags_ContextMenuInBody: c_int = undefined;
    pub var TableFlags_Hideable: c_int = undefined;
    pub var TableFlags_NoSavedSettings: c_int = undefined;
    pub var TableFlags_Reorderable: c_int = undefined;
    pub var TableFlags_Resizable: c_int = undefined;
    pub var TableFlags_Sortable: c_int = undefined;
    pub var TableFlags_HighlightHoveredColumn: c_int = undefined;
    pub var TableFlags_NoPadInnerX: c_int = undefined;
    pub var TableFlags_NoPadOuterX: c_int = undefined;
    pub var TableFlags_PadOuterX: c_int = undefined;
    pub var TableFlags_ScrollX: c_int = undefined;
    pub var TableFlags_ScrollY: c_int = undefined;
    pub var TableFlags_NoHostExtendX: c_int = undefined;
    pub var TableFlags_NoHostExtendY: c_int = undefined;
    pub var TableFlags_NoKeepColumnsVisible: c_int = undefined;
    pub var TableFlags_PreciseWidths: c_int = undefined;
    pub var TableFlags_SizingFixedFit: c_int = undefined;
    pub var TableFlags_SizingFixedSame: c_int = undefined;
    pub var TableFlags_SizingStretchProp: c_int = undefined;
    pub var TableFlags_SizingStretchSame: c_int = undefined;
    pub var TableFlags_SortMulti: c_int = undefined;
    pub var TableFlags_SortTristate: c_int = undefined;
    pub var InputTextFlags_AllowTabInput: c_int = undefined;
    pub var InputTextFlags_AlwaysOverwrite: c_int = undefined;
    pub var InputTextFlags_AutoSelectAll: c_int = undefined;
    pub var InputTextFlags_CallbackAlways: c_int = undefined;
    pub var InputTextFlags_CallbackCharFilter: c_int = undefined;
    pub var InputTextFlags_CallbackCompletion: c_int = undefined;
    pub var InputTextFlags_CallbackEdit: c_int = undefined;
    pub var InputTextFlags_CallbackHistory: c_int = undefined;
    pub var InputTextFlags_CharsDecimal: c_int = undefined;
    pub var InputTextFlags_CharsHexadecimal: c_int = undefined;
    pub var InputTextFlags_CharsNoBlank: c_int = undefined;
    pub var InputTextFlags_CharsScientific: c_int = undefined;
    pub var InputTextFlags_CharsUppercase: c_int = undefined;
    pub var InputTextFlags_CtrlEnterForNewLine: c_int = undefined;
    pub var InputTextFlags_EnterReturnsTrue: c_int = undefined;
    pub var InputTextFlags_EscapeClearsAll: c_int = undefined;
    pub var InputTextFlags_NoHorizontalScroll: c_int = undefined;
    pub var InputTextFlags_NoUndoRedo: c_int = undefined;
    pub var InputTextFlags_None: c_int = undefined;
    pub var InputTextFlags_Password: c_int = undefined;
    pub var InputTextFlags_ReadOnly: c_int = undefined;
    pub var TreeNodeFlags_AllowOverlap: c_int = undefined;
    pub var TreeNodeFlags_Bullet: c_int = undefined;
    pub var TreeNodeFlags_CollapsingHeader: c_int = undefined;
    pub var TreeNodeFlags_DefaultOpen: c_int = undefined;
    pub var TreeNodeFlags_FramePadding: c_int = undefined;
    pub var TreeNodeFlags_Framed: c_int = undefined;
    pub var TreeNodeFlags_Leaf: c_int = undefined;
    pub var TreeNodeFlags_NoAutoOpenOnLog: c_int = undefined;
    pub var TreeNodeFlags_NoTreePushOnOpen: c_int = undefined;
    pub var TreeNodeFlags_None: c_int = undefined;
    pub var TreeNodeFlags_OpenOnArrow: c_int = undefined;
    pub var TreeNodeFlags_OpenOnDoubleClick: c_int = undefined;
    pub var TreeNodeFlags_Selected: c_int = undefined;
    pub var TreeNodeFlags_SpanAllColumns: c_int = undefined;
    pub var TreeNodeFlags_SpanAvailWidth: c_int = undefined;
    pub var TreeNodeFlags_SpanFullWidth: c_int = undefined;
    pub var TreeNodeFlags_SpanTextWidth: c_int = undefined;
    pub var Cond_Always: c_int = undefined;
    pub var Cond_Appearing: c_int = undefined;
    pub var Cond_FirstUseEver: c_int = undefined;
    pub var Cond_Once: c_int = undefined;
    pub var ChildFlags_AlwaysAutoResize: c_int = undefined;
    pub var ChildFlags_AlwaysUseWindowPadding: c_int = undefined;
    pub var ChildFlags_AutoResizeX: c_int = undefined;
    pub var ChildFlags_AutoResizeY: c_int = undefined;
    pub var ChildFlags_Border: c_int = undefined;
    pub var ChildFlags_FrameStyle: c_int = undefined;
    pub var ChildFlags_None: c_int = undefined;
    pub var ChildFlags_ResizeX: c_int = undefined;
    pub var ChildFlags_ResizeY: c_int = undefined;
    pub var WindowFlags_AlwaysAutoResize: c_int = undefined;
    pub var WindowFlags_AlwaysHorizontalScrollbar: c_int = undefined;
    pub var WindowFlags_AlwaysVerticalScrollbar: c_int = undefined;
    pub var WindowFlags_HorizontalScrollbar: c_int = undefined;
    pub var WindowFlags_MenuBar: c_int = undefined;
    pub var WindowFlags_NoBackground: c_int = undefined;
    pub var WindowFlags_NoCollapse: c_int = undefined;
    pub var WindowFlags_NoDecoration: c_int = undefined;
    pub var WindowFlags_NoDocking: c_int = undefined;
    pub var WindowFlags_NoFocusOnAppearing: c_int = undefined;
    pub var WindowFlags_NoInputs: c_int = undefined;
    pub var WindowFlags_NoMouseInputs: c_int = undefined;
    pub var WindowFlags_NoMove: c_int = undefined;
    pub var WindowFlags_NoNav: c_int = undefined;
    pub var WindowFlags_NoNavFocus: c_int = undefined;
    pub var WindowFlags_NoNavInputs: c_int = undefined;
    pub var WindowFlags_NoResize: c_int = undefined;
    pub var WindowFlags_NoSavedSettings: c_int = undefined;
    pub var WindowFlags_NoScrollWithMouse: c_int = undefined;
    pub var WindowFlags_NoScrollbar: c_int = undefined;
    pub var WindowFlags_NoTitleBar: c_int = undefined;
    pub var WindowFlags_None: c_int = undefined;
    pub var WindowFlags_TopMost: c_int = undefined;
    pub var WindowFlags_UnsavedDocument: c_int = undefined;
    pub var FocusedFlags_AnyWindow: c_int = undefined;
    pub var FocusedFlags_ChildWindows: c_int = undefined;
    pub var FocusedFlags_DockHierarchy: c_int = undefined;
    pub var FocusedFlags_NoPopupHierarchy: c_int = undefined;
    pub var FocusedFlags_None: c_int = undefined;
    pub var FocusedFlags_RootAndChildWindows: c_int = undefined;
    pub var FocusedFlags_RootWindow: c_int = undefined;
};

var api: API = undefined;
pub usingnamespace API;

///-- **Button > ArrowButton**
///--
///-- Square button with an arrow shape. 'dir' is one of the Dir_* values
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param dir integer
///-- @return boolean retval
pub const ArrowButton = function(&api.ArrowButton, 3, &.{ ContextPtr, [*:0]const u8, c_int });
///-- **Button > Button**
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param size_w? number default value = `0.0`
///-- @param size_h? number default value = `0.0`
///-- @return boolean retval
pub const Button = function(&api.Button, 2, &.{ ContextPtr, [*:0]const u8, ?f64, ?f64 });
///-- **Button > Checkbox**
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v boolean
///-- @return boolean retval
///-- @return boolean v
pub const Checkbox = function(&api.Checkbox, 3, &.{ ContextPtr, [*:0]const u8, *bool });
///-- **Button > CheckboxFlags**
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param flags integer
///-- @param flags_value integer
///-- @return boolean retval
///-- @return integer flags
pub const CheckboxFlags = function(&api.CheckboxFlags, 4, &.{ ContextPtr, [*:0]const u8, *c_int, c_int });
///-- **Button > InvisibleButton**
///--
///-- Flexible button behavior without the visuals, frequently useful to build
///-- custom behaviors using the public api (along with IsItemActive, IsItemHovered, etc.).
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param size_w number
///-- @param size_h number
///-- @param flags? integer default value = `ButtonFlags_None`
///-- @return boolean retval
pub const InvisibleButton = function(&api.InvisibleButton, 4, &.{ ContextPtr, [*:0]const u8, f64, f64, ?c_int });
///-- **Button > PopButtonRepeat**
///--
///-- See PushButtonRepeat
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const PopButtonRepeat = function(&api.PopButtonRepeat, 1, &.{ContextPtr});
///-- **Button > PushButtonRepeat**
///--
///-- In 'repeat' mode, Button*() functions return repeated true in a typematic
///-- manner (using ConfigVar_KeyRepeatDelay/ConfigVar_KeyRepeatRate settings).
///--
///-- Note that you can call IsItemActive after any Button to tell if the button is
///-- held in the current frame.
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param repeat boolean
pub const PushButtonRepeat = function(&api.PushButtonRepeat, 2, &.{ ContextPtr, bool });
///-- **Button > RadioButton**
///--
///-- Use with e.g. if (RadioButton("one", my_value==1)) { my_value = 1; }
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param active boolean
///-- @return boolean retval
pub const RadioButton = function(&api.RadioButton, 3, &.{ ContextPtr, [*:0]const u8, bool });
///-- **Button > RadioButtonEx**
///--
///-- Shortcut to handle RadioButton's example pattern when value is an integer
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_button integer
///-- @return boolean retval
///-- @return integer v
pub const RadioButtonEx = function(&api.RadioButtonEx, 4, &.{ ContextPtr, [*:0]const u8, *c_int, c_int });
///-- **Button > SmallButton**
///--
///-- Button with StyleVar_FramePadding.y == 0 to easily embed within text.
///--
///-- ---
///--
///-- **Button**
///--
///-- Most widgets return true when the value has been changed or when pressed/selected.
///--
///-- You may also use one of the many IsItem* functions (e.g. IsItemActive,
///-- IsItemHovered, etc.) to query widget state.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @return boolean retval
pub const SmallButton = function(&api.SmallButton, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Color Edit > ColorButton**
///--
///-- Display a color square/button, hover for details, return true when pressed.
///-- Color is in 0xRRGGBBAA or, if ColorEditFlags_NoAlpha is set, 0xRRGGBB.
///--
///-- ---
///--
///-- **Color Edit**
///--
///-- Tip: the ColorEdit* functions have a little color square that can be
///-- left-clicked to open a picker, and right-clicked to open an option menu.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param desc_id string
///-- @param col_rgba integer
///-- @param flags? integer default value = `ColorEditFlags_None`
///-- @param size_w? number default value = `0.0`
///-- @param size_h? number default value = `0.0`
///-- @return boolean retval
pub const ColorButton = function(&api.ColorButton, 3, &.{ ContextPtr, [*:0]const u8, c_int, ?c_int, ?f64, ?f64 });
pub const ColorEdit3 = function(&api.ColorEdit3, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int });
pub const ColorEdit4 = function(&api.ColorEdit4, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int });
pub const ColorPicker3 = function(&api.ColorPicker3, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int });
pub const ColorPicker4 = function(&api.ColorPicker4, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int, ?c_int });
///-- **Color Edit > SetColorEditOptions**
///--
///-- Picker type, etc. User will be able to change many settings, unless you pass
///-- the _NoOptions flag to your calls.
///--
///-- ---
///--
///-- **Color Edit**
///--
///-- Tip: the ColorEdit* functions have a little color square that can be
///-- left-clicked to open a picker, and right-clicked to open an option menu.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param flags integer
pub const SetColorEditOptions = function(&api.SetColorEditOptions, 2, &.{ ContextPtr, c_int });
///-- **Combo \& List > Combo Box \(Dropdown\) > BeginCombo**
///--
///-- The BeginCombo/EndCombo API allows you to manage your contents and selection
///-- state however you want it, by creating e.g. Selectable items.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param preview_value string
///-- @param flags? integer default value = `ComboFlags_None`
///-- @nodiscard
///-- @return boolean retval
pub const BeginCombo = function(&api.BeginCombo, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, ?c_int });
///-- **Combo \& List > Combo Box \(Dropdown\) > Combo**
///--
///-- Helper over BeginCombo/EndCombo for convenience purpose. Each item must be
///-- null-terminated (requires REAPER v6.44 or newer for EEL and Lua).
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param current_item integer
///-- @param items string
///-- @param popup_max_height_in_items? integer default value = `-1`
///-- @return boolean retval
///-- @return integer current_item
pub const Combo = function(&api.Combo, 5, &.{ ContextPtr, [*:0]const u8, *c_int, [*:0]const u8, c_int, ?c_int });
///-- **Combo \& List > Combo Box \(Dropdown\) > EndCombo**
///--
///-- Only call EndCombo() if BeginCombo returns true!
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndCombo = function(&api.EndCombo, 1, &.{ContextPtr});
///-- **Combo \& List > List Boxes > BeginListBox**
///--
///-- Open a framed scrolling region.
///--
///-- You can submit contents and manage your selection state however you want it,
///-- by creating e.g. Selectable or any other items.
///--
///-- - Choose frame width:
///--   - width  > 0.0: custom
///--   - width  < 0.0 or -FLT_MIN: right-align
///--   - width  = 0.0 (default): use current ItemWidth
///-- - Choose frame height:
///--   - height > 0.0: custom
///--   - height < 0.0 or -FLT_MIN: bottom-align
///--   - height = 0.0 (default): arbitrary default height which can fit ~7 items
///--
///-- See EndListBox.
///--
///-- ---
///--
///-- **Combo \& List > List Boxes**
///--
///-- This is essentially a thin wrapper to using BeginChild/EndChild with the
///-- ChildFlags_FrameStyle flag for stylistic changes + displaying a label.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param size_w? number default value = `0.0`
///-- @param size_h? number default value = `0.0`
///-- @nodiscard
///-- @return boolean retval
pub const BeginListBox = function(&api.BeginListBox, 2, &.{ ContextPtr, [*:0]const u8, ?f64, ?f64 });
///-- **Combo \& List > List Boxes > EndListBox**
///--
///-- Only call EndListBox() if BeginListBox returned true!
///--
///-- ---
///--
///-- **Combo \& List > List Boxes**
///--
///-- This is essentially a thin wrapper to using BeginChild/EndChild with the
///-- ChildFlags_FrameStyle flag for stylistic changes + displaying a label.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndListBox = function(&api.EndListBox, 1, &.{ContextPtr});
///-- **Combo \& List > List Boxes > ListBox**
///--
///-- This is an helper over BeginListBox/EndListBox for convenience purpose.
///--
///-- Each item must be null-terminated (requires REAPER v6.44 or newer for EEL and Lua).
///--
///-- ---
///--
///-- **Combo \& List > List Boxes**
///--
///-- This is essentially a thin wrapper to using BeginChild/EndChild with the
///-- ChildFlags_FrameStyle flag for stylistic changes + displaying a label.
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param current_item integer
///-- @param items string
///-- @param height_in_items? integer default value = `-1`
///-- @return boolean retval
///-- @return integer current_item
pub const ListBox = function(&api.ListBox, 5, &.{ ContextPtr, [*:0]const u8, *c_int, [*:0]const u8, c_int, ?c_int });
///-- **Combo \& List > Selectables > Selectable**
///--
///-- ---
///--
///-- **Combo \& List > Selectables**
///--
///-- A selectable highlights when hovered, and can display another color when
///-- selected. Neighbors selectable extend their highlight bounds in order to leave
///-- no gap between them. This is so a series of selected Selectable appear
///-- contiguous.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param p_selected? boolean default value = `nil`
///-- @param flags? integer default value = `SelectableFlags_None`
///-- @param size_w? number default value = `0.0`
///-- @param size_h? number default value = `0.0`
///-- @return boolean retval
///-- @return boolean p_selected
pub const Selectable = function(&api.Selectable, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int, ?f64, ?f64 });
///-- **Context > Attach**
///--
///-- Link the object's lifetime to the given context.
///-- Objects can be draw list splitters, fonts, images, list clippers, etc.
///-- Call Detach to let the object be garbage-collected after unuse again.
///--
///-- List clipper objects may only be attached to the context they were created for.
///--
///-- Fonts are (currently) a special case: they must be attached to the context
///-- before usage. Furthermore, fonts may only be attached or detached immediately
///-- after the context is created or before any other function calls modifying the
///-- context per defer cycle. See "limitations" in the font API documentation.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @param obj ImGui_Resource
pub const Attach = function(&api.Attach, 2, &.{ ContextPtr, ResourcePtr });
///-- **Context > CreateContext**
///--
///-- Create a new ReaImGui context.
///-- The context will remain valid as long as it is used in each defer cycle.
///--
///-- The label is used for the tab text when windows are docked in REAPER
///-- and also as a unique identifier for storing settings.
///--
///-- ---
///--
///-- @since 0.5
///-- @param label string
///-- @param config_flags? integer default value = `ConfigFlags_None`
///-- @nodiscard
///-- @return ImGui_Context retval
pub const CreateContext = function(&api.CreateContext, 1, &.{ [*:0]const u8, ?c_int });
///-- **Context > Detach**
///--
///-- Unlink the object's lifetime. Unattached objects are automatically destroyed
///-- when left unused. You may check whether an object has been destroyed using
///-- ValidatePtr.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @param obj ImGui_Resource
pub const Detach = function(&api.Detach, 2, &.{ ContextPtr, ResourcePtr });
///-- **Context > GetDeltaTime**
///--
///-- Time elapsed since last frame, in seconds.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetDeltaTime = function(&api.GetDeltaTime, 1, &.{ContextPtr});
///-- **Context > GetFrameCount**
///--
///-- Get global imgui frame count. incremented by 1 every frame.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const GetFrameCount = function(&api.GetFrameCount, 1, &.{ContextPtr});
///-- **Context > GetFramerate**
///--
///-- Estimate of application framerate (rolling average over 60 frames, based on
///-- GetDeltaTime), in frame per second. Solely for convenience.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetFramerate = function(&api.GetFramerate, 1, &.{ContextPtr});
///-- **Context > GetTime**
///--
///-- Get global imgui time. Incremented every frame.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetTime = function(&api.GetTime, 1, &.{ContextPtr});
///-- **Context > Options > GetConfigVar**
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param var_idx integer
///-- @return number retval
pub const GetConfigVar = function(&api.GetConfigVar, 2, &.{ ContextPtr, c_int });
///-- **Context > Options > SetConfigVar**
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param var_idx integer
///-- @param value number
pub const SetConfigVar = function(&api.SetConfigVar, 3, &.{ ContextPtr, c_int, f64 });
///-- **Drag \& Drop > AcceptDragDropPayload**
///--
///-- Accept contents of a given type. If DragDropFlags_AcceptBeforeDelivery is set
///-- you can peek into the payload before the mouse button is released.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param type string
///-- @param _1? nil​
///-- @param flags? integer default value = `DragDropFlags_None`
///-- @return boolean retval
///-- @return string payload
pub const AcceptDragDropPayload = function(&api.AcceptDragDropPayload, 4, &.{ ContextPtr, [*:0]const u8, [*]u8, c_int, ?c_int });
///-- **Drag \& Drop > AcceptDragDropPayloadFiles**
///--
///-- Accept a list of dropped files. See AcceptDragDropPayload and GetDragDropPayloadFile.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param _1? nil​
///-- @param flags? integer default value = `DragDropFlags_None`
///-- @return boolean retval
///-- @return integer count
pub const AcceptDragDropPayloadFiles = function(&api.AcceptDragDropPayloadFiles, 2, &.{ ContextPtr, *c_int, ?c_int });
///-- **Drag \& Drop > AcceptDragDropPayloadRGB**
///--
///-- Accept a RGB color. See AcceptDragDropPayload.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param _1? nil​
///-- @param flags? integer default value = `DragDropFlags_None`
///-- @return boolean retval
///-- @return integer rgb
pub const AcceptDragDropPayloadRGB = function(&api.AcceptDragDropPayloadRGB, 2, &.{ ContextPtr, *c_int, ?c_int });
///-- **Drag \& Drop > AcceptDragDropPayloadRGBA**
///--
///-- Accept a RGBA color. See AcceptDragDropPayload.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param _1? nil​
///-- @param flags? integer default value = `DragDropFlags_None`
///-- @return boolean retval
///-- @return integer rgba
pub const AcceptDragDropPayloadRGBA = function(&api.AcceptDragDropPayloadRGBA, 2, &.{ ContextPtr, *c_int, ?c_int });
///-- **Drag \& Drop > BeginDragDropSource**
///--
///-- Call after submitting an item which may be dragged. when this return true,
///-- you can call SetDragDropPayload() + EndDragDropSource()
///--
///-- If you stop calling BeginDragDropSource() the payload is preserved however
///-- it won't have a preview tooltip (we currently display a fallback "..." tooltip
///-- as replacement).
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param flags? integer default value = `DragDropFlags_None`
///-- @nodiscard
///-- @return boolean retval
pub const BeginDragDropSource = function(&api.BeginDragDropSource, 1, &.{ ContextPtr, ?c_int });
///-- **Drag \& Drop > BeginDragDropTarget**
///--
///-- Call after submitting an item that may receive a payload.
///-- If this returns true, you can call AcceptDragDropPayload + EndDragDropTarget.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @nodiscard
///-- @return boolean retval
pub const BeginDragDropTarget = function(&api.BeginDragDropTarget, 1, &.{ContextPtr});
///-- **Drag \& Drop > EndDragDropSource**
///--
///-- Only call EndDragDropSource() if BeginDragDropSource returns true!
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndDragDropSource = function(&api.EndDragDropSource, 1, &.{ContextPtr});
///-- **Drag \& Drop > EndDragDropTarget**
///--
///-- Only call EndDragDropTarget() if BeginDragDropTarget returns true!
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndDragDropTarget = function(&api.EndDragDropTarget, 1, &.{ContextPtr});
///-- **Drag \& Drop > GetDragDropPayload**
///--
///-- Peek directly into the current payload from anywhere.
///-- Returns false when drag and drop is finished or inactive.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
///-- @return string type
///-- @return string payload
///-- @return boolean is_preview
///-- @return boolean is_delivery
pub const GetDragDropPayload = function(&api.GetDragDropPayload, 7, &.{ ContextPtr, [*]u8, c_int, [*]u8, c_int, *bool, *bool });
///-- **Drag \& Drop > GetDragDropPayloadFile**
///--
///-- Get a filename from the list of dropped files.
///-- Returns false if index is out of bounds.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param index integer
///-- @return boolean retval
///-- @return string filename
pub const GetDragDropPayloadFile = function(&api.GetDragDropPayloadFile, 4, &.{ ContextPtr, c_int, [*]u8, c_int });
///-- **Drag \& Drop > SetDragDropPayload**
///--
///-- The type is a user defined string of maximum 32 characters.
///-- Strings starting with '_' are reserved for dear imgui internal types.
///-- Data is copied and held by imgui.
///--
///-- ---
///--
///-- **Drag \& Drop**
///--
///-- On source items, call BeginDragDropSource(),
///-- if it returns true also call SetDragDropPayload() + EndDragDropSource().
///--
///-- On target candidates, call BeginDragDropTarget(),
///-- if it returns true also call AcceptDragDropPayload() + EndDragDropTarget().
///--
///-- An item can be both a drag source and a drop target.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param type string
///-- @param data string
///-- @param cond? integer default value = `Cond_Always`
///-- @return boolean retval
pub const SetDragDropPayload = function(&api.SetDragDropPayload, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragDouble**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? number default value = `0.0`
///-- @param v_max? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const DragDouble = function(&api.DragDouble, 3, &.{ ContextPtr, [*:0]const u8, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragDouble**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? number default value = `0.0`
///-- @param v_max? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const DragDouble2 = function(&api.DragDouble2, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragDouble**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? number default value = `0.0`
///-- @param v_max? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const DragDouble3 = function(&api.DragDouble3, 5, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragDouble**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? number default value = `0.0`
///-- @param v_max? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const DragDouble4 = function(&api.DragDouble4, 6, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragDoubleN**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param values reaper.array
///-- @param speed? number default value = `1.0`
///-- @param min? number default value = `0.0`
///-- @param max? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
pub const DragDoubleN = function(&api.DragDoubleN, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const DragFloatRange2 = function(&api.DragFloatRange2, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragInt**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? integer default value = `0`
///-- @param v_max? integer default value = `0`
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const DragInt = function(&api.DragInt, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragInt**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? integer default value = `0`
///-- @param v_max? integer default value = `0`
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const DragInt2 = function(&api.DragInt2, 4, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragInt**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? integer default value = `0`
///-- @param v_max? integer default value = `0`
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const DragInt3 = function(&api.DragInt3, 5, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Drag Sliders > DragInt**
///--
///-- ---
///--
///-- **Drag \& Slider > Drag Sliders**
///--
///-- Speed are per-pixel of mouse movement (v_speed=0.2: mouse needs to move by 5
///-- pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed
///-- is Max(v_speed, minimum_step_at_given_precision).
///--
///-- Use v_min < v_max to clamp edits to given limits. Note that CTRL+Click manual
///-- input can override those limits if SliderFlags_AlwaysClamp is not used.
///-- Use v_max = FLT_MAX / INT_MAX etc to avoid clamping to a maximum, same with
///-- v_min = -FLT_MAX / INT_MIN to avoid clamping to a minimum.
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_speed? number default value = `1.0`
///-- @param v_min? integer default value = `0`
///-- @param v_max? integer default value = `0`
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const DragInt4 = function(&api.DragInt4, 6, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
pub const DragIntRange2 = function(&api.DragIntRange2, 4, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderAngle**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v_rad number
///-- @param v_degrees_min? number default value = `-360.0`
///-- @param v_degrees_max? number default value = `+360.0`
///-- @param format? string default value = `"%.0f deg"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v_rad
pub const SliderAngle = function(&api.SliderAngle, 3, &.{ ContextPtr, [*:0]const u8, *f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderDouble**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_min number
///-- @param v_max number
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const SliderDouble = function(&api.SliderDouble, 5, &.{ ContextPtr, [*:0]const u8, *f64, f64, f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderDouble**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_min number
///-- @param v_max number
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const SliderDouble2 = function(&api.SliderDouble2, 6, &.{ ContextPtr, [*:0]const u8, *f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderDouble**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_min number
///-- @param v_max number
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const SliderDouble3 = function(&api.SliderDouble3, 7, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderDouble**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param v_min number
///-- @param v_max number
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const SliderDouble4 = function(&api.SliderDouble4, 8, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderDoubleN**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param values reaper.array
///-- @param v_min number
///-- @param v_max number
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
pub const SliderDoubleN = function(&api.SliderDoubleN, 5, &.{ ContextPtr, [*:0]const u8, *reaper_array, f64, f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderInt**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_min integer
///-- @param v_max integer
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const SliderInt = function(&api.SliderInt, 5, &.{ ContextPtr, [*:0]const u8, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderInt**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_min integer
///-- @param v_max integer
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const SliderInt2 = function(&api.SliderInt2, 6, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderInt**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_min integer
///-- @param v_max integer
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const SliderInt3 = function(&api.SliderInt3, 7, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > SliderInt**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param v_min integer
///-- @param v_max integer
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const SliderInt4 = function(&api.SliderInt4, 8, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > VSliderDouble**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param size_w number
///-- @param size_h number
///-- @param v number
///-- @param v_min number
///-- @param v_max number
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return number v
pub const VSliderDouble = function(&api.VSliderDouble, 7, &.{ ContextPtr, [*:0]const u8, f64, f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
///-- **Drag \& Slider > Regular Sliders > VSliderInt**
///--
///-- ---
///--
///-- **Drag \& Slider**
///--
///-- We use the same sets of flags for Drag*() and Slider*() functions as the
///-- features are the same and it makes it easier to swap them.
///--
///-- CTRL+Click on any drag box or slider to turn them into an input box.
///-- Manually input values aren't clamped by default and can go off-bounds.
///-- Use SliderFlags_AlwaysClamp to always clamp.
///--
///-- Adjust format string to decorate the value with a prefix, a suffix, or adapt the
///-- editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs;
///-- "Biscuit: %.0f" -> Biscuit: 1; etc.
///--
///-- Format string may also be set to nil or use the default format ("%f" or "%d").
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param size_w number
///-- @param size_h number
///-- @param v integer
///-- @param v_min integer
///-- @param v_max integer
///-- @param format? string default value = `"%d"`
///-- @param flags? integer default value = `SliderFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const VSliderInt = function(&api.VSliderInt, 7, &.{ ContextPtr, [*:0]const u8, f64, f64, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
///-- **Draw List > DrawList\_PopClipRect**
///--
///-- See DrawList_PushClipRect
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
pub const DrawList_PopClipRect = function(&api.DrawList_PopClipRect, 1, &.{DrawListPtr});
///-- **Draw List > DrawList\_PushClipRect**
///--
///-- Render-level scissoring. Prefer using higher-level PushClipRect to affect
///-- logic (hit-testing and widget culling).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param clip_rect_min_x number
///-- @param clip_rect_min_y number
///-- @param clip_rect_max_x number
///-- @param clip_rect_max_y number
///-- @param intersect_with_current_clip_rect? boolean default value = `false`
pub const DrawList_PushClipRect = function(&api.DrawList_PushClipRect, 5, &.{ DrawListPtr, f64, f64, f64, f64, ?bool });
///-- **Draw List > DrawList\_PushClipRectFullScreen**
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
pub const DrawList_PushClipRectFullScreen = function(&api.DrawList_PushClipRectFullScreen, 1, &.{DrawListPtr});
///-- **Draw List > GetBackgroundDrawList**
///--
///-- This draw list will be the first rendering one. Useful to quickly draw
///-- shapes/text behind dear imgui contents.
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return ImGui_DrawList retval
pub const GetBackgroundDrawList = function(&api.GetBackgroundDrawList, 1, &.{ContextPtr});
///-- **Draw List > GetForegroundDrawList**
///--
///-- This draw list will be the last rendered one. Useful to quickly draw
///-- shapes/text over dear imgui contents.
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return ImGui_DrawList retval
pub const GetForegroundDrawList = function(&api.GetForegroundDrawList, 1, &.{ContextPtr});
///-- **Draw List > GetWindowDrawList**
///--
///-- The draw list associated to the current window, to append your own drawing primitives
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return ImGui_DrawList retval
pub const GetWindowDrawList = function(&api.GetWindowDrawList, 1, &.{ContextPtr});
///-- **Draw List > Primitives > DrawList\_AddBezierCubic**
///--
///-- Cubic Bezier (4 control points)
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param p4_x number
///-- @param p4_y number
///-- @param col_rgba integer
///-- @param thickness number
///-- @param num_segments? integer default value = `0`
pub const DrawList_AddBezierCubic = function(&api.DrawList_AddBezierCubic, 11, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddBezierQuadratic**
///--
///-- Quadratic Bezier (3 control points)
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param col_rgba integer
///-- @param thickness number
///-- @param num_segments? integer default value = `0`
pub const DrawList_AddBezierQuadratic = function(&api.DrawList_AddBezierQuadratic, 9, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddCircle**
///--
///-- Use "num_segments == 0" to automatically calculate tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius number
///-- @param col_rgba integer
///-- @param num_segments? integer default value = `0`
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddCircle = function(&api.DrawList_AddCircle, 5, &.{ DrawListPtr, f64, f64, f64, c_int, ?c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddCircleFilled**
///--
///-- Use "num_segments == 0" to automatically calculate tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius number
///-- @param col_rgba integer
///-- @param num_segments? integer default value = `0`
pub const DrawList_AddCircleFilled = function(&api.DrawList_AddCircleFilled, 5, &.{ DrawListPtr, f64, f64, f64, c_int, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddConcavePolyFilled**
///--
///-- Concave polygon fill is more expensive than convex one: it has O(N^2) complexity.
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.9
///-- @param draw_list ImGui_DrawList
///-- @param points reaper.array
///-- @param col_rgba integer
pub const DrawList_AddConcavePolyFilled = function(&api.DrawList_AddConcavePolyFilled, 3, &.{ DrawListPtr, *reaper_array, c_int });
///-- **Draw List > Primitives > DrawList\_AddConvexPolyFilled**
///--
///-- Note: Anti-aliased filling requires points to be in clockwise order.
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.6
///-- @param draw_list ImGui_DrawList
///-- @param points reaper.array
///-- @param col_rgba integer
pub const DrawList_AddConvexPolyFilled = function(&api.DrawList_AddConvexPolyFilled, 3, &.{ DrawListPtr, *reaper_array, c_int });
///-- **Draw List > Primitives > DrawList\_AddEllipse**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.9
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius_x number
///-- @param radius_y number
///-- @param col_rgba integer
///-- @param rot? number default value = `0.0`
///-- @param num_segments? integer default value = `0`
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddEllipse = function(&api.DrawList_AddEllipse, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddEllipseFilled**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.9
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius_x number
///-- @param radius_y number
///-- @param col_rgba integer
///-- @param rot? number default value = `0.0`
///-- @param num_segments? integer default value = `0`
pub const DrawList_AddEllipseFilled = function(&api.DrawList_AddEllipseFilled, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddImage**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.8
///-- @param draw_list ImGui_DrawList
///-- @param image ImGui_Image
///-- @param p_min_x number
///-- @param p_min_y number
///-- @param p_max_x number
///-- @param p_max_y number
///-- @param uv_min_x? number default value = `0.0`
///-- @param uv_min_y? number default value = `0.0`
///-- @param uv_max_x? number default value = `1.0`
///-- @param uv_max_y? number default value = `1.0`
///-- @param col_rgba? integer default value = `0xFFFFFFFF`
pub const DrawList_AddImage = function(&api.DrawList_AddImage, 6, &.{ DrawListPtr, ImagePtr, f64, f64, f64, f64, ?f64, ?f64, ?f64, ?f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddImageQuad**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.8
///-- @param draw_list ImGui_DrawList
///-- @param image ImGui_Image
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param p4_x number
///-- @param p4_y number
///-- @param uv1_x? number default value = `0.0`
///-- @param uv1_y? number default value = `0.0`
///-- @param uv2_x? number default value = `1.0`
///-- @param uv2_y? number default value = `0.0`
///-- @param uv3_x? number default value = `1.0`
///-- @param uv3_y? number default value = `1.0`
///-- @param uv4_x? number default value = `0.0`
///-- @param uv4_y? number default value = `1.0`
///-- @param col_rgba? integer default value = `0xFFFFFFFF`
pub const DrawList_AddImageQuad = function(&api.DrawList_AddImageQuad, 10, &.{ DrawListPtr, ImagePtr, f64, f64, f64, f64, f64, f64, f64, f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddImageRounded**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.8
///-- @param draw_list ImGui_DrawList
///-- @param image ImGui_Image
///-- @param p_min_x number
///-- @param p_min_y number
///-- @param p_max_x number
///-- @param p_max_y number
///-- @param uv_min_x number
///-- @param uv_min_y number
///-- @param uv_max_x number
///-- @param uv_max_y number
///-- @param col_rgba integer
///-- @param rounding number
///-- @param flags? integer default value = `DrawFlags_None`
pub const DrawList_AddImageRounded = function(&api.DrawList_AddImageRounded, 12, &.{ DrawListPtr, ImagePtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddLine**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param col_rgba integer
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddLine = function(&api.DrawList_AddLine, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddNgon**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius number
///-- @param col_rgba integer
///-- @param num_segments integer
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddNgon = function(&api.DrawList_AddNgon, 6, &.{ DrawListPtr, f64, f64, f64, c_int, c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddNgonFilled**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius number
///-- @param col_rgba integer
///-- @param num_segments integer
pub const DrawList_AddNgonFilled = function(&api.DrawList_AddNgonFilled, 6, &.{ DrawListPtr, f64, f64, f64, c_int, c_int });
///-- **Draw List > Primitives > DrawList\_AddPolyline**
///--
///-- Points is a list of x,y coordinates.
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.2
///-- @param draw_list ImGui_DrawList
///-- @param points reaper.array
///-- @param col_rgba integer
///-- @param flags integer
///-- @param thickness number
pub const DrawList_AddPolyline = function(&api.DrawList_AddPolyline, 5, &.{ DrawListPtr, *reaper_array, c_int, c_int, f64 });
///-- **Draw List > Primitives > DrawList\_AddQuad**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param p4_x number
///-- @param p4_y number
///-- @param col_rgba integer
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddQuad = function(&api.DrawList_AddQuad, 10, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddQuadFilled**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param p4_x number
///-- @param p4_y number
///-- @param col_rgba integer
pub const DrawList_AddQuadFilled = function(&api.DrawList_AddQuadFilled, 10, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int });
///-- **Draw List > Primitives > DrawList\_AddRect**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p_min_x number
///-- @param p_min_y number
///-- @param p_max_x number
///-- @param p_max_y number
///-- @param col_rgba integer
///-- @param rounding? number default value = `0.0`
///-- @param flags? integer default value = `DrawFlags_None`
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddRect = function(&api.DrawList_AddRect, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddRectFilled**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p_min_x number
///-- @param p_min_y number
///-- @param p_max_x number
///-- @param p_max_y number
///-- @param col_rgba integer
///-- @param rounding? number default value = `0.0`
///-- @param flags? integer default value = `DrawFlags_None`
pub const DrawList_AddRectFilled = function(&api.DrawList_AddRectFilled, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int });
///-- **Draw List > Primitives > DrawList\_AddRectFilledMultiColor**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p_min_x number
///-- @param p_min_y number
///-- @param p_max_x number
///-- @param p_max_y number
///-- @param col_upr_left integer
///-- @param col_upr_right integer
///-- @param col_bot_right integer
///-- @param col_bot_left integer
pub const DrawList_AddRectFilledMultiColor = function(&api.DrawList_AddRectFilledMultiColor, 9, &.{ DrawListPtr, f64, f64, f64, f64, c_int, c_int, c_int, c_int });
///-- **Draw List > Primitives > DrawList\_AddText**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param x number
///-- @param y number
///-- @param col_rgba integer
///-- @param text string
pub const DrawList_AddText = function(&api.DrawList_AddText, 5, &.{ DrawListPtr, f64, f64, c_int, [*:0]const u8 });
///-- **Draw List > Primitives > DrawList\_AddTextEx**
///--
///-- The last pushed font is used if font is nil.
///-- The size of the last pushed font is used if font_size is 0.
///-- cpu_fine_clip_rect_* only takes effect if all four are non-nil.
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.4
///-- @param draw_list ImGui_DrawList
///-- @param font ImGui_Font|nil
///-- @param font_size number
///-- @param pos_x number
///-- @param pos_y number
///-- @param col_rgba integer
///-- @param text string
///-- @param wrap_width? number default value = `0.0`
///-- @param cpu_fine_clip_rect_x? number default value = `nil`
///-- @param cpu_fine_clip_rect_y? number default value = `nil`
///-- @param cpu_fine_clip_rect_w? number default value = `nil`
///-- @param cpu_fine_clip_rect_h? number default value = `nil`
pub const DrawList_AddTextEx = function(&api.DrawList_AddTextEx, 7, &.{ DrawListPtr, FontPtr, f64, f64, f64, c_int, [*:0]const u8, ?f64, ?f64, ?f64, ?f64, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddTriangle**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param col_rgba integer
///-- @param thickness? number default value = `1.0`
pub const DrawList_AddTriangle = function(&api.DrawList_AddTriangle, 8, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, ?f64 });
///-- **Draw List > Primitives > DrawList\_AddTriangleFilled**
///--
///-- ---
///--
///-- **Draw List > Primitives**
///--
///-- Filled shapes must always use clockwise winding order! The anti-aliasing
///-- fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
///-- So e.g. `DrawList_PathArcTo(center, radius, PI * -0.5, PI)` is ok, whereas
///-- `DrawList_PathArcTo(center, radius, PI, PI * -0.5)` won't have correct
///-- anti-aliasing when followed by DrawList_PathFillConvex.
///--
///-- For rectangular primitives, "p_min" and "p_max" represent the upper-left and
///-- lower-right corners.
///--
///-- For circle primitives, use "num_segments == 0" to automatically calculate
///-- tessellation (preferred).
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p1_x number
///-- @param p1_y number
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param col_rgba integer
pub const DrawList_AddTriangleFilled = function(&api.DrawList_AddTriangleFilled, 8, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, c_int });
///-- **Draw List > Splitter > CreateDrawListSplitter**
///--
///-- ---
///--
///-- **Draw List > Splitter**
///--
///-- Split/Merge functions are used to split the draw list into different layers
///-- which can be drawn into out of order (e.g. submit FG primitives before BG primitives).
///--
///-- Use to minimize draw calls (e.g. if going back-and-forth between multiple
///-- clipping rectangles, prefer to append into separate channels then merge at the end).
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(splitter, 'ImGui_DrawListSplitter*') then
///--       splitter = ImGui.CreateDrawListSplitter(draw_list)
///--     end
///--     ImGui.DrawListSplitter_Split(splitter, 2)
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- foreground
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_Merge(splitter)
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.9
///-- @param draw_list ImGui_DrawList
///-- @nodiscard
///-- @return ImGui_DrawListSplitter retval
pub const CreateDrawListSplitter = function(&api.CreateDrawListSplitter, 1, &.{DrawListPtr});
///-- **Draw List > Splitter > DrawListSplitter\_Clear**
///--
///-- ---
///--
///-- **Draw List > Splitter**
///--
///-- Split/Merge functions are used to split the draw list into different layers
///-- which can be drawn into out of order (e.g. submit FG primitives before BG primitives).
///--
///-- Use to minimize draw calls (e.g. if going back-and-forth between multiple
///-- clipping rectangles, prefer to append into separate channels then merge at the end).
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(splitter, 'ImGui_DrawListSplitter*') then
///--       splitter = ImGui.CreateDrawListSplitter(draw_list)
///--     end
///--     ImGui.DrawListSplitter_Split(splitter, 2)
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- foreground
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_Merge(splitter)
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.7.1
///-- @param splitter ImGui_DrawListSplitter
pub const DrawListSplitter_Clear = function(&api.DrawListSplitter_Clear, 1, &.{DrawListSplitterPtr});
///-- **Draw List > Splitter > DrawListSplitter\_Merge**
///--
///-- ---
///--
///-- **Draw List > Splitter**
///--
///-- Split/Merge functions are used to split the draw list into different layers
///-- which can be drawn into out of order (e.g. submit FG primitives before BG primitives).
///--
///-- Use to minimize draw calls (e.g. if going back-and-forth between multiple
///-- clipping rectangles, prefer to append into separate channels then merge at the end).
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(splitter, 'ImGui_DrawListSplitter*') then
///--       splitter = ImGui.CreateDrawListSplitter(draw_list)
///--     end
///--     ImGui.DrawListSplitter_Split(splitter, 2)
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- foreground
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_Merge(splitter)
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.7.1
///-- @param splitter ImGui_DrawListSplitter
pub const DrawListSplitter_Merge = function(&api.DrawListSplitter_Merge, 1, &.{DrawListSplitterPtr});
///-- **Draw List > Splitter > DrawListSplitter\_SetCurrentChannel**
///--
///-- ---
///--
///-- **Draw List > Splitter**
///--
///-- Split/Merge functions are used to split the draw list into different layers
///-- which can be drawn into out of order (e.g. submit FG primitives before BG primitives).
///--
///-- Use to minimize draw calls (e.g. if going back-and-forth between multiple
///-- clipping rectangles, prefer to append into separate channels then merge at the end).
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(splitter, 'ImGui_DrawListSplitter*') then
///--       splitter = ImGui.CreateDrawListSplitter(draw_list)
///--     end
///--     ImGui.DrawListSplitter_Split(splitter, 2)
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- foreground
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_Merge(splitter)
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.7.1
///-- @param splitter ImGui_DrawListSplitter
///-- @param channel_idx integer
pub const DrawListSplitter_SetCurrentChannel = function(&api.DrawListSplitter_SetCurrentChannel, 2, &.{ DrawListSplitterPtr, c_int });
///-- **Draw List > Splitter > DrawListSplitter\_Split**
///--
///-- ---
///--
///-- **Draw List > Splitter**
///--
///-- Split/Merge functions are used to split the draw list into different layers
///-- which can be drawn into out of order (e.g. submit FG primitives before BG primitives).
///--
///-- Use to minimize draw calls (e.g. if going back-and-forth between multiple
///-- clipping rectangles, prefer to append into separate channels then merge at the end).
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(splitter, 'ImGui_DrawListSplitter*') then
///--       splitter = ImGui.CreateDrawListSplitter(draw_list)
///--     end
///--     ImGui.DrawListSplitter_Split(splitter, 2)
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- foreground
///--     ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0)
///--     ImGui.DrawList_AddRectFilled(draw_list, ...) -- background
///--     ImGui.DrawListSplitter_Merge(splitter)
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.7.1
///-- @param splitter ImGui_DrawListSplitter
///-- @param count integer
pub const DrawListSplitter_Split = function(&api.DrawListSplitter_Split, 2, &.{ DrawListSplitterPtr, c_int });
///-- **Draw List > Stateful Path > DrawList\_PathArcTo**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius number
///-- @param a_min number
///-- @param a_max number
///-- @param num_segments? integer default value = `0`
pub const DrawList_PathArcTo = function(&api.DrawList_PathArcTo, 6, &.{ DrawListPtr, f64, f64, f64, f64, f64, ?c_int });
///-- **Draw List > Stateful Path > DrawList\_PathArcToFast**
///--
///-- Use precomputed angles for a 12 steps circle.
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius number
///-- @param a_min_of_12 integer
///-- @param a_max_of_12 integer
pub const DrawList_PathArcToFast = function(&api.DrawList_PathArcToFast, 6, &.{ DrawListPtr, f64, f64, f64, c_int, c_int });
///-- **Draw List > Stateful Path > DrawList\_PathBezierCubicCurveTo**
///--
///-- Cubic Bezier (4 control points)
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param p4_x number
///-- @param p4_y number
///-- @param num_segments? integer default value = `0`
pub const DrawList_PathBezierCubicCurveTo = function(&api.DrawList_PathBezierCubicCurveTo, 7, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, ?c_int });
///-- **Draw List > Stateful Path > DrawList\_PathBezierQuadraticCurveTo**
///--
///-- Quadratic Bezier (3 control points)
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param p2_x number
///-- @param p2_y number
///-- @param p3_x number
///-- @param p3_y number
///-- @param num_segments? integer default value = `0`
pub const DrawList_PathBezierQuadraticCurveTo = function(&api.DrawList_PathBezierQuadraticCurveTo, 5, &.{ DrawListPtr, f64, f64, f64, f64, ?c_int });
///-- **Draw List > Stateful Path > DrawList\_PathClear**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
pub const DrawList_PathClear = function(&api.DrawList_PathClear, 1, &.{DrawListPtr});
///-- **Draw List > Stateful Path > DrawList\_PathEllipticalArcTo**
///--
///-- Ellipse
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.9
///-- @param draw_list ImGui_DrawList
///-- @param center_x number
///-- @param center_y number
///-- @param radius_x number
///-- @param radius_y number
///-- @param rot number
///-- @param a_min number
///-- @param a_max number
///-- @param num_segments? integer default value = `0`
pub const DrawList_PathEllipticalArcTo = function(&api.DrawList_PathEllipticalArcTo, 8, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, ?c_int });
///-- **Draw List > Stateful Path > DrawList\_PathFillConcave**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.9
///-- @param draw_list ImGui_DrawList
///-- @param col_rgba integer
pub const DrawList_PathFillConcave = function(&api.DrawList_PathFillConcave, 2, &.{ DrawListPtr, c_int });
///-- **Draw List > Stateful Path > DrawList\_PathFillConvex**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.5.1
///-- @param draw_list ImGui_DrawList
///-- @param col_rgba integer
pub const DrawList_PathFillConvex = function(&api.DrawList_PathFillConvex, 2, &.{ DrawListPtr, c_int });
///-- **Draw List > Stateful Path > DrawList\_PathLineTo**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param pos_x number
///-- @param pos_y number
pub const DrawList_PathLineTo = function(&api.DrawList_PathLineTo, 3, &.{ DrawListPtr, f64, f64 });
///-- **Draw List > Stateful Path > DrawList\_PathRect**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.1
///-- @param draw_list ImGui_DrawList
///-- @param rect_min_x number
///-- @param rect_min_y number
///-- @param rect_max_x number
///-- @param rect_max_y number
///-- @param rounding? number default value = `0.0`
///-- @param flags? integer default value = `DrawFlags_None`
pub const DrawList_PathRect = function(&api.DrawList_PathRect, 5, &.{ DrawListPtr, f64, f64, f64, f64, ?f64, ?c_int });
///-- **Draw List > Stateful Path > DrawList\_PathStroke**
///--
///-- ---
///--
///-- **Draw List > Stateful Path**
///--
///-- Stateful path API, add points then finish with PathFillConvex() or PathStroke().
///--
///-- ---
///--
///-- **Draw List**
///--
///-- This is the low-level list of polygons that ImGui functions are filling.
///-- At the end of the frame, all draw lists are passed to the GPU for rendering.
///--
///-- Each dear imgui window contains its own Draw List.
///-- You can use GetWindowDrawList() to access the current window draw list and draw
///-- custom primitives.
///--
///-- The Draw List API uses absolute coordinates (0,0 is the top-left corner of the
///-- primary monitor, not of your window!). See GetCursorScreenPos.
///--
///-- ---
///--
///-- @since 0.2
///-- @param draw_list ImGui_DrawList
///-- @param col_rgba integer
///-- @param flags? integer default value = `DrawFlags_None`
///-- @param thickness? number default value = `1.0`
pub const DrawList_PathStroke = function(&api.DrawList_PathStroke, 2, &.{ DrawListPtr, c_int, ?c_int, ?f64 });
///-- **Font > CreateFont**
///--
///-- Load a font matching a font family name or from a font file.
///-- The font will remain valid while it's attached to a context. See Attach.
///--
///-- The family name can be an installed font or one of the generic fonts:
///-- sans-serif, serif, monospace, cursive, fantasy.
///--
///-- If 'family_or_file' specifies a path to a font file (contains a / or \\):
///-- - The first byte of 'flags' is used as the font index within the file
///-- - The font styles in 'flags' are simulated by the font renderer
///--
///-- ---
///--
///-- **Font**
///--
///-- Supports loading fonts from the system by family name or from a file.
///-- Glyphs may contain colors in COLR/CPAL format.
///--
///-- This API currently has multiple limitations (v1.0 blockers):
///-- - ReaImGui rasterizes glyphs only from the Basic Latin and Latin Supplement
///--   Unicode blocks (U+0020 to U+00FF). UTF-8 is fully supported internally,
///--   however characters outside those blocks are displayed as '?'.
///--   See [issue #5](https://github.com/cfillion/reaimgui/issues/5).
///-- - Dear ImGui does not support using new fonts in the middle of a frame.
///--   Because of this, fonts must first be registered using Attach before any
///--   other context functions are used in the same defer cycle.
///--   (Attaching a font is a heavy operation and should ideally be done outside
///--   of the defer loop.)
///--
///-- ---
///--
///-- @since 0.9
///-- @param family_or_file string
///-- @param size integer
///-- @param flags? integer default value = `FontFlags_None`
///-- @nodiscard
///-- @return ImGui_Font retval
pub const CreateFont = function(&api.CreateFont, 2, &.{ [*:0]const u8, c_int, ?c_int });
///-- **Font > GetFont**
///--
///-- Get the current font
///--
///-- ---
///--
///-- **Font**
///--
///-- Supports loading fonts from the system by family name or from a file.
///-- Glyphs may contain colors in COLR/CPAL format.
///--
///-- This API currently has multiple limitations (v1.0 blockers):
///-- - ReaImGui rasterizes glyphs only from the Basic Latin and Latin Supplement
///--   Unicode blocks (U+0020 to U+00FF). UTF-8 is fully supported internally,
///--   however characters outside those blocks are displayed as '?'.
///--   See [issue #5](https://github.com/cfillion/reaimgui/issues/5).
///-- - Dear ImGui does not support using new fonts in the middle of a frame.
///--   Because of this, fonts must first be registered using Attach before any
///--   other context functions are used in the same defer cycle.
///--   (Attaching a font is a heavy operation and should ideally be done outside
///--   of the defer loop.)
///--
///-- ---
///--
///-- @since 0.4
///-- @param ctx ImGui_Context
///-- @return ImGui_Font retval
pub const GetFont = function(&api.GetFont, 1, &.{ContextPtr});
///-- **Font > GetFontSize**
///--
///-- Get current font size (= height in pixels) of current font with current scale
///-- applied.
///--
///-- ---
///--
///-- **Font**
///--
///-- Supports loading fonts from the system by family name or from a file.
///-- Glyphs may contain colors in COLR/CPAL format.
///--
///-- This API currently has multiple limitations (v1.0 blockers):
///-- - ReaImGui rasterizes glyphs only from the Basic Latin and Latin Supplement
///--   Unicode blocks (U+0020 to U+00FF). UTF-8 is fully supported internally,
///--   however characters outside those blocks are displayed as '?'.
///--   See [issue #5](https://github.com/cfillion/reaimgui/issues/5).
///-- - Dear ImGui does not support using new fonts in the middle of a frame.
///--   Because of this, fonts must first be registered using Attach before any
///--   other context functions are used in the same defer cycle.
///--   (Attaching a font is a heavy operation and should ideally be done outside
///--   of the defer loop.)
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetFontSize = function(&api.GetFontSize, 1, &.{ContextPtr});
///-- **Font > PopFont**
///--
///-- See PushFont.
///--
///-- ---
///--
///-- **Font**
///--
///-- Supports loading fonts from the system by family name or from a file.
///-- Glyphs may contain colors in COLR/CPAL format.
///--
///-- This API currently has multiple limitations (v1.0 blockers):
///-- - ReaImGui rasterizes glyphs only from the Basic Latin and Latin Supplement
///--   Unicode blocks (U+0020 to U+00FF). UTF-8 is fully supported internally,
///--   however characters outside those blocks are displayed as '?'.
///--   See [issue #5](https://github.com/cfillion/reaimgui/issues/5).
///-- - Dear ImGui does not support using new fonts in the middle of a frame.
///--   Because of this, fonts must first be registered using Attach before any
///--   other context functions are used in the same defer cycle.
///--   (Attaching a font is a heavy operation and should ideally be done outside
///--   of the defer loop.)
///--
///-- ---
///--
///-- @since 0.4
///-- @param ctx ImGui_Context
pub const PopFont = function(&api.PopFont, 1, &.{ContextPtr});
///-- **Font > PushFont**
///--
///-- Change the current font. Use nil to push the default font.
///-- The font object must have been registered using Attach. See PopFont.
///--
///-- ---
///--
///-- **Font**
///--
///-- Supports loading fonts from the system by family name or from a file.
///-- Glyphs may contain colors in COLR/CPAL format.
///--
///-- This API currently has multiple limitations (v1.0 blockers):
///-- - ReaImGui rasterizes glyphs only from the Basic Latin and Latin Supplement
///--   Unicode blocks (U+0020 to U+00FF). UTF-8 is fully supported internally,
///--   however characters outside those blocks are displayed as '?'.
///--   See [issue #5](https://github.com/cfillion/reaimgui/issues/5).
///-- - Dear ImGui does not support using new fonts in the middle of a frame.
///--   Because of this, fonts must first be registered using Attach before any
///--   other context functions are used in the same defer cycle.
///--   (Attaching a font is a heavy operation and should ideally be done outside
///--   of the defer loop.)
///--
///-- ---
///--
///-- @since 0.4
///-- @param ctx ImGui_Context
///-- @param font ImGui_Font|nil
pub const PushFont = function(&api.PushFont, 2, &.{ ContextPtr, FontPtr });
///-- **Function > CreateFunctionFromEEL**
///--
///-- Compile an EEL program.
///--
///-- Standard EEL [math](https://www.reaper.fm/sdk/js/basiccode.php#js_basicfunc)
///-- and [string](https://www.reaper.fm/sdk/js/strings.php#js_string_funcs)
///-- functions are available in addition to callback-specific functions
///-- (see InputTextCallback_*).
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.9
///-- @param code string
///-- @nodiscard
///-- @return ImGui_Function retval
pub const CreateFunctionFromEEL = function(&api.CreateFunctionFromEEL, 1, &.{[*:0]const u8});
///-- **Function > Function\_Execute**
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
pub const Function_Execute = function(&api.Function_Execute, 1, &.{FunctionPtr});
///-- **Function > Function\_GetValue**
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
///-- @param name string
///-- @return number retval
pub const Function_GetValue = function(&api.Function_GetValue, 2, &.{ FunctionPtr, [*:0]const u8 });
///-- **Function > Function\_GetValue\_Array**
///--
///-- Copy the values in the function's memory starting at the address stored
///-- in the given variable into the array.
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
///-- @param name string
///-- @param values reaper.array
pub const Function_GetValue_Array = function(&api.Function_GetValue_Array, 3, &.{ FunctionPtr, [*:0]const u8, *reaper_array });
///-- **Function > Function\_GetValue\_String**
///--
///-- Read from a string slot or a named string (when name starts with a `#`).
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
///-- @param name string
///-- @return string value
pub const Function_GetValue_String = function(&api.Function_GetValue_String, 4, &.{ FunctionPtr, [*:0]const u8, [*]u8, c_int });
///-- **Function > Function\_SetValue**
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
///-- @param name string
///-- @param value number
pub const Function_SetValue = function(&api.Function_SetValue, 3, &.{ FunctionPtr, [*:0]const u8, f64 });
///-- **Function > Function\_SetValue\_Array**
///--
///-- Copy the values in the array to the function's memory at the address stored
///-- in the given variable.
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
///-- @param name string
///-- @param values reaper.array
pub const Function_SetValue_Array = function(&api.Function_SetValue_Array, 3, &.{ FunctionPtr, [*:0]const u8, *reaper_array });
///-- **Function > Function\_SetValue\_String**
///--
///-- Write to a string slot or a named string (when name starts with a `#`).
///--
///-- ---
///--
///-- **Function**
///--
///-- Create reusable programs that can passed to and called back from functions
///-- such as InputText* and SetNextWindowSizeConstraints.
///--
///-- They can also be used standalone with Function_Execute
///-- (eg. faster-than-Lua DSP processing).
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param func ImGui_Function
///-- @param name string
///-- @param value string
pub const Function_SetValue_String = function(&api.Function_SetValue_String, 4, &.{ FunctionPtr, [*:0]const u8, [*:0]const u8, c_int });
///-- **Image > CreateImage**
///--
///-- The returned object is valid as long as it is used in each defer cycle
///-- unless attached to a context (see Attach).
///--
///-- ('flags' currently unused and reserved for future expansion)
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.9
///-- @param file string
///-- @param flags? integer default value = `nil`
///-- @nodiscard
///-- @return ImGui_Image retval
pub const CreateImage = function(&api.CreateImage, 1, &.{ [*:0]const u8, ?c_int });
///-- **Image > CreateImageFromMem**
///--
///-- Requires REAPER v6.44 or newer for EEL and Lua. Load from a file using
///-- CreateImage or explicitely specify data_sz if supporting older versions.
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.9
///-- @param data string
///-- @nodiscard
///-- @return ImGui_Image retval
pub const CreateImageFromMem = function(&api.CreateImageFromMem, 2, &.{ [*:0]const u8, c_int });
///-- **Image > Image**
///--
///-- Adds 2.0 to the provided size if a border is visible.
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @param image ImGui_Image
///-- @param image_size_w number
///-- @param image_size_h number
///-- @param uv0_x? number default value = `0.0`
///-- @param uv0_y? number default value = `0.0`
///-- @param uv1_x? number default value = `1.0`
///-- @param uv1_y? number default value = `1.0`
///-- @param tint_col_rgba? integer default value = `0xFFFFFFFF`
///-- @param border_col_rgba? integer default value = `0x00000000`
pub const Image = function(&api.Image, 4, &.{ ContextPtr, ImagePtr, f64, f64, ?f64, ?f64, ?f64, ?f64, ?c_int, ?c_int });
///-- **Image > ImageButton**
///--
///-- Adds StyleVar_FramePadding*2.0 to provided size.
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param image ImGui_Image
///-- @param image_size_w number
///-- @param image_size_h number
///-- @param uv0_x? number default value = `0.0`
///-- @param uv0_y? number default value = `0.0`
///-- @param uv1_x? number default value = `1.0`
///-- @param uv1_y? number default value = `1.0`
///-- @param bg_col_rgba? integer default value = `0x00000000`
///-- @param tint_col_rgba? integer default value = `0xFFFFFFFF`
///-- @return boolean retval
pub const ImageButton = function(&api.ImageButton, 5, &.{ ContextPtr, [*:0]const u8, ImagePtr, f64, f64, ?f64, ?f64, ?f64, ?f64, ?c_int, ?c_int });
///-- **Image > Image\_GetSize**
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.8
///-- @param image ImGui_Image
///-- @return number w
///-- @return number h
pub const Image_GetSize = function(&api.Image_GetSize, 3, &.{ ImagePtr, *f64, *f64 });
///-- **Image > Image Set > CreateImageSet**
///--
///-- ---
///--
///-- **Image > Image Set**
///--
///-- Helper to automatically select and scale an image to the DPI scale of
///-- the current window upon usage.
///--
///-- ImGui_ImageSet objects can be given to any function that expect an image as
///-- parameter.
///--
///-- Usage:
///--
///--     local set = ImGui.CreateImageSet()
///--     ImGui.ImageSet_Add(set, 1.0, ImGui.CreateImage('32x32.png'))
///--     ImGui.ImageSet_Add(set, 2.0, ImGui.CreateImage('64x64.png'))
///--
///--     local function frame()
///--       ImGui.Image(ctx, set, ImGui.Image_GetSize(set))
///--       -- ...
///--     end
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.9
///-- @nodiscard
///-- @return ImGui_ImageSet retval
pub const CreateImageSet = function(&api.CreateImageSet, 0, &.{});
///-- **Image > Image Set > ImageSet\_Add**
///--
///-- 'img' cannot be another ImageSet.
///--
///-- ---
///--
///-- **Image > Image Set**
///--
///-- Helper to automatically select and scale an image to the DPI scale of
///-- the current window upon usage.
///--
///-- ImGui_ImageSet objects can be given to any function that expect an image as
///-- parameter.
///--
///-- Usage:
///--
///--     local set = ImGui.CreateImageSet()
///--     ImGui.ImageSet_Add(set, 1.0, ImGui.CreateImage('32x32.png'))
///--     ImGui.ImageSet_Add(set, 2.0, ImGui.CreateImage('64x64.png'))
///--
///--     local function frame()
///--       ImGui.Image(ctx, set, ImGui.Image_GetSize(set))
///--       -- ...
///--     end
///--
///-- ---
///--
///-- **Image**
///--
///-- ReaImGui currently supports loading PNG and JPEG bitmap images.
///-- Flat vector images may be loaded as fonts, see CreateFont.
///--
///-- UV parameters are texture coordinates in a scale of 0.0 (top/left) to 1.0
///-- (bottom/right). Use values below 0.0 or above 1.0 to tile the image.
///--
///-- Width/height are limited to 8192 pixels.
///--
///-- There are also image functions in the DrawList API such as
///-- DrawList_AddImageQuad and DrawList_AddImageRounded.
///--
///-- ---
///--
///-- @since 0.8
///-- @param set ImGui_ImageSet
///-- @param scale number
///-- @param image ImGui_Image
pub const ImageSet_Add = function(&api.ImageSet_Add, 3, &.{ ImageSetPtr, f64, ImagePtr });
///-- **Item \& Status > BeginDisabled**
///--
///-- Disable all user interactions and dim items visuals
///-- (applying StyleVar_DisabledAlpha over current colors).
///--
///-- BeginDisabled(false) essentially does nothing useful but is provided to
///-- facilitate use of boolean expressions.
///-- If you can avoid calling BeginDisabled(false)/EndDisabled() best to avoid it.
///--
///-- ---
///--
///-- @since 0.5.5
///-- @param ctx ImGui_Context
///-- @param disabled? boolean default value = `true`
pub const BeginDisabled = function(&api.BeginDisabled, 1, &.{ ContextPtr, ?bool });
///-- **Item \& Status > DebugStartItemPicker**
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
pub const DebugStartItemPicker = function(&api.DebugStartItemPicker, 1, &.{ContextPtr});
///-- **Item \& Status > EndDisabled**
///--
///-- See BeginDisabled.
///--
///-- ---
///--
///-- @since 0.5.5
///-- @param ctx ImGui_Context
pub const EndDisabled = function(&api.EndDisabled, 1, &.{ContextPtr});
///-- **Item \& Status > SetNextItemAllowOverlap**
///--
///-- Allow next item to be overlapped by a subsequent item.
///-- Useful with invisible buttons, selectable, treenode covering an area where
///-- subsequent items may need to be added. Note that both Selectable() and TreeNode()
///-- have dedicated flags doing this.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
pub const SetNextItemAllowOverlap = function(&api.SetNextItemAllowOverlap, 1, &.{ContextPtr});
///-- **Item \& Status > Dimensions > CalcItemWidth**
///--
///-- Width of item given pushed settings and current cursor position.
///-- NOT necessarily the width of last item unlike most 'Item' functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const CalcItemWidth = function(&api.CalcItemWidth, 1, &.{ContextPtr});
///-- **Item \& Status > Dimensions > GetItemRectMax**
///--
///-- Get lower-right bounding rectangle of the last item (screen space)
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetItemRectMax = function(&api.GetItemRectMax, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Item \& Status > Dimensions > GetItemRectMin**
///--
///-- Get upper-left bounding rectangle of the last item (screen space)
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetItemRectMin = function(&api.GetItemRectMin, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Item \& Status > Dimensions > GetItemRectSize**
///--
///-- Get size of last item
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number w
///-- @return number h
pub const GetItemRectSize = function(&api.GetItemRectSize, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Item \& Status > Dimensions > PopItemWidth**
///--
///-- See PushItemWidth
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const PopItemWidth = function(&api.PopItemWidth, 1, &.{ContextPtr});
///-- **Item \& Status > Dimensions > PushItemWidth**
///--
///-- Push width of items for common large "item+label" widgets.
///--
///-- - \>0.0: width in pixels
///-- - <0.0 align xx pixels to the right of window
///--   (so -FLT_MIN always align width to the right side)
///-- - 0.0 = default to ~2/3 of windows width.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param item_width number
pub const PushItemWidth = function(&api.PushItemWidth, 2, &.{ ContextPtr, f64 });
///-- **Item \& Status > Dimensions > SetNextItemWidth**
///--
///-- Set width of the _next_ common large "item+label" widget.
///--
///-- - \>0.0: width in pixels
///-- - <0.0 align xx pixels to the right of window
///--   (so -FLT_MIN always align width to the right side)
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param item_width number
pub const SetNextItemWidth = function(&api.SetNextItemWidth, 2, &.{ ContextPtr, f64 });
///-- **Item \& Status > Focus \& Activation > PopTabStop**
///--
///-- See PushTabStop
///--
///-- ---
///--
///-- **Item \& Status > Focus \& Activation**
///--
///-- Prefer using "SetItemDefaultFocus()" over
///-- "if(IsWindowAppearing()) SetScrollHereY()" when applicable to signify
///-- "this is the default item".
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param ctx ImGui_Context
pub const PopTabStop = function(&api.PopTabStop, 1, &.{ContextPtr});
///-- **Item \& Status > Focus \& Activation > PushTabStop**
///--
///-- Allow focusing using TAB/Shift-TAB, enabled by default but you can disable it
///-- for certain widgets
///--
///-- ---
///--
///-- **Item \& Status > Focus \& Activation**
///--
///-- Prefer using "SetItemDefaultFocus()" over
///-- "if(IsWindowAppearing()) SetScrollHereY()" when applicable to signify
///-- "this is the default item".
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param ctx ImGui_Context
///-- @param tab_stop boolean
pub const PushTabStop = function(&api.PushTabStop, 2, &.{ ContextPtr, bool });
///-- **Item \& Status > Focus \& Activation > SetItemDefaultFocus**
///--
///-- Make last item the default focused item of a window.
///--
///-- ---
///--
///-- **Item \& Status > Focus \& Activation**
///--
///-- Prefer using "SetItemDefaultFocus()" over
///-- "if(IsWindowAppearing()) SetScrollHereY()" when applicable to signify
///-- "this is the default item".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const SetItemDefaultFocus = function(&api.SetItemDefaultFocus, 1, &.{ContextPtr});
///-- **Item \& Status > Focus \& Activation > SetKeyboardFocusHere**
///--
///-- Focus keyboard on the next widget. Use positive 'offset' to access sub
///-- components of a multiple component widget. Use -1 to access previous widget.
///--
///-- ---
///--
///-- **Item \& Status > Focus \& Activation**
///--
///-- Prefer using "SetItemDefaultFocus()" over
///-- "if(IsWindowAppearing()) SetScrollHereY()" when applicable to signify
///-- "this is the default item".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param offset? integer default value = `0`
pub const SetKeyboardFocusHere = function(&api.SetKeyboardFocusHere, 1, &.{ ContextPtr, ?c_int });
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsAnyItemActive**
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsAnyItemActive = function(&api.IsAnyItemActive, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsAnyItemFocused**
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsAnyItemFocused = function(&api.IsAnyItemFocused, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsAnyItemHovered**
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsAnyItemHovered = function(&api.IsAnyItemHovered, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemActivated**
///--
///-- Was the last item just made active (item was previously inactive).
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemActivated = function(&api.IsItemActivated, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemActive**
///--
///-- Is the last item active? (e.g. button being held, text field being edited.
///-- This will continuously return true while holding mouse button on an item.
///-- Items that don't interact will always return false.
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemActive = function(&api.IsItemActive, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemClicked**
///--
///-- Is the last item clicked? (e.g. button/node just clicked on)
///-- == IsMouseClicked(mouse_button) && IsItemHovered().
///--
///-- This is NOT equivalent to the behavior of e.g. Button.
///-- Most widgets have specific reactions based on mouse-up/down state, mouse position etc.
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param mouse_button? integer default value = `MouseButton_Left`
///-- @return boolean retval
pub const IsItemClicked = function(&api.IsItemClicked, 1, &.{ ContextPtr, ?c_int });
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemDeactivated**
///--
///-- Was the last item just made inactive (item was previously active).
///-- Useful for Undo/Redo patterns with widgets that require continuous editing.
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemDeactivated = function(&api.IsItemDeactivated, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemDeactivatedAfterEdit**
///--
///-- Was the last item just made inactive and made a value change when it was
///-- active? (e.g. Slider/Drag moved).
///--
///-- Useful for Undo/Redo patterns with widgets that require continuous editing. Note
///-- that you may get false positives (some widgets such as Combo/ListBox/Selectable
///-- will return true even when clicking an already selected item).
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemDeactivatedAfterEdit = function(&api.IsItemDeactivatedAfterEdit, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemEdited**
///--
///-- Did the last item modify its underlying value this frame? or was pressed?
///-- This is generally the same as the "bool" return value of many widgets.
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemEdited = function(&api.IsItemEdited, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemFocused**
///--
///-- Is the last item focused for keyboard/gamepad navigation?
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemFocused = function(&api.IsItemFocused, 1, &.{ContextPtr});
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemHovered**
///--
///-- Is the last item hovered? (and usable, aka not blocked by a popup, etc.).
///-- See HoveredFlags_* for more options.
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param flags? integer default value = `HoveredFlags_None`
///-- @return boolean retval
pub const IsItemHovered = function(&api.IsItemHovered, 1, &.{ ContextPtr, ?c_int });
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions > IsItemVisible**
///--
///-- Is the last item visible? (items may be out of sight because of clipping/scrolling)
///--
///-- ---
///--
///-- **Item \& Status > Item\/Widgets Utilities and Query Functions**
///--
///-- Most of the functions are referring to the previous Item that has been submitted.
///--
///-- See Demo Window under "Widgets->Querying Item Status" for an interactive
///-- visualization of most of those functions.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemVisible = function(&api.IsItemVisible, 1, &.{ContextPtr});
///-- **Keyboard \& Mouse > Keyboard > GetInputQueueCharacter**
///--
///-- Read from ImGui's character input queue.
///-- Call with increasing idx until false is returned.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param idx integer
///-- @return boolean retval
///-- @return integer unicode_char
pub const GetInputQueueCharacter = function(&api.GetInputQueueCharacter, 3, &.{ ContextPtr, c_int, *c_int });
///-- **Keyboard \& Mouse > Keyboard > GetKeyDownDuration**
///--
///-- Duration the keyboard key has been down (0.0 == just pressed)
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param key integer
///-- @return number retval
pub const GetKeyDownDuration = function(&api.GetKeyDownDuration, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Keyboard > GetKeyMods**
///--
///-- Flags for the Ctrl/Shift/Alt/Super keys. Uses Mod_* values.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const GetKeyMods = function(&api.GetKeyMods, 1, &.{ContextPtr});
///-- **Keyboard \& Mouse > Keyboard > GetKeyPressedAmount**
///--
///-- Uses provided repeat rate/delay. Return a count, most often 0 or 1 but might
///-- be >1 if ConfigVar_RepeatRate is small enough that GetDeltaTime > RepeatRate.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param key integer
///-- @param repeat_delay number
///-- @param rate number
///-- @return integer retval
pub const GetKeyPressedAmount = function(&api.GetKeyPressedAmount, 4, &.{ ContextPtr, c_int, f64, f64 });
///-- **Keyboard \& Mouse > Keyboard > IsKeyChordPressed**
///--
///-- Was key chord (mods + key) pressed? You can pass e.g. `Mod_Shortcut | Key_S`
///-- as a key chord.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param key_chord integer
///-- @return boolean retval
pub const IsKeyChordPressed = function(&api.IsKeyChordPressed, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Keyboard > IsKeyDown**
///--
///-- Is key being held.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param key integer
///-- @return boolean retval
pub const IsKeyDown = function(&api.IsKeyDown, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Keyboard > IsKeyPressed**
///--
///-- Was key pressed (went from !Down to Down)?
///-- If repeat=true, uses ConfigVar_KeyRepeatDelay / ConfigVar_KeyRepeatRate.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param key integer
///-- @param repeat? boolean default value = `true`
///-- @return boolean retval
pub const IsKeyPressed = function(&api.IsKeyPressed, 2, &.{ ContextPtr, c_int, ?bool });
///-- **Keyboard \& Mouse > Keyboard > IsKeyReleased**
///--
///-- Was key released (went from Down to !Down)?
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param key integer
///-- @return boolean retval
pub const IsKeyReleased = function(&api.IsKeyReleased, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Keyboard > SetNextFrameWantCaptureKeyboard**
///--
///-- Request capture of keyboard shortcuts in REAPER's global scope for the next frame.
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param want_capture_keyboard boolean
pub const SetNextFrameWantCaptureKeyboard = function(&api.SetNextFrameWantCaptureKeyboard, 2, &.{ ContextPtr, bool });
///-- **Keyboard \& Mouse > Mouse > GetMouseClickedCount**
///--
///-- Return the number of successive mouse-clicks at the time where a click happen (otherwise 0).
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.5.10
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @return integer retval
pub const GetMouseClickedCount = function(&api.GetMouseClickedCount, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Mouse > GetMouseClickedPos**
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @return number x
///-- @return number y
pub const GetMouseClickedPos = function(&api.GetMouseClickedPos, 4, &.{ ContextPtr, c_int, *f64, *f64 });
///-- **Keyboard \& Mouse > Mouse > GetMouseDelta**
///--
///-- Mouse delta. Note that this is zero if either current or previous position
///-- are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have
///-- a huge delta.
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetMouseDelta = function(&api.GetMouseDelta, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Keyboard \& Mouse > Mouse > GetMouseDownDuration**
///--
///-- Duration the mouse button has been down (0.0 == just clicked)
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @return number retval
pub const GetMouseDownDuration = function(&api.GetMouseDownDuration, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Mouse > GetMouseDragDelta**
///--
///-- Return the delta from the initial clicking position while the mouse button is
///-- pressed or was just released. This is locked and return 0.0 until the mouse
///-- moves past a distance threshold at least once (if lock_threshold < -1.0, uses
///-- ConfigVar_MouseDragThreshold).
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param _1? nil​
///-- @param _2? nil​
///-- @param button? integer default value = `MouseButton_Left`
///-- @param lock_threshold? number default value = `-1.0`
///-- @return number x
///-- @return number y
pub const GetMouseDragDelta = function(&api.GetMouseDragDelta, 3, &.{ ContextPtr, *f64, *f64, ?c_int, ?f64 });
///-- **Keyboard \& Mouse > Mouse > GetMousePos**
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetMousePos = function(&api.GetMousePos, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Keyboard \& Mouse > Mouse > GetMousePosOnOpeningCurrentPopup**
///--
///-- Retrieve mouse position at the time of opening popup we have BeginPopup()
///-- into (helper to avoid user backing that value themselves).
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetMousePosOnOpeningCurrentPopup = function(&api.GetMousePosOnOpeningCurrentPopup, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Keyboard \& Mouse > Mouse > GetMouseWheel**
///--
///-- Vertical: 1 unit scrolls about 5 lines text. >0 scrolls Up, <0 scrolls Down.
///-- Hold SHIFT to turn vertical scroll into horizontal scroll
///--
///-- Horizontal: >0 scrolls Left, <0 scrolls Right.
///-- Most users don't have a mouse with a horizontal wheel.
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number vertical
///-- @return number horizontal
pub const GetMouseWheel = function(&api.GetMouseWheel, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Keyboard \& Mouse > Mouse > IsAnyMouseDown**
///--
///-- Is any mouse button held?
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsAnyMouseDown = function(&api.IsAnyMouseDown, 1, &.{ContextPtr});
///-- **Keyboard \& Mouse > Mouse > IsMouseClicked**
///--
///-- Did mouse button clicked? (went from !Down to Down).
///-- Same as GetMouseClickedCount() == 1.
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @param repeat? boolean default value = `false`
///-- @return boolean retval
pub const IsMouseClicked = function(&api.IsMouseClicked, 2, &.{ ContextPtr, c_int, ?bool });
///-- **Keyboard \& Mouse > Mouse > IsMouseDoubleClicked**
///--
///-- Did mouse button double-clicked? Same as GetMouseClickedCount() == 2.
///-- (Note that a double-click will also report IsMouseClicked() == true)
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @return boolean retval
pub const IsMouseDoubleClicked = function(&api.IsMouseDoubleClicked, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Mouse > IsMouseDown**
///--
///-- Is mouse button held?
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @return boolean retval
pub const IsMouseDown = function(&api.IsMouseDown, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Mouse > IsMouseDragging**
///--
///-- Is mouse dragging? (if lock_threshold < -1.0, uses ConfigVar_MouseDragThreshold)
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @param lock_threshold? number default value = `-1.0`
///-- @return boolean retval
pub const IsMouseDragging = function(&api.IsMouseDragging, 2, &.{ ContextPtr, c_int, ?f64 });
///-- **Keyboard \& Mouse > Mouse > IsMouseHoveringRect**
///--
///-- Is mouse hovering given bounding rect (in screen space).
///-- Clipped by current clipping settings, but disregarding of other consideration
///-- of focus/window ordering/popup-block.
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param r_min_x number
///-- @param r_min_y number
///-- @param r_max_x number
///-- @param r_max_y number
///-- @param clip? boolean default value = `true`
///-- @return boolean retval
pub const IsMouseHoveringRect = function(&api.IsMouseHoveringRect, 5, &.{ ContextPtr, f64, f64, f64, f64, ?bool });
///-- **Keyboard \& Mouse > Mouse > IsMousePosValid**
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param mouse_pos_x? number default value = `nil`
///-- @param mouse_pos_y? number default value = `nil`
///-- @return boolean retval
pub const IsMousePosValid = function(&api.IsMousePosValid, 1, &.{ ContextPtr, ?f64, ?f64 });
///-- **Keyboard \& Mouse > Mouse > IsMouseReleased**
///--
///-- Did mouse button released? (went from Down to !Down)
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button integer
///-- @return boolean retval
pub const IsMouseReleased = function(&api.IsMouseReleased, 2, &.{ ContextPtr, c_int });
///-- **Keyboard \& Mouse > Mouse > ResetMouseDragDelta**
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param button? integer default value = `MouseButton_Left`
pub const ResetMouseDragDelta = function(&api.ResetMouseDragDelta, 1, &.{ ContextPtr, ?c_int });
///-- **Keyboard \& Mouse > Mouse > Mouse Cursor > GetMouseCursor**
///--
///-- Get desired mouse cursor shape, reset every frame. This is updated during the frame.
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const GetMouseCursor = function(&api.GetMouseCursor, 1, &.{ContextPtr});
///-- **Keyboard \& Mouse > Mouse > Mouse Cursor > SetMouseCursor**
///--
///-- Set desired mouse cursor shape. See MouseCursor_* for possible values.
///--
///-- ---
///--
///-- **Keyboard \& Mouse > Mouse**
///--
///-- To refer to a mouse button, you may use named enums in your code e.g.
///-- MouseButton_Left, MouseButton_Right.
///--
///-- You can also use regular integer: it is forever guaranteed that
///-- 0=Left, 1=Right, 2=Middle. Buttons 3 and 4 do not have a named enum.
///--
///-- Dragging operations are only reported after mouse has moved a certain distance
///-- away from the initial clicking position (see 'lock_threshold' parameters and
///-- 'ConfigVar_MouseDragThreshold').
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param cursor_type integer
pub const SetMouseCursor = function(&api.SetMouseCursor, 2, &.{ ContextPtr, c_int });
///-- **Layout > BeginGroup**
///--
///-- Lock horizontal starting position. See EndGroup.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const BeginGroup = function(&api.BeginGroup, 1, &.{ContextPtr});
///-- **Layout > Dummy**
///--
///-- Add a dummy item of given size. unlike InvisibleButton, Dummy() won't take the
///-- mouse click or be navigable into.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param size_w number
///-- @param size_h number
pub const Dummy = function(&api.Dummy, 3, &.{ ContextPtr, f64, f64 });
///-- **Layout > EndGroup**
///--
///-- Unlock horizontal starting position + capture the whole group bounding box
///-- into one "item" (so you can use IsItemHovered or layout primitives such as
///-- SameLine on whole group, etc.).
///--
///-- See BeginGroup.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
pub const EndGroup = function(&api.EndGroup, 1, &.{ContextPtr});
///-- **Layout > Indent**
///--
///-- Move content position toward the right, by 'indent_w', or
///-- StyleVar_IndentSpacing if 'indent_w' <= 0. See Unindent.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param indent_w? number default value = `0.0`
pub const Indent = function(&api.Indent, 1, &.{ ContextPtr, ?f64 });
///-- **Layout > NewLine**
///--
///-- Undo a SameLine() or force a new line when in a horizontal-layout context.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const NewLine = function(&api.NewLine, 1, &.{ContextPtr});
///-- **Layout > SameLine**
///--
///-- Call between widgets or groups to layout them horizontally.
///-- X position given in window coordinates.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param offset_from_start_x? number default value = `0.0`
///-- @param spacing? number default value = `-1.0`
pub const SameLine = function(&api.SameLine, 1, &.{ ContextPtr, ?f64, ?f64 });
///-- **Layout > Separator**
///--
///-- Separator, generally horizontal. inside a menu bar or in horizontal layout
///-- mode, this becomes a vertical separator.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const Separator = function(&api.Separator, 1, &.{ContextPtr});
///-- **Layout > SeparatorText**
///--
///-- Text formatted with an horizontal line
///--
///-- ---
///--
///-- @since 0.8.4
///-- @param ctx ImGui_Context
///-- @param label string
pub const SeparatorText = function(&api.SeparatorText, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Layout > Spacing**
///--
///-- Add vertical spacing.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const Spacing = function(&api.Spacing, 1, &.{ContextPtr});
///-- **Layout > Unindent**
///--
///-- Move content position back to the left, by 'indent_w', or
///-- StyleVar_IndentSpacing if 'indent_w' <= 0
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param indent_w? number default value = `0.0`
pub const Unindent = function(&api.Unindent, 1, &.{ ContextPtr, ?f64 });
///-- **Layout > Clipping > IsRectVisible**
///--
///-- Test if rectangle (of given size, starting from cursor position) is
///-- visible / not clipped.
///--
///-- ---
///--
///-- **Layout > Clipping**
///--
///-- Mouse hovering is affected by PushClipRect() calls, unlike direct calls to
///-- DrawList_PushClipRect() which are render only. Coordinates are in screen space.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param size_w number
///-- @param size_h number
///-- @return boolean retval
pub const IsRectVisible = function(&api.IsRectVisible, 3, &.{ ContextPtr, f64, f64 });
///-- **Layout > Clipping > IsRectVisibleEx**
///--
///-- Test if rectangle (in screen space) is visible / not clipped. to perform
///-- coarse clipping on user's side.
///--
///-- ---
///--
///-- **Layout > Clipping**
///--
///-- Mouse hovering is affected by PushClipRect() calls, unlike direct calls to
///-- DrawList_PushClipRect() which are render only. Coordinates are in screen space.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param rect_min_x number
///-- @param rect_min_y number
///-- @param rect_max_x number
///-- @param rect_max_y number
///-- @return boolean retval
pub const IsRectVisibleEx = function(&api.IsRectVisibleEx, 5, &.{ ContextPtr, f64, f64, f64, f64 });
///-- **Layout > Clipping > PopClipRect**
///--
///-- See PushClipRect
///--
///-- ---
///--
///-- **Layout > Clipping**
///--
///-- Mouse hovering is affected by PushClipRect() calls, unlike direct calls to
///-- DrawList_PushClipRect() which are render only. Coordinates are in screen space.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const PopClipRect = function(&api.PopClipRect, 1, &.{ContextPtr});
///-- **Layout > Clipping > PushClipRect**
///--
///-- ---
///--
///-- **Layout > Clipping**
///--
///-- Mouse hovering is affected by PushClipRect() calls, unlike direct calls to
///-- DrawList_PushClipRect() which are render only. Coordinates are in screen space.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param clip_rect_min_x number
///-- @param clip_rect_min_y number
///-- @param clip_rect_max_x number
///-- @param clip_rect_max_y number
///-- @param intersect_with_current_clip_rect boolean
pub const PushClipRect = function(&api.PushClipRect, 6, &.{ ContextPtr, f64, f64, f64, f64, bool });
///-- **Layout > Layout Cursor Positioning > GetCursorPos**
///--
///-- Cursor position in window
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetCursorPos = function(&api.GetCursorPos, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Layout > Layout Cursor Positioning > GetCursorPosX**
///--
///-- Cursor X position in window
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetCursorPosX = function(&api.GetCursorPosX, 1, &.{ContextPtr});
///-- **Layout > Layout Cursor Positioning > GetCursorPosY**
///--
///-- Cursor Y position in window
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetCursorPosY = function(&api.GetCursorPosY, 1, &.{ContextPtr});
///-- **Layout > Layout Cursor Positioning > GetCursorScreenPos**
///--
///-- Cursor position in absolute screen coordinates (useful to work with the DrawList API).
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetCursorScreenPos = function(&api.GetCursorScreenPos, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Layout > Layout Cursor Positioning > GetCursorStartPos**
///--
///-- Initial cursor position in window coordinates.
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetCursorStartPos = function(&api.GetCursorStartPos, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Layout > Layout Cursor Positioning > SetCursorPos**
///--
///-- Cursor position in window
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param local_pos_x number
///-- @param local_pos_y number
pub const SetCursorPos = function(&api.SetCursorPos, 3, &.{ ContextPtr, f64, f64 });
///-- **Layout > Layout Cursor Positioning > SetCursorPosX**
///--
///-- Cursor X position in window
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param local_x number
pub const SetCursorPosX = function(&api.SetCursorPosX, 2, &.{ ContextPtr, f64 });
///-- **Layout > Layout Cursor Positioning > SetCursorPosY**
///--
///-- Cursor Y position in window
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param local_y number
pub const SetCursorPosY = function(&api.SetCursorPosY, 2, &.{ ContextPtr, f64 });
///-- **Layout > Layout Cursor Positioning > SetCursorScreenPos**
///--
///-- Cursor position in absolute screen coordinates.
///--
///-- ---
///--
///-- **Layout > Layout Cursor Positioning**
///--
///-- By "cursor" we mean the current output position.
///-- The typical widget behavior is to output themselves at the current cursor
///-- position, then move the cursor one line down.
///--
///-- You can call SameLine() between widgets to undo the last carriage return and
///-- output at the right of the preceding widget.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param pos_x number
///-- @param pos_y number
pub const SetCursorScreenPos = function(&api.SetCursorScreenPos, 3, &.{ ContextPtr, f64, f64 });
///-- **List Clipper > CreateListClipper**
///--
///-- The returned clipper object is only valid for the given context and is valid
///-- as long as it is used in each defer cycle unless attached (see Attach).
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @nodiscard
///-- @return ImGui_ListClipper retval
pub const CreateListClipper = function(&api.CreateListClipper, 1, &.{ContextPtr});
///-- **List Clipper > ListClipper\_Begin**
///--
///-- - items_count: Use INT_MAX if you don't know how many items you have
///-- (in which case the cursor won't be advanced in the final step)
///-- - items_height: Use -1.0 to be calculated automatically on first step.
///--   Otherwise pass in the distance between your items, typically
///--   GetTextLineHeightWithSpacing or GetFrameHeightWithSpacing.
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.1
///-- @param clipper ImGui_ListClipper
///-- @param items_count integer
///-- @param items_height? number default value = `-1.0`
pub const ListClipper_Begin = function(&api.ListClipper_Begin, 2, &.{ ListClipperPtr, c_int, ?f64 });
///-- **List Clipper > ListClipper\_End**
///--
///-- Automatically called on the last call of ListClipper_Step that returns false.
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.1
///-- @param clipper ImGui_ListClipper
pub const ListClipper_End = function(&api.ListClipper_End, 1, &.{ListClipperPtr});
///-- **List Clipper > ListClipper\_GetDisplayRange**
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.3
///-- @param clipper ImGui_ListClipper
///-- @return integer display_start
///-- @return integer display_end
pub const ListClipper_GetDisplayRange = function(&api.ListClipper_GetDisplayRange, 3, &.{ ListClipperPtr, *c_int, *c_int });
///-- **List Clipper > ListClipper\_IncludeItemByIndex**
///--
///-- Call ListClipper_IncludeItemByIndex or ListClipper_IncludeItemsByIndex before
///-- the first call to ListClipper_Step if you need a range of items to be displayed
///-- regardless of visibility.
///--
///-- (Due to alignment / padding of certain items it is possible that an extra item
///-- may be included on either end of the display range).
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.9
///-- @param clipper ImGui_ListClipper
///-- @param item_index integer
pub const ListClipper_IncludeItemByIndex = function(&api.ListClipper_IncludeItemByIndex, 2, &.{ ListClipperPtr, c_int });
///-- **List Clipper > ListClipper\_IncludeItemsByIndex**
///--
///-- See ListClipper_IncludeItemByIndex.
///--
///-- item_end is exclusive e.g. use (42, 42+1) to make item 42 never clipped.
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.9
///-- @param clipper ImGui_ListClipper
///-- @param item_begin integer
///-- @param item_end integer
pub const ListClipper_IncludeItemsByIndex = function(&api.ListClipper_IncludeItemsByIndex, 3, &.{ ListClipperPtr, c_int, c_int });
///-- **List Clipper > ListClipper\_Step**
///--
///-- Call until it returns false. The display_start/display_end fields from
///-- ListClipper_GetDisplayRange will be set and you can process/draw those items.
///--
///-- ---
///--
///-- **List Clipper**
///--
///-- Helper to manually clip large list of items.
///--
///-- If you have lots evenly spaced items and you have random access to the list,
///-- you can perform coarse clipping based on visibility to only submit items that
///-- are in view.
///--
///-- The clipper calculates the range of visible items and advance the cursor to
///-- compensate for the non-visible items we have skipped.
///-- (Dear ImGui already clip items based on their bounds but: it needs to first
///-- layout the item to do so, and generally fetching/submitting your own data incurs
///-- additional cost. Coarse clipping using ImGui_ListClipper allows you to easily
///-- scale using lists with tens of thousands of items without a problem.)
///--
///-- Usage:
///--
///--     if not ImGui.ValidatePtr(clipper, 'ImGui_ListClipper*') then
///--       clipper = ImGui.CreateListClipper(ctx)
///--     end
///--     ImGui.ListClipper_Begin(clipper, 1000) -- We have 1000 elements, evenly spaced
///--     while ImGui.ListClipper_Step(clipper) do
///--       local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
///--       for row = display_start, display_end - 1 do
///--         ImGui.Text(ctx, ("line number %d"):format(row))
///--       end
///--     end
///--
///-- Generally what happens is:
///-- - Clipper lets you process the first element (DisplayStart = 0, DisplayEnd = 1)
///--   regardless of it being visible or not.
///-- - User code submit that one element.
///-- - Clipper can measure the height of the first element
///-- - Clipper calculate the actual range of elements to display based on the current
///--   clipping rectangle, position the cursor before the first visible element.
///-- - User code submit visible elements.
///-- - The clipper also handles various subtleties related to keyboard/gamepad
///--   navigation, wrapping etc.
///--
///-- ---
///--
///-- @since 0.1
///-- @param clipper ImGui_ListClipper
///-- @return boolean retval
pub const ListClipper_Step = function(&api.ListClipper_Step, 1, &.{ListClipperPtr});
///-- **Menu > BeginMenu**
///--
///-- Create a sub-menu entry. only call EndMenu if this returns true!
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param enabled? boolean default value = `true`
///-- @nodiscard
///-- @return boolean retval
pub const BeginMenu = function(&api.BeginMenu, 2, &.{ ContextPtr, [*:0]const u8, ?bool });
///-- **Menu > BeginMenuBar**
///--
///-- Append to menu-bar of current window (requires WindowFlags_MenuBar flag set
///-- on parent window). See EndMenuBar.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @nodiscard
///-- @return boolean retval
pub const BeginMenuBar = function(&api.BeginMenuBar, 1, &.{ContextPtr});
///-- **Menu > EndMenu**
///--
///-- Only call EndMenu() if BeginMenu returns true!
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndMenu = function(&api.EndMenu, 1, &.{ContextPtr});
///-- **Menu > EndMenuBar**
///--
///-- Only call EndMenuBar if BeginMenuBar returns true!
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndMenuBar = function(&api.EndMenuBar, 1, &.{ContextPtr});
///-- **Menu > MenuItem**
///--
///-- Return true when activated. Shortcuts are displayed for convenience but not
///-- processed by ImGui at the moment. Toggle state is written to 'selected' when
///-- provided.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param shortcut? string default value = `nil`
///-- @param p_selected? boolean default value = `nil`
///-- @param enabled? boolean default value = `true`
///-- @return boolean retval
///-- @return boolean p_selected
pub const MenuItem = function(&api.MenuItem, 2, &.{ ContextPtr, [*:0]const u8, ?[*:0]const u8, ?*bool, ?bool });
///-- **Plot > PlotHistogram**
///--
///-- ---
///--
///-- **Plot**
///--
///-- Simple data plotting using reaper_array as data source.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param values reaper.array
///-- @param values_offset? integer default value = `0`
///-- @param overlay_text? string default value = `nil`
///-- @param scale_min? number default value = `FLT_MAX`
///-- @param scale_max? number default value = `FLT_MAX`
///-- @param graph_size_w? number default value = `0.0`
///-- @param graph_size_h? number default value = `0.0`
pub const PlotHistogram = function(&api.PlotHistogram, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?c_int, ?[*:0]const u8, ?f64, ?f64, ?f64, ?f64 });
///-- **Plot > PlotLines**
///--
///-- ---
///--
///-- **Plot**
///--
///-- Simple data plotting using reaper_array as data source.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param values reaper.array
///-- @param values_offset? integer default value = `0`
///-- @param overlay_text? string default value = `nil`
///-- @param scale_min? number default value = `FLT_MAX`
///-- @param scale_max? number default value = `FLT_MAX`
///-- @param graph_size_w? number default value = `0.0`
///-- @param graph_size_h? number default value = `0.0`
pub const PlotLines = function(&api.PlotLines, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?c_int, ?[*:0]const u8, ?f64, ?f64, ?f64, ?f64 });
///-- **Popup \& Modal > BeginPopup**
///--
///-- Query popup state, if open start appending into the window. Call EndPopup
///-- afterwards if returned true. WindowFlags* are forwarded to the window.
///--
///-- Return true if the popup is open, and you can start outputting to it.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param flags? integer default value = `WindowFlags_None`
///-- @nodiscard
///-- @return boolean retval
pub const BeginPopup = function(&api.BeginPopup, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
///-- **Popup \& Modal > BeginPopupModal**
///--
///-- Block every interaction behind the window, cannot be closed by user, add a
///-- dimming background, has a title bar. Return true if the modal is open, and you
///-- can start outputting to it. See BeginPopup.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param name string
///-- @param p_open? boolean default value = `nil`
///-- @param flags? integer default value = `WindowFlags_None`
///-- @nodiscard
///-- @return boolean retval
///-- @return boolean p_open
pub const BeginPopupModal = function(&api.BeginPopupModal, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
///-- **Popup \& Modal > CloseCurrentPopup**
///--
///-- Manually close the popup we have begin-ed into.
///-- Use inside the BeginPopup/EndPopup scope to close manually.
///--
///-- CloseCurrentPopup() is called by default by Selectable/MenuItem when activated.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const CloseCurrentPopup = function(&api.CloseCurrentPopup, 1, &.{ContextPtr});
///-- **Popup \& Modal > EndPopup**
///--
///-- Only call EndPopup() if BeginPopup*() returns true!
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
pub const EndPopup = function(&api.EndPopup, 1, &.{ContextPtr});
///-- **Popup \& Modal > IsPopupOpen**
///--
///-- Return true if the popup is open at the current BeginPopup level of the
///-- popup stack.
///--
///-- - With PopupFlags_AnyPopupId: return true if any popup is open at the current
///--   BeginPopup() level of the popup stack.
///-- - With PopupFlags_AnyPopupId + PopupFlags_AnyPopupLevel: return true if any
///--   popup is open.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param flags? integer default value = `PopupFlags_None`
///-- @return boolean retval
pub const IsPopupOpen = function(&api.IsPopupOpen, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
///-- **Popup \& Modal > OpenPopup**
///--
///-- Set popup state to open (don't call every frame!).
///-- ImGuiPopupFlags are available for opening options.
///--
///-- If not modal: they can be closed by clicking anywhere outside them, or by
///-- pressing ESCAPE.
///--
///-- Use PopupFlags_NoOpenOverExistingPopup to avoid opening a popup if there's
///-- already one at the same level.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param popup_flags? integer default value = `PopupFlags_None`
pub const OpenPopup = function(&api.OpenPopup, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
///-- **Popup \& Modal > OpenPopupOnItemClick**
///--
///-- Helper to open popup when clicked on last item. return true when just opened.
///-- (Note: actually triggers on the mouse _released_ event to be consistent with
///-- popup behaviors.)
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id? string default value = `nil`
///-- @param popup_flags? integer default value = `PopupFlags_MouseButtonRight`
pub const OpenPopupOnItemClick = function(&api.OpenPopupOnItemClick, 1, &.{ ContextPtr, ?[*:0]const u8, ?c_int });
///-- **Popup \& Modal > Open\+Begin Combined Helpers > BeginPopupContextItem**
///--
///-- This is a helper to handle the simplest case of associating one named popup
///-- to one given widget. You can pass a nil str_id to use the identifier of the last
///-- item. This is essentially the same as calling OpenPopupOnItemClick + BeginPopup
///-- but written to avoid computing the ID twice because BeginPopupContext*
///-- functions may be called very frequently.
///--
///-- If you want to use that on a non-interactive item such as Text you need to pass
///-- in an explicit ID here.
///--
///-- ---
///--
///-- **Popup \& Modal > Open\+Begin Combined Helpers**
///--
///--
///-- Helpers to do OpenPopup+BeginPopup where the Open action is triggered by e.g.
///-- hovering an item and right-clicking. They are convenient to easily create
///-- context menus, hence the name.
///--
///-- Notice that BeginPopupContext* takes PopupFlags_* just like OpenPopup and
///-- unlike BeginPopup.
///--
///-- We exceptionally default their flags to 1 (== PopupFlags_MouseButtonRight) for
///-- backward compatibility with older API taking 'int mouse_button = 1' parameter,
///-- so if you add other flags remember to re-add the PopupFlags_MouseButtonRight.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id? string default value = `nil`
///-- @param popup_flags? integer default value = `PopupFlags_MouseButtonRight`
///-- @nodiscard
///-- @return boolean retval
pub const BeginPopupContextItem = function(&api.BeginPopupContextItem, 1, &.{ ContextPtr, ?[*:0]const u8, ?c_int });
///-- **Popup \& Modal > Open\+Begin Combined Helpers > BeginPopupContextWindow**
///--
///-- Open+begin popup when clicked on current window.
///--
///-- ---
///--
///-- **Popup \& Modal > Open\+Begin Combined Helpers**
///--
///--
///-- Helpers to do OpenPopup+BeginPopup where the Open action is triggered by e.g.
///-- hovering an item and right-clicking. They are convenient to easily create
///-- context menus, hence the name.
///--
///-- Notice that BeginPopupContext* takes PopupFlags_* just like OpenPopup and
///-- unlike BeginPopup.
///--
///-- We exceptionally default their flags to 1 (== PopupFlags_MouseButtonRight) for
///-- backward compatibility with older API taking 'int mouse_button = 1' parameter,
///-- so if you add other flags remember to re-add the PopupFlags_MouseButtonRight.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id? string default value = `nil`
///-- @param popup_flags? integer default value = `PopupFlags_MouseButtonRight`
///-- @nodiscard
///-- @return boolean retval
pub const BeginPopupContextWindow = function(&api.BeginPopupContextWindow, 1, &.{ ContextPtr, ?[*:0]const u8, ?c_int });
///-- **Popup \& Modal > Tooltips > BeginItemTooltip**
///--
///-- Begin/append a tooltip window if preceding item was hovered. Shortcut for
///-- `IsItemHovered(HoveredFlags_ForTooltip) && BeginTooltip()`.
///--
///-- ---
///--
///-- **Popup \& Modal > Tooltips**
///--
///-- Tooltips are windows following the mouse. They do not take focus away.
///-- A tooltip window can contain items of any type.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @nodiscard
///-- @return boolean retval
pub const BeginItemTooltip = function(&api.BeginItemTooltip, 1, &.{ContextPtr});
///-- **Popup \& Modal > Tooltips > BeginTooltip**
///--
///-- Begin/append a tooltip window.
///--
///-- ---
///--
///-- **Popup \& Modal > Tooltips**
///--
///-- Tooltips are windows following the mouse. They do not take focus away.
///-- A tooltip window can contain items of any type.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @nodiscard
///-- @return boolean retval
pub const BeginTooltip = function(&api.BeginTooltip, 1, &.{ContextPtr});
///-- **Popup \& Modal > Tooltips > EndTooltip**
///--
///-- Only call EndTooltip() if BeginTooltip()/BeginItemTooltip() returns true.
///--
///-- ---
///--
///-- **Popup \& Modal > Tooltips**
///--
///-- Tooltips are windows following the mouse. They do not take focus away.
///-- A tooltip window can contain items of any type.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
pub const EndTooltip = function(&api.EndTooltip, 1, &.{ContextPtr});
///-- **Popup \& Modal > Tooltips > SetItemTooltip**
///--
///-- Set a text-only tooltip if preceeding item was hovered.
///-- Override any previous call to SetTooltip(). Shortcut for
///-- `if (IsItemHovered(HoveredFlags_ForTooltip)) { SetTooltip(...); }`.
///--
///-- ---
///--
///-- **Popup \& Modal > Tooltips**
///--
///-- Tooltips are windows following the mouse. They do not take focus away.
///-- A tooltip window can contain items of any type.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param text string
pub const SetItemTooltip = function(&api.SetItemTooltip, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Popup \& Modal > Tooltips > SetTooltip**
///--
///-- Set a text-only tooltip. Often used after a IsItemHovered() check.
///-- Override any previous call to SetTooltip.
///--
///-- Shortcut for `if (BeginTooltip()) { Text(...); EndTooltip(); }`.
///--
///-- ---
///--
///-- **Popup \& Modal > Tooltips**
///--
///-- Tooltips are windows following the mouse. They do not take focus away.
///-- A tooltip window can contain items of any type.
///--
///-- ---
///--
///-- **Popup \& Modal**
///--
///-- - They block normal mouse hovering detection (and therefore most mouse
///--   interactions) behind them.
///-- - If not modal: they can be closed by clicking anywhere outside them, or by
///--   pressing ESCAPE.
///-- - Their visibility state (~bool) is held internally instead of being held by the
///--   programmer as we are used to with regular Begin*() calls.
///--
///-- The 3 properties above are related: we need to retain popup visibility state in
///-- the library because popups may be closed as any time.
///--
///-- You can bypass the hovering restriction by using
///-- HoveredFlags_AllowWhenBlockedByPopup when calling IsItemHovered or IsWindowHovered.
///--
///-- IMPORTANT: Popup identifiers are relative to the current ID stack, so OpenPopup
///-- and BeginPopup generally needs to be at the same level of the stack.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const SetTooltip = function(&api.SetTooltip, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Style > Colors > DebugFlashStyleColor**
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param idx integer
pub const DebugFlashStyleColor = function(&api.DebugFlashStyleColor, 2, &.{ ContextPtr, c_int });
///-- **Style > Colors > GetColor**
///--
///-- Retrieve given style color with style alpha applied and optional extra alpha
///-- multiplier, packed as a 32-bit value (RGBA). See Col_* for available style colors.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param idx integer
///-- @param alpha_mul? number default value = `1.0`
///-- @return integer retval
pub const GetColor = function(&api.GetColor, 2, &.{ ContextPtr, c_int, ?f64 });
///-- **Style > Colors > GetColorEx**
///--
///-- Retrieve given color with style alpha applied, packed as a 32-bit value (RGBA).
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param col_rgba integer
///-- @param alpha_mul? number default value = `1.0`
///-- @return integer retval
pub const GetColorEx = function(&api.GetColorEx, 2, &.{ ContextPtr, c_int, ?f64 });
///-- **Style > Colors > GetStyleColor**
///--
///-- Retrieve style color as stored in ImGuiStyle structure.
///-- Use to feed back into PushStyleColor, Otherwise use GetColor to get style color
///-- with style alpha baked in. See Col_* for available style colors.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param idx integer
///-- @return integer retval
pub const GetStyleColor = function(&api.GetStyleColor, 2, &.{ ContextPtr, c_int });
///-- **Style > Colors > PopStyleColor**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param count? integer default value = `1`
pub const PopStyleColor = function(&api.PopStyleColor, 1, &.{ ContextPtr, ?c_int });
///-- **Style > Colors > PushStyleColor**
///--
///-- Temporarily modify a style color.
///-- Call PopStyleColor to undo after use (before the end of the frame).
///-- See Col_* for available style colors.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param idx integer
///-- @param col_rgba integer
pub const PushStyleColor = function(&api.PushStyleColor, 3, &.{ ContextPtr, c_int, c_int });
///-- **Style > Variables > GetStyleVar**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param var_idx integer
///-- @return number val1
///-- @return number val2
pub const GetStyleVar = function(&api.GetStyleVar, 4, &.{ ContextPtr, c_int, *f64, *f64 });
///-- **Style > Variables > PopStyleVar**
///--
///-- Reset a style variable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param count? integer default value = `1`
pub const PopStyleVar = function(&api.PopStyleVar, 1, &.{ ContextPtr, ?c_int });
///-- **Style > Variables > PushStyleVar**
///--
///-- Temporarily modify a style variable.
///-- Call PopStyleVar to undo after use (before the end of the frame).
///-- See StyleVar_* for possible values of 'var_idx'.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param var_idx integer
///-- @param val1 number
///-- @param val2? number default value = `nil`
pub const PushStyleVar = function(&api.PushStyleVar, 3, &.{ ContextPtr, c_int, f64, ?f64 });
///-- **Tab Bar > BeginTabBar**
///--
///-- Create and append into a TabBar.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param flags? integer default value = `TabBarFlags_None`
///-- @nodiscard
///-- @return boolean retval
pub const BeginTabBar = function(&api.BeginTabBar, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
///-- **Tab Bar > EndTabBar**
///--
///-- Only call EndTabBar() if BeginTabBar() returns true!
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndTabBar = function(&api.EndTabBar, 1, &.{ContextPtr});
///-- **Tab Bar > Tab Item > BeginTabItem**
///--
///-- Create a Tab. Returns true if the Tab is selected.
///-- Set 'p_open' to true to enable the close button.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param p_open? boolean default value = `nil`
///-- @param flags? integer default value = `TabItemFlags_None`
///-- @nodiscard
///-- @return boolean retval
///-- @return boolean p_open
pub const BeginTabItem = function(&api.BeginTabItem, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
///-- **Tab Bar > Tab Item > EndTabItem**
///--
///-- Only call EndTabItem() if BeginTabItem() returns true!
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const EndTabItem = function(&api.EndTabItem, 1, &.{ContextPtr});
///-- **Tab Bar > Tab Item > SetTabItemClosed**
///--
///-- Notify TabBar or Docking system of a closed tab/window ahead
///-- (useful to reduce visual flicker on reorderable tab bars).
///-- For tab-bar: call after BeginTabBar and before Tab submissions.
///-- Otherwise call with a window name.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param tab_or_docked_window_label string
pub const SetTabItemClosed = function(&api.SetTabItemClosed, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Tab Bar > Tab Item > TabItemButton**
///--
///-- Create a Tab behaving like a button. Return true when clicked.
///-- Cannot be selected in the tab bar.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param flags? integer default value = `TabItemFlags_None`
///-- @return boolean retval
pub const TabItemButton = function(&api.TabItemButton, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
///-- **Table > BeginTable**
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param column integer
///-- @param flags? integer default value = `TableFlags_None`
///-- @param outer_size_w? number default value = `0.0`
///-- @param outer_size_h? number default value = `0.0`
///-- @param inner_width? number default value = `0.0`
///-- @nodiscard
///-- @return boolean retval
pub const BeginTable = function(&api.BeginTable, 3, &.{ ContextPtr, [*:0]const u8, c_int, ?c_int, ?f64, ?f64, ?f64 });
///-- **Table > EndTable**
///--
///-- Only call EndTable() if BeginTable() returns true!
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
pub const EndTable = function(&api.EndTable, 1, &.{ContextPtr});
///-- **Table > TableGetColumnCount**
///--
///-- Return number of columns (value passed to BeginTable).
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const TableGetColumnCount = function(&api.TableGetColumnCount, 1, &.{ContextPtr});
///-- **Table > TableGetColumnIndex**
///--
///-- Return current column index.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const TableGetColumnIndex = function(&api.TableGetColumnIndex, 1, &.{ContextPtr});
///-- **Table > TableGetRowIndex**
///--
///-- Return current row index.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const TableGetRowIndex = function(&api.TableGetRowIndex, 1, &.{ContextPtr});
///-- **Table > TableNextColumn**
///--
///-- Append into the next column (or first column of next row if currently in
///-- last column). Return true when column is visible.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const TableNextColumn = function(&api.TableNextColumn, 1, &.{ContextPtr});
///-- **Table > TableNextRow**
///--
///-- Append into the first cell of a new row.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param row_flags? integer default value = `TableRowFlags_None`
///-- @param min_row_height? number default value = `0.0`
pub const TableNextRow = function(&api.TableNextRow, 1, &.{ ContextPtr, ?c_int, ?f64 });
///-- **Table > TableSetColumnIndex**
///--
///-- Append into the specified column. Return true when column is visible.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
///-- @param column_n integer
///-- @return boolean retval
pub const TableSetColumnIndex = function(&api.TableSetColumnIndex, 2, &.{ ContextPtr, c_int });
///-- **Table > Background > TableSetBgColor**
///--
///-- Change the color of a cell, row, or column.
///-- See TableBgTarget_* flags for details.
///--
///-- ---
///--
///-- **Table > Background**
///--
///-- Background colors are rendering in 3 layers:
///--
///-- - Layer 0: draw with RowBg0 color if set, otherwise draw with ColumnBg0 if set.
///-- - Layer 1: draw with RowBg1 color if set, otherwise draw with ColumnBg1 if set.
///-- - Layer 2: draw with CellBg color if set.
///--
///-- The purpose of the two row/columns layers is to let you decide if a background
///-- color change should override or blend with the existing color.
///-- When using TableFlags_RowBg on the table, each row has the RowBg0 color
///-- automatically set for odd/even rows.
///-- If you set the color of RowBg0 target, your color will override the existing
///-- RowBg0 color.
///-- If you set the color of RowBg1 or ColumnBg1 target, your color will blend over
///-- the RowBg0 color.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param target integer
///-- @param color_rgba integer
///-- @param column_n? integer default value = `-1`
pub const TableSetBgColor = function(&api.TableSetBgColor, 3, &.{ ContextPtr, c_int, c_int, ?c_int });
///-- **Table > Header \& Columns > TableAngledHeadersRow**
///--
///-- Submit a row with angled headers for every column with the
///-- TableColumnFlags_AngledHeader flag. Must be the first row.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const TableAngledHeadersRow = function(&api.TableAngledHeadersRow, 1, &.{ContextPtr});
///-- **Table > Header \& Columns > TableGetColumnFlags**
///--
///-- Return column flags so you can query their Enabled/Visible/Sorted/Hovered
///-- status flags. Pass -1 to use current column.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param column_n? integer default value = `-1`
///-- @return integer retval
pub const TableGetColumnFlags = function(&api.TableGetColumnFlags, 1, &.{ ContextPtr, ?c_int });
///-- **Table > Header \& Columns > TableGetColumnName**
///--
///-- Return "" if column didn't have a name declared by TableSetupColumn.
///-- Pass -1 to use current column.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param column_n? integer default value = `-1`
///-- @return string retval
pub const TableGetColumnName = function(&api.TableGetColumnName, 1, &.{ ContextPtr, ?c_int });
///-- **Table > Header \& Columns > TableHeader**
///--
///-- Submit one header cell manually (rarely used). See TableSetupColumn.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
pub const TableHeader = function(&api.TableHeader, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Table > Header \& Columns > TableHeadersRow**
///--
///-- Submit a row with headers cells based on data provided to TableSetupColumn
///-- + submit context menu.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const TableHeadersRow = function(&api.TableHeadersRow, 1, &.{ContextPtr});
///-- **Table > Header \& Columns > TableSetColumnEnabled**
///--
///-- Change user-accessible enabled/disabled state of a column, set to false to
///-- hide the column. Note that end-user can use the context menu to change this
///-- themselves (right-click in headers, or right-click in columns body with
///-- TableFlags_ContextMenuInBody).
///--
///-- - Require table to have the TableFlags_Hideable flag because we are manipulating
///--   user accessible state.
///-- - Request will be applied during next layout, which happens on the first call to
///--   TableNextRow after Begin_Table.
///-- - For the getter you can test
///--   (TableGetColumnFlags() & TableColumnFlags_IsEnabled) != 0.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.4.1
///-- @param ctx ImGui_Context
///-- @param column_n integer
///-- @param v boolean
pub const TableSetColumnEnabled = function(&api.TableSetColumnEnabled, 3, &.{ ContextPtr, c_int, bool });
///-- **Table > Header \& Columns > TableSetupColumn**
///--
///-- Use to specify label, resizing policy, default width/weight, id,
///-- various other flags etc.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param flags? integer default value = `TableColumnFlags_None`
///-- @param init_width_or_weight? number default value = `0.0`
///-- @param user_id? integer default value = `0`
pub const TableSetupColumn = function(&api.TableSetupColumn, 2, &.{ ContextPtr, [*:0]const u8, ?c_int, ?f64, ?c_int });
///-- **Table > Header \& Columns > TableSetupScrollFreeze**
///--
///-- Lock columns/rows so they stay visible when scrolled.
///--
///-- ---
///--
///-- **Table > Header \& Columns**
///--
///-- Use TableSetupColumn() to specify label, resizing policy, default
///-- width/weight, id, various other flags etc.
///--
///-- Use TableHeadersRow() to create a header row and automatically submit a
///-- TableHeader() for each column. Headers are required to perform: reordering,
///-- sorting, and opening the context menu. The context menu can also be made
///-- available in columns body using ImGuiTableFlags_ContextMenuInBody.
///--
///-- You may manually submit headers using TableNextRow() + TableHeader() calls, but
///-- this is only useful in some advanced use cases (e.g. adding custom widgets in
///-- header row).
///--
///-- Use TableSetupScrollFreeze() to lock columns/rows so they stay visible when
///-- scrolled.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param cols integer
///-- @param rows integer
pub const TableSetupScrollFreeze = function(&api.TableSetupScrollFreeze, 3, &.{ ContextPtr, c_int, c_int });
///-- **Table > Sorting > TableGetColumnSortSpecs**
///--
///-- Sorting specification for one column of a table.
///-- Call while incrementing 'id' from 0 until false is returned.
///--
///-- - id:             Index of the sorting specification (always stored in order
///--   starting from 0, tables sorted on a single criteria will always have a 0 here)
///-- - column_index:   Index of the column
///-- - column_user_id: User ID of the column (if specified by a TableSetupColumn call)
///-- - sort_direction: SortDirection_Ascending or SortDirection_Descending
///--
///-- See TableNeedSort.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param id integer
///-- @return boolean retval
///-- @return integer column_index
///-- @return integer column_user_id
///-- @return integer sort_direction
pub const TableGetColumnSortSpecs = function(&api.TableGetColumnSortSpecs, 5, &.{ ContextPtr, c_int, *c_int, *c_int, *c_int });
///-- **Table > Sorting > TableNeedSort**
///--
///-- Return true once when sorting specs have changed since last call,
///-- or the first time. 'has_specs' is false when not sorting.
///--
///-- See TableGetColumnSortSpecs.
///--
///-- ---
///--
///-- **Table**
///--
///-- See top of [imgui_tables.cpp](https://github.com/ocornut/imgui/blob/master/imgui_tables.cpp)
///-- for general commentary.
///--
///-- See TableFlags* and TableColumnFlags* enums for a description of available flags.
///--
///-- The typical call flow is:
///-- 1. Call BeginTable.
///-- 2. Optionally call TableSetupColumn to submit column name/flags/defaults.
///-- 3. Optionally call TableSetupScrollFreeze to request scroll freezing of columns/rows.
///-- 4. Optionally call TableHeadersRow to submit a header row. Names are pulled from
///--    TableSetupColumn data.
///-- 5. Populate contents:
///--    - In most situations you can use TableNextRow + TableSetColumnIndex(N) to
///--      start appending into a column.
///--    - If you are using tables as a sort of grid, where every column is holding
///--      the same type of contents,
///--      you may prefer using TableNextColumn instead of
///--      TableNextRow + TableSetColumnIndex.
///--      TableNextColumn will automatically wrap-around into the next row if needed.
///--    - Summary of possible call flow:
///--      ```
///--      TableNextRow() -> TableSetColumnIndex(0) -> Text("Hello 0") -> TableSetColumnIndex(1) -> Text("Hello 1")  // OK
///--      TableNextRow() -> TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK
///--                        TableNextColumn()      -> Text("Hello 0") -> TableNextColumn()      -> Text("Hello 1")  // OK: TableNextColumn() automatically gets to next row!
///--      TableNextRow()                           -> Text("Hello 0")                                               // Not OK! Missing TableSetColumnIndex() or TableNextColumn()! Text will not appear!
///--      ```
///-- 5. Call EndTable.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
///-- @return boolean has_specs
pub const TableNeedSort = function(&api.TableNeedSort, 2, &.{ ContextPtr, *bool });
///-- **Text > AlignTextToFramePadding**
///--
///-- Vertically align upcoming text baseline to StyleVar_FramePadding.y so that it
///-- will align properly to regularly framed items (call if you have text on a line
///-- before a framed item).
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const AlignTextToFramePadding = function(&api.AlignTextToFramePadding, 1, &.{ContextPtr});
///-- **Text > Bullet**
///--
///-- Draw a small circle + keep the cursor on the same line.
///-- Advance cursor x position by GetTreeNodeToLabelSpacing,
///-- same distance that TreeNode uses.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const Bullet = function(&api.Bullet, 1, &.{ContextPtr});
///-- **Text > BulletText**
///--
///-- Shortcut for Bullet + Text.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const BulletText = function(&api.BulletText, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Text > CalcTextSize**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
///-- @param _1? nil​
///-- @param _2? nil​
///-- @param hide_text_after_double_hash? boolean default value = `false`
///-- @param wrap_width? number default value = `-1.0`
///-- @return number w
///-- @return number h
pub const CalcTextSize = function(&api.CalcTextSize, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?bool, ?f64 });
///-- **Text > DebugTextEncoding**
///--
///-- Helper tool to diagnose between text encoding issues and font loading issues.
///-- Pass your UTF-8 string and verify that there are correct.
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param text string
pub const DebugTextEncoding = function(&api.DebugTextEncoding, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Text > GetFrameHeight**
///--
///-- GetFontSize + StyleVar_FramePadding.y * 2
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetFrameHeight = function(&api.GetFrameHeight, 1, &.{ContextPtr});
///-- **Text > GetFrameHeightWithSpacing**
///--
///-- GetFontSize + StyleVar_FramePadding.y * 2 + StyleVar_ItemSpacing.y
///-- (distance in pixels between 2 consecutive lines of framed widgets).
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetFrameHeightWithSpacing = function(&api.GetFrameHeightWithSpacing, 1, &.{ContextPtr});
///-- **Text > GetTextLineHeight**
///--
///-- Same as GetFontSize
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetTextLineHeight = function(&api.GetTextLineHeight, 1, &.{ContextPtr});
///-- **Text > GetTextLineHeightWithSpacing**
///--
///-- GetFontSize + StyleVar_ItemSpacing.y
///-- (distance in pixels between 2 consecutive lines of text).
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetTextLineHeightWithSpacing = function(&api.GetTextLineHeightWithSpacing, 1, &.{ContextPtr});
///-- **Text > LabelText**
///--
///-- Display text+label aligned the same way as value+label widgets
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param text string
pub const LabelText = function(&api.LabelText, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8 });
///-- **Text > PopTextWrapPos**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const PopTextWrapPos = function(&api.PopTextWrapPos, 1, &.{ContextPtr});
///-- **Text > PushTextWrapPos**
///--
///-- Push word-wrapping position for Text*() commands.
///--
///-- -  < 0.0: no wrapping
///-- -  = 0.0: wrap to end of window (or column)
///-- - \> 0.0: wrap at 'wrap_pos_x' position in window local space.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param wrap_local_pos_x? number default value = `0.0`
pub const PushTextWrapPos = function(&api.PushTextWrapPos, 1, &.{ ContextPtr, ?f64 });
///-- **Text > Text**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const Text = function(&api.Text, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Text > TextColored**
///--
///-- Shortcut for PushStyleColor(Col_Text, color); Text(text); PopStyleColor();
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param col_rgba integer
///-- @param text string
pub const TextColored = function(&api.TextColored, 3, &.{ ContextPtr, c_int, [*:0]const u8 });
///-- **Text > TextDisabled**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const TextDisabled = function(&api.TextDisabled, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Text > TextWrapped**
///--
///-- Shortcut for PushTextWrapPos(0.0); Text(text); PopTextWrapPos();.
///-- Note that this won't work on an auto-resizing window if there's no other
///-- widgets to extend the window width, yoy may need to set a size using
///-- SetNextWindowSize.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const TextWrapped = function(&api.TextWrapped, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Text \& Scalar Input > InputDouble**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param step? number default value = `0.0`
///-- @param step_fast? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return number v
pub const InputDouble = function(&api.InputDouble, 3, &.{ ContextPtr, [*:0]const u8, *f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Text \& Scalar Input > InputDouble**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param step? number default value = `0.0`
///-- @param step_fast? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return number v
pub const InputDouble2 = function(&api.InputDouble2, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?[*:0]const u8, ?c_int });
///-- **Text \& Scalar Input > InputDouble**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param step? number default value = `0.0`
///-- @param step_fast? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return number v
pub const InputDouble3 = function(&api.InputDouble3, 5, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, ?[*:0]const u8, ?c_int });
///-- **Text \& Scalar Input > InputDouble**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v number
///-- @param step? number default value = `0.0`
///-- @param step_fast? number default value = `0.0`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return number v
pub const InputDouble4 = function(&api.InputDouble4, 6, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, ?[*:0]const u8, ?c_int });
///-- **Text \& Scalar Input > InputDoubleN**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param values reaper.array
///-- @param step? number default value = `nil`
///-- @param step_fast? number default value = `nil`
///-- @param format? string default value = `"%.3f"`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
pub const InputDoubleN = function(&api.InputDoubleN, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?f64, ?f64, ?[*:0]const u8, ?c_int });
///-- **Text \& Scalar Input > InputInt**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param step? integer default value = `1`
///-- @param step_fast? integer default value = `100`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const InputInt = function(&api.InputInt, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int, ?c_int, ?c_int });
///-- **Text \& Scalar Input > InputInt**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param step? integer default value = `1`
///-- @param step_fast? integer default value = `100`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const InputInt2 = function(&api.InputInt2, 4, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, ?c_int });
///-- **Text \& Scalar Input > InputInt**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param step? integer default value = `1`
///-- @param step_fast? integer default value = `100`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const InputInt3 = function(&api.InputInt3, 5, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, ?c_int });
///-- **Text \& Scalar Input > InputInt**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param v integer
///-- @param step? integer default value = `1`
///-- @param step_fast? integer default value = `100`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @return boolean retval
///-- @return integer v
pub const InputInt4 = function(&api.InputInt4, 6, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, ?c_int });
///-- **Text \& Scalar Input > InputText**
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param buf string
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @param callback? ImGui_Function default value = `nil`
///-- @return boolean retval
///-- @return string buf
pub const InputText = function(&api.InputText, 4, &.{ ContextPtr, [*:0]const u8, [*]u8, c_int, ?c_int, FunctionPtr });
///-- **Text \& Scalar Input > InputTextMultiline**
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param buf string
///-- @param size_w? number default value = `0.0`
///-- @param size_h? number default value = `0.0`
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @param callback? ImGui_Function default value = `nil`
///-- @return boolean retval
///-- @return string buf
pub const InputTextMultiline = function(&api.InputTextMultiline, 4, &.{ ContextPtr, [*:0]const u8, [*]u8, c_int, ?f64, ?f64, ?c_int, FunctionPtr });
///-- **Text \& Scalar Input > InputTextWithHint**
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param hint string
///-- @param buf string
///-- @param flags? integer default value = `InputTextFlags_None`
///-- @param callback? ImGui_Function default value = `nil`
///-- @return boolean retval
///-- @return string buf
pub const InputTextWithHint = function(&api.InputTextWithHint, 5, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, [*]u8, c_int, ?c_int, FunctionPtr });
///-- **Text Filter > CreateTextFilter**
///--
///-- Valid while used every frame unless attached to a context (see Attach).
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.9
///-- @param default_filter? string default value = `""`
///-- @nodiscard
///-- @return ImGui_TextFilter retval
pub const CreateTextFilter = function(&api.CreateTextFilter, 0, &.{?[*:0]const u8});
///-- **Text Filter > TextFilter\_Clear**
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.5.6
///-- @param filter ImGui_TextFilter
pub const TextFilter_Clear = function(&api.TextFilter_Clear, 1, &.{TextFilterPtr});
///-- **Text Filter > TextFilter\_Draw**
///--
///-- Helper calling InputText+TextFilter_Set
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.5.6
///-- @param filter ImGui_TextFilter
///-- @param ctx ImGui_Context
///-- @param label? string default value = `"Filter (inc,-exc)"`
///-- @param width? number default value = `0.0`
///-- @return boolean retval
pub const TextFilter_Draw = function(&api.TextFilter_Draw, 2, &.{ TextFilterPtr, ContextPtr, ?[*:0]const u8, ?f64 });
///-- **Text Filter > TextFilter\_Get**
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.5.6
///-- @param filter ImGui_TextFilter
///-- @return string retval
pub const TextFilter_Get = function(&api.TextFilter_Get, 1, &.{TextFilterPtr});
///-- **Text Filter > TextFilter\_IsActive**
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.5.6
///-- @param filter ImGui_TextFilter
///-- @return boolean retval
pub const TextFilter_IsActive = function(&api.TextFilter_IsActive, 1, &.{TextFilterPtr});
///-- **Text Filter > TextFilter\_PassFilter**
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.5.6
///-- @param filter ImGui_TextFilter
///-- @param text string
///-- @return boolean retval
pub const TextFilter_PassFilter = function(&api.TextFilter_PassFilter, 2, &.{ TextFilterPtr, [*:0]const u8 });
///-- **Text Filter > TextFilter\_Set**
///--
///-- ---
///--
///-- **Text Filter**
///--
///-- Helper to perform simple filtering on text strings.
///-- In format "aaaaa[,bbbb][,ccccc]".
///--
///-- Filter usage:
///-- - ""         display all lines
///-- - "xxx"      display lines containing "xxx"
///-- - "xxx,yyy"  display lines containing "xxx" or "yyy"
///-- - "-xxx"     hide lines containing "xxx"
///--
///-- ---
///--
///-- @since 0.5.6
///-- @param filter ImGui_TextFilter
///-- @param filter_text string
pub const TextFilter_Set = function(&api.TextFilter_Set, 2, &.{ TextFilterPtr, [*:0]const u8 });
///-- **Tree Node > CollapsingHeader**
///--
///-- Returns true when opened but do not indent nor push into the ID stack
///-- (because of the TreeNodeFlags_NoTreePushOnOpen flag).
///--
///-- This is basically the same as calling TreeNode(label, TreeNodeFlags_CollapsingHeader).
///-- You can remove the _NoTreePushOnOpen flag if you want behavior closer to normal
///-- TreeNode.
///--
///-- When 'visible' is provided: if 'true' display an additional small close button
///-- on upper right of the header which will set the bool to false when clicked,
///-- if 'false' don't display the header.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param p_visible? boolean default value = `nil`
///-- @param flags? integer default value = `TreeNodeFlags_None`
///-- @return boolean retval
///-- @return boolean p_visible
pub const CollapsingHeader = function(&api.CollapsingHeader, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
///-- **Tree Node > GetTreeNodeToLabelSpacing**
///--
///-- Horizontal distance preceding label when using TreeNode*() or Bullet()
///-- == (GetFontSize + StyleVar_FramePadding.x*2) for a regular unframed TreeNode.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetTreeNodeToLabelSpacing = function(&api.GetTreeNodeToLabelSpacing, 1, &.{ContextPtr});
///-- **Tree Node > IsItemToggledOpen**
///--
///-- Was the last item open state toggled? Set by TreeNode.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsItemToggledOpen = function(&api.IsItemToggledOpen, 1, &.{ContextPtr});
///-- **Tree Node > SetNextItemOpen**
///--
///-- Set next TreeNode/CollapsingHeader open state.
///-- Can also be done with the TreeNodeFlags_DefaultOpen flag.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param is_open boolean
///-- @param cond? integer default value = `Cond_Always`
pub const SetNextItemOpen = function(&api.SetNextItemOpen, 2, &.{ ContextPtr, bool, ?c_int });
///-- **Tree Node > TreeNode**
///--
///-- TreeNode functions return true when the node is open, in which case you need
///-- to also call TreePop when you are finished displaying the tree node contents.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param label string
///-- @param flags? integer default value = `TreeNodeFlags_None`
///-- @return boolean retval
pub const TreeNode = function(&api.TreeNode, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
///-- **Tree Node > TreeNodeEx**
///--
///-- Helper variation to easily decorelate the id from the displayed string.
///-- Read the [FAQ](https://dearimgui.com/faq) about why and how to use ID.
///-- To align arbitrary text at the same level as a TreeNode you can use Bullet.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param label string
///-- @param flags? integer default value = `TreeNodeFlags_None`
///-- @return boolean retval
pub const TreeNodeEx = function(&api.TreeNodeEx, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, ?c_int });
///-- **Tree Node > TreePop**
///--
///-- Unindent()+PopID()
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const TreePop = function(&api.TreePop, 1, &.{ContextPtr});
///-- **Tree Node > TreePush**
///--
///-- Indent()+PushID(). Already called by TreeNode when returning true,
///-- but you can call TreePush/TreePop yourself if desired.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
pub const TreePush = function(&api.TreePush, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Utility > GetBuiltinPath**
///--
///-- Returns the path to the directory containing imgui.lua, imgui.py and gfx2imgui.lua.
///--
///-- ---
///--
///-- @since 0.9
///-- @return string retval
pub const GetBuiltinPath = function(&api.GetBuiltinPath, 0, &.{});
///-- **Utility > GetVersion**
///--
///-- ---
///--
///-- @since 0.7
///-- @return string imgui_version
///-- @return integer imgui_version_num
///-- @return string reaimgui_version
pub const GetVersion = function(&api.GetVersion, 5, &.{ [*]u8, c_int, *c_int, [*]u8, c_int });
///-- **Utility > NumericLimits\_Double**
///--
///-- Returns DBL_MIN and DBL_MAX for this system.
///--
///-- ---
///--
///-- @since 0.8.4
///-- @return number min
///-- @return number max
pub const NumericLimits_Double = function(&api.NumericLimits_Double, 2, &.{ *f64, *f64 });
///-- **Utility > NumericLimits\_Float**
///--
///-- Returns FLT_MIN and FLT_MAX for this system.
///--
///-- ---
///--
///-- @since 0.4
///-- @return number min
///-- @return number max
pub const NumericLimits_Float = function(&api.NumericLimits_Float, 2, &.{ *f64, *f64 });
///-- **Utility > NumericLimits\_Int**
///--
///-- Returns INT_MIN and INT_MAX for this system.
///--
///-- ---
///--
///-- @since 0.8.4
///-- @return integer min
///-- @return integer max
pub const NumericLimits_Int = function(&api.NumericLimits_Int, 2, &.{ *c_int, *c_int });
///-- **Utility > PointConvertNative**
///--
///-- Convert a position from the current platform's native coordinate position
///-- system to ReaImGui global coordinates (or vice versa).
///--
///-- This effectively flips the Y coordinate on macOS and applies HiDPI scaling on
///-- Windows and Linux.
///--
///-- ---
///--
///-- @since 0.5.1
///-- @param ctx ImGui_Context
///-- @param x number
///-- @param y number
///-- @param to_native? boolean default value = `false`
///-- @return number x
///-- @return number y
pub const PointConvertNative = function(&api.PointConvertNative, 3, &.{ ContextPtr, *f64, *f64, ?bool });
///-- **Utility > ProgressBar**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param fraction number
///-- @param size_arg_w? number default value = `-FLT_MIN`
///-- @param size_arg_h? number default value = `0.0`
///-- @param overlay? string default value = `nil`
pub const ProgressBar = function(&api.ProgressBar, 2, &.{ ContextPtr, f64, ?f64, ?f64, ?[*:0]const u8 });
///-- **Utility > ValidatePtr**
///--
///-- Return whether the given pointer is a valid instance of one of the following
///-- types (indentation represents inheritance):
///--
///-- - ImGui_Context*
///-- - ImGui_DrawList*
///-- - ImGui_DrawListSplitter*
///-- - ImGui_Font*
///-- - ImGui_Function*
///-- - ImGui_Image*
///--   - ImGui_ImageSet*
///-- - ImGui_ListClipper*
///-- - ImGui_TextFilter*
///-- - ImGui_Viewport*
///--
///-- ---
///--
///-- @since 0.3
///-- @param pointer userdata
///-- @param type string
///-- @return boolean retval
pub const ValidatePtr = function(&api.ValidatePtr, 2, &.{ *anyopaque, [*:0]const u8 });
///-- **Utility > Clipboard > GetClipboardText**
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return string retval
pub const GetClipboardText = function(&api.GetClipboardText, 1, &.{ContextPtr});
///-- **Utility > Clipboard > SetClipboardText**
///--
///-- See also the LogToClipboard function to capture GUI into clipboard,
///-- or easily output text data to the clipboard.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const SetClipboardText = function(&api.SetClipboardText, 2, &.{ ContextPtr, [*:0]const u8 });
pub const ColorConvertDouble4ToU32 = function(&api.ColorConvertDouble4ToU32, 4, &.{ f64, f64, f64, f64 });
///-- **Utility > Color Conversion > ColorConvertHSVtoRGB**
///--
///-- Convert HSV values (0..1) into RGB (0..1).
///--
///-- ---
///--
///-- @since 0.7
///-- @param h number
///-- @param s number
///-- @param v number
///-- @return number r
///-- @return number g
///-- @return number b
pub const ColorConvertHSVtoRGB = function(&api.ColorConvertHSVtoRGB, 6, &.{ f64, f64, f64, *f64, *f64, *f64 });
///-- **Utility > Color Conversion > ColorConvertNative**
///--
///-- Convert a native color coming from REAPER or 0xRRGGBB to native.
///-- This swaps the red and blue channels on Windows.
///--
///-- ---
///--
///-- @since 0.3
///-- @param rgb integer
///-- @return integer retval
pub const ColorConvertNative = function(&api.ColorConvertNative, 1, &.{c_int});
///-- **Utility > Color Conversion > ColorConvertRGBtoHSV**
///--
///-- Convert RGB values (0..1) into HSV (0..1).
///--
///-- ---
///--
///-- @since 0.7
///-- @param r number
///-- @param g number
///-- @param b number
///-- @return number h
///-- @return number s
///-- @return number v
pub const ColorConvertRGBtoHSV = function(&api.ColorConvertRGBtoHSV, 6, &.{ f64, f64, f64, *f64, *f64, *f64 });
pub const ColorConvertU32ToDouble4 = function(&api.ColorConvertU32ToDouble4, 5, &.{ c_int, *f64, *f64, *f64, *f64 });
///-- **Utility > ID Stack\/Scope > PopID**
///--
///-- Pop from the ID stack.
///--
///-- ---
///--
///-- **Utility > ID Stack\/Scope**
///--
///-- Read the [FAQ](https://dearimgui.com/faq) for more details about how IDs are
///-- handled in dear imgui.
///--
///-- - Those questions are answered and impacted by understanding of the ID stack system:
///--   - "Q: Why is my widget not reacting when I click on it?"
///--   - "Q: How can I have widgets with an empty label?"
///--   - "Q: How can I have multiple widgets with the same label?"
///-- - Short version: ID are hashes of the entire ID stack. If you are creating widgets
///--   in a loop you most likely want to push a unique identifier (e.g. object pointer,
///--   loop index) to uniquely differentiate them.
///-- - You can also use the "Label##foobar" syntax within widget label to distinguish
///--   them from each others.
///-- - We use the "label"/"name" terminology to denote a string that will be
///--   displayed + used as an ID, whereas "str_id" denote a string that is only used
///--   as an ID and not normally displayed.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const PopID = function(&api.PopID, 1, &.{ContextPtr});
///-- **Utility > ID Stack\/Scope > PushID**
///--
///-- Push string into the ID stack.
///--
///-- ---
///--
///-- **Utility > ID Stack\/Scope**
///--
///-- Read the [FAQ](https://dearimgui.com/faq) for more details about how IDs are
///-- handled in dear imgui.
///--
///-- - Those questions are answered and impacted by understanding of the ID stack system:
///--   - "Q: Why is my widget not reacting when I click on it?"
///--   - "Q: How can I have widgets with an empty label?"
///--   - "Q: How can I have multiple widgets with the same label?"
///-- - Short version: ID are hashes of the entire ID stack. If you are creating widgets
///--   in a loop you most likely want to push a unique identifier (e.g. object pointer,
///--   loop index) to uniquely differentiate them.
///-- - You can also use the "Label##foobar" syntax within widget label to distinguish
///--   them from each others.
///-- - We use the "label"/"name" terminology to denote a string that will be
///--   displayed + used as an ID, whereas "str_id" denote a string that is only used
///--   as an ID and not normally displayed.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param str_id string
pub const PushID = function(&api.PushID, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Utility > Logging\/Capture > LogFinish**
///--
///-- Stop logging (close file, etc.)
///--
///-- ---
///--
///-- **Utility > Logging\/Capture**
///--
///-- All text output from the interface can be captured into tty/file/clipboard.
///-- By default, tree nodes are automatically opened during logging.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const LogFinish = function(&api.LogFinish, 1, &.{ContextPtr});
///-- **Utility > Logging\/Capture > LogText**
///--
///-- Pass text data straight to log (without being displayed)
///--
///-- ---
///--
///-- **Utility > Logging\/Capture**
///--
///-- All text output from the interface can be captured into tty/file/clipboard.
///-- By default, tree nodes are automatically opened during logging.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param text string
pub const LogText = function(&api.LogText, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Utility > Logging\/Capture > LogToClipboard**
///--
///-- Start logging all text output from the interface to the OS clipboard.
///-- See also SetClipboardText.
///--
///-- ---
///--
///-- **Utility > Logging\/Capture**
///--
///-- All text output from the interface can be captured into tty/file/clipboard.
///-- By default, tree nodes are automatically opened during logging.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param auto_open_depth? integer default value = `-1`
pub const LogToClipboard = function(&api.LogToClipboard, 1, &.{ ContextPtr, ?c_int });
///-- **Utility > Logging\/Capture > LogToFile**
///--
///-- Start logging all text output from the interface to a file.
///-- The data is saved to $resource_path/imgui_log.txt if filename is nil.
///--
///-- ---
///--
///-- **Utility > Logging\/Capture**
///--
///-- All text output from the interface can be captured into tty/file/clipboard.
///-- By default, tree nodes are automatically opened during logging.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param auto_open_depth? integer default value = `-1`
///-- @param filename? string default value = `nil`
pub const LogToFile = function(&api.LogToFile, 1, &.{ ContextPtr, ?c_int, ?[*:0]const u8 });
///-- **Utility > Logging\/Capture > LogToTTY**
///--
///-- Start logging all text output from the interface to the TTY (stdout).
///--
///-- ---
///--
///-- **Utility > Logging\/Capture**
///--
///-- All text output from the interface can be captured into tty/file/clipboard.
///-- By default, tree nodes are automatically opened during logging.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param auto_open_depth? integer default value = `-1`
pub const LogToTTY = function(&api.LogToTTY, 1, &.{ ContextPtr, ?c_int });
///-- **Viewport > GetMainViewport**
///--
///-- Currently represents REAPER's main window (arrange view).
///-- WARNING: This may change or be removed in the future.
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return ImGui_Viewport retval
pub const GetMainViewport = function(&api.GetMainViewport, 1, &.{ContextPtr});
///-- **Viewport > GetWindowViewport**
///--
///-- Get viewport currently associated to the current window.
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @return ImGui_Viewport retval
pub const GetWindowViewport = function(&api.GetWindowViewport, 1, &.{ContextPtr});
///-- **Viewport > Viewport\_GetCenter**
///--
///-- Center of the viewport.
///--
///-- ---
///--
///-- @since 0.1
///-- @param viewport ImGui_Viewport
///-- @return number x
///-- @return number y
pub const Viewport_GetCenter = function(&api.Viewport_GetCenter, 3, &.{ ViewportPtr, *f64, *f64 });
///-- **Viewport > Viewport\_GetPos**
///--
///-- Main Area: Position of the viewport
///--
///-- ---
///--
///-- @since 0.1
///-- @param viewport ImGui_Viewport
///-- @return number x
///-- @return number y
pub const Viewport_GetPos = function(&api.Viewport_GetPos, 3, &.{ ViewportPtr, *f64, *f64 });
///-- **Viewport > Viewport\_GetSize**
///--
///-- Main Area: Size of the viewport.
///--
///-- ---
///--
///-- @since 0.1
///-- @param viewport ImGui_Viewport
///-- @return number w
///-- @return number h
pub const Viewport_GetSize = function(&api.Viewport_GetSize, 3, &.{ ViewportPtr, *f64, *f64 });
///-- **Viewport > Work Area > Viewport\_GetWorkCenter**
///--
///-- Center of the viewport's work area.
///--
///-- ---
///--
///-- **Viewport > Work Area**
///--
///-- Viewport minus task bars, menu bars, status bars
///--
///-- ---
///--
///-- @since 0.1
///-- @param viewport ImGui_Viewport
///-- @return number x
///-- @return number y
pub const Viewport_GetWorkCenter = function(&api.Viewport_GetWorkCenter, 3, &.{ ViewportPtr, *f64, *f64 });
///-- **Viewport > Work Area > Viewport\_GetWorkPos**
///--
///-- >= Viewport_GetPos
///--
///-- ---
///--
///-- **Viewport > Work Area**
///--
///-- Viewport minus task bars, menu bars, status bars
///--
///-- ---
///--
///-- @since 0.1
///-- @param viewport ImGui_Viewport
///-- @return number x
///-- @return number y
pub const Viewport_GetWorkPos = function(&api.Viewport_GetWorkPos, 3, &.{ ViewportPtr, *f64, *f64 });
///-- **Viewport > Work Area > Viewport\_GetWorkSize**
///--
///-- <= Viewport_GetSize
///--
///-- ---
///--
///-- **Viewport > Work Area**
///--
///-- Viewport minus task bars, menu bars, status bars
///--
///-- ---
///--
///-- @since 0.1
///-- @param viewport ImGui_Viewport
///-- @return number w
///-- @return number h
pub const Viewport_GetWorkSize = function(&api.Viewport_GetWorkSize, 3, &.{ ViewportPtr, *f64, *f64 });
///-- **Window > Begin**
///--
///-- Push window to the stack and start appending to it.
///--
///-- - Passing true to 'p_open' shows a window-closing widget in the upper-right
///--   corner of the window, which clicking will set the boolean to false when returned.
///-- - You may append multiple times to the same window during the same frame by
///--   calling Begin()/End() pairs multiple times. Some information such as 'flags'
///--   or 'p_open' will only be considered by the first call to Begin().
///-- - Begin() return false to indicate the window is collapsed or fully clipped,
///--   so you may early out and omit submitting anything to the window.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param name string
///-- @param p_open? boolean default value = `nil`
///-- @param flags? integer default value = `WindowFlags_None`
///-- @nodiscard
///-- @return boolean retval
///-- @return boolean p_open
pub const Begin = function(&api.Begin, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
///-- **Window > End**
///--
///-- Pop window from the stack. See Begin.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
pub const End = function(&api.End, 1, &.{ContextPtr});
///-- **Window > Child Windows > BeginChild**
///--
///-- Manual sizing (each axis can use a different setting e.g. ImVec2(0.0f, 400.0f)):
///-- - = 0.0: use remaining parent window size for this axis
///-- - \> 0.0: use specified size for this axis
///-- - < 0.0: right/bottom-align to specified distance from available content boundaries
///--
///-- Specifying ChildFlags_AutoResizeX or ChildFlags_AutoResizeY makes the sizing
///-- automatic based on child contents.
///--
///-- Combining both ChildFlags_AutoResizeX _and_ ChildFlags_AutoResizeY defeats
///-- purpose of a scrolling region and is NOT recommended.
///--
///-- Returns false to indicate the window is collapsed or fully clipped.
///--
///-- ---
///--
///-- **Window > Child Windows**
///--
///-- Use child windows to begin into a self-contained independent
///-- scrolling/clipping regions within a host window.
///-- Child windows can embed their own child.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param str_id string
///-- @param size_w? number default value = `0.0`
///-- @param size_h? number default value = `0.0`
///-- @param child_flags? integer default value = `ChildFlags_None`
///-- @param window_flags? integer default value = `WindowFlags_None`
///-- @nodiscard
///-- @return boolean retval
pub const BeginChild = function(&api.BeginChild, 2, &.{ ContextPtr, [*:0]const u8, ?f64, ?f64, ?c_int, ?c_int });
///-- **Window > Child Windows > EndChild**
///--
///-- See BeginChild.
///--
///-- ---
///--
///-- **Window > Child Windows**
///--
///-- Use child windows to begin into a self-contained independent
///-- scrolling/clipping regions within a host window.
///-- Child windows can embed their own child.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.8
///-- @param ctx ImGui_Context
pub const EndChild = function(&api.EndChild, 1, &.{ContextPtr});
///-- **Window > Content Region > GetContentRegionAvail**
///--
///-- == GetContentRegionMax() - GetCursorPos()
///--
///-- ---
///--
///-- **Window > Content Region**
///--
///-- Retrieve available space from a given point.
///-- GetContentRegionAvail() is frequently useful.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetContentRegionAvail = function(&api.GetContentRegionAvail, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Window > Content Region > GetContentRegionMax**
///--
///-- Current content boundaries (typically window boundaries including scrolling,
///-- or current column boundaries), in windows coordinates.
///--
///-- ---
///--
///-- **Window > Content Region**
///--
///-- Retrieve available space from a given point.
///-- GetContentRegionAvail() is frequently useful.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetContentRegionMax = function(&api.GetContentRegionMax, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Window > Content Region > GetWindowContentRegionMax**
///--
///-- Content boundaries max (roughly (0,0)+Size-Scroll) where Size can be
///-- overridden with SetNextWindowContentSize, in window coordinates.
///--
///-- ---
///--
///-- **Window > Content Region**
///--
///-- Retrieve available space from a given point.
///-- GetContentRegionAvail() is frequently useful.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetWindowContentRegionMax = function(&api.GetWindowContentRegionMax, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Window > Content Region > GetWindowContentRegionMin**
///--
///-- Content boundaries min (roughly (0,0)-Scroll), in window coordinates.
///--
///-- ---
///--
///-- **Window > Content Region**
///--
///-- Retrieve available space from a given point.
///-- GetContentRegionAvail() is frequently useful.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetWindowContentRegionMin = function(&api.GetWindowContentRegionMin, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Window > Debug Windows > ShowAboutWindow**
///--
///-- Create About window.
///-- Display ReaImGui version, Dear ImGui version, credits and build/system information.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5.4
///-- @param ctx ImGui_Context
///-- @param p_open? boolean default value = `nil`
///-- @return boolean p_open
pub const ShowAboutWindow = function(&api.ShowAboutWindow, 1, &.{ ContextPtr, ?*bool });
///-- **Window > Debug Windows > ShowDebugLogWindow**
///--
///-- Create Debug Log window. display a simplified log of important dear imgui events.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.7
///-- @param ctx ImGui_Context
///-- @param p_open? boolean default value = `nil`
///-- @return boolean p_open
pub const ShowDebugLogWindow = function(&api.ShowDebugLogWindow, 1, &.{ ContextPtr, ?*bool });
///-- **Window > Debug Windows > ShowIDStackToolWindow**
///--
///-- Create Stack Tool window. Hover items with mouse to query information about
///-- the source of their unique ID.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param p_open? boolean default value = `nil`
///-- @return boolean p_open
pub const ShowIDStackToolWindow = function(&api.ShowIDStackToolWindow, 1, &.{ ContextPtr, ?*bool });
///-- **Window > Debug Windows > ShowMetricsWindow**
///--
///-- Create Metrics/Debugger window.
///-- Display Dear ImGui internals: windows, draw commands, various internal state, etc.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param p_open? boolean default value = `nil`
///-- @return boolean p_open
pub const ShowMetricsWindow = function(&api.ShowMetricsWindow, 1, &.{ ContextPtr, ?*bool });
///-- **Window > Docking > GetWindowDockID**
///--
///-- ---
///--
///-- **Window > Docking**
///--
///-- Dock windows into other windows or in REAPER dockers.
///--
///-- Dock IDs are:
///-- - 0 = undocked
///-- - -1 to -16 = REAPER docker index
///-- - \> 0 = Dear ImGui dockspace ID (when the user docked the window into another one).
///--
///-- Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.
///-- Drag from window menu button (upper-left button) to undock an entire node (all windows).
///-- DockingWithShift == true, you instead need to hold SHIFT to _enable_ docking.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @return integer retval
pub const GetWindowDockID = function(&api.GetWindowDockID, 1, &.{ContextPtr});
///-- **Window > Docking > IsWindowDocked**
///--
///-- Is current window docked into another window or a REAPER docker?
///--
///-- ---
///--
///-- **Window > Docking**
///--
///-- Dock windows into other windows or in REAPER dockers.
///--
///-- Dock IDs are:
///-- - 0 = undocked
///-- - -1 to -16 = REAPER docker index
///-- - \> 0 = Dear ImGui dockspace ID (when the user docked the window into another one).
///--
///-- Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.
///-- Drag from window menu button (upper-left button) to undock an entire node (all windows).
///-- DockingWithShift == true, you instead need to hold SHIFT to _enable_ docking.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsWindowDocked = function(&api.IsWindowDocked, 1, &.{ContextPtr});
///-- **Window > Docking > SetNextWindowDockID**
///--
///-- ---
///--
///-- **Window > Docking**
///--
///-- Dock windows into other windows or in REAPER dockers.
///--
///-- Dock IDs are:
///-- - 0 = undocked
///-- - -1 to -16 = REAPER docker index
///-- - \> 0 = Dear ImGui dockspace ID (when the user docked the window into another one).
///--
///-- Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.
///-- Drag from window menu button (upper-left button) to undock an entire node (all windows).
///-- DockingWithShift == true, you instead need to hold SHIFT to _enable_ docking.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param dock_id integer
///-- @param cond? integer default value = `Cond_Always`
pub const SetNextWindowDockID = function(&api.SetNextWindowDockID, 2, &.{ ContextPtr, c_int, ?c_int });
///-- **Window > Properties > GetWindowDpiScale**
///--
///-- Get DPI scale currently associated to the current window's viewport
///-- (1.0 = 96 DPI).
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.7.2
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetWindowDpiScale = function(&api.GetWindowDpiScale, 1, &.{ContextPtr});
///-- **Window > Properties > GetWindowHeight**
///--
///-- Get current window height (shortcut for (GetWindowSize().h).
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetWindowHeight = function(&api.GetWindowHeight, 1, &.{ContextPtr});
///-- **Window > Properties > GetWindowPos**
///--
///-- Get current window position in screen space (note: it is unlikely you need to
///-- use this. Consider using current layout pos instead, GetCursorScreenPos()).
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number x
///-- @return number y
pub const GetWindowPos = function(&api.GetWindowPos, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Window > Properties > GetWindowSize**
///--
///-- Get current window size (note: it is unlikely you need to use this.
///-- Consider using GetCursorScreenPos() and e.g. GetContentRegionAvail() instead)
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number w
///-- @return number h
pub const GetWindowSize = function(&api.GetWindowSize, 3, &.{ ContextPtr, *f64, *f64 });
///-- **Window > Properties > GetWindowWidth**
///--
///-- Get current window width (shortcut for (GetWindowSize().w).
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetWindowWidth = function(&api.GetWindowWidth, 1, &.{ContextPtr});
///-- **Window > Properties > IsWindowAppearing**
///--
///-- Use after Begin/BeginPopup/BeginPopupModal to tell if a window just opened.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return boolean retval
pub const IsWindowAppearing = function(&api.IsWindowAppearing, 1, &.{ContextPtr});
///-- **Window > Properties > IsWindowFocused**
///--
///-- Is current window focused? or its root/child, depending on flags.
///-- See flags for options.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param flags? integer default value = `FocusedFlags_None`
///-- @return boolean retval
pub const IsWindowFocused = function(&api.IsWindowFocused, 1, &.{ ContextPtr, ?c_int });
///-- **Window > Properties > IsWindowHovered**
///--
///-- Is current window hovered and hoverable (e.g. not blocked by a popup/modal)?
///-- See HoveredFlags_* for options.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.9
///-- @param ctx ImGui_Context
///-- @param flags? integer default value = `HoveredFlags_None`
///-- @return boolean retval
pub const IsWindowHovered = function(&api.IsWindowHovered, 1, &.{ ContextPtr, ?c_int });
///-- **Window > Properties > SetNextWindowBgAlpha**
///--
///-- Set next window background color alpha. Helper to easily override the Alpha
///-- component of Col_WindowBg/Col_ChildBg/Col_PopupBg.
///-- You may also use WindowFlags_NoBackground for a fully transparent window.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param alpha number
pub const SetNextWindowBgAlpha = function(&api.SetNextWindowBgAlpha, 2, &.{ ContextPtr, f64 });
///-- **Window > Properties > SetNextWindowCollapsed**
///--
///-- Set next window collapsed state.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param collapsed boolean
///-- @param cond? integer default value = `Cond_Always`
pub const SetNextWindowCollapsed = function(&api.SetNextWindowCollapsed, 2, &.{ ContextPtr, bool, ?c_int });
///-- **Window > Properties > SetNextWindowContentSize**
///--
///-- Set next window content size (~ scrollable client area, which enforce the
///-- range of scrollbars). Not including window decorations (title bar, menu bar,
///-- etc.) nor StyleVar_WindowPadding. set an axis to 0.0 to leave it automatic.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param size_w number
///-- @param size_h number
pub const SetNextWindowContentSize = function(&api.SetNextWindowContentSize, 3, &.{ ContextPtr, f64, f64 });
///-- **Window > Properties > SetNextWindowFocus**
///--
///-- Set next window to be focused / top-most.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
pub const SetNextWindowFocus = function(&api.SetNextWindowFocus, 1, &.{ContextPtr});
///-- **Window > Properties > SetNextWindowPos**
///--
///-- Set next window position. Use pivot=(0.5,0.5) to center on given point, etc.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param pos_x number
///-- @param pos_y number
///-- @param cond? integer default value = `Cond_Always`
///-- @param pivot_x? number default value = `0.0`
///-- @param pivot_y? number default value = `0.0`
pub const SetNextWindowPos = function(&api.SetNextWindowPos, 3, &.{ ContextPtr, f64, f64, ?c_int, ?f64, ?f64 });
///-- **Window > Properties > SetNextWindowScroll**
///--
///-- Set next window scrolling value (use < 0.0 to not affect a given axis).
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param scroll_x number
///-- @param scroll_y number
pub const SetNextWindowScroll = function(&api.SetNextWindowScroll, 3, &.{ ContextPtr, f64, f64 });
///-- **Window > Properties > SetNextWindowSize**
///--
///-- Set next window size. set axis to 0.0 to force an auto-fit on this axis.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param size_w number
///-- @param size_h number
///-- @param cond? integer default value = `Cond_Always`
pub const SetNextWindowSize = function(&api.SetNextWindowSize, 3, &.{ ContextPtr, f64, f64, ?c_int });
///-- **Window > Properties > SetNextWindowSizeConstraints**
///--
///-- Set next window size limits. Use 0.0 or FLT_MAX (second return value of
///-- NumericLimits_Float) if you don't want limits.
///--
///-- Use -1 for both min and max of same axis to preserve current size (which itself
///-- is a constraint).
///--
///-- Use callback to apply non-trivial programmatic constraints.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.8.5
///-- @param ctx ImGui_Context
///-- @param size_min_w number
///-- @param size_min_h number
///-- @param size_max_w number
///-- @param size_max_h number
///-- @param custom_callback? ImGui_Function default value = `nil`
pub const SetNextWindowSizeConstraints = function(&api.SetNextWindowSizeConstraints, 5, &.{ ContextPtr, f64, f64, f64, f64, FunctionPtr });
///-- **Window > Properties > SetWindowCollapsed**
///--
///-- (Not recommended) Set current window collapsed state.
///-- Prefer using SetNextWindowCollapsed.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param collapsed boolean
///-- @param cond? integer default value = `Cond_Always`
pub const SetWindowCollapsed = function(&api.SetWindowCollapsed, 2, &.{ ContextPtr, bool, ?c_int });
///-- **Window > Properties > SetWindowCollapsedEx**
///--
///-- Set named window collapsed state.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param name string
///-- @param collapsed boolean
///-- @param cond? integer default value = `Cond_Always`
pub const SetWindowCollapsedEx = function(&api.SetWindowCollapsedEx, 3, &.{ ContextPtr, [*:0]const u8, bool, ?c_int });
///-- **Window > Properties > SetWindowFocus**
///--
///-- (Not recommended) Set current window to be focused / top-most.
///-- Prefer using SetNextWindowFocus.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
pub const SetWindowFocus = function(&api.SetWindowFocus, 1, &.{ContextPtr});
///-- **Window > Properties > SetWindowFocusEx**
///--
///-- Set named window to be focused / top-most. Use an empty name to remove focus.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param name string
pub const SetWindowFocusEx = function(&api.SetWindowFocusEx, 2, &.{ ContextPtr, [*:0]const u8 });
///-- **Window > Properties > SetWindowPos**
///--
///-- (Not recommended) Set current window position - call within Begin/End.
///-- Prefer using SetNextWindowPos, as this may incur tearing and minor side-effects.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param pos_x number
///-- @param pos_y number
///-- @param cond? integer default value = `Cond_Always`
pub const SetWindowPos = function(&api.SetWindowPos, 3, &.{ ContextPtr, f64, f64, ?c_int });
///-- **Window > Properties > SetWindowPosEx**
///--
///-- Set named window position.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param name string
///-- @param pos_x number
///-- @param pos_y number
///-- @param cond? integer default value = `Cond_Always`
pub const SetWindowPosEx = function(&api.SetWindowPosEx, 4, &.{ ContextPtr, [*:0]const u8, f64, f64, ?c_int });
///-- **Window > Properties > SetWindowSize**
///--
///-- (Not recommended) Set current window size - call within Begin/End.
///-- Set size_w and size_h to 0 to force an auto-fit.
///-- Prefer using SetNextWindowSize, as this may incur tearing and minor side-effects.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param size_w number
///-- @param size_h number
///-- @param cond? integer default value = `Cond_Always`
pub const SetWindowSize = function(&api.SetWindowSize, 3, &.{ ContextPtr, f64, f64, ?c_int });
///-- **Window > Properties > SetWindowSizeEx**
///--
///-- Set named window size. Set axis to 0.0 to force an auto-fit on this axis.
///--
///-- ---
///--
///-- **Window > Properties**
///--
///-- Prefer using SetNextWindow* functions (before Begin) rather that SetWindow* functions
///-- (after Begin).
///--
///-- 'Current window' = the window we are appending into while inside a Begin()/End()
///-- block. 'Next window' = next window we will Begin() into.
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.5
///-- @param ctx ImGui_Context
///-- @param name string
///-- @param size_w number
///-- @param size_h number
///-- @param cond? integer default value = `Cond_Always`
pub const SetWindowSizeEx = function(&api.SetWindowSizeEx, 4, &.{ ContextPtr, [*:0]const u8, f64, f64, ?c_int });
///-- **Window > Scrolling > GetScrollMaxX**
///--
///-- Get maximum scrolling amount ~~ ContentSize.x - WindowSize.x - DecorationsSize.x
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetScrollMaxX = function(&api.GetScrollMaxX, 1, &.{ContextPtr});
///-- **Window > Scrolling > GetScrollMaxY**
///--
///-- Get maximum scrolling amount ~~ ContentSize.y - WindowSize.y - DecorationsSize.y
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetScrollMaxY = function(&api.GetScrollMaxY, 1, &.{ContextPtr});
///-- **Window > Scrolling > GetScrollX**
///--
///-- Get scrolling amount [0 .. GetScrollMaxX()]
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetScrollX = function(&api.GetScrollX, 1, &.{ContextPtr});
///-- **Window > Scrolling > GetScrollY**
///--
///-- Get scrolling amount [0 .. GetScrollMaxY()]
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @return number retval
pub const GetScrollY = function(&api.GetScrollY, 1, &.{ContextPtr});
///-- **Window > Scrolling > SetScrollFromPosX**
///--
///-- Adjust scrolling amount to make given position visible.
///-- Generally GetCursorStartPos() + offset to compute a valid position.
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param local_x number
///-- @param center_x_ratio? number default value = `0.5`
pub const SetScrollFromPosX = function(&api.SetScrollFromPosX, 2, &.{ ContextPtr, f64, ?f64 });
///-- **Window > Scrolling > SetScrollFromPosY**
///--
///-- Adjust scrolling amount to make given position visible.
///-- Generally GetCursorStartPos() + offset to compute a valid position.
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param local_y number
///-- @param center_y_ratio? number default value = `0.5`
pub const SetScrollFromPosY = function(&api.SetScrollFromPosY, 2, &.{ ContextPtr, f64, ?f64 });
///-- **Window > Scrolling > SetScrollHereX**
///--
///-- Adjust scrolling amount to make current cursor position visible.
///-- center_x_ratio=0.0: left, 0.5: center, 1.0: right.
///-- When using to make a "default/current item" visible,
///-- consider using SetItemDefaultFocus instead.
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param center_x_ratio? number default value = `0.5`
pub const SetScrollHereX = function(&api.SetScrollHereX, 1, &.{ ContextPtr, ?f64 });
///-- **Window > Scrolling > SetScrollHereY**
///--
///-- Adjust scrolling amount to make current cursor position visible.
///-- center_y_ratio=0.0: top, 0.5: center, 1.0: bottom.
///-- When using to make a "default/current item" visible,
///-- consider using SetItemDefaultFocus instead.
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param center_y_ratio? number default value = `0.5`
pub const SetScrollHereY = function(&api.SetScrollHereY, 1, &.{ ContextPtr, ?f64 });
///-- **Window > Scrolling > SetScrollX**
///--
///-- Set scrolling amount [0 .. GetScrollMaxX()]
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param scroll_x number
pub const SetScrollX = function(&api.SetScrollX, 2, &.{ ContextPtr, f64 });
///-- **Window > Scrolling > SetScrollY**
///--
///-- Set scrolling amount [0 .. GetScrollMaxY()]
///--
///-- ---
///--
///-- **Window > Scrolling**
///--
///-- Any change of Scroll will be applied at the beginning of next frame in the
///-- first call to Begin().
///--
///-- You may instead use SetNextWindowScroll() prior to calling Begin() to avoid this
///-- delay, as an alternative to using SetScrollX()/SetScrollY().
///--
///-- ---
///--
///-- **Window**
///--
///-- Functions for creating and manipulating windows.
///-- Note that the bottom of the window stack always contains a window called "Debug".
///--
///-- ---
///--
///-- @since 0.1
///-- @param ctx ImGui_Context
///-- @param scroll_y number
pub const SetScrollY = function(&api.SetScrollY, 2, &.{ ContextPtr, f64 });

var getError: ?*fn () callconv(.C) ?[*:0]const u8 = undefined;

inline fn checkError() Error!void {
    @setRuntimeSafety(false);
    last_error = getError.?();
    if (last_error != null)
        return error.ImGui;
}

inline fn getEnum(func: ?*fn () callconv(.C) c_int) c_int {
    return if (func) |f| f() else 0;
}

pub fn init(plugin_getapi: *fn (name: [*:0]const u8) callconv(.C) ?*anyopaque) !void {
    @setEvalBranchQuota(0x1000);
    @setRuntimeSafety(false);

    const getFunc: ?*fn (v: [*:0]const u8, n: [*:0]const u8) *anyopaque =
        @alignCast(@ptrCast(plugin_getapi("ImGui__getapi")));
    getError = @alignCast(@ptrCast(plugin_getapi("ImGui__geterr")));

    if (getFunc == null or getError == null) {
        last_error = "ReaImGui is not installed or too old";
        return error.ImGui;
    }

    inline for (@typeInfo(API).Struct.fields) |field| {
        @field(api, field.name) = @alignCast(@ptrCast(getFunc.?(api_version, field.name)));
        try checkError();
    }

    inline for (@typeInfo(API).Struct.decls) |decl| {
        @field(API, decl.name) = getEnum(@alignCast(@ptrCast(getFunc.?(api_version, decl.name))));
        try checkError();
    }
}

fn funcType(comptime func: anytype) type {
    return @typeInfo(@TypeOf(func.*)).Pointer.child;
}

fn returnType(comptime func: anytype) type {
    return Error!@typeInfo(funcType(func)).Fn.return_type.?;
}

fn function(comptime func: anytype, min_argc: comptime_int, comptime arg_types: []const type) fn (args: anytype) callconv(.Inline) returnType(func) {
    return struct {
        inline fn wrapper(args: anytype) returnType(func) {
            var cast_args: std.meta.Tuple(arg_types) = undefined;
            if (args.len < min_argc) {
                @compileError(std.fmt.comptimePrint("expected {}..{} arguments, got {}", .{ min_argc, cast_args.len, args.len }));
            }
            inline for (0..cast_args.len) |i| {
                if (i >= args.len) {
                    cast_args[i] = null;
                    continue;
                }
                const arg_type = @typeInfo(@TypeOf(args[i]));
                comptime var cast_arg_type = @typeInfo(@TypeOf(cast_args[i]));
                if (cast_arg_type == .Optional)
                    cast_arg_type = @typeInfo(cast_arg_type.Optional.child);
                cast_args[i] = if (cast_arg_type == .Int and ((arg_type == .ComptimeInt and args[i] > std.math.maxInt(c_int)) or
                    (arg_type == .Int and arg_type.Int.signedness == .unsigned)))
                    @bitCast(@as(c_uint, args[i]))
                else
                    args[i];
            }

            var call_args: std.meta.ArgsTuple(funcType(func)) = undefined;
            inline for (0..call_args.len) |i| {
                const cast_arg_type = @typeInfo(@TypeOf(cast_args[i]));
                call_args[i] =
                    if (cast_arg_type == .Optional)
                    if (cast_args[i]) |*arg_val|
                        if (@typeInfo(cast_arg_type.Optional.child) == .Pointer)
                            arg_val.*
                        else
                            arg_val
                    else
                        null
                else
                    cast_args[i];
            }

            const rv = @call(.auto, func.*, call_args);
            try checkError();
            return rv;
        }
    }.wrapper;
}
