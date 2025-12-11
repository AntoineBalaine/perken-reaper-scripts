# Filesystem Operations Refactoring Plan

## Goal

Move `fs_ops` from a global variable in `fs_helpers.zig` to a field in the `Globals` struct, and ensure tests have actual embedded default files in their temp directories.

## Background

### Problem with Previous Approach

The original mocking approach had a schizophrenic design:
1. `FileSystemOps` interface with standalone function pointers
2. `MockFileSystem` with instance methods needing global variable bridge
3. Wrapper functions converting between the two patterns
4. Global `global_mock_fs` variable for state

This was unnecessarily complex and not idiomatic Zig.

### Revised Approach: Context-Based VTable Pattern

We refactored to use the std.mem.Allocator pattern:
- `FileSystemOps` contains `ptr: *anyopaque` and `vtable: *VTable`
- `RealFileSystem` provides production implementation
- `MockFileSystem` provides test implementation
- Both create `FileSystemOps` instances via `fileSystemOps()` method
- No wrappers or global state needed

However, we still had a global `fs_ops` variable in `fs_helpers.zig`, and tests used `std.testing.TmpDir` which writes real files.

### Final Solution

After realizing that:
1. No Zig stdlib examples mock the entire filesystem
2. The pragmatic approach is temporary directories with real I/O
3. Tests need actual embedded default files to load mappings

We decided to:
- Move `fs_ops` to `Globals` struct (like allocator pattern)
- Copy embedded default files to test temp directories
- Use real filesystem operations in temp isolation

## Implementation Steps

### Step 1: Add fs_ops field to Globals

**File:** `src/globals.zig`

Add field after line 37:
```zig
resource_path: [:0]const u8 = undefined,
fs_ops: fs_helpers.FileSystemOps = undefined,
```

Update `defaults()` (line 49):
```zig
pub fn defaults(debug_allocator: std.mem.Allocator) !Globals {
    var globals = Globals{};
    globals.arena_int = std.heap.ArenaAllocator.init(debug_allocator);
    globals.arena = globals.arena_int.allocator();
    globals.fs_ops = fs_helpers.RealFileSystem.fileSystemOps();  // ADD
    globals.resource_path = "";
    // ... rest unchanged
}
```

Update `init()` (line 70):
```zig
pub fn init() !void {
    instance = .{};
    instance.gpa_int = .{};
    instance.arena_int = .init(instance.gpa_int.allocator());
    instance.arena = instance.arena_int.allocator();
    instance.fs_ops = fs_helpers.RealFileSystem.fileSystemOps();  // ADD

    fs_helpers.ensureConfigPath(instance.fs_ops) catch {};  // CHANGE: add parameter
    // ... rest unchanged
}
```

### Step 2: Update fs_helpers function signatures

**File:** `src/fs_helpers.zig`

Update `ensureConfigPath` (line 143):
```zig
pub fn ensureConfigPath(fs_ops: FileSystemOps) !void {
```

Update `ensureDir` (line 268):
```zig
fn ensureDir(fs_ops: FileSystemOps, path: []const u8) !void {
    fs_ops.access(path, .{}) catch |err| {  // CHANGE: use parameter
        if (err == error.FileNotFound) {
            try fs_ops.makeDirAbsolute(path);  // CHANGE: use parameter
        } else {
            return err;
        }
    };
}
```

Update `ensureFile` (line 278):
```zig
fn ensureFile(fs_ops: FileSystemOps, path: []const u8, contents: []const u8) !void {
    const file = fs_ops.createFileAbsolute(path, .{ .exclusive = true }) catch |err| {  // CHANGE
        // ... rest unchanged
```

Update all calls to `ensureDir` and `ensureFile` throughout `ensureConfigPath` to pass `fs_ops` parameter.

### Step 3: Add helper to copy embedded files

**File:** `src/fs_helpers.zig`

