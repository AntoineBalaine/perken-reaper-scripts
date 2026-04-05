const std = @import("std");
const imgui = @import("reaper_imgui");

// -- Types --

pub const WidgetKind = enum {
    begin_window,
    end_window,
    text,
    text_colored,
    text_disabled,
    button,
    small_button,
    invisible_button,
    arrow_button,
    checkbox,
    selectable,
    begin_combo,
    end_combo,
    begin_group,
    end_group,
    begin_child,
    end_child,
    begin_menu,
    end_menu,
    begin_popup,
    end_popup,
    open_popup,
    begin_disabled,
    end_disabled,
    separator,
    same_line,
    spacing,
    dummy,
    push_font,
    pop_font,
    push_style_color,
    pop_style_color,
    push_id,
    pop_id,
    push_item_width,
    pop_item_width,
    set_cursor_pos_x,
    set_cursor_pos_y,
    set_next_window_size,
    set_next_window_dock_id,
    set_next_item_allow_overlap,
    draw_list_add_rect_filled,
    draw_list_add_text,
    draw_list_add_circle_filled,
    draw_list_add_circle,
    draw_list_add_line,
    draw_list_add_triangle_filled,
    draw_list_add_triangle,
    draw_list_path_arc_to,
    draw_list_path_stroke,
    draw_list_path_clear,
    set_tooltip,
    calc_text_size,
    color_button,
    color_picker4,
    scroll_here_y,
    indent,
    unindent,
    get_window_draw_list,
    get_window_pos,
    get_window_size,
    get_cursor_screen_pos,
    set_cursor_screen_pos,
    is_item_active,
    is_item_hovered,
    is_mouse_double_clicked,
    is_key_down,
    get_mouse_drag_delta,
    reset_mouse_drag_delta,
    get_item_rect_max,
    get_style_color,
    get_style_var,
    get_text_line_height_with_spacing,
    push_clip_rect,
    pop_clip_rect,
    set_config_var,
    color_convert_native,
    begin_drag_drop_target,
    end_drag_drop_target,
    accept_drag_drop_payload_rgb,
    text_wrapped,
    input_text,
    set_keyboard_focus_here,
    is_key_pressed,
};

pub const TraceEntry = struct {
    kind: WidgetKind,
    label: []const u8,
};

// -- Global mock pointer --

pub var g_mock: ?*MockImGui = null;

fn trace(kind: WidgetKind, label: []const u8) void {
    const m = g_mock orelse @panic("g_mock is null in mock imgui function");
    const owned_label = m.frame_arena.allocator().dupe(u8, label) catch @panic("trace label dupe OOM");
    m.trace_list.append(m.allocator, .{ .kind = kind, .label = owned_label }) catch @panic("trace OOM");
}

fn pushPair(cat: PairCategory) void {
    const m = g_mock orelse @panic("g_mock is null");
    m.pair_depths.getPtr(cat).* += 1;
}

fn popPair(cat: PairCategory) void {
    const m = g_mock orelse @panic("g_mock is null");
    const ptr = m.pair_depths.getPtr(cat);
    std.debug.assert(ptr.* > 0); // pop without matching push
    ptr.* -= 1;
}

// -- ImguiMocks: the set of api fields we replace --
// Each field name must exactly match a field in imgui.API.

