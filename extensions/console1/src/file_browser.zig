const std = @import("std");
const imgui = @import("reaper_imgui");
const styles = @import("styles.zig");

pub const FileBrowserMode = enum {
    load,
    save,
};

pub const FileBrowserResult = union(enum) {
    selected: []const u8,
    cancelled: void,
};

pub const FileBrowserState = struct {
    root_path: []const u8,
    current_path: []const u8,
    entries_dirs: std.ArrayListUnmanaged([:0]const u8),
    entries_files: std.ArrayListUnmanaged([:0]const u8),
    selected_entry: ?[:0]const u8,
    selected_is_dir: bool,
    name_buffer: [512:0]u8,
    mode: FileBrowserMode,
    extensions: []const []const u8,
    show_overwrite_confirm: bool,
    arena: std.heap.ArenaAllocator,
    backing_allocator: std.mem.Allocator,

    // Creates a new file browser state. Because the returned struct contains an arena
    // that stores root_path and current_path, the caller should call refresh() after
    // the struct is stored at its final memory location if the struct will be moved
    // (e.g., assigned into a union field). For direct use without moving, use initAndRefresh.
    pub fn init(
        allocator: std.mem.Allocator,
        root_path: []const u8,
        mode: FileBrowserMode,
        extensions: []const []const u8,
    ) FileBrowserState {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_alloc = arena.allocator();

        const root_copy = arena_alloc.dupeZ(u8, root_path) catch @panic("FileBrowserState.init: OOM");
        const current_copy = arena_alloc.dupeZ(u8, root_path) catch @panic("FileBrowserState.init: OOM");

        return FileBrowserState{
            .root_path = root_copy,
            .current_path = current_copy,
            .entries_dirs = .{},
            .entries_files = .{},
            .selected_entry = null,
            .selected_is_dir = false,
            .name_buffer = std.mem.zeroes([512:0]u8),
            .mode = mode,
            .extensions = extensions,
            .show_overwrite_confirm = false,
            .arena = arena,
            .backing_allocator = allocator,
        };
    }

    // Convenience constructor that immediately populates the directory listing.
    // Because this calls refresh() before returning, the returned struct should
    // be used directly without being moved to another memory location.
    pub fn initAndRefresh(
        allocator: std.mem.Allocator,
        root_path: []const u8,
        mode: FileBrowserMode,
        extensions: []const []const u8,
    ) FileBrowserState {
        var state = init(allocator, root_path, mode, extensions);
        state.refresh();
        return state;
    }

    pub fn deinit(self: *FileBrowserState) void {
        // Because entries_dirs/entries_files may have zero capacity (if refresh() was
        // never called or the directory didn't exist), we only free when capacity > 0
        // to avoid freeing a zero-length slice from the empty default init.
        if (self.entries_dirs.capacity > 0) self.entries_dirs.deinit(self.backing_allocator);
        if (self.entries_files.capacity > 0) self.entries_files.deinit(self.backing_allocator);
        self.arena.deinit();
    }

    pub fn refresh(self: *FileBrowserState) void {
        // Because the arena holds all our strings (including root_path and current_path),
        // we need to preserve those values before resetting the arena.
        var root_buf: [std.fs.max_path_bytes]u8 = undefined;
        var current_buf: [std.fs.max_path_bytes]u8 = undefined;
        const root_len = self.root_path.len;
        const current_len = self.current_path.len;
        @memcpy(root_buf[0..root_len], self.root_path);
        @memcpy(current_buf[0..current_len], self.current_path);

        _ = self.arena.reset(.retain_capacity);
        const arena_alloc = self.arena.allocator();

        self.root_path = arena_alloc.dupeZ(u8, root_buf[0..root_len]) catch @panic("refresh: OOM");
        self.current_path = arena_alloc.dupeZ(u8, current_buf[0..current_len]) catch @panic("refresh: OOM");

        self.entries_dirs.clearRetainingCapacity();
        self.entries_files.clearRetainingCapacity();
        self.selected_entry = null;

        var dir = std.fs.openDirAbsolute(self.current_path, .{ .iterate = true }) catch return;
        defer dir.close();

        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            // Skip hidden entries (those starting with '.')
            if (entry.name.len > 0 and entry.name[0] == '.') continue;

            const name_z = arena_alloc.dupeZ(u8, entry.name) catch continue;

            switch (entry.kind) {
                .directory => {
                    self.entries_dirs.append(self.backing_allocator, name_z) catch continue;
                },
                .file => {
                    if (self.matchesExtension(entry.name)) {
                        self.entries_files.append(self.backing_allocator, name_z) catch continue;
                    }
                },
                else => {},
            }
        }

        // Sort both lists case-insensitively
        sortEntries(self.entries_dirs.items);
        sortEntries(self.entries_files.items);
    }

    pub fn navigateInto(self: *FileBrowserState, dir_name: [:0]const u8) void {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const new_path = std.fmt.bufPrint(&path_buf, "{s}" ++ &[_]u8{std.fs.path.sep} ++ "{s}", .{ self.current_path, dir_name }) catch return;

        const arena_alloc = self.arena.allocator();
        self.current_path = arena_alloc.dupeZ(u8, new_path) catch return;
        self.refresh();
    }

    pub fn navigateUp(self: *FileBrowserState) void {
        if (self.isAtRoot()) return;

        const parent = std.fs.path.dirname(self.current_path) orelse return;
        const arena_alloc = self.arena.allocator();
        self.current_path = arena_alloc.dupeZ(u8, parent) catch return;
        self.refresh();
    }

    pub fn navigateTo(self: *FileBrowserState, absolute_path: []const u8) void {
        std.debug.assert(std.mem.startsWith(u8, absolute_path, self.root_path));

        const arena_alloc = self.arena.allocator();
        self.current_path = arena_alloc.dupeZ(u8, absolute_path) catch return;
        self.refresh();
    }

    pub fn isAtRoot(self: *const FileBrowserState) bool {
        return std.mem.eql(u8, self.current_path, self.root_path);
    }

    pub fn getRelativePath(self: *const FileBrowserState) []const u8 {
        if (self.current_path.len <= self.root_path.len) return "";
        // Skip the root_path prefix and the separator that follows it
        return self.current_path[self.root_path.len + 1 ..];
    }

    fn matchesExtension(self: *const FileBrowserState, name: []const u8) bool {
        for (self.extensions) |ext| {
            if (std.mem.eql(u8, ext, ".*")) return true;
            if (std.mem.endsWith(u8, name, ext)) return true;
        }
        return false;
    }

    fn sortEntries(items: [][:0]const u8) void {
        std.mem.sort([:0]const u8, items, {}, caseInsensitiveLessThan);
    }

    fn caseInsensitiveLessThan(_: void, a: [:0]const u8, b: [:0]const u8) bool {
        const min_len = @min(a.len, b.len);
        for (a[0..min_len], b[0..min_len]) |ca, cb| {
            const la = std.ascii.toLower(ca);
            const lb = std.ascii.toLower(cb);
            if (la != lb) return la < lb;
        }
        return a.len < b.len;
    }
};

