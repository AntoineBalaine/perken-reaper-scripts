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

pub const ArrowButton = function(&api.ArrowButton, 3, &.{ ContextPtr, [*:0]const u8, c_int });
pub const Button = function(&api.Button, 2, &.{ ContextPtr, [*:0]const u8, ?f64, ?f64 });
pub const Checkbox = function(&api.Checkbox, 3, &.{ ContextPtr, [*:0]const u8, *bool });
pub const CheckboxFlags = function(&api.CheckboxFlags, 4, &.{ ContextPtr, [*:0]const u8, *c_int, c_int });
pub const InvisibleButton = function(&api.InvisibleButton, 4, &.{ ContextPtr, [*:0]const u8, f64, f64, ?c_int });
pub const PopButtonRepeat = function(&api.PopButtonRepeat, 1, &.{ContextPtr});
pub const PushButtonRepeat = function(&api.PushButtonRepeat, 2, &.{ ContextPtr, bool });
pub const RadioButton = function(&api.RadioButton, 3, &.{ ContextPtr, [*:0]const u8, bool });
pub const RadioButtonEx = function(&api.RadioButtonEx, 4, &.{ ContextPtr, [*:0]const u8, *c_int, c_int });
pub const SmallButton = function(&api.SmallButton, 2, &.{ ContextPtr, [*:0]const u8 });
pub const ColorButton = function(&api.ColorButton, 3, &.{ ContextPtr, [*:0]const u8, c_int, ?c_int, ?f64, ?f64 });
pub const ColorEdit3 = function(&api.ColorEdit3, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int });
pub const ColorEdit4 = function(&api.ColorEdit4, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int });
pub const ColorPicker3 = function(&api.ColorPicker3, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int });
pub const ColorPicker4 = function(&api.ColorPicker4, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int, ?c_int });
pub const SetColorEditOptions = function(&api.SetColorEditOptions, 2, &.{ ContextPtr, c_int });
pub const BeginCombo = function(&api.BeginCombo, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, ?c_int });
pub const Combo = function(&api.Combo, 5, &.{ ContextPtr, [*:0]const u8, *c_int, [*:0]const u8, c_int, ?c_int });
pub const EndCombo = function(&api.EndCombo, 1, &.{ContextPtr});
pub const BeginListBox = function(&api.BeginListBox, 2, &.{ ContextPtr, [*:0]const u8, ?f64, ?f64 });
pub const EndListBox = function(&api.EndListBox, 1, &.{ContextPtr});
pub const ListBox = function(&api.ListBox, 5, &.{ ContextPtr, [*:0]const u8, *c_int, [*:0]const u8, c_int, ?c_int });
pub const Selectable = function(&api.Selectable, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int, ?f64, ?f64 });
pub const Attach = function(&api.Attach, 2, &.{ ContextPtr, ResourcePtr });
pub const CreateContext = function(&api.CreateContext, 1, &.{ [*:0]const u8, ?c_int });
pub const Detach = function(&api.Detach, 2, &.{ ContextPtr, ResourcePtr });
pub const GetDeltaTime = function(&api.GetDeltaTime, 1, &.{ContextPtr});
pub const GetFrameCount = function(&api.GetFrameCount, 1, &.{ContextPtr});
pub const GetFramerate = function(&api.GetFramerate, 1, &.{ContextPtr});
pub const GetTime = function(&api.GetTime, 1, &.{ContextPtr});
pub const GetConfigVar = function(&api.GetConfigVar, 2, &.{ ContextPtr, c_int });
pub const SetConfigVar = function(&api.SetConfigVar, 3, &.{ ContextPtr, c_int, f64 });
pub const AcceptDragDropPayload = function(&api.AcceptDragDropPayload, 4, &.{ ContextPtr, [*:0]const u8, [*]u8, c_int, ?c_int });
pub const AcceptDragDropPayloadFiles = function(&api.AcceptDragDropPayloadFiles, 2, &.{ ContextPtr, *c_int, ?c_int });
pub const AcceptDragDropPayloadRGB = function(&api.AcceptDragDropPayloadRGB, 2, &.{ ContextPtr, *c_int, ?c_int });
pub const AcceptDragDropPayloadRGBA = function(&api.AcceptDragDropPayloadRGBA, 2, &.{ ContextPtr, *c_int, ?c_int });
pub const BeginDragDropSource = function(&api.BeginDragDropSource, 1, &.{ ContextPtr, ?c_int });
pub const BeginDragDropTarget = function(&api.BeginDragDropTarget, 1, &.{ContextPtr});
pub const EndDragDropSource = function(&api.EndDragDropSource, 1, &.{ContextPtr});
pub const EndDragDropTarget = function(&api.EndDragDropTarget, 1, &.{ContextPtr});
pub const GetDragDropPayload = function(&api.GetDragDropPayload, 7, &.{ ContextPtr, [*]u8, c_int, [*]u8, c_int, *bool, *bool });
pub const GetDragDropPayloadFile = function(&api.GetDragDropPayloadFile, 4, &.{ ContextPtr, c_int, [*]u8, c_int });
pub const SetDragDropPayload = function(&api.SetDragDropPayload, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, ?c_int });
pub const DragDouble = function(&api.DragDouble, 3, &.{ ContextPtr, [*:0]const u8, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const DragDouble2 = function(&api.DragDouble2, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const DragDouble3 = function(&api.DragDouble3, 5, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const DragDouble4 = function(&api.DragDouble4, 6, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const DragDoubleN = function(&api.DragDoubleN, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const DragFloatRange2 = function(&api.DragFloatRange2, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?f64, ?f64, ?f64, ?[*:0]const u8, ?[*:0]const u8, ?c_int });
pub const DragInt = function(&api.DragInt, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
pub const DragInt2 = function(&api.DragInt2, 4, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
pub const DragInt3 = function(&api.DragInt3, 5, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
pub const DragInt4 = function(&api.DragInt4, 6, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?c_int });
pub const DragIntRange2 = function(&api.DragIntRange2, 4, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, ?f64, ?c_int, ?c_int, ?[*:0]const u8, ?[*:0]const u8, ?c_int });
pub const SliderAngle = function(&api.SliderAngle, 3, &.{ ContextPtr, [*:0]const u8, *f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const SliderDouble = function(&api.SliderDouble, 5, &.{ ContextPtr, [*:0]const u8, *f64, f64, f64, ?[*:0]const u8, ?c_int });
pub const SliderDouble2 = function(&api.SliderDouble2, 6, &.{ ContextPtr, [*:0]const u8, *f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
pub const SliderDouble3 = function(&api.SliderDouble3, 7, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
pub const SliderDouble4 = function(&api.SliderDouble4, 8, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
pub const SliderDoubleN = function(&api.SliderDoubleN, 5, &.{ ContextPtr, [*:0]const u8, *reaper_array, f64, f64, ?[*:0]const u8, ?c_int });
pub const SliderInt = function(&api.SliderInt, 5, &.{ ContextPtr, [*:0]const u8, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
pub const SliderInt2 = function(&api.SliderInt2, 6, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
pub const SliderInt3 = function(&api.SliderInt3, 7, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
pub const SliderInt4 = function(&api.SliderInt4, 8, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
pub const VSliderDouble = function(&api.VSliderDouble, 7, &.{ ContextPtr, [*:0]const u8, f64, f64, *f64, f64, f64, ?[*:0]const u8, ?c_int });
pub const VSliderInt = function(&api.VSliderInt, 7, &.{ ContextPtr, [*:0]const u8, f64, f64, *c_int, c_int, c_int, ?[*:0]const u8, ?c_int });
pub const DrawList_PopClipRect = function(&api.DrawList_PopClipRect, 1, &.{DrawListPtr});
pub const DrawList_PushClipRect = function(&api.DrawList_PushClipRect, 5, &.{ DrawListPtr, f64, f64, f64, f64, ?bool });
pub const DrawList_PushClipRectFullScreen = function(&api.DrawList_PushClipRectFullScreen, 1, &.{DrawListPtr});
pub const GetBackgroundDrawList = function(&api.GetBackgroundDrawList, 1, &.{ContextPtr});
pub const GetForegroundDrawList = function(&api.GetForegroundDrawList, 1, &.{ContextPtr});
pub const GetWindowDrawList = function(&api.GetWindowDrawList, 1, &.{ContextPtr});
pub const DrawList_AddBezierCubic = function(&api.DrawList_AddBezierCubic, 11, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, f64, ?c_int });
pub const DrawList_AddBezierQuadratic = function(&api.DrawList_AddBezierQuadratic, 9, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, f64, ?c_int });
pub const DrawList_AddCircle = function(&api.DrawList_AddCircle, 5, &.{ DrawListPtr, f64, f64, f64, c_int, ?c_int, ?f64 });
pub const DrawList_AddCircleFilled = function(&api.DrawList_AddCircleFilled, 5, &.{ DrawListPtr, f64, f64, f64, c_int, ?c_int });
pub const DrawList_AddConcavePolyFilled = function(&api.DrawList_AddConcavePolyFilled, 3, &.{ DrawListPtr, *reaper_array, c_int });
pub const DrawList_AddConvexPolyFilled = function(&api.DrawList_AddConvexPolyFilled, 3, &.{ DrawListPtr, *reaper_array, c_int });
pub const DrawList_AddEllipse = function(&api.DrawList_AddEllipse, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int, ?f64 });
pub const DrawList_AddEllipseFilled = function(&api.DrawList_AddEllipseFilled, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int });
pub const DrawList_AddImage = function(&api.DrawList_AddImage, 6, &.{ DrawListPtr, ImagePtr, f64, f64, f64, f64, ?f64, ?f64, ?f64, ?f64, ?c_int });
pub const DrawList_AddImageQuad = function(&api.DrawList_AddImageQuad, 10, &.{ DrawListPtr, ImagePtr, f64, f64, f64, f64, f64, f64, f64, f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?f64, ?c_int });
pub const DrawList_AddImageRounded = function(&api.DrawList_AddImageRounded, 12, &.{ DrawListPtr, ImagePtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, f64, ?c_int });
pub const DrawList_AddLine = function(&api.DrawList_AddLine, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64 });
pub const DrawList_AddNgon = function(&api.DrawList_AddNgon, 6, &.{ DrawListPtr, f64, f64, f64, c_int, c_int, ?f64 });
pub const DrawList_AddNgonFilled = function(&api.DrawList_AddNgonFilled, 6, &.{ DrawListPtr, f64, f64, f64, c_int, c_int });
pub const DrawList_AddPolyline = function(&api.DrawList_AddPolyline, 5, &.{ DrawListPtr, *reaper_array, c_int, c_int, f64 });
pub const DrawList_AddQuad = function(&api.DrawList_AddQuad, 10, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int, ?f64 });
pub const DrawList_AddQuadFilled = function(&api.DrawList_AddQuadFilled, 10, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, f64, c_int });
pub const DrawList_AddRect = function(&api.DrawList_AddRect, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int, ?f64 });
pub const DrawList_AddRectFilled = function(&api.DrawList_AddRectFilled, 6, &.{ DrawListPtr, f64, f64, f64, f64, c_int, ?f64, ?c_int });
pub const DrawList_AddRectFilledMultiColor = function(&api.DrawList_AddRectFilledMultiColor, 9, &.{ DrawListPtr, f64, f64, f64, f64, c_int, c_int, c_int, c_int });
pub const DrawList_AddText = function(&api.DrawList_AddText, 5, &.{ DrawListPtr, f64, f64, c_int, [*:0]const u8 });
pub const DrawList_AddTextEx = function(&api.DrawList_AddTextEx, 7, &.{ DrawListPtr, FontPtr, f64, f64, f64, c_int, [*:0]const u8, ?f64, ?f64, ?f64, ?f64, ?f64 });
pub const DrawList_AddTriangle = function(&api.DrawList_AddTriangle, 8, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, ?f64 });
pub const DrawList_AddTriangleFilled = function(&api.DrawList_AddTriangleFilled, 8, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, c_int });
pub const CreateDrawListSplitter = function(&api.CreateDrawListSplitter, 1, &.{DrawListPtr});
pub const DrawListSplitter_Clear = function(&api.DrawListSplitter_Clear, 1, &.{DrawListSplitterPtr});
pub const DrawListSplitter_Merge = function(&api.DrawListSplitter_Merge, 1, &.{DrawListSplitterPtr});
pub const DrawListSplitter_SetCurrentChannel = function(&api.DrawListSplitter_SetCurrentChannel, 2, &.{ DrawListSplitterPtr, c_int });
pub const DrawListSplitter_Split = function(&api.DrawListSplitter_Split, 2, &.{ DrawListSplitterPtr, c_int });
pub const DrawList_PathArcTo = function(&api.DrawList_PathArcTo, 6, &.{ DrawListPtr, f64, f64, f64, f64, f64, ?c_int });
pub const DrawList_PathArcToFast = function(&api.DrawList_PathArcToFast, 6, &.{ DrawListPtr, f64, f64, f64, c_int, c_int });
pub const DrawList_PathBezierCubicCurveTo = function(&api.DrawList_PathBezierCubicCurveTo, 7, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, ?c_int });
pub const DrawList_PathBezierQuadraticCurveTo = function(&api.DrawList_PathBezierQuadraticCurveTo, 5, &.{ DrawListPtr, f64, f64, f64, f64, ?c_int });
pub const DrawList_PathClear = function(&api.DrawList_PathClear, 1, &.{DrawListPtr});
pub const DrawList_PathEllipticalArcTo = function(&api.DrawList_PathEllipticalArcTo, 8, &.{ DrawListPtr, f64, f64, f64, f64, f64, f64, f64, ?c_int });
pub const DrawList_PathFillConcave = function(&api.DrawList_PathFillConcave, 2, &.{ DrawListPtr, c_int });
pub const DrawList_PathFillConvex = function(&api.DrawList_PathFillConvex, 2, &.{ DrawListPtr, c_int });
pub const DrawList_PathLineTo = function(&api.DrawList_PathLineTo, 3, &.{ DrawListPtr, f64, f64 });
pub const DrawList_PathRect = function(&api.DrawList_PathRect, 5, &.{ DrawListPtr, f64, f64, f64, f64, ?f64, ?c_int });
pub const DrawList_PathStroke = function(&api.DrawList_PathStroke, 2, &.{ DrawListPtr, c_int, ?c_int, ?f64 });
pub const CreateFont = function(&api.CreateFont, 2, &.{ [*:0]const u8, c_int, ?c_int });
pub const GetFont = function(&api.GetFont, 1, &.{ContextPtr});
pub const GetFontSize = function(&api.GetFontSize, 1, &.{ContextPtr});
pub const PopFont = function(&api.PopFont, 1, &.{ContextPtr});
pub const PushFont = function(&api.PushFont, 2, &.{ ContextPtr, FontPtr });
pub const CreateFunctionFromEEL = function(&api.CreateFunctionFromEEL, 1, &.{[*:0]const u8});
pub const Function_Execute = function(&api.Function_Execute, 1, &.{FunctionPtr});
pub const Function_GetValue = function(&api.Function_GetValue, 2, &.{ FunctionPtr, [*:0]const u8 });
pub const Function_GetValue_Array = function(&api.Function_GetValue_Array, 3, &.{ FunctionPtr, [*:0]const u8, *reaper_array });
pub const Function_GetValue_String = function(&api.Function_GetValue_String, 4, &.{ FunctionPtr, [*:0]const u8, [*]u8, c_int });
pub const Function_SetValue = function(&api.Function_SetValue, 3, &.{ FunctionPtr, [*:0]const u8, f64 });
pub const Function_SetValue_Array = function(&api.Function_SetValue_Array, 3, &.{ FunctionPtr, [*:0]const u8, *reaper_array });
pub const Function_SetValue_String = function(&api.Function_SetValue_String, 4, &.{ FunctionPtr, [*:0]const u8, [*:0]const u8, c_int });
pub const CreateImage = function(&api.CreateImage, 1, &.{ [*:0]const u8, ?c_int });
pub const CreateImageFromMem = function(&api.CreateImageFromMem, 2, &.{ [*:0]const u8, c_int });
pub const Image = function(&api.Image, 4, &.{ ContextPtr, ImagePtr, f64, f64, ?f64, ?f64, ?f64, ?f64, ?c_int, ?c_int });
pub const ImageButton = function(&api.ImageButton, 5, &.{ ContextPtr, [*:0]const u8, ImagePtr, f64, f64, ?f64, ?f64, ?f64, ?f64, ?c_int, ?c_int });
pub const Image_GetSize = function(&api.Image_GetSize, 3, &.{ ImagePtr, *f64, *f64 });
pub const CreateImageSet = function(&api.CreateImageSet, 0, &.{});
pub const ImageSet_Add = function(&api.ImageSet_Add, 3, &.{ ImageSetPtr, f64, ImagePtr });
pub const BeginDisabled = function(&api.BeginDisabled, 1, &.{ ContextPtr, ?bool });
pub const DebugStartItemPicker = function(&api.DebugStartItemPicker, 1, &.{ContextPtr});
pub const EndDisabled = function(&api.EndDisabled, 1, &.{ContextPtr});
pub const SetNextItemAllowOverlap = function(&api.SetNextItemAllowOverlap, 1, &.{ContextPtr});
pub const CalcItemWidth = function(&api.CalcItemWidth, 1, &.{ContextPtr});
pub const GetItemRectMax = function(&api.GetItemRectMax, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetItemRectMin = function(&api.GetItemRectMin, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetItemRectSize = function(&api.GetItemRectSize, 3, &.{ ContextPtr, *f64, *f64 });
pub const PopItemWidth = function(&api.PopItemWidth, 1, &.{ContextPtr});
pub const PushItemWidth = function(&api.PushItemWidth, 2, &.{ ContextPtr, f64 });
pub const SetNextItemWidth = function(&api.SetNextItemWidth, 2, &.{ ContextPtr, f64 });
pub const PopTabStop = function(&api.PopTabStop, 1, &.{ContextPtr});
pub const PushTabStop = function(&api.PushTabStop, 2, &.{ ContextPtr, bool });
pub const SetItemDefaultFocus = function(&api.SetItemDefaultFocus, 1, &.{ContextPtr});
pub const SetKeyboardFocusHere = function(&api.SetKeyboardFocusHere, 1, &.{ ContextPtr, ?c_int });
pub const IsAnyItemActive = function(&api.IsAnyItemActive, 1, &.{ContextPtr});
pub const IsAnyItemFocused = function(&api.IsAnyItemFocused, 1, &.{ContextPtr});
pub const IsAnyItemHovered = function(&api.IsAnyItemHovered, 1, &.{ContextPtr});
pub const IsItemActivated = function(&api.IsItemActivated, 1, &.{ContextPtr});
pub const IsItemActive = function(&api.IsItemActive, 1, &.{ContextPtr});
pub const IsItemClicked = function(&api.IsItemClicked, 1, &.{ ContextPtr, ?c_int });
pub const IsItemDeactivated = function(&api.IsItemDeactivated, 1, &.{ContextPtr});
pub const IsItemDeactivatedAfterEdit = function(&api.IsItemDeactivatedAfterEdit, 1, &.{ContextPtr});
pub const IsItemEdited = function(&api.IsItemEdited, 1, &.{ContextPtr});
pub const IsItemFocused = function(&api.IsItemFocused, 1, &.{ContextPtr});
pub const IsItemHovered = function(&api.IsItemHovered, 1, &.{ ContextPtr, ?c_int });
pub const IsItemVisible = function(&api.IsItemVisible, 1, &.{ContextPtr});
pub const GetInputQueueCharacter = function(&api.GetInputQueueCharacter, 3, &.{ ContextPtr, c_int, *c_int });
pub const GetKeyDownDuration = function(&api.GetKeyDownDuration, 2, &.{ ContextPtr, c_int });
pub const GetKeyMods = function(&api.GetKeyMods, 1, &.{ContextPtr});
pub const GetKeyPressedAmount = function(&api.GetKeyPressedAmount, 4, &.{ ContextPtr, c_int, f64, f64 });
pub const IsKeyChordPressed = function(&api.IsKeyChordPressed, 2, &.{ ContextPtr, c_int });
pub const IsKeyDown = function(&api.IsKeyDown, 2, &.{ ContextPtr, c_int });
pub const IsKeyPressed = function(&api.IsKeyPressed, 2, &.{ ContextPtr, c_int, ?bool });
pub const IsKeyReleased = function(&api.IsKeyReleased, 2, &.{ ContextPtr, c_int });
pub const SetNextFrameWantCaptureKeyboard = function(&api.SetNextFrameWantCaptureKeyboard, 2, &.{ ContextPtr, bool });
pub const GetMouseClickedCount = function(&api.GetMouseClickedCount, 2, &.{ ContextPtr, c_int });
pub const GetMouseClickedPos = function(&api.GetMouseClickedPos, 4, &.{ ContextPtr, c_int, *f64, *f64 });
pub const GetMouseDelta = function(&api.GetMouseDelta, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetMouseDownDuration = function(&api.GetMouseDownDuration, 2, &.{ ContextPtr, c_int });
pub const GetMouseDragDelta = function(&api.GetMouseDragDelta, 3, &.{ ContextPtr, *f64, *f64, ?c_int, ?f64 });
pub const GetMousePos = function(&api.GetMousePos, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetMousePosOnOpeningCurrentPopup = function(&api.GetMousePosOnOpeningCurrentPopup, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetMouseWheel = function(&api.GetMouseWheel, 3, &.{ ContextPtr, *f64, *f64 });
pub const IsAnyMouseDown = function(&api.IsAnyMouseDown, 1, &.{ContextPtr});
pub const IsMouseClicked = function(&api.IsMouseClicked, 2, &.{ ContextPtr, c_int, ?bool });
pub const IsMouseDoubleClicked = function(&api.IsMouseDoubleClicked, 2, &.{ ContextPtr, c_int });
pub const IsMouseDown = function(&api.IsMouseDown, 2, &.{ ContextPtr, c_int });
pub const IsMouseDragging = function(&api.IsMouseDragging, 2, &.{ ContextPtr, c_int, ?f64 });
pub const IsMouseHoveringRect = function(&api.IsMouseHoveringRect, 5, &.{ ContextPtr, f64, f64, f64, f64, ?bool });
pub const IsMousePosValid = function(&api.IsMousePosValid, 1, &.{ ContextPtr, ?f64, ?f64 });
pub const IsMouseReleased = function(&api.IsMouseReleased, 2, &.{ ContextPtr, c_int });
pub const ResetMouseDragDelta = function(&api.ResetMouseDragDelta, 1, &.{ ContextPtr, ?c_int });
pub const GetMouseCursor = function(&api.GetMouseCursor, 1, &.{ContextPtr});
pub const SetMouseCursor = function(&api.SetMouseCursor, 2, &.{ ContextPtr, c_int });
pub const BeginGroup = function(&api.BeginGroup, 1, &.{ContextPtr});
pub const Dummy = function(&api.Dummy, 3, &.{ ContextPtr, f64, f64 });
pub const EndGroup = function(&api.EndGroup, 1, &.{ContextPtr});
pub const Indent = function(&api.Indent, 1, &.{ ContextPtr, ?f64 });
pub const NewLine = function(&api.NewLine, 1, &.{ContextPtr});
pub const SameLine = function(&api.SameLine, 1, &.{ ContextPtr, ?f64, ?f64 });
pub const Separator = function(&api.Separator, 1, &.{ContextPtr});
pub const SeparatorText = function(&api.SeparatorText, 2, &.{ ContextPtr, [*:0]const u8 });
pub const Spacing = function(&api.Spacing, 1, &.{ContextPtr});
pub const Unindent = function(&api.Unindent, 1, &.{ ContextPtr, ?f64 });
pub const IsRectVisible = function(&api.IsRectVisible, 3, &.{ ContextPtr, f64, f64 });
pub const IsRectVisibleEx = function(&api.IsRectVisibleEx, 5, &.{ ContextPtr, f64, f64, f64, f64 });
pub const PopClipRect = function(&api.PopClipRect, 1, &.{ContextPtr});
pub const PushClipRect = function(&api.PushClipRect, 6, &.{ ContextPtr, f64, f64, f64, f64, bool });
pub const GetCursorPos = function(&api.GetCursorPos, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetCursorPosX = function(&api.GetCursorPosX, 1, &.{ContextPtr});
pub const GetCursorPosY = function(&api.GetCursorPosY, 1, &.{ContextPtr});
pub const GetCursorScreenPos = function(&api.GetCursorScreenPos, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetCursorStartPos = function(&api.GetCursorStartPos, 3, &.{ ContextPtr, *f64, *f64 });
pub const SetCursorPos = function(&api.SetCursorPos, 3, &.{ ContextPtr, f64, f64 });
pub const SetCursorPosX = function(&api.SetCursorPosX, 2, &.{ ContextPtr, f64 });
pub const SetCursorPosY = function(&api.SetCursorPosY, 2, &.{ ContextPtr, f64 });
pub const SetCursorScreenPos = function(&api.SetCursorScreenPos, 3, &.{ ContextPtr, f64, f64 });
pub const CreateListClipper = function(&api.CreateListClipper, 1, &.{ContextPtr});
pub const ListClipper_Begin = function(&api.ListClipper_Begin, 2, &.{ ListClipperPtr, c_int, ?f64 });
pub const ListClipper_End = function(&api.ListClipper_End, 1, &.{ListClipperPtr});
pub const ListClipper_GetDisplayRange = function(&api.ListClipper_GetDisplayRange, 3, &.{ ListClipperPtr, *c_int, *c_int });
pub const ListClipper_IncludeItemByIndex = function(&api.ListClipper_IncludeItemByIndex, 2, &.{ ListClipperPtr, c_int });
pub const ListClipper_IncludeItemsByIndex = function(&api.ListClipper_IncludeItemsByIndex, 3, &.{ ListClipperPtr, c_int, c_int });
pub const ListClipper_Step = function(&api.ListClipper_Step, 1, &.{ListClipperPtr});
pub const BeginMenu = function(&api.BeginMenu, 2, &.{ ContextPtr, [*:0]const u8, ?bool });
pub const BeginMenuBar = function(&api.BeginMenuBar, 1, &.{ContextPtr});
pub const EndMenu = function(&api.EndMenu, 1, &.{ContextPtr});
pub const EndMenuBar = function(&api.EndMenuBar, 1, &.{ContextPtr});
pub const MenuItem = function(&api.MenuItem, 2, &.{ ContextPtr, [*:0]const u8, ?[*:0]const u8, ?*bool, ?bool });
pub const PlotHistogram = function(&api.PlotHistogram, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?c_int, ?[*:0]const u8, ?f64, ?f64, ?f64, ?f64 });
pub const PlotLines = function(&api.PlotLines, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?c_int, ?[*:0]const u8, ?f64, ?f64, ?f64, ?f64 });
pub const BeginPopup = function(&api.BeginPopup, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
pub const BeginPopupModal = function(&api.BeginPopupModal, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
pub const CloseCurrentPopup = function(&api.CloseCurrentPopup, 1, &.{ContextPtr});
pub const EndPopup = function(&api.EndPopup, 1, &.{ContextPtr});
pub const IsPopupOpen = function(&api.IsPopupOpen, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
pub const OpenPopup = function(&api.OpenPopup, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
pub const OpenPopupOnItemClick = function(&api.OpenPopupOnItemClick, 1, &.{ ContextPtr, ?[*:0]const u8, ?c_int });
pub const BeginPopupContextItem = function(&api.BeginPopupContextItem, 1, &.{ ContextPtr, ?[*:0]const u8, ?c_int });
pub const BeginPopupContextWindow = function(&api.BeginPopupContextWindow, 1, &.{ ContextPtr, ?[*:0]const u8, ?c_int });
pub const BeginItemTooltip = function(&api.BeginItemTooltip, 1, &.{ContextPtr});
pub const BeginTooltip = function(&api.BeginTooltip, 1, &.{ContextPtr});
pub const EndTooltip = function(&api.EndTooltip, 1, &.{ContextPtr});
pub const SetItemTooltip = function(&api.SetItemTooltip, 2, &.{ ContextPtr, [*:0]const u8 });
pub const SetTooltip = function(&api.SetTooltip, 2, &.{ ContextPtr, [*:0]const u8 });
pub const DebugFlashStyleColor = function(&api.DebugFlashStyleColor, 2, &.{ ContextPtr, c_int });
pub const GetColor = function(&api.GetColor, 2, &.{ ContextPtr, c_int, ?f64 });
pub const GetColorEx = function(&api.GetColorEx, 2, &.{ ContextPtr, c_int, ?f64 });
pub const GetStyleColor = function(&api.GetStyleColor, 2, &.{ ContextPtr, c_int });
pub const PopStyleColor = function(&api.PopStyleColor, 1, &.{ ContextPtr, ?c_int });
pub const PushStyleColor = function(&api.PushStyleColor, 3, &.{ ContextPtr, c_int, c_int });
pub const GetStyleVar = function(&api.GetStyleVar, 4, &.{ ContextPtr, c_int, *f64, *f64 });
pub const PopStyleVar = function(&api.PopStyleVar, 1, &.{ ContextPtr, ?c_int });
pub const PushStyleVar = function(&api.PushStyleVar, 3, &.{ ContextPtr, c_int, f64, ?f64 });
pub const BeginTabBar = function(&api.BeginTabBar, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
pub const EndTabBar = function(&api.EndTabBar, 1, &.{ContextPtr});
pub const BeginTabItem = function(&api.BeginTabItem, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
pub const EndTabItem = function(&api.EndTabItem, 1, &.{ContextPtr});
pub const SetTabItemClosed = function(&api.SetTabItemClosed, 2, &.{ ContextPtr, [*:0]const u8 });
pub const TabItemButton = function(&api.TabItemButton, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
pub const BeginTable = function(&api.BeginTable, 3, &.{ ContextPtr, [*:0]const u8, c_int, ?c_int, ?f64, ?f64, ?f64 });
pub const EndTable = function(&api.EndTable, 1, &.{ContextPtr});
pub const TableGetColumnCount = function(&api.TableGetColumnCount, 1, &.{ContextPtr});
pub const TableGetColumnIndex = function(&api.TableGetColumnIndex, 1, &.{ContextPtr});
pub const TableGetRowIndex = function(&api.TableGetRowIndex, 1, &.{ContextPtr});
pub const TableNextColumn = function(&api.TableNextColumn, 1, &.{ContextPtr});
pub const TableNextRow = function(&api.TableNextRow, 1, &.{ ContextPtr, ?c_int, ?f64 });
pub const TableSetColumnIndex = function(&api.TableSetColumnIndex, 2, &.{ ContextPtr, c_int });
pub const TableSetBgColor = function(&api.TableSetBgColor, 3, &.{ ContextPtr, c_int, c_int, ?c_int });
pub const TableAngledHeadersRow = function(&api.TableAngledHeadersRow, 1, &.{ContextPtr});
pub const TableGetColumnFlags = function(&api.TableGetColumnFlags, 1, &.{ ContextPtr, ?c_int });
pub const TableGetColumnName = function(&api.TableGetColumnName, 1, &.{ ContextPtr, ?c_int });
pub const TableHeader = function(&api.TableHeader, 2, &.{ ContextPtr, [*:0]const u8 });
pub const TableHeadersRow = function(&api.TableHeadersRow, 1, &.{ContextPtr});
pub const TableSetColumnEnabled = function(&api.TableSetColumnEnabled, 3, &.{ ContextPtr, c_int, bool });
pub const TableSetupColumn = function(&api.TableSetupColumn, 2, &.{ ContextPtr, [*:0]const u8, ?c_int, ?f64, ?c_int });
pub const TableSetupScrollFreeze = function(&api.TableSetupScrollFreeze, 3, &.{ ContextPtr, c_int, c_int });
pub const TableGetColumnSortSpecs = function(&api.TableGetColumnSortSpecs, 5, &.{ ContextPtr, c_int, *c_int, *c_int, *c_int });
pub const TableNeedSort = function(&api.TableNeedSort, 2, &.{ ContextPtr, *bool });
pub const AlignTextToFramePadding = function(&api.AlignTextToFramePadding, 1, &.{ContextPtr});
pub const Bullet = function(&api.Bullet, 1, &.{ContextPtr});
pub const BulletText = function(&api.BulletText, 2, &.{ ContextPtr, [*:0]const u8 });
pub const CalcTextSize = function(&api.CalcTextSize, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?bool, ?f64 });
pub const DebugTextEncoding = function(&api.DebugTextEncoding, 2, &.{ ContextPtr, [*:0]const u8 });
pub const GetFrameHeight = function(&api.GetFrameHeight, 1, &.{ContextPtr});
pub const GetFrameHeightWithSpacing = function(&api.GetFrameHeightWithSpacing, 1, &.{ContextPtr});
pub const GetTextLineHeight = function(&api.GetTextLineHeight, 1, &.{ContextPtr});
pub const GetTextLineHeightWithSpacing = function(&api.GetTextLineHeightWithSpacing, 1, &.{ContextPtr});
pub const LabelText = function(&api.LabelText, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8 });
pub const PopTextWrapPos = function(&api.PopTextWrapPos, 1, &.{ContextPtr});
pub const PushTextWrapPos = function(&api.PushTextWrapPos, 1, &.{ ContextPtr, ?f64 });
pub const Text = function(&api.Text, 2, &.{ ContextPtr, [*:0]const u8 });
pub const TextColored = function(&api.TextColored, 3, &.{ ContextPtr, c_int, [*:0]const u8 });
pub const TextDisabled = function(&api.TextDisabled, 2, &.{ ContextPtr, [*:0]const u8 });
pub const TextWrapped = function(&api.TextWrapped, 2, &.{ ContextPtr, [*:0]const u8 });
pub const InputDouble = function(&api.InputDouble, 3, &.{ ContextPtr, [*:0]const u8, *f64, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const InputDouble2 = function(&api.InputDouble2, 4, &.{ ContextPtr, [*:0]const u8, *f64, *f64, ?[*:0]const u8, ?c_int });
pub const InputDouble3 = function(&api.InputDouble3, 5, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, ?[*:0]const u8, ?c_int });
pub const InputDouble4 = function(&api.InputDouble4, 6, &.{ ContextPtr, [*:0]const u8, *f64, *f64, *f64, *f64, ?[*:0]const u8, ?c_int });
pub const InputDoubleN = function(&api.InputDoubleN, 3, &.{ ContextPtr, [*:0]const u8, *reaper_array, ?f64, ?f64, ?[*:0]const u8, ?c_int });
pub const InputInt = function(&api.InputInt, 3, &.{ ContextPtr, [*:0]const u8, *c_int, ?c_int, ?c_int, ?c_int });
pub const InputInt2 = function(&api.InputInt2, 4, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, ?c_int });
pub const InputInt3 = function(&api.InputInt3, 5, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, ?c_int });
pub const InputInt4 = function(&api.InputInt4, 6, &.{ ContextPtr, [*:0]const u8, *c_int, *c_int, *c_int, *c_int, ?c_int });
pub const InputText = function(&api.InputText, 4, &.{ ContextPtr, [*:0]const u8, [*]u8, c_int, ?c_int, FunctionPtr });
pub const InputTextMultiline = function(&api.InputTextMultiline, 4, &.{ ContextPtr, [*:0]const u8, [*]u8, c_int, ?f64, ?f64, ?c_int, FunctionPtr });
pub const InputTextWithHint = function(&api.InputTextWithHint, 5, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, [*]u8, c_int, ?c_int, FunctionPtr });
pub const CreateTextFilter = function(&api.CreateTextFilter, 0, &.{?[*:0]const u8});
pub const TextFilter_Clear = function(&api.TextFilter_Clear, 1, &.{TextFilterPtr});
pub const TextFilter_Draw = function(&api.TextFilter_Draw, 2, &.{ TextFilterPtr, ContextPtr, ?[*:0]const u8, ?f64 });
pub const TextFilter_Get = function(&api.TextFilter_Get, 1, &.{TextFilterPtr});
pub const TextFilter_IsActive = function(&api.TextFilter_IsActive, 1, &.{TextFilterPtr});
pub const TextFilter_PassFilter = function(&api.TextFilter_PassFilter, 2, &.{ TextFilterPtr, [*:0]const u8 });
pub const TextFilter_Set = function(&api.TextFilter_Set, 2, &.{ TextFilterPtr, [*:0]const u8 });
pub const CollapsingHeader = function(&api.CollapsingHeader, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
pub const GetTreeNodeToLabelSpacing = function(&api.GetTreeNodeToLabelSpacing, 1, &.{ContextPtr});
pub const IsItemToggledOpen = function(&api.IsItemToggledOpen, 1, &.{ContextPtr});
pub const SetNextItemOpen = function(&api.SetNextItemOpen, 2, &.{ ContextPtr, bool, ?c_int });
pub const TreeNode = function(&api.TreeNode, 2, &.{ ContextPtr, [*:0]const u8, ?c_int });
pub const TreeNodeEx = function(&api.TreeNodeEx, 3, &.{ ContextPtr, [*:0]const u8, [*:0]const u8, ?c_int });
pub const TreePop = function(&api.TreePop, 1, &.{ContextPtr});
pub const TreePush = function(&api.TreePush, 2, &.{ ContextPtr, [*:0]const u8 });
pub const GetBuiltinPath = function(&api.GetBuiltinPath, 0, &.{});
pub const GetVersion = function(&api.GetVersion, 5, &.{ [*]u8, c_int, *c_int, [*]u8, c_int });
pub const NumericLimits_Double = function(&api.NumericLimits_Double, 2, &.{ *f64, *f64 });
pub const NumericLimits_Float = function(&api.NumericLimits_Float, 2, &.{ *f64, *f64 });
pub const NumericLimits_Int = function(&api.NumericLimits_Int, 2, &.{ *c_int, *c_int });
pub const PointConvertNative = function(&api.PointConvertNative, 3, &.{ ContextPtr, *f64, *f64, ?bool });
pub const ProgressBar = function(&api.ProgressBar, 2, &.{ ContextPtr, f64, ?f64, ?f64, ?[*:0]const u8 });
pub const ValidatePtr = function(&api.ValidatePtr, 2, &.{ *anyopaque, [*:0]const u8 });
pub const GetClipboardText = function(&api.GetClipboardText, 1, &.{ContextPtr});
pub const SetClipboardText = function(&api.SetClipboardText, 2, &.{ ContextPtr, [*:0]const u8 });
pub const ColorConvertDouble4ToU32 = function(&api.ColorConvertDouble4ToU32, 4, &.{ f64, f64, f64, f64 });
pub const ColorConvertHSVtoRGB = function(&api.ColorConvertHSVtoRGB, 6, &.{ f64, f64, f64, *f64, *f64, *f64 });
pub const ColorConvertNative = function(&api.ColorConvertNative, 1, &.{c_int});
pub const ColorConvertRGBtoHSV = function(&api.ColorConvertRGBtoHSV, 6, &.{ f64, f64, f64, *f64, *f64, *f64 });
pub const ColorConvertU32ToDouble4 = function(&api.ColorConvertU32ToDouble4, 5, &.{ c_int, *f64, *f64, *f64, *f64 });
pub const PopID = function(&api.PopID, 1, &.{ContextPtr});
pub const PushID = function(&api.PushID, 2, &.{ ContextPtr, [*:0]const u8 });
pub const LogFinish = function(&api.LogFinish, 1, &.{ContextPtr});
pub const LogText = function(&api.LogText, 2, &.{ ContextPtr, [*:0]const u8 });
pub const LogToClipboard = function(&api.LogToClipboard, 1, &.{ ContextPtr, ?c_int });
pub const LogToFile = function(&api.LogToFile, 1, &.{ ContextPtr, ?c_int, ?[*:0]const u8 });
pub const LogToTTY = function(&api.LogToTTY, 1, &.{ ContextPtr, ?c_int });
pub const GetMainViewport = function(&api.GetMainViewport, 1, &.{ContextPtr});
pub const GetWindowViewport = function(&api.GetWindowViewport, 1, &.{ContextPtr});
pub const Viewport_GetCenter = function(&api.Viewport_GetCenter, 3, &.{ ViewportPtr, *f64, *f64 });
pub const Viewport_GetPos = function(&api.Viewport_GetPos, 3, &.{ ViewportPtr, *f64, *f64 });
pub const Viewport_GetSize = function(&api.Viewport_GetSize, 3, &.{ ViewportPtr, *f64, *f64 });
pub const Viewport_GetWorkCenter = function(&api.Viewport_GetWorkCenter, 3, &.{ ViewportPtr, *f64, *f64 });
pub const Viewport_GetWorkPos = function(&api.Viewport_GetWorkPos, 3, &.{ ViewportPtr, *f64, *f64 });
pub const Viewport_GetWorkSize = function(&api.Viewport_GetWorkSize, 3, &.{ ViewportPtr, *f64, *f64 });
pub const Begin = function(&api.Begin, 2, &.{ ContextPtr, [*:0]const u8, ?*bool, ?c_int });
pub const End = function(&api.End, 1, &.{ContextPtr});
pub const BeginChild = function(&api.BeginChild, 2, &.{ ContextPtr, [*:0]const u8, ?f64, ?f64, ?c_int, ?c_int });
pub const EndChild = function(&api.EndChild, 1, &.{ContextPtr});
pub const GetContentRegionAvail = function(&api.GetContentRegionAvail, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetContentRegionMax = function(&api.GetContentRegionMax, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetWindowContentRegionMax = function(&api.GetWindowContentRegionMax, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetWindowContentRegionMin = function(&api.GetWindowContentRegionMin, 3, &.{ ContextPtr, *f64, *f64 });
pub const ShowAboutWindow = function(&api.ShowAboutWindow, 1, &.{ ContextPtr, ?*bool });
pub const ShowDebugLogWindow = function(&api.ShowDebugLogWindow, 1, &.{ ContextPtr, ?*bool });
pub const ShowIDStackToolWindow = function(&api.ShowIDStackToolWindow, 1, &.{ ContextPtr, ?*bool });
pub const ShowMetricsWindow = function(&api.ShowMetricsWindow, 1, &.{ ContextPtr, ?*bool });
pub const GetWindowDockID = function(&api.GetWindowDockID, 1, &.{ContextPtr});
pub const IsWindowDocked = function(&api.IsWindowDocked, 1, &.{ContextPtr});
pub const SetNextWindowDockID = function(&api.SetNextWindowDockID, 2, &.{ ContextPtr, c_int, ?c_int });
pub const GetWindowDpiScale = function(&api.GetWindowDpiScale, 1, &.{ContextPtr});
pub const GetWindowHeight = function(&api.GetWindowHeight, 1, &.{ContextPtr});
pub const GetWindowPos = function(&api.GetWindowPos, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetWindowSize = function(&api.GetWindowSize, 3, &.{ ContextPtr, *f64, *f64 });
pub const GetWindowWidth = function(&api.GetWindowWidth, 1, &.{ContextPtr});
pub const IsWindowAppearing = function(&api.IsWindowAppearing, 1, &.{ContextPtr});
pub const IsWindowFocused = function(&api.IsWindowFocused, 1, &.{ ContextPtr, ?c_int });
pub const IsWindowHovered = function(&api.IsWindowHovered, 1, &.{ ContextPtr, ?c_int });
pub const SetNextWindowBgAlpha = function(&api.SetNextWindowBgAlpha, 2, &.{ ContextPtr, f64 });
pub const SetNextWindowCollapsed = function(&api.SetNextWindowCollapsed, 2, &.{ ContextPtr, bool, ?c_int });
pub const SetNextWindowContentSize = function(&api.SetNextWindowContentSize, 3, &.{ ContextPtr, f64, f64 });
pub const SetNextWindowFocus = function(&api.SetNextWindowFocus, 1, &.{ContextPtr});
pub const SetNextWindowPos = function(&api.SetNextWindowPos, 3, &.{ ContextPtr, f64, f64, ?c_int, ?f64, ?f64 });
pub const SetNextWindowScroll = function(&api.SetNextWindowScroll, 3, &.{ ContextPtr, f64, f64 });
pub const SetNextWindowSize = function(&api.SetNextWindowSize, 3, &.{ ContextPtr, f64, f64, ?c_int });
pub const SetNextWindowSizeConstraints = function(&api.SetNextWindowSizeConstraints, 5, &.{ ContextPtr, f64, f64, f64, f64, FunctionPtr });
pub const SetWindowCollapsed = function(&api.SetWindowCollapsed, 2, &.{ ContextPtr, bool, ?c_int });
pub const SetWindowCollapsedEx = function(&api.SetWindowCollapsedEx, 3, &.{ ContextPtr, [*:0]const u8, bool, ?c_int });
pub const SetWindowFocus = function(&api.SetWindowFocus, 1, &.{ContextPtr});
pub const SetWindowFocusEx = function(&api.SetWindowFocusEx, 2, &.{ ContextPtr, [*:0]const u8 });
pub const SetWindowPos = function(&api.SetWindowPos, 3, &.{ ContextPtr, f64, f64, ?c_int });
pub const SetWindowPosEx = function(&api.SetWindowPosEx, 4, &.{ ContextPtr, [*:0]const u8, f64, f64, ?c_int });
pub const SetWindowSize = function(&api.SetWindowSize, 3, &.{ ContextPtr, f64, f64, ?c_int });
pub const SetWindowSizeEx = function(&api.SetWindowSizeEx, 4, &.{ ContextPtr, [*:0]const u8, f64, f64, ?c_int });
pub const GetScrollMaxX = function(&api.GetScrollMaxX, 1, &.{ContextPtr});
pub const GetScrollMaxY = function(&api.GetScrollMaxY, 1, &.{ContextPtr});
pub const GetScrollX = function(&api.GetScrollX, 1, &.{ContextPtr});
pub const GetScrollY = function(&api.GetScrollY, 1, &.{ContextPtr});
pub const SetScrollFromPosX = function(&api.SetScrollFromPosX, 2, &.{ ContextPtr, f64, ?f64 });
pub const SetScrollFromPosY = function(&api.SetScrollFromPosY, 2, &.{ ContextPtr, f64, ?f64 });
pub const SetScrollHereX = function(&api.SetScrollHereX, 1, &.{ ContextPtr, ?f64 });
pub const SetScrollHereY = function(&api.SetScrollHereY, 1, &.{ ContextPtr, ?f64 });
pub const SetScrollX = function(&api.SetScrollX, 2, &.{ ContextPtr, f64 });
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
        @ptrCast(plugin_getapi("ImGui__getapi"));
    getError = @ptrCast(plugin_getapi("ImGui__geterr"));

    if (getFunc == null or getError == null) {
        last_error = "ReaImGui is not installed or too old";
        return error.ImGui;
    }

    inline for (@typeInfo(API).Struct.fields) |field| {
        @field(api, field.name) = @ptrCast(getFunc.?(api_version, field.name));
        try checkError();
    }

    inline for (@typeInfo(API).Struct.decls) |decl| {
        @field(API, decl.name) = getEnum(@ptrCast(getFunc.?(api_version, decl.name)));
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