const ImguiMocks = struct {
    Begin: @TypeOf(imgui.api.Begin),
    End: @TypeOf(imgui.api.End),
    BeginChild: @TypeOf(imgui.api.BeginChild),
    EndChild: @TypeOf(imgui.api.EndChild),
    Text: @TypeOf(imgui.api.Text),
    TextColored: @TypeOf(imgui.api.TextColored),
    TextDisabled: @TypeOf(imgui.api.TextDisabled),
    Button: @TypeOf(imgui.api.Button),
    SmallButton: @TypeOf(imgui.api.SmallButton),
    InvisibleButton: @TypeOf(imgui.api.InvisibleButton),
    ArrowButton: @TypeOf(imgui.api.ArrowButton),
    Checkbox: @TypeOf(imgui.api.Checkbox),
    Selectable: @TypeOf(imgui.api.Selectable),
    BeginCombo: @TypeOf(imgui.api.BeginCombo),
    EndCombo: @TypeOf(imgui.api.EndCombo),
    BeginGroup: @TypeOf(imgui.api.BeginGroup),
    EndGroup: @TypeOf(imgui.api.EndGroup),
    BeginMenu: @TypeOf(imgui.api.BeginMenu),
    EndMenu: @TypeOf(imgui.api.EndMenu),
    BeginPopup: @TypeOf(imgui.api.BeginPopup),
    EndPopup: @TypeOf(imgui.api.EndPopup),
    OpenPopup: @TypeOf(imgui.api.OpenPopup),
    BeginDisabled: @TypeOf(imgui.api.BeginDisabled),
    EndDisabled: @TypeOf(imgui.api.EndDisabled),
    Separator: @TypeOf(imgui.api.Separator),
    SameLine: @TypeOf(imgui.api.SameLine),
    Spacing: @TypeOf(imgui.api.Spacing),
    Dummy: @TypeOf(imgui.api.Dummy),
    Indent: @TypeOf(imgui.api.Indent),
    Unindent: @TypeOf(imgui.api.Unindent),
    PushFont: @TypeOf(imgui.api.PushFont),
    PopFont: @TypeOf(imgui.api.PopFont),
    PushStyleColor: @TypeOf(imgui.api.PushStyleColor),
    PopStyleColor: @TypeOf(imgui.api.PopStyleColor),
    PushID: @TypeOf(imgui.api.PushID),
    PopID: @TypeOf(imgui.api.PopID),
    SetNextItemWidth: @TypeOf(imgui.api.SetNextItemWidth),
    PushItemWidth: @TypeOf(imgui.api.PushItemWidth),
    PopItemWidth: @TypeOf(imgui.api.PopItemWidth),
    SetCursorPosX: @TypeOf(imgui.api.SetCursorPosX),
    SetCursorPosY: @TypeOf(imgui.api.SetCursorPosY),
    GetCursorPosX: @TypeOf(imgui.api.GetCursorPosX),
    GetCursorPosY: @TypeOf(imgui.api.GetCursorPosY),
    GetCursorScreenPos: @TypeOf(imgui.api.GetCursorScreenPos),
    SetCursorScreenPos: @TypeOf(imgui.api.SetCursorScreenPos),
    GetWindowDrawList: @TypeOf(imgui.api.GetWindowDrawList),
    GetWindowPos: @TypeOf(imgui.api.GetWindowPos),
    GetWindowSize: @TypeOf(imgui.api.GetWindowSize),
    DrawList_AddRectFilled: @TypeOf(imgui.api.DrawList_AddRectFilled),
    DrawList_AddText: @TypeOf(imgui.api.DrawList_AddText),
    DrawList_AddCircleFilled: @TypeOf(imgui.api.DrawList_AddCircleFilled),
    DrawList_AddCircle: @TypeOf(imgui.api.DrawList_AddCircle),
    DrawList_AddLine: @TypeOf(imgui.api.DrawList_AddLine),
    DrawList_AddTriangleFilled: @TypeOf(imgui.api.DrawList_AddTriangleFilled),
    DrawList_AddTriangle: @TypeOf(imgui.api.DrawList_AddTriangle),
    DrawList_PathArcTo: @TypeOf(imgui.api.DrawList_PathArcTo),
    DrawList_PathStroke: @TypeOf(imgui.api.DrawList_PathStroke),
    DrawList_PathClear: @TypeOf(imgui.api.DrawList_PathClear),
    SetTooltip: @TypeOf(imgui.api.SetTooltip),
    CalcTextSize: @TypeOf(imgui.api.CalcTextSize),
    ColorButton: @TypeOf(imgui.api.ColorButton),
    ColorPicker4: @TypeOf(imgui.api.ColorPicker4),
    SetScrollHereY: @TypeOf(imgui.api.SetScrollHereY),
    SetNextWindowSize: @TypeOf(imgui.api.SetNextWindowSize),
    SetNextWindowDockID: @TypeOf(imgui.api.SetNextWindowDockID),
    SetNextItemAllowOverlap: @TypeOf(imgui.api.SetNextItemAllowOverlap),
    IsItemActive: @TypeOf(imgui.api.IsItemActive),
    IsItemHovered: @TypeOf(imgui.api.IsItemHovered),
    IsMouseDoubleClicked: @TypeOf(imgui.api.IsMouseDoubleClicked),
    IsKeyDown: @TypeOf(imgui.api.IsKeyDown),
    GetMouseDragDelta: @TypeOf(imgui.api.GetMouseDragDelta),
    ResetMouseDragDelta: @TypeOf(imgui.api.ResetMouseDragDelta),
    GetItemRectMax: @TypeOf(imgui.api.GetItemRectMax),
    GetStyleColor: @TypeOf(imgui.api.GetStyleColor),
    GetStyleVar: @TypeOf(imgui.api.GetStyleVar),
    GetTextLineHeightWithSpacing: @TypeOf(imgui.api.GetTextLineHeightWithSpacing),
    PushClipRect: @TypeOf(imgui.api.PushClipRect),
    PopClipRect: @TypeOf(imgui.api.PopClipRect),
    SetConfigVar: @TypeOf(imgui.api.SetConfigVar),
    ColorConvertNative: @TypeOf(imgui.api.ColorConvertNative),
    BeginDragDropTarget: @TypeOf(imgui.api.BeginDragDropTarget),
    EndDragDropTarget: @TypeOf(imgui.api.EndDragDropTarget),
    AcceptDragDropPayloadRGB: @TypeOf(imgui.api.AcceptDragDropPayloadRGB),
    PushStyleVar: @TypeOf(imgui.api.PushStyleVar),
    PopStyleVar: @TypeOf(imgui.api.PopStyleVar),
    SetNextWindowSizeConstraints: @TypeOf(imgui.api.SetNextWindowSizeConstraints),
    // Debug panel functions
    GetFramerate: @TypeOf(imgui.api.GetFramerate),
    BeginTable: @TypeOf(imgui.api.BeginTable),
    EndTable: @TypeOf(imgui.api.EndTable),
    TableHeadersRow: @TypeOf(imgui.api.TableHeadersRow),
    TableSetupColumn: @TypeOf(imgui.api.TableSetupColumn),
    TextWrapped: @TypeOf(imgui.api.TextWrapped),
    CollapsingHeader: @TypeOf(imgui.api.CollapsingHeader),
    // Next batch:  TableNextColumn, TableNextRow (used by debug_panel tables)
    TableNextColumn: @TypeOf(imgui.api.TableNextColumn),
    TableNextRow: @TypeOf(imgui.api.TableNextRow),
    // DrawListSplitter functions (used by module_selection_panel and fx_sel_panel)
    CreateDrawListSplitter: @TypeOf(imgui.api.CreateDrawListSplitter),
    DrawListSplitter_Split: @TypeOf(imgui.api.DrawListSplitter_Split),
    DrawListSplitter_Merge: @TypeOf(imgui.api.DrawListSplitter_Merge),
    DrawListSplitter_SetCurrentChannel: @TypeOf(imgui.api.DrawListSplitter_SetCurrentChannel),
    ValidatePtr: @TypeOf(imgui.api.ValidatePtr),
    GetItemRectMin: @TypeOf(imgui.api.GetItemRectMin),
    // Tab bar functions (used by settings panel)
    BeginTabBar: @TypeOf(imgui.api.BeginTabBar),
    EndTabBar: @TypeOf(imgui.api.EndTabBar),
    BeginTabItem: @TypeOf(imgui.api.BeginTabItem),
    EndTabItem: @TypeOf(imgui.api.EndTabItem),
    ColorEdit4: @TypeOf(imgui.api.ColorEdit4),
    // Knob value text editing functions
    InputText: @TypeOf(imgui.api.InputText),
    SetKeyboardFocusHere: @TypeOf(imgui.api.SetKeyboardFocusHere),
    IsKeyPressed: @TypeOf(imgui.api.IsKeyPressed),
};