// -- Rendering --

const PathSegments = struct {
    segments: [64][]const u8,
    count: usize,
};

fn splitPath(path: []const u8) PathSegments {
    var result = PathSegments{
        .segments = undefined,
        .count = 0,
    };

    var iter = std.mem.splitScalar(u8, path, std.fs.path.sep);
    while (iter.next()) |segment| {
        if (segment.len == 0) continue;
        if (result.count >= 64) break;
        result.segments[result.count] = segment;
        result.count += 1;
    }
    return result;
}

fn drawBreadcrumbs(ctx: imgui.ContextPtr, state: *FileBrowserState) !void {
    // Because the breadcrumbs show the full current_path but the user should only
    // be able to navigate within the root_path boundary, we determine which segment
    // index corresponds to the root_path and only make segments at or below that
    // level clickable.
    const root_info = splitPath(state.root_path);
    const root_segment_count = root_info.count;

    const path_info = splitPath(state.current_path);
    const segments = path_info.segments[0..path_info.count];

    var fp_x: f64 = 0;
    var fp_y: f64 = 0;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &fp_x, &fp_y });
    try imgui.PushStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, 0, @as(f64, 0) });
    try imgui.PushStyleVar(.{ ctx, imgui.StyleVar_FramePadding, 0, fp_y });
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Button, @as(c_int, 0) });
    defer {
        imgui.PopStyleVar(.{ ctx, @as(c_int, 2) }) catch {};
        imgui.PopStyleColor(.{ctx}) catch {};
    }

    var win_x: f64 = 0;
    var win_y: f64 = 0;
    var content_max_x: f64 = 0;
    var content_max_y: f64 = 0;
    try imgui.GetWindowPos(.{ ctx, &win_x, &win_y });
    try imgui.GetWindowContentRegionMax(.{ ctx, &content_max_x, &content_max_y });
    const window_x2 = win_x + content_max_x;

    for (segments, 0..) |segment, i| {
        var label_buf: [256:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&label_buf, "{s}/", .{segment}) catch continue;

        // Segments above the root_path are shown as plain text (not clickable),
        // and the last segment (current directory) is also not clickable because
        // navigating to it would be a no-op.
        const is_clickable = i >= root_segment_count and i < segments.len - 1;

        if (is_clickable) {
            if (try imgui.Button(.{ ctx, label })) {
                var reconstruct_buf: [std.fs.max_path_bytes]u8 = undefined;
                var pos: usize = 0;
                if (state.current_path.len > 0 and state.current_path[0] == std.fs.path.sep) {
                    reconstruct_buf[0] = std.fs.path.sep;
                    pos = 1;
                }
                for (segments[0 .. i + 1], 0..) |seg, j| {
                    if (j > 0) {
                        reconstruct_buf[pos] = std.fs.path.sep;
                        pos += 1;
                    }
                    @memcpy(reconstruct_buf[pos .. pos + seg.len], seg);
                    pos += seg.len;
                }
                state.navigateTo(reconstruct_buf[0..pos]);
            }
        } else {
            try imgui.Text(.{ ctx, label });
        }

        // Because we want items to flow on the same line when they fit,
        // we check if the next item would overflow the window width.
        if (i + 1 < segments.len) {
            var next_label_buf: [256:0]u8 = undefined;
            const next_label = std.fmt.bufPrintZ(&next_label_buf, "{s}/", .{segments[i + 1]}) catch continue;
            var next_w: f64 = 0;
            var next_h: f64 = 0;
            try imgui.CalcTextSize(.{ ctx, next_label, &next_w, &next_h });
            var button_x2: f64 = 0;
            var button_y2: f64 = 0;
            try imgui.GetItemRectMax(.{ ctx, &button_x2, &button_y2 });
            if (button_x2 + next_w + 10 < window_x2) {
                try imgui.SameLine(.{ctx});
            }
        }
    }
}