Add after `ensureFile` function (~line 289):
```zig
/// Copy embedded default files to a target directory for testing.
/// Because tests need actual mapping files in the temp directory, we write embedded defaults there.
pub fn copyEmbeddedFilesToDir(fs_ops: FileSystemOps, target_path: []const u8) !void {
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;

    const console1_path = joinStrings(&path_buffer, &.{
        target_path, std.fs.path.sep_str, "Data", std.fs.path.sep_str,
        "Perken", std.fs.path.sep_str, "Console1"
    });

    // Create directory hierarchy
    try ensureDir(fs_ops, target_path);
    const data_path = joinStrings(&path_buffer, &.{target_path, std.fs.path.sep_str, "Data"});
    try ensureDir(fs_ops, data_path);
    const perken_path = joinStrings(&path_buffer, &.{data_path, std.fs.path.sep_str, "Perken"});
    try ensureDir(fs_ops, perken_path);
    try ensureDir(fs_ops, console1_path);

    // Write preferences
    const pref_path = joinStrings(&path_buffer, &.{console1_path, std.fs.path.sep_str, "preferences.ini"});
    try ensureFile(fs_ops, pref_path, default_preferences);

    // Create maps directory and all default mappings
    const maps_path = joinStrings(&path_buffer, &.{console1_path, std.fs.path.sep_str, "maps"});
    try ensureDir(fs_ops, maps_path);

    const structure = .{
        .{ "COMP", "VST: ReaComp (Cockos)", "default.ini", default_mappings.comp_recomp },
        .{ "EQ", "VST: ReaEQ (Cockos)", "default.ini", default_mappings.eq_reaeq },
        .{ "GATE", "VST: ReaGate (Cockos)", "default.ini", default_mappings.gate_reagate },
        .{ "INPUT", "JS: RBJ Highpass_Lowpass Filters", "default.ini", default_mappings.input.rbj },
        .{ "INPUT", "JS: Volume Adjustment", "default.ini", default_mappings.input.vol_adj },
        .{ "INPUT", "JS: Volume_Pan Smoother v5", "default.ini", default_mappings.input.vol_pan },
        .{ "OUTPT", "JS: ReaAnalog", "default.ini", default_mappings.output.analog },
        .{ "OUTPT", "JS: Saturation", "default.ini", default_mappings.output.saturation },
    };

    inline for (structure) |item| {
        const module_dir = joinStrings(&path_buffer, &.{maps_path, std.fs.path.sep_str, item[0]});
        try ensureDir(fs_ops, module_dir);

        const fx_dir = joinStrings(&path_buffer, &.{module_dir, std.fs.path.sep_str, item[1]});
        try ensureDir(fs_ops, fx_dir);

        const file_path = joinStrings(&path_buffer, &.{fx_dir, std.fs.path.sep_str, item[2]});
        try ensureFile(fs_ops, file_path, item[3]);
    }
}
```

### Step 4: Update MapStore.saveToFile

**File:** `src/mappings.zig`

Update signature (line 570):
```zig
pub fn saveToFile(
    self: *MapStore,
    fs_ops: fs_helpers.FileSystemOps,  // ADD parameter
    module: ModulesList,
    fx_name: [:0]const u8,
    mapping: TaggedMapping,
    mapping_name: [:0]const u8
) !void {
```

Update calls (lines 588, 611):
```zig
fs_ops.makeDirAbsolute(dir_path) catch |err| {  // CHANGE: use parameter
const file = try fs_ops.createFileAbsolute(path, .{  // CHANGE: use parameter
```

**File:** `src/mapping_actions.zig`

Update call site (line 395):
```zig
globals.map_store.saveToFile(
    globals.fs_ops,  // ADD parameter
    module,
    fx_name_z,
    tagged_mapping,
    mapping_name,
) catch {
```

### Step 5: Update test infrastructure

**File:** `src/tests/mapping_panel_stateful_test.zig`

Update `System` struct (line 129) - remove `old_fs_ops` field:
```zig
const System = struct {
    globals: Globals,
    allocator: std.mem.Allocator,
    mock_fs: *MockFileSystem,
    // REMOVE: old_fs_ops: fs_helpers.FileSystemOps,
```

Update `System.init` (line 135):
```zig
pub fn init(allocator: std.mem.Allocator) !System {
    const mock_fs = try allocator.create(MockFileSystem);
    mock_fs.* = try MockFileSystem.init(allocator);

    // Get temp directory absolute path
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const temp_path = try mock_fs.temp_dir.dir.realpath(".", &path_buffer);
    const temp_path_owned = try allocator.dupeZ(u8, temp_path);

    // Use real filesystem to copy embedded files to temp dir
    const real_fs = fs_helpers.RealFileSystem.fileSystemOps();
    try fs_helpers.copyEmbeddedFilesToDir(real_fs, temp_path_owned);

    // Build resource_path pointing to temp Console1 directory
    const resource_path = try std.fs.path.joinZ(allocator, &.{
        temp_path_owned, "Data", "Perken", "Console1"
    });

    // Create test Globals
    var g = try Globals.defaults(allocator);
    g.resource_path = resource_path;
    g.fs_ops = mock_fs.fileSystemOps();  // Use mock for tracking
    g.state.current_mode = .fx_ctrl;

    return System{
        .globals = g,
        .allocator = allocator,
        .mock_fs = mock_fs,
    };
}
```