// -- Push/Pop pair tracking --
// Each category tracks the nesting depth. A push increments, a pop decrements.
// At frame boundaries (resetTrace), all depths must be zero.

pub const PairCategory = enum {
    font,
    style_color,
    style_var,
    id,
    item_width,
    clip_rect,
    group,
    disabled,
    // Conditional pairs: End is only called when Begin returned true.
    // The mock only increments depth when Begin returns true.
    window,
    child,
    combo,
    menu,
    popup,
    tab_bar,
    tab_item,
    table,
    drag_drop_target,
};

// -- MockImGui struct --

pub const MockImGui = struct {
    trace_list: std.ArrayListUnmanaged(TraceEntry),
    frame_arena: std.heap.ArenaAllocator,
    pair_depths: std.EnumArray(PairCategory, i32),
    click_targets: std.StringHashMapUnmanaged(void),
    checkbox_overrides: std.StringHashMapUnmanaged(bool),
    selectable_targets: std.StringHashMapUnmanaged(void),
    combo_open_targets: std.StringHashMapUnmanaged(void),
    double_click_targets: std.StringHashMapUnmanaged(void),
    key_press_targets: std.AutoArrayHashMap(c_int, void),
    input_text_enter: std.StringHashMapUnmanaged(void),
    last_invisible_button_label: []const u8 = "",
    allocator: std.mem.Allocator,
    orig_funcs: ImguiMocks,
    orig_get_error: @TypeOf(imgui.getError),

    pub fn init(allocator: std.mem.Allocator) MockImGui {
        return .{
            .trace_list = .{},
            .frame_arena = std.heap.ArenaAllocator.init(allocator),
            .pair_depths = std.EnumArray(PairCategory, i32).initFill(0),
            .click_targets = .{},
            .checkbox_overrides = .{},
            .selectable_targets = .{},
            .combo_open_targets = .{},
            .double_click_targets = .{},
            .key_press_targets = std.AutoArrayHashMap(c_int, void).init(allocator),
            .input_text_enter = .{},
            .allocator = allocator,
            .orig_funcs = undefined,
            .orig_get_error = undefined,
        };
    }

    pub fn deinit(self: *MockImGui) void {
        self.trace_list.deinit(self.allocator);
        self.frame_arena.deinit();
        self.click_targets.deinit(self.allocator);
        self.checkbox_overrides.deinit(self.allocator);
        self.selectable_targets.deinit(self.allocator);
        self.combo_open_targets.deinit(self.allocator);
        self.double_click_targets.deinit(self.allocator);
        self.key_press_targets.deinit();
        self.input_text_enter.deinit(self.allocator);
    }

    pub fn install(self: *MockImGui) void {
        @setEvalBranchQuota(50000);
        g_mock = self;

        // Save original getError
        self.orig_get_error = imgui.getError;
        imgui.getError = @constCast(&mockGetError);

        // First pass: set all api fields to the name-reporting panic stub
        inline for (@typeInfo(imgui.API).@"struct".fields) |field| {
            @field(imgui.api, field.name) = @ptrCast(@alignCast(@as(*anyopaque, @ptrCast(@constCast(&makeNamedPanic(field.name))))));
        }

        // Second pass: set all enum/constant decl vars to 0
        inline for (@typeInfo(imgui.API).@"struct".decls) |decl| {
            if (@TypeOf(@field(imgui.API, decl.name)) == c_int) {
                @field(imgui.API, decl.name) = 0;
            }
        }

        // Third pass: save originals and install mocks
        inline for (std.meta.fields(ImguiMocks)) |field| {
            @field(self.orig_funcs, field.name) = @field(imgui.api, field.name);
            @field(imgui.api, field.name) = @constCast(@field(@This(), field.name));
        }
    }

    pub fn restore(self: *MockImGui) void {
        inline for (std.meta.fields(ImguiMocks)) |field| {
            @field(imgui.api, field.name) = @field(self.orig_funcs, field.name);
        }
        imgui.getError = self.orig_get_error;
        g_mock = null;
    }

    // -- Interaction configuration --

    pub fn click(self: *MockImGui, label: []const u8) void {
        self.click_targets.put(self.allocator, label, {}) catch @panic("click_targets put OOM");
    }

    pub fn setCheckbox(self: *MockImGui, label: []const u8, value: bool) void {
        self.checkbox_overrides.put(self.allocator, label, value) catch @panic("checkbox_overrides put OOM");
    }

    pub fn openCombo(self: *MockImGui, label: []const u8) void {
        self.combo_open_targets.put(self.allocator, label, {}) catch @panic("combo_open_targets put OOM");
    }

    pub fn selectItem(self: *MockImGui, label: []const u8) void {
        self.selectable_targets.put(self.allocator, label, {}) catch @panic("selectable_targets put OOM");
    }

    pub fn doubleClick(self: *MockImGui, label: []const u8) void {
        self.double_click_targets.put(self.allocator, label, {}) catch @panic("double_click_targets put OOM");
    }

    pub fn pressKey(self: *MockImGui, key: c_int) void {
        self.key_press_targets.put(key, {}) catch @panic("key_press_targets put OOM");
    }

    pub fn setInputTextEnter(self: *MockImGui, label: []const u8) void {
        self.input_text_enter.put(self.allocator, label, {}) catch @panic("input_text_enter put OOM");
    }

    pub fn assertBalanced(self: *const MockImGui) !void {
        for (std.enums.values(PairCategory)) |cat| {
            if (self.pair_depths.get(cat) != 0) {
                return error.TestUnexpectedResult;
            }
        }
    }

    /// Returns the first unbalanced pair category and its depth, or null
    /// if all pairs are balanced. Useful for diagnosing failures.
    pub fn findUnbalanced(self: *const MockImGui) ?struct { category: PairCategory, depth: i32 } {
        for (std.enums.values(PairCategory)) |cat| {
            const depth = self.pair_depths.get(cat);
            if (depth != 0) return .{ .category = cat, .depth = depth };
        }
        return null;
    }

    pub fn resetTrace(self: *MockImGui) void {
        self.assertBalanced() catch @panic("unbalanced push/pop pairs at frame boundary");
        self.trace_list.clearRetainingCapacity();
        _ = self.frame_arena.reset(.retain_capacity);
        self.pair_depths = std.EnumArray(PairCategory, i32).initFill(0);
    }

    /// Reset the trace without checking pair balance. Use this only when
    /// intentionally rendering a partial frame.
    pub fn resetTraceUnchecked(self: *MockImGui) void {
        self.trace_list.clearRetainingCapacity();
        _ = self.frame_arena.reset(.retain_capacity);
        self.pair_depths = std.EnumArray(PairCategory, i32).initFill(0);
    }

    pub fn resetInteractions(self: *MockImGui) void {
        self.click_targets.clearRetainingCapacity();
        self.checkbox_overrides.clearRetainingCapacity();
        self.selectable_targets.clearRetainingCapacity();
        self.combo_open_targets.clearRetainingCapacity();
        self.double_click_targets.clearRetainingCapacity();
        self.key_press_targets.clearRetainingCapacity();
        self.input_text_enter.clearRetainingCapacity();
        self.last_invisible_button_label = "";
    }

    // -- Trace query helpers --

    pub fn containsText(self: *const MockImGui, text: []const u8) bool {
        for (self.trace_list.items) |entry| {
            switch (entry.kind) {
                .text, .text_colored, .text_disabled => {
                    if (std.mem.eql(u8, entry.label, text)) return true;
                },
                else => {},
            }
        }
        return false;
    }

    pub fn containsButton(self: *const MockImGui, label: []const u8) bool {
        return self.containsWidget(.button, label) or
            self.containsWidget(.small_button, label) or
            self.containsWidget(.invisible_button, label) or
            self.containsWidget(.arrow_button, label);
    }

    pub fn containsWidget(self: *const MockImGui, kind: WidgetKind, label: []const u8) bool {
        for (self.trace_list.items) |entry| {
            if (entry.kind == kind and std.mem.eql(u8, entry.label, label)) return true;
        }
        return false;
    }

    pub fn widgetCount(self: *const MockImGui, kind: WidgetKind) usize {
        var count: usize = 0;
        for (self.trace_list.items) |entry| {
            if (entry.kind == kind) count += 1;
        }
        return count;
    }

    // -- Mock function implementations (decls on this struct for comptime field lookup) --

    // Window
    const Begin = &mockBegin;
    const End = &mockEnd;
    const BeginChild = &mockBeginChild;
    const EndChild = &mockEndChild;

    // Text
    const Text = &mockText;
    const TextColored = &mockTextColored;
    const TextDisabled = &mockTextDisabled;

    // Buttons
    const Button = &mockButton;
    const SmallButton = &mockSmallButton;
    const InvisibleButton = &mockInvisibleButton;
    const ArrowButton = &mockArrowButton;

    // Input widgets
    const Checkbox = &mockCheckbox;
    const Selectable = &mockSelectable;
    const BeginCombo = &mockBeginCombo;
    const EndCombo = &mockEndCombo;
    const ColorButton = &mockColorButton;
    const ColorPicker4 = &mockColorPicker4;

    // Groups / containers
    const BeginGroup = &mockBeginGroup;
    const EndGroup = &mockEndGroup;
    const BeginMenu = &mockBeginMenu;
    const EndMenu = &mockEndMenu;
    const BeginPopup = &mockBeginPopup;
    const EndPopup = &mockEndPopup;
    const OpenPopup = &mockOpenPopup;
    const BeginDisabled = &mockBeginDisabled;
    const EndDisabled = &mockEndDisabled;

    // Layout
    const Separator = &mockVoidCtx;
    const SameLine = &mockSameLine;
    const Spacing = &mockVoidCtx;
    const Dummy = &mockDummy;
    const Indent = &mockIndent;
    const Unindent = &mockUnindent;

    // Font/style
    const PushFont = &mockPushFont;
    const PopFont = &mockPopFont;
    const PushStyleColor = &mockPushStyleColor;
    const PopStyleColor = &mockPopStyleColor;
    const PushID = &mockPushID;
    const PopID = &mockPopID;
    const SetNextItemWidth = &mockSetNextItemWidth;
    const PushItemWidth = &mockPushItemWidth;
    const PopItemWidth = &mockPopItemWidth;

    // Cursor
    const SetCursorPosX = &mockSetCursorPosX;
    const SetCursorPosY = &mockSetCursorPosY;
    const GetCursorPosX = &mockGetCursorPosX;
    const GetCursorPosY = &mockGetCursorPosY;
    const GetCursorScreenPos = &mockGetCursorScreenPos;
    const SetCursorScreenPos = &mockSetCursorScreenPos;

    // Window queries
    const GetWindowDrawList = &mockGetWindowDrawList;
    const GetWindowPos = &mockGetWindowPos;
    const GetWindowSize = &mockGetWindowSize;

    // DrawList
    const DrawList_AddRectFilled = &mockDL_AddRectFilled;
    const DrawList_AddText = &mockDL_AddText;
    const DrawList_AddCircleFilled = &mockDL_AddCircleFilled;
    const DrawList_AddCircle = &mockDL_AddCircle;
    const DrawList_AddLine = &mockDL_AddLine;
    const DrawList_AddTriangleFilled = &mockDL_AddTriangleFilled;
    const DrawList_AddTriangle = &mockDL_AddTriangle;
    const DrawList_PathArcTo = &mockDL_PathArcTo;
    const DrawList_PathStroke = &mockDL_PathStroke;
    const DrawList_PathClear = &mockDL_PathClear;

    // Misc
    const SetTooltip = &mockSetTooltip;
    const CalcTextSize = &mockCalcTextSize;
    const SetScrollHereY = &mockSetScrollHereY;
    const SetNextWindowSize = &mockSetNextWindowSize;
    const SetNextWindowDockID = &mockSetNextWindowDockID;
    const SetNextItemAllowOverlap = &mockVoidCtx;
    const IsItemActive = &mockBoolCtxFalse;
    const IsItemHovered = &mockIsItemHovered;
    const IsMouseDoubleClicked = &mockIsMouseDoubleClicked;
    const IsKeyDown = &mockIsKeyDown;
    const GetMouseDragDelta = &mockGetMouseDragDelta;
    const ResetMouseDragDelta = &mockResetMouseDragDelta;
    const GetItemRectMax = &mockGetItemRectMax;
    const GetStyleColor = &mockGetStyleColor;
    const GetStyleVar = &mockGetStyleVar;
    const GetTextLineHeightWithSpacing = &mockGetTextLineHeightWithSpacing;
    const PushClipRect = &mockPushClipRect;
    const PopClipRect = &mockPopClipRect;
    const SetConfigVar = &mockSetConfigVar;
    const ColorConvertNative = &mockColorConvertNative;
    const BeginDragDropTarget = &mockBeginDragDropTarget;
    const EndDragDropTarget = &mockEndDragDropTarget;
    const AcceptDragDropPayloadRGB = &mockAcceptDragDropPayloadRGB;
    const PushStyleVar = &mockPushStyleVar;
    const PopStyleVar = &mockPopStyleVar;
    const SetNextWindowSizeConstraints = &mockSetNextWindowSizeConstraints;
    const GetFramerate = &mockGetFramerate;
    const BeginTable = &mockBeginTable;
    const EndTable = &mockEndTable;
    const TableHeadersRow = &mockVoidCtx;
    const TableSetupColumn = &mockTableSetupColumn;
    const TextWrapped = &mockTextWrapped;
    const CollapsingHeader = &mockCollapsingHeader;
    const TableNextColumn = &mockBoolCtxFalse;
    const TableNextRow = &mockTableNextRow;
    const CreateDrawListSplitter = &mockCreateDrawListSplitter;
    const DrawListSplitter_Split = &mockDLSplitterSplit;
    const DrawListSplitter_Merge = &mockDLSplitterMerge;
    const DrawListSplitter_SetCurrentChannel = &mockDLSplitterSetChannel;
    const ValidatePtr = &mockValidatePtr;
    const GetItemRectMin = &mockGetItemRectMin;
    const BeginTabBar = &mockBeginTabBar;
    const EndTabBar = &mockEndTabBar;
    const BeginTabItem = &mockBeginTabItem;
    const EndTabItem = &mockEndTabItem;
    const ColorEdit4 = &mockColorEdit4;
    // Knob value text editing
    const InputText = &mockInputText;
    const SetKeyboardFocusHere = &mockSetKeyboardFocusHere;
    const IsKeyPressed = &mockIsKeyPressed;
};