fn drawFileList(ctx: imgui.ContextPtr, state: *FileBrowserState) !?FileBrowserResult {
    var result: ?FileBrowserResult = null;

    // Because navigateInto/navigateUp call refresh() which invalidates the
    // entries we're iterating over, we must defer navigation until after the
    // list rendering loop completes.
    var pending_navigate_into: ?[:0]const u8 = null;
    var pending_navigate_up = false;

    // Because the bottom bar needs space for buttons plus padding, we reserve
    // enough height (frame height + spacing).
    var fp_y: f64 = 0;
    var sp_y: f64 = 0;
    {
        var fp_x: f64 = 0;
        try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &fp_x, &fp_y });
        var sp_x: f64 = 0;
        try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &sp_x, &sp_y });
    }
    const font_size = try imgui.GetFontSize(.{ctx});
    const bottom_reserve = font_size + fp_y * 2 + sp_y * 2 + 10;

    if (try imgui.BeginListBox(.{ ctx, "##file_list", @as(f64, -1), -bottom_reserve })) {
        defer imgui.EndListBox(.{ctx}) catch {};

        // Show ".." only when we are deeper than the root
        if (!state.isAtRoot()) {
            var dotdot_sel = false;
            if (try imgui.Selectable(.{ ctx, "..", &dotdot_sel, imgui.SelectableFlags_AllowDoubleClick })) {
                if (try imgui.IsMouseDoubleClicked(.{ ctx, 0 })) {
                    pending_navigate_up = true;
                }
            }
        }

        // Directories first
        for (state.entries_dirs.items) |dir_name| {
            var is_selected = if (state.selected_entry) |sel| std.mem.eql(u8, sel, dir_name) else false;
            if (try imgui.Selectable(.{ ctx, dir_name.ptr, &is_selected, imgui.SelectableFlags_AllowDoubleClick })) {
                state.selected_entry = dir_name;
                state.selected_is_dir = true;
                copyToNameBuffer(&state.name_buffer, dir_name);
                if (try imgui.IsMouseDoubleClicked(.{ ctx, 0 })) {
                    pending_navigate_into = dir_name;
                }
            }
        }

        // Then files
        for (state.entries_files.items) |file_name| {
            var is_selected = if (state.selected_entry) |sel| std.mem.eql(u8, sel, file_name) else false;
            if (try imgui.Selectable(.{ ctx, file_name.ptr, &is_selected, imgui.SelectableFlags_AllowDoubleClick })) {
                state.selected_entry = file_name;
                state.selected_is_dir = false;
                copyNameWithoutExtension(&state.name_buffer, file_name);
                if (try imgui.IsMouseDoubleClicked(.{ ctx, 0 })) {
                    if (state.mode == .load) {
                        result = FileBrowserResult{ .selected = buildFullPath(state, file_name) };
                    } else {
                        result = trySave(state, file_name);
                    }
                }
            }
        }
    }

    // Because we deferred navigation to avoid invalidating entries during iteration,
    // we execute it now that the list rendering is complete.
    if (pending_navigate_up) {
        state.navigateUp();
    } else if (pending_navigate_into) |dir_name| {
        state.navigateInto(dir_name);
    }

    return result;
}

