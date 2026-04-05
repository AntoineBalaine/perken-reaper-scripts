# reaziglib

Shared Zig modules for building REAPER extensions with ReaImGui.

## Modules

### Core

| Module         | Description                                                      |
|----------------|------------------------------------------------------------------|
| `reaper`       | REAPER C API bindings (function pointers, opaque types)          |
| `reaper_imgui` | ReaImGui bindings                                                |
| `utils`        | Volume/pan conversion, GUID handling, CC delta helpers, StringPool |

### FX

| Module               | Description                               |
|----------------------|-------------------------------------------|
| `fx_parser`          | FX plugin enumeration (VST, AU, JS, CLAP) |
| `fx_parser_types`    | Type definitions for fx_parser            |
| `preset_file_reader` | REAPER preset INI reader                  |

### UI

| Module         | Description                               |
|----------------|-------------------------------------------|
| `knob`         | Knob widget for ReaImGui                  |
| `colorHelpers` | Color utilities (HSV, contrast, blending) |

### Helpers

| Module        | Description                                               |
|---------------|-----------------------------------------------------------|
| `fs_helpers`  | Buffer-based path utilities (joinStrings, sanitizeFxName) |
| `string_pool` | Interned string deduplication                             |
| `Translator`  | Translation file loader                                   |

### Testing

| Module        | Description                                               |
|---------------|-----------------------------------------------------------|
| `mock_imgui`  | ReaImGui mock that records widget calls into a trace list |
| `reaper_mock` | REAPER API mock with a Session model for stateful testing |

### Model types

| Module            | Description                                                   |
|-------------------|---------------------------------------------------------------|
| `session`         | Mock session state (tracks, FX, selection)                    |
| `track_model`     | Track struct (name, FX list, automation mode, info)           |
| `fx_model`        | FX and Param structs                                          |
| `automation_mode` | REAPER automation mode enum (trim, read, touch, latch, write) |

## Usage

Add reaziglib to your `build.zig.zon`:

```zig
.reaziglib = .{
    .url = "https://github.com/AntoineBalaine/reaziglib/archive/<commit>.tar.gz",
    .hash = "<hash>",
},
```

Get the hash with:

```
zig fetch https://github.com/AntoineBalaine/reaziglib/archive/<commit>.tar.gz
```

Then in your `build.zig`, wire all modules at once:

```zig
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });

    const lib = b.addSharedLibrary(.{ ... });
    lib.linkLibC();

    reaziglib.addSharedModules(reazig_dep, lib.root_module);
}
```

Or pick individual modules:

```zig
const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });
lib.root_module.addImport("reaper", reazig_dep.module("reaper"));
lib.root_module.addImport("reaper_imgui", reazig_dep.module("reaper_imgui"));
```

Then in your Zig source files:

```zig
const reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
```

## Example

The `example/` directory contains a minimal REAPER extension that loads and prints a message to the console. To build it:

```
cd example
zig build
```

The output is `zig-out/lib/reaper_hello.so` (or `.dylib` on macOS). Copy it to your REAPER `UserPlugins` directory and restart REAPER.

## License

LGPL-3.0-or-later. See `COPYING` and `COPYING.LESSER`.