// -- Panic stub for unmocked functions --

fn unmockedPanic() callconv(.C) noreturn {
    @panic("unmocked ImGui function called in test");
}

fn makeNamedPanic(comptime name: []const u8) fn () callconv(.C) noreturn {
    return struct {
        fn panic() callconv(.C) noreturn {
            std.debug.print("UNMOCKED: {s}\n", .{name});
            @panic("unmocked ImGui function: " ++ name);
        }
    }.panic;
}

// -- Mock getError: always returns null (no error) --

fn mockGetError() callconv(.C) ?[*:0]const u8 {
    return null;
}

// -- Generic reusable stubs --

fn mockVoidCtx(_: imgui.ContextPtr) callconv(.C) void {}

fn mockBoolCtxFalse(_: imgui.ContextPtr) callconv(.C) bool {
    return false;
}

// -- Window mocks --

fn mockBegin(_: imgui.ContextPtr, name: [*:0]const u8, _: ?*bool, _: ?*c_int) callconv(.C) bool {
    trace(.begin_window, std.mem.span(name));
    pushPair(.window);
    return true;
}

fn mockEnd(_: imgui.ContextPtr) callconv(.C) void {
    trace(.end_window, "");
    popPair(.window);
}

fn mockBeginChild(_: imgui.ContextPtr, name: [*:0]const u8, _: ?*f64, _: ?*f64, _: ?*c_int, _: ?*c_int) callconv(.C) bool {
    trace(.begin_child, std.mem.span(name));
    pushPair(.child);
    return true;
}