fn drawBottomBar(ctx: imgui.ContextPtr, state: *FileBrowserState) !?FileBrowserResult {
    // Text input -- disabled in load mode
    if (state.mode == .load) try imgui.BeginDisabled(.{ctx});
    try imgui.SetNextItemWidth(.{ ctx, @as(f64, -203) });
    _ = try imgui.InputText(.{
        ctx,
        "##filename",
        @as([*]u8, @ptrCast(&state.name_buffer)),
        @as(c_int, @intCast(state.name_buffer.len)),
    });
    if (state.mode == .load) try imgui.EndDisabled(.{ctx});

    try imgui.SameLine(.{ctx});

    // Action button
    if (state.mode == .load) {
        const has_selection = state.selected_entry != null;
        if (!has_selection) try imgui.BeginDisabled(.{ctx});
        if (try imgui.Button(.{ ctx, "Open" })) {
            if (state.selected_entry) |sel| {
                if (state.selected_is_dir) {
                    state.navigateInto(sel);
                } else {
                    return FileBrowserResult{ .selected = buildFullPath(state, sel) };
                }
            }
        }
        if (!has_selection) try imgui.EndDisabled(.{ctx});

        // Enter key triggers the action
        if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Enter })) {
            if (state.selected_entry) |sel| {
                if (state.selected_is_dir) {
                    state.navigateInto(sel);
                } else {
                    return FileBrowserResult{ .selected = buildFullPath(state, sel) };
                }
            }
        }
    } else {
        const name_span = std.mem.span(@as([*:0]const u8, @ptrCast(&state.name_buffer)));
        const name_empty = name_span.len == 0;
        if (name_empty) try imgui.BeginDisabled(.{ctx});
        if (try imgui.Button(.{ ctx, "Save" })) {
            return trySaveFromNameBuffer(state);
        }
        if (!state.show_overwrite_confirm) {
            if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Enter })) {
                if (!name_empty) return trySaveFromNameBuffer(state);
            }
        }
        if (name_empty) try imgui.EndDisabled(.{ctx});
    }

    try imgui.SameLine(.{ctx});

    if (try imgui.Button(.{ ctx, "Cancel" })) {
        return FileBrowserResult{ .cancelled = {} };
    }

    if (!state.show_overwrite_confirm) {
        if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Escape })) {
            return FileBrowserResult{ .cancelled = {} };
        }
    }

    return null;
}