Update `System.deinit` (line 163):
```zig
pub fn deinit(self: *System) void {
    // REMOVE: fs_helpers.fs_ops = self.old_fs_ops;

    self.mock_fs.deinit();
    self.allocator.destroy(self.mock_fs);

    self.globals.state.mapping_panel.deinit();
    _ = self.globals.arena_int.reset(.free_all);
}
```

### Step 6: Remove global fs_ops

**File:** `src/fs_helpers.zig`

Delete lines 67-70:
```zig
// DELETE:
/// Global filesystem operations instance.
/// Because tests need to mock filesystem operations without performing actual I/O,
/// this variable can be replaced with mock implementations during test execution.
pub var fs_ops = RealFileSystem.fileSystemOps();
```

### Step 7: Move MockFileSystem to fs_helpers

**File:** `src/fs_helpers.zig`

Add at end of file:
```zig
/// MockFileSystem for testing - tracks operations and uses temp directory
pub const MockFileSystem = struct {
    allocator: std.mem.Allocator,
    dirs_created: std.ArrayList([]const u8),
    files_created: std.ArrayList([]const u8),
    temp_dir: std.testing.TmpDir,

    pub fn init(allocator: std.mem.Allocator) !MockFileSystem {
        return MockFileSystem{
            .allocator = allocator,
            .dirs_created = std.ArrayList([]const u8).init(allocator),
            .files_created = std.ArrayList([]const u8).init(allocator),
            .temp_dir = std.testing.tmpDir(.{}),
        };
    }

    pub fn deinit(self: *MockFileSystem) void {
        for (self.dirs_created.items) |dir| {
            self.allocator.free(dir);
        }
        self.dirs_created.deinit();

        for (self.files_created.items) |file| {
            self.allocator.free(file);
        }
        self.files_created.deinit();

        self.temp_dir.cleanup();
    }

    fn makeDirAbsolute(ptr: *anyopaque, path: []const u8) !void {
        const self: *MockFileSystem = @ptrCast(@alignCast(ptr));
        const owned = try self.allocator.dupe(u8, path);
        try self.dirs_created.append(owned);
    }

    fn createFileAbsolute(ptr: *anyopaque, path: []const u8, flags: std.fs.File.CreateFlags) !std.fs.File {
        const self: *MockFileSystem = @ptrCast(@alignCast(ptr));
        const owned_path = try self.allocator.dupe(u8, path);
        try self.files_created.append(owned_path);

        const file = try self.temp_dir.dir.createFile("test_file", flags);
        return file;
    }

    fn access(ptr: *anyopaque, path: []const u8, flags: std.fs.File.OpenFlags) !void {
        _ = ptr;
        _ = path;
        _ = flags;
    }

    const vtable = FileSystemOps.VTable{
        .makeDirAbsolute = makeDirAbsolute,
        .createFileAbsolute = createFileAbsolute,
        .access = access,
    };

    pub fn fileSystemOps(self: *MockFileSystem) FileSystemOps {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }
};
```

**File:** `src/tests/mapping_panel_stateful_test.zig`

Remove `MockFileSystem` definition (lines 21-89) and update import:
```zig
const MockFileSystem = fs_helpers.MockFileSystem;
```

## Order of Operations

1. Step 1: Add fs_ops to Globals
2. Step 2: Update fs_helpers signatures
3. Step 3: Add copyEmbeddedFilesToDir helper
4. Step 5: Update test infrastructure
5. Step 4: Update MapStore.saveToFile and call sites
6. Step 6: Remove global fs_ops
7. Step 7: Move MockFileSystem to fs_helpers

## Critical Files

- `src/globals.zig` - Add fs_ops field, update init/defaults
- `src/fs_helpers.zig` - Update signatures, add helper, remove global, add MockFileSystem
- `src/mappings.zig` - Update saveToFile signature
- `src/mapping_actions.zig` - Update call site
- `src/tests/mapping_panel_stateful_test.zig` - Update test setup

## Key Design Decisions

### Why fs_ops in Globals?

Matches Zig idiom of storing context objects (like allocators) in struct fields rather than passing as parameters everywhere. This provides:
- Single swap point for tests
- Clearer lifetime management
- Less parameter threading

### Why temp directories with real I/O?

After researching Zig stdlib patterns:
- No examples of fully mocked filesystem interfaces
- std.testing.TmpDir is the idiomatic approach
- Pragmatic: provides isolation without complex mocking infrastructure
- Tests can verify actual file operations and content

### Why copy embedded files to temp dir?

Tests need to load actual default mappings to verify the full workflow. Without real files, tests would skip critical validation of mapping loading logic.