fn mockEndChild(_: imgui.ContextPtr) callconv(.C) void {
    trace(.end_child, "");
    popPair(.child);
}

// -- Text mocks --

fn mockText(_: imgui.ContextPtr, txt: [*:0]const u8) callconv(.C) void {
    trace(.text, std.mem.span(txt));
}

fn mockTextColored(_: imgui.ContextPtr, _: c_int, txt: [*:0]const u8) callconv(.C) void {
    trace(.text_colored, std.mem.span(txt));
}

fn mockTextDisabled(_: imgui.ContextPtr, txt: [*:0]const u8) callconv(.C) void {
    trace(.text_disabled, std.mem.span(txt));
}

// -- Shared click helper: traces the widget and consumes a click target if present --

fn traceAndConsumeClick(kind: WidgetKind, label: [*:0]const u8) bool {
    const label_str = std.mem.span(label);
    trace(kind, label_str);
    const m = g_mock.?;
    return m.click_targets.fetchRemove(label_str) != null;
}

// -- Button mocks --

fn mockButton(_: imgui.ContextPtr, label: [*:0]const u8, _: ?*f64, _: ?*f64) callconv(.C) bool {
    return traceAndConsumeClick(.button, label);
}

fn mockSmallButton(_: imgui.ContextPtr, label: [*:0]const u8) callconv(.C) bool {
    return traceAndConsumeClick(.small_button, label);
}

fn mockInvisibleButton(_: imgui.ContextPtr, label: [*:0]const u8, _: f64, _: f64, _: ?*c_int) callconv(.C) bool {
    const m = g_mock orelse @panic("g_mock is null");
    const lbl = std.mem.span(label);
    m.last_invisible_button_label = m.frame_arena.allocator().dupe(u8, lbl) catch @panic("dupe OOM");
    return traceAndConsumeClick(.invisible_button, label);
}

fn mockArrowButton(_: imgui.ContextPtr, label: [*:0]const u8, _: c_int) callconv(.C) bool {
    return traceAndConsumeClick(.arrow_button, label);
}