fn drawOverwritePopup(ctx: imgui.ContextPtr, state: *FileBrowserState) !?FileBrowserResult {
    if (state.show_overwrite_confirm) {
        try imgui.OpenPopup(.{ ctx, "Overwrite?" });
        state.show_overwrite_confirm = false;
    }

    var rv: ?FileBrowserResult = null;
    if (try imgui.BeginPopup(.{ ctx, "Overwrite?" })) {
        defer imgui.EndPopup(.{ctx}) catch {};

        const name_span = std.mem.span(@as([*:0]const u8, @ptrCast(&state.name_buffer)));
        var msg_buf: [512:0]u8 = undefined;
        const msg = std.fmt.bufPrintZ(&msg_buf, "'{s}' already exists. Overwrite?", .{name_span}) catch "File already exists. Overwrite?";
        try imgui.Text(.{ ctx, msg });
        try imgui.Separator(.{ctx});

        if (try imgui.Button(.{ ctx, "OK" })) {
            rv = FileBrowserResult{ .selected = buildFullPathFromNameBuffer(state) };
            try imgui.CloseCurrentPopup(.{ctx});
        }
        try imgui.SameLine(.{ctx});
        if (try imgui.Button(.{ ctx, "Cancel" })) {
            try imgui.CloseCurrentPopup(.{ctx});
        }
    }
    return rv;
}

pub fn drawFileBrowser(
    ctx: imgui.ContextPtr,
    state: *FileBrowserState,
    style_manager: *styles.StyleManager,
) !?FileBrowserResult {
    // Because the file browser renders inside a BeginChild region in gui_lib.zig
    // where the theme already applies the correct text and background colors,
    // we do not push an additional window style here. Pushing .main would
    // override the theme's text color with a dark value that is invisible
    // against the dark background.
    _ = style_manager;

    try drawBreadcrumbs(ctx, state);
    try imgui.Separator(.{ctx});

    if (try drawFileList(ctx, state)) |result| return result;

    if (try drawBottomBar(ctx, state)) |result| return result;

    if (try drawOverwritePopup(ctx, state)) |result| return result;

    return null;
}

// -- Helpers --

fn copyToNameBuffer(buf: *[512:0]u8, name: [:0]const u8) void {
    const len = @min(name.len, buf.len - 1);
    @memcpy(buf[0..len], name[0..len]);
    buf[len] = 0;
    // Zero the rest to avoid stale data
    @memset(buf[len + 1 ..], 0);
}

fn copyNameWithoutExtension(buf: *[512:0]u8, name: [:0]const u8) void {
    const stem = std.fs.path.stem(name);
    const len = @min(stem.len, buf.len - 1);
    @memcpy(buf[0..len], stem[0..len]);
    buf[len] = 0;
    @memset(buf[len + 1 ..], 0);
}

fn buildFullPath(state: *FileBrowserState, file_name: []const u8) []const u8 {
    const arena_alloc = state.arena.allocator();
    const sep = &[_]u8{std.fs.path.sep};
    const full = std.mem.concat(arena_alloc, u8, &.{ state.current_path, sep, file_name }) catch return state.current_path;
    return full;
}