// -- Input widget mocks --

fn mockCheckbox(_: imgui.ContextPtr, label: [*:0]const u8, v: *bool) callconv(.C) bool {
    const label_str = std.mem.span(label);
    trace(.checkbox, label_str);
    const m = g_mock.?;
    if (m.checkbox_overrides.get(label_str)) |val| {
        v.* = val;
        return true;
    }
    return false;
}

fn mockSelectable(_: imgui.ContextPtr, label: [*:0]const u8, _: ?*bool, _: ?*c_int, _: ?*f64, _: ?*f64) callconv(.C) bool {
    const label_str = std.mem.span(label);
    trace(.selectable, label_str);
    return g_mock.?.selectable_targets.fetchRemove(label_str) != null;
}

fn mockBeginCombo(_: imgui.ContextPtr, label: [*:0]const u8, _: [*:0]const u8, _: ?*c_int) callconv(.C) bool {
    const label_str = std.mem.span(label);
    trace(.begin_combo, label_str);
    const opened = g_mock.?.combo_open_targets.contains(label_str);
    if (opened) pushPair(.combo);
    return opened;
}

fn mockEndCombo(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.combo);
}

fn mockColorButton(_: imgui.ContextPtr, label: [*:0]const u8, _: c_int, _: ?*c_int, _: ?*f64, _: ?*f64) callconv(.C) bool {
    trace(.color_button, std.mem.span(label));
    return false;
}

fn mockColorPicker4(_: imgui.ContextPtr, label: [*:0]const u8, _: *c_int, _: ?*c_int, _: ?*c_int) callconv(.C) bool {
    trace(.color_picker4, std.mem.span(label));
    return false;
}

// -- Menu/popup mocks --

fn mockBeginGroup(_: imgui.ContextPtr) callconv(.C) void {
    pushPair(.group);
}

fn mockEndGroup(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.group);
}

fn mockBeginMenu(_: imgui.ContextPtr, label: [*:0]const u8, _: ?*bool) callconv(.C) bool {
    trace(.begin_menu, std.mem.span(label));
    // Conditional: EndMenu only called if this returns true.
    // We return false, so we do not push.
    return false;
}

fn mockEndMenu(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.menu);
}

fn mockBeginPopup(_: imgui.ContextPtr, label: [*:0]const u8, _: ?*c_int) callconv(.C) bool {
    trace(.begin_popup, std.mem.span(label));
    // Conditional: returns false, no push.
    return false;
}

fn mockEndPopup(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.popup);
}

fn mockOpenPopup(_: imgui.ContextPtr, label: [*:0]const u8, _: ?*c_int) callconv(.C) void {
    trace(.open_popup, std.mem.span(label));
}

fn mockBeginDisabled(_: imgui.ContextPtr, _: ?*bool) callconv(.C) void {
    trace(.begin_disabled, "");
    pushPair(.disabled);
}

fn mockEndDisabled(_: imgui.ContextPtr) callconv(.C) void {
    trace(.end_disabled, "");
    popPair(.disabled);
}

// -- Layout mocks --

fn mockSameLine(_: imgui.ContextPtr, _: ?*f64, _: ?*f64) callconv(.C) void {
    trace(.same_line, "");
}

fn mockDummy(_: imgui.ContextPtr, _: f64, _: f64) callconv(.C) void {
    trace(.dummy, "");
}

fn mockIndent(_: imgui.ContextPtr, _: ?*f64) callconv(.C) void {
    trace(.indent, "");
}

fn mockUnindent(_: imgui.ContextPtr, _: ?*f64) callconv(.C) void {
    trace(.unindent, "");
}

// -- Font/style mocks --

fn mockPushFont(_: imgui.ContextPtr, _: imgui.FontPtr) callconv(.C) void {
    trace(.push_font, "");
    pushPair(.font);
}

fn mockPopFont(_: imgui.ContextPtr) callconv(.C) void {
    trace(.pop_font, "");
    popPair(.font);
}

fn mockPushStyleColor(_: imgui.ContextPtr, _: c_int, _: c_int) callconv(.C) void {
    trace(.push_style_color, "");
    pushPair(.style_color);
}

fn mockPopStyleColor(_: imgui.ContextPtr, count: ?*c_int) callconv(.C) void {
    trace(.pop_style_color, "");
    // PopStyleColor can pop multiple at once via the count parameter
    const n: i32 = if (count) |c| c.* else 1;
    var i: i32 = 0;
    while (i < n) : (i += 1) {
        popPair(.style_color);
    }
}

fn mockPushID(_: imgui.ContextPtr, label: [*:0]const u8) callconv(.C) void {
    trace(.push_id, std.mem.span(label));
    pushPair(.id);
}

fn mockPopID(_: imgui.ContextPtr) callconv(.C) void {
    trace(.pop_id, "");
    popPair(.id);
}

fn mockSetNextItemWidth(_: imgui.ContextPtr, _: f64) callconv(.C) void {}

fn mockPushItemWidth(_: imgui.ContextPtr, _: f64) callconv(.C) void {
    trace(.push_item_width, "");
    pushPair(.item_width);
}

fn mockPopItemWidth(_: imgui.ContextPtr) callconv(.C) void {
    trace(.pop_item_width, "");
    popPair(.item_width);
}

// -- Cursor mocks --

fn mockSetCursorPosX(_: imgui.ContextPtr, _: f64) callconv(.C) void {
    trace(.set_cursor_pos_x, "");
}

fn mockSetCursorPosY(_: imgui.ContextPtr, _: f64) callconv(.C) void {
    trace(.set_cursor_pos_y, "");
}

fn mockGetCursorPosX(_: imgui.ContextPtr) callconv(.C) f64 {
    return 0.0;
}

fn mockGetCursorPosY(_: imgui.ContextPtr) callconv(.C) f64 {
    return 0.0;
}

fn mockGetCursorScreenPos(_: imgui.ContextPtr, x: *f64, y: *f64) callconv(.C) void {
    trace(.get_cursor_screen_pos, "");
    x.* = 0.0;
    y.* = 0.0;
}