fn buildFullPathFromNameBuffer(state: *FileBrowserState) []const u8 {
    const name_span = std.mem.span(@as([*:0]const u8, @ptrCast(&state.name_buffer)));
    // Because the user may not have typed an extension, we append the first extension if needed
    var name_with_ext_buf: [768]u8 = undefined;
    var name_to_use: []const u8 = name_span;
    if (state.extensions.len > 0 and !std.mem.eql(u8, state.extensions[0], ".*")) {
        const ext = state.extensions[0];
        if (!std.mem.endsWith(u8, name_span, ext)) {
            const result = std.fmt.bufPrint(&name_with_ext_buf, "{s}{s}", .{ name_span, ext }) catch name_span;
            name_to_use = result;
        }
    }
    return buildFullPath(state, name_to_use);
}

fn trySave(state: *FileBrowserState, file_name: [:0]const u8) ?FileBrowserResult {
    // Because the file already exists in the listing, we trigger overwrite confirmation
    _ = file_name;
    state.show_overwrite_confirm = true;
    return null;
}

fn trySaveFromNameBuffer(state: *FileBrowserState) ?FileBrowserResult {
    const name_span = std.mem.span(@as([*:0]const u8, @ptrCast(&state.name_buffer)));
    // Check if a file with this name (with extension) already exists
    var name_with_ext_buf: [768:0]u8 = std.mem.zeroes([768:0]u8);
    var name_to_check: []const u8 = name_span;
    if (state.extensions.len > 0 and !std.mem.eql(u8, state.extensions[0], ".*")) {
        const ext = state.extensions[0];
        if (!std.mem.endsWith(u8, name_span, ext)) {
            const result = std.fmt.bufPrint(&name_with_ext_buf, "{s}{s}", .{ name_span, ext }) catch name_span;
            name_to_check = result;
        }
    }

    for (state.entries_files.items) |existing| {
        if (std.mem.eql(u8, existing, name_to_check)) {
            state.show_overwrite_confirm = true;
            return null;
        }
    }

    return FileBrowserResult{ .selected = buildFullPathFromNameBuffer(state) };
}

// -- Tests --

test "init populates entries from a temp directory" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create test files and directories
    tmp.dir.makeDir("subdir_a") catch unreachable;
    tmp.dir.makeDir("subdir_b") catch unreachable;
    (tmp.dir.createFile("file1.txt", .{}) catch unreachable).close();
    (tmp.dir.createFile("file2.txt", .{}) catch unreachable).close();
    (tmp.dir.createFile("file3.wav", .{}) catch unreachable).close();

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    const extensions = &[_][]const u8{".txt"};
    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, extensions);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 2), state.entries_dirs.items.len);
    // Because we filter by .txt, only 2 files should appear (not the .wav)
    try std.testing.expectEqual(@as(usize, 2), state.entries_files.items.len);
}

test "navigateInto changes current path and refreshes" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    tmp.dir.makeDir("child") catch unreachable;
    tmp.dir.makeDir("child/grandchild") catch unreachable;

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".*"});
    defer state.deinit();

    try std.testing.expect(!std.mem.eql(u8, state.current_path, state.root_path) == false);
    state.navigateInto("child");
    try std.testing.expect(!state.isAtRoot());
    try std.testing.expectEqual(@as(usize, 1), state.entries_dirs.items.len);
    try std.testing.expectEqualStrings("grandchild", state.entries_dirs.items[0]);
}

test "navigateUp strips last component" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    tmp.dir.makeDir("child") catch unreachable;

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".*"});
    defer state.deinit();

    state.navigateInto("child");
    try std.testing.expect(!state.isAtRoot());

    state.navigateUp();
    try std.testing.expect(state.isAtRoot());
}

test "navigateUp at root is a no-op" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".*"});
    defer state.deinit();

    const path_before = state.current_path;
    state.navigateUp();
    try std.testing.expectEqualStrings(path_before, state.current_path);
}

test "isAtRoot returns true at root and false after navigateInto" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    tmp.dir.makeDir("sub") catch unreachable;

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".*"});
    defer state.deinit();

    try std.testing.expect(state.isAtRoot());
    state.navigateInto("sub");
    try std.testing.expect(!state.isAtRoot());
}

test "extension filtering only shows matching files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    (tmp.dir.createFile("song.wav", .{}) catch unreachable).close();
    (tmp.dir.createFile("notes.txt", .{}) catch unreachable).close();
    (tmp.dir.createFile("preset.rfxchain", .{}) catch unreachable).close();

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    const extensions = &[_][]const u8{".wav"};
    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, extensions);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 1), state.entries_files.items.len);
    try std.testing.expectEqualStrings("song.wav", state.entries_files.items[0]);
}

test "wildcard extension shows all files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    (tmp.dir.createFile("a.txt", .{}) catch unreachable).close();
    (tmp.dir.createFile("b.wav", .{}) catch unreachable).close();

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".*"});
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 2), state.entries_files.items.len);
}

test "hidden entries are skipped" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    (tmp.dir.createFile(".hidden", .{}) catch unreachable).close();
    (tmp.dir.createFile("visible.txt", .{}) catch unreachable).close();
    tmp.dir.makeDir(".hidden_dir") catch unreachable;
    tmp.dir.makeDir("visible_dir") catch unreachable;

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".*"});
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 1), state.entries_dirs.items.len);
    try std.testing.expectEqual(@as(usize, 1), state.entries_files.items.len);
    try std.testing.expectEqualStrings("visible_dir", state.entries_dirs.items[0]);
    try std.testing.expectEqualStrings("visible.txt", state.entries_files.items[0]);
}

test "entries are sorted case-insensitively" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    (tmp.dir.createFile("Zebra.txt", .{}) catch unreachable).close();
    (tmp.dir.createFile("apple.txt", .{}) catch unreachable).close();
    (tmp.dir.createFile("Banana.txt", .{}) catch unreachable).close();

    const root_path = tmp.dir.realpathAlloc(std.testing.allocator, ".") catch unreachable;
    defer std.testing.allocator.free(root_path);

    var state = FileBrowserState.initAndRefresh(std.testing.allocator, root_path, .load, &.{".txt"});
    defer state.deinit();

    try std.testing.expectEqualStrings("apple.txt", state.entries_files.items[0]);
    try std.testing.expectEqualStrings("Banana.txt", state.entries_files.items[1]);
    try std.testing.expectEqualStrings("Zebra.txt", state.entries_files.items[2]);
}

test "splitPath splits correctly" {
    const result = splitPath("/Users/test/Documents/folder");
    try std.testing.expectEqual(@as(usize, 4), result.count);
    try std.testing.expectEqualStrings("Users", result.segments[0]);
    try std.testing.expectEqualStrings("test", result.segments[1]);
    try std.testing.expectEqualStrings("Documents", result.segments[2]);
    try std.testing.expectEqualStrings("folder", result.segments[3]);
}

test "copyNameWithoutExtension strips extension" {
    var buf: [512:0]u8 = std.mem.zeroes([512:0]u8);
    copyNameWithoutExtension(&buf, "preset.rfxchain");
    const result = std.mem.span(@as([*:0]const u8, @ptrCast(&buf)));
    try std.testing.expectEqualStrings("preset", result);
}

test {
    std.testing.refAllDecls(@This());
}

test "repeated init-refresh-deinit cycle does not corrupt memory" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    tmp.dir.makeDir("sub") catch unreachable;
    (tmp.dir.createFile("test.ini", .{}) catch unreachable).close();

    const root_path = tmp.dir.realpathAlloc(allocator, ".") catch unreachable;
    defer allocator.free(root_path);

    // Simulate the enter_save/save_cancel cycle that happens in the stateful test
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var state = FileBrowserState.init(allocator, root_path, .save, &.{".ini"});
        state.refresh();
        state.deinit();
    }
}