fn mockSetCursorScreenPos(_: imgui.ContextPtr, _: f64, _: f64) callconv(.C) void {
    trace(.set_cursor_screen_pos, "");
}

// -- Window query mocks --

// We return a non-null dummy value because panel code passes the DrawListPtr to
// DrawList_* functions, and the wrapper may unwrap the optional before calling the
// C function. A sentinel address avoids the "attempt to use null value" safety check.
var dummy_draw_list_storage: u8 = 0;

fn mockGetWindowDrawList(_: imgui.ContextPtr) callconv(.C) imgui.DrawListPtr {
    trace(.get_window_draw_list, "");
    return @ptrCast(&dummy_draw_list_storage);
}

fn mockGetWindowPos(_: imgui.ContextPtr, x: *f64, y: *f64) callconv(.C) void {
    trace(.get_window_pos, "");
    x.* = 0.0;
    y.* = 0.0;
}

fn mockGetWindowSize(_: imgui.ContextPtr, w: *f64, h: *f64) callconv(.C) void {
    trace(.get_window_size, "");
    w.* = 800.0;
    h.* = 600.0;
}

// -- DrawList mocks (take DrawListPtr as first arg, not ContextPtr) --
// Each signature must exactly match the corresponding API field.

// DrawList_AddRectFilled: (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64, ?*c_int) void
fn mockDL_AddRectFilled(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: f64, _: c_int, _: ?*f64, _: ?*c_int) callconv(.C) void {
    trace(.draw_list_add_rect_filled, "");
}

// DrawList_AddText: (DrawListPtr, f64, f64, c_int, [*:0]const u8) void
fn mockDL_AddText(_: imgui.DrawListPtr, _: f64, _: f64, _: c_int, txt: [*:0]const u8) callconv(.C) void {
    trace(.draw_list_add_text, std.mem.span(txt));
}

// DrawList_AddCircleFilled: (DrawListPtr, f64, f64, f64, c_int, ?*c_int) void
fn mockDL_AddCircleFilled(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: c_int, _: ?*c_int) callconv(.C) void {
    trace(.draw_list_add_circle_filled, "");
}

// DrawList_AddCircle: (DrawListPtr, f64, f64, f64, c_int, ?*c_int, ?*f64) void
fn mockDL_AddCircle(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: c_int, _: ?*c_int, _: ?*f64) callconv(.C) void {
    trace(.draw_list_add_circle, "");
}

// DrawList_AddLine: (DrawListPtr, f64, f64, f64, f64, c_int, ?*f64) void
fn mockDL_AddLine(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: f64, _: c_int, _: ?*f64) callconv(.C) void {
    trace(.draw_list_add_line, "");
}

// DrawList_AddTriangleFilled: (DrawListPtr, f64, f64, f64, f64, f64, f64, c_int) void
fn mockDL_AddTriangleFilled(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64, _: c_int) callconv(.C) void {
    trace(.draw_list_add_triangle_filled, "");
}

// DrawList_AddTriangle: (DrawListPtr, f64, f64, f64, f64, f64, f64, c_int, ?*f64) void
fn mockDL_AddTriangle(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64, _: c_int, _: ?*f64) callconv(.C) void {
    trace(.draw_list_add_triangle, "");
}

// DrawList_PathArcTo: (DrawListPtr, f64, f64, f64, f64, f64, ?*c_int) void
fn mockDL_PathArcTo(_: imgui.DrawListPtr, _: f64, _: f64, _: f64, _: f64, _: f64, _: ?*c_int) callconv(.C) void {
    trace(.draw_list_path_arc_to, "");
}

// DrawList_PathStroke: (DrawListPtr, c_int, ?*c_int, ?*f64) void
fn mockDL_PathStroke(_: imgui.DrawListPtr, _: c_int, _: ?*c_int, _: ?*f64) callconv(.C) void {
    trace(.draw_list_path_stroke, "");
}

// DrawList_PathClear: (DrawListPtr) void
fn mockDL_PathClear(_: imgui.DrawListPtr) callconv(.C) void {
    trace(.draw_list_path_clear, "");
}

// -- Misc mocks --

fn mockSetTooltip(_: imgui.ContextPtr, txt: [*:0]const u8) callconv(.C) void {
    trace(.set_tooltip, std.mem.span(txt));
}

fn mockCalcTextSize(_: imgui.ContextPtr, _: [*:0]const u8, w: *f64, h: *f64, _: ?*bool, _: ?*f64) callconv(.C) void {
    trace(.calc_text_size, "");
    w.* = 50.0;
    h.* = 16.0;
}

fn mockSetScrollHereY(_: imgui.ContextPtr, _: ?*f64) callconv(.C) void {
    trace(.scroll_here_y, "");
}

fn mockSetNextWindowSize(_: imgui.ContextPtr, _: f64, _: f64, _: ?*c_int) callconv(.C) void {
    trace(.set_next_window_size, "");
}

fn mockSetNextWindowDockID(_: imgui.ContextPtr, _: c_int, _: ?*c_int) callconv(.C) void {
    trace(.set_next_window_dock_id, "");
}

fn mockIsItemHovered(_: imgui.ContextPtr, _: ?*c_int) callconv(.C) bool {
    const m = g_mock orelse return false;
    return m.double_click_targets.contains(m.last_invisible_button_label);
}

fn mockIsMouseDoubleClicked(_: imgui.ContextPtr, _: c_int) callconv(.C) bool {
    const m = g_mock orelse return false;
    return m.double_click_targets.contains(m.last_invisible_button_label);
}

fn mockIsKeyDown(_: imgui.ContextPtr, _: c_int) callconv(.C) bool {
    return false;
}

fn mockIsKeyPressed(_: imgui.ContextPtr, key: c_int, _: ?*bool) callconv(.C) bool {
    trace(.is_key_pressed, "");
    const m = g_mock orelse return false;
    return m.key_press_targets.contains(key);
}

fn mockSetKeyboardFocusHere(_: imgui.ContextPtr, _: ?*c_int) callconv(.C) void {
    trace(.set_keyboard_focus_here, "");
}

fn mockInputText(_: imgui.ContextPtr, label: [*:0]const u8, _: [*]u8, _: c_int, _: ?*c_int, _: imgui.FunctionPtr) callconv(.C) bool {
    trace(.input_text, std.mem.span(label));
    const m = g_mock orelse return false;
    return m.input_text_enter.contains(std.mem.span(label));
}

fn mockGetMouseDragDelta(_: imgui.ContextPtr, x: *f64, y: *f64, _: ?*c_int, _: ?*f64) callconv(.C) void {
    x.* = 0.0;
    y.* = 0.0;
}

fn mockResetMouseDragDelta(_: imgui.ContextPtr, _: ?*c_int) callconv(.C) void {}

fn mockGetItemRectMax(_: imgui.ContextPtr, x: *f64, y: *f64) callconv(.C) void {
    x.* = 0.0;
    y.* = 0.0;
}

fn mockGetStyleColor(_: imgui.ContextPtr, _: c_int) callconv(.C) c_int {
    return 0;
}

fn mockGetStyleVar(_: imgui.ContextPtr, _: c_int, x: *f64, y: *f64) callconv(.C) void {
    x.* = 0.0;
    y.* = 0.0;
}

fn mockGetTextLineHeightWithSpacing(_: imgui.ContextPtr) callconv(.C) f64 {
    return 20.0;
}

fn mockPushClipRect(_: imgui.ContextPtr, _: f64, _: f64, _: f64, _: f64, _: bool) callconv(.C) void {
    trace(.push_clip_rect, "");
    pushPair(.clip_rect);
}

fn mockPopClipRect(_: imgui.ContextPtr) callconv(.C) void {
    trace(.pop_clip_rect, "");
    popPair(.clip_rect);
}

fn mockSetConfigVar(_: imgui.ContextPtr, _: c_int, _: f64) callconv(.C) void {
    trace(.set_config_var, "");
}

fn mockColorConvertNative(color: c_int) callconv(.C) c_int {
    return color;
}

fn mockBeginDragDropTarget(_: imgui.ContextPtr) callconv(.C) bool {
    // Conditional: returns false, no push.
    return false;
}

fn mockEndDragDropTarget(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.drag_drop_target);
}

fn mockAcceptDragDropPayloadRGB(_: imgui.ContextPtr, _: *c_int, _: ?*c_int) callconv(.C) bool {
    return false;
}

// PushStyleVar: (ContextPtr, c_int, f64, ?*f64) void
fn mockPushStyleVar(_: imgui.ContextPtr, _: c_int, _: f64, _: ?*f64) callconv(.C) void {
    pushPair(.style_var);
}

fn mockPopStyleVar(_: imgui.ContextPtr, count: ?*c_int) callconv(.C) void {
    const n: i32 = if (count) |c| c.* else 1;
    var i: i32 = 0;
    while (i < n) : (i += 1) {
        popPair(.style_var);
    }
}

// SetNextWindowSizeConstraints: (ContextPtr, f64, f64, f64, f64, FunctionPtr) void
fn mockSetNextWindowSizeConstraints(_: imgui.ContextPtr, _: f64, _: f64, _: f64, _: f64, _: imgui.FunctionPtr) callconv(.C) void {}

// Debug panel mocks
fn mockGetFramerate(_: imgui.ContextPtr) callconv(.C) f64 {
    return 60.0;
}

fn mockBeginTable(_: imgui.ContextPtr, _: [*:0]const u8, _: c_int, _: ?*c_int, _: ?*f64, _: ?*f64, _: ?*f64) callconv(.C) bool {
    pushPair(.table);
    return true;
}

fn mockEndTable(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.table);
}

fn mockTableSetupColumn(_: imgui.ContextPtr, _: [*:0]const u8, _: ?*c_int, _: ?*f64, _: ?*c_int) callconv(.C) void {}

fn mockTextWrapped(_: imgui.ContextPtr, txt: [*:0]const u8) callconv(.C) void {
    trace(.text_wrapped, std.mem.span(txt));
}

fn mockCollapsingHeader(_: imgui.ContextPtr, _: [*:0]const u8, _: ?*bool, _: ?*c_int) callconv(.C) bool {
    return false; // collapsed by default
}

fn mockTableNextRow(_: imgui.ContextPtr, _: ?*c_int, _: ?*f64) callconv(.C) void {}

// DrawListSplitter mocks
var dummy_splitter_storage: u8 = 0;

fn mockCreateDrawListSplitter(_: imgui.DrawListPtr) callconv(.C) imgui.DrawListSplitterPtr {
    return @ptrCast(&dummy_splitter_storage);
}

fn mockDLSplitterSplit(_: imgui.DrawListSplitterPtr, _: c_int) callconv(.C) void {}
fn mockDLSplitterMerge(_: imgui.DrawListSplitterPtr) callconv(.C) void {}
fn mockDLSplitterSetChannel(_: imgui.DrawListSplitterPtr, _: c_int) callconv(.C) void {}

fn mockValidatePtr(_: *anyopaque, _: [*:0]const u8) callconv(.C) bool {
    return true; // all pointers are considered valid in tests
}

fn mockGetItemRectMin(_: imgui.ContextPtr, x: *f64, y: *f64) callconv(.C) void {
    x.* = 0.0;
    y.* = 0.0;
}

// Tab bar mocks
fn mockBeginTabBar(_: imgui.ContextPtr, _: [*:0]const u8, _: ?*c_int) callconv(.C) bool {
    pushPair(.tab_bar);
    return true;
}

fn mockEndTabBar(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.tab_bar);
}

fn mockBeginTabItem(_: imgui.ContextPtr, label: [*:0]const u8, _: ?*bool, _: ?*c_int) callconv(.C) bool {
    _ = label;
    pushPair(.tab_item);
    return true;
}

fn mockEndTabItem(_: imgui.ContextPtr) callconv(.C) void {
    popPair(.tab_item);
}

fn mockColorEdit4(_: imgui.ContextPtr, _: [*:0]const u8, _: *c_int, _: ?*c_int) callconv(.C) bool {
    return false;
}
