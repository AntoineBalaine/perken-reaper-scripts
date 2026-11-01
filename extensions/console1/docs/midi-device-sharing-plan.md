# Sharing the MIDI device code of the surfaces

## Goal

Because REAPER numbers its MIDI devices from a list that goes stale, the Console 1 surface and the MFT surface both find their devices again by a key that they save in their config string. The code that does this was written for Console 1 and then copied for the MFT, and the VR-09 plugin has its own copy of the part that reads the name of a device. After this change each piece of that code exists once in `extensions/reaziglib`, and the three extensions use it.

## What exists today

Four places call `GetMIDIInputName` and `GetMIDIOutputName` with the same sequence (choose the function from a flag, zero the buffer, call, cut at the first NUL):

| Place | What it is |
|---|---|
| `console1/src/csurf/control_surface.zig`, `ReaperDevices.name` | The lookup for `midi_device_names.find`. A false answer from REAPER gives null. |
| `console1/src/csurf/control_surface.zig`, `deviceName(buf: *[128:0]u8, input: bool, dev: c_int) []const u8` | The name for the log. It repeats the call, returns `""` under `builtin.is_test`, and returns `"?"` when REAPER answers false. |
| `console1/src/mft/csurf/control_surface_mft.zig`, `ReaperDevices.name` | A copy of the first one. |
| `vr09/src/reaper_glue.zig`, `deviceName(dir: Direction, index: usize, buf: []u8) ?[]const u8` | The name for the track routing. A false answer still gives the name, because REAPER answers false for a device that is closed but valid, such as a JACK port. It gives null only for an empty name. |

The module `console1/src/csurf/midi_device_names.zig` (182 lines, depends on `std` only) is not in reaziglib. Because of that, `console1/build.zig` creates it by hand: line 249 makes `device_names_mod` for the `reaper_mft` library, line 250 imports it, and line 328 imports it in the `mft_test` step. The Console 1 library imports it by file path, and its tests run from line 92 of `console1/src/console1_extension.zig`.

The two surfaces share about 175 lines that are copies: `ReaperDevices`, the key buffers and `setKey`, `resolveDevice`, `keyOfDevice`, `parseDeviceKeys`, the part of `createFunc` that resolves and remembers the keys, `sendDlgItemMessage`, `makeIntResource`, `parseParms`, `configFunc`, and the two blocks of `dlgProc` (`WM_INITDIALOG` fills the combo boxes, `WM_USER + 1024` writes the config string). Both write the config as `"0 0 {in} {out} {in key} {out key}"`.

## Decisions

- The VR-09 plugin saves no device number in a config string, so it does not use `midi_device_names`. It only uses the shared name lookup.
- Because the surfaces and VR-09 want different answers for a device that REAPER reports as closed, the shared lookup takes that choice as an argument.
- Because the two surfaces log under different scopes and each keeps its own device keys, the shared module is a function of a comptime scope that returns a type (step 3). Each surface instantiates it with its own scope, so the logs keep their scopes, and the state that the callbacks of REAPER reach without a context pointer is distinct per surface.
- The `c` module stays in `console1/build.zig`, and the dialog stays in console1 (step 4), because the module mixes the WDL and SWELL types with the C++ wrappers and the dialog ids of console1, and reaziglib has no WDL dependency.

## To do

- [ ] Step 0: create and move every file of the plan in one command.
- [ ] Step 1: add `deviceName` to `reaper_helpers.zig`, with its test, and use it in the four places.
- [ ] Step 2: register `midi_device_names` in reaziglib and delete the hand-made module of `console1/build.zig`.
- [ ] Step 3: fill `midi_device_config.zig` and use it in both surfaces.
- [ ] Step 4: fill `midi_device_dialog.zig` and use it in both surfaces.
- [ ] Final check: search for the leftover calls, and open both configuration windows in REAPER.

Every step ends with a commit that builds and passes its tests, with the prefix `reaziglib:` for steps 1 to 3 and `console1:` for step 4. Before each commit we run `zig fmt` on every file that we edited.

## Step 0: the files

One bash command does all of this before any edit, from `extensions/`:

```
git mv console1/src/csurf/midi_device_names.zig reaziglib/src/midi_device_names.zig
create reaziglib/src/midi_device_config.zig        (empty, header comment only)
create console1/src/csurf/midi_device_dialog.zig   (empty, header comment only)
```

Because an empty file that nothing imports does not compile into anything, the build stays green until the steps fill them. The edits of step 2 must follow the move at once, since the move breaks the two imports of the old path.

## Step 1: the shared name lookup

In `reaziglib/src/reaper_helpers.zig`, which already has `const Reaper = @import("reaper").reaper;`, add:

```
/// Copies the name of a MIDI device into buf and returns it.
/// closed_counts tells what a false answer of REAPER means:
///   false: the device is not there, the result is null (the surfaces)
///   true:  REAPER answers false for a closed device that has a name, so the name counts (VR-09)
/// In both cases an empty name is null.
pub fn deviceName(buf: []u8, input: bool, dev: c_int, closed_counts: bool) ?[]const u8
    assert buf.len >= 2
    zero buf
    ptr = @ptrCast(buf.ptr) as [*]c_char
    found = if input then Reaper.GetMIDIInputName(dev, ptr, buf.len - 1)
            else          Reaper.GetMIDIOutputName(dev, ptr, buf.len - 1)
    if not found and not closed_counts: return null
    name = sliceTo(buf, 0)
    return if name.len == 0 then null else name
```

Because the two surfaces passed `buf.len` and not `buf.len - 1` to REAPER, a name that fills the buffer was not NUL terminated, and now it is cut one byte earlier. Names are a few dozen letters, so this changes nothing in practice.

The test goes in the same file, which `reaziglib/build.zig` already lists in `test_files` with the import `reaper`. The mock in `reaziglib/src/models/reaper_mock.zig` has no MIDI device functions, so the test assigns fake functions to `Reaper.GetMIDIInputName` and `Reaper.GetMIDIOutputName`, which are `pub var` with the type that `reaziglib/src/reaper.zig` declares at lines 1260 and 1262 (and the output one next to it). The test restores the previous values with `defer`. It covers:

```
open device with a name            -> name, for both values of closed_counts
closed device with a name          -> null with closed_counts false, name with true
number that has no name            -> null, for both values
buffer of 1 byte                   -> asserts (not tested)
```

The users change as follows:

```
control_surface.zig   ReaperDevices.name(self, dev, buf)  -> return reaper_helpers.deviceName(buf, self.input, dev, false)
control_surface_mft.zig  the same
control_surface.zig   deviceName(buf, input, dev)         -> if builtin.is_test return ""
                                                             return reaper_helpers.deviceName(buf[0..], input, dev, false) orelse "?"
vr09/src/reaper_glue.zig  deviceName(dir, index, buf)     -> return reaper_helpers.deviceName(buf, dir == .input, @intCast(index), true)
```

Imports to add: `const reaper_helpers = @import("reaper_helpers");` in `control_surface.zig` and `control_surface_mft.zig`, and the same in `vr09/src/reaper_glue.zig`. All three extensions already call `reaziglib.addSharedModules`, which lists `reaper_helpers`, so no build change is needed. Callers of `glue.deviceName` in `vr09/src/ui.zig` and `vr09/src/debug_api.zig` keep the same signature.

## Step 2: `midi_device_names` becomes a module of reaziglib

In `reaziglib/build.zig`:

```
const midi_device_names_mod = b.addModule("midi_device_names", .{ .root_source_file = b.path("src/midi_device_names.zig") })
add "midi_device_names" to module_names of addSharedModules (line 459)
add "src/midi_device_names.zig" to test_files (line 197)
```

In `console1/build.zig`:

```
delete line 248 (the comment about the MFT) and lines 249-250 (device_names_mod and its addImport)
delete line 328 (mft_test.root_module.addImport("midi_device_names", device_names_mod))
```

The `reaper_c1` library, the `reaper_mft` library and the `mft_test` step already run `reaziglib.addSharedModules`, so `@import("midi_device_names")` works in all three. Because `control_surface_mft.zig` already imports it by that name, it needs no edit.

In `console1/src/csurf/control_surface.zig` line 16, change `@import("midi_device_names.zig")` to `@import("midi_device_names")`. In `console1/src/console1_extension.zig`, delete line 92, because the tests now run in the reaziglib test step.

## Step 3: the state of the surfaces

`reaziglib/src/midi_device_config.zig` imports `std`, `reaper_helpers` and `midi_device_names`. Because the two surfaces log under the scopes `.csurf` and `.csurf_mft`, and because `std.log.scoped` needs a comptime scope, the pieces that log or hold state are in a function of the scope that returns a type. Each call with a different scope gives a distinct type, and so a distinct copy of the `var` declarations inside of it. The callbacks of REAPER have no context pointer, and they reach the state of their surface through the type, without a parameter. The type declarations are the following:

```
/// The types are declared here and imported by the surfaces: const config = @import("midi_device_config");
pub const KeyStore = struct { buf: [device_names.max_key]u8 = undefined, len: usize = 0 }
    pub fn set(self: *KeyStore, key: []const u8) void     (the body of setKey)
    pub fn get(self: *const KeyStore) []const u8

pub const SurfaceKeys = struct { in: KeyStore = .{}, out: KeyStore = .{} }

pub const ReaperDevices = struct { input: bool }            (count and name, as in step 1)

pub fn keyOfDevice(input: bool, dev: c_int, buf: *[512]u8) ?[]const u8        (as today)
pub fn parseDeviceKeys(str: [*c]const c_char, keys: *device_names.Keys) void  (as today)

pub fn MidiDeviceConfig(comptime scope: @TypeOf(.enum_literal)) type
    const log = std.log.scoped(scope)
    return struct
        /// The keys of the devices that the surface is set to now.
        pub var surface: SurfaceKeys = .{}
        /// What the open dialog was given and did not find among the devices.
        pub var dialog: SurfaceKeys = .{}

        pub fn resolveDevice(input: bool, id: c_int, key: ?[]const u8) c_int     (as today, logs with `log`)

        /// The tail of createFunc: keeps the key of each device that the surface has now,
        /// and of the others the key that its config named.
        pub fn rememberKeys(in_dev: c_int, out_dev: c_int, named: device_names.Keys) void
            var name_buf: [512]u8
            if keyOfDevice(true, in_dev, &name_buf) |key| then surface.in.set(key) else surface.in.set(named.in orelse "")
            the same for out
```

In each surface file:

```
const devices = config.MidiDeviceConfig(.csurf)        (.csurf_mft in control_surface_mft.zig)
delete in_key_buf, in_key_len, out_key_buf, out_key_len        (devices.surface replaces them)
delete dialog_in_key_buf ... dialog_out_key_len                (devices.dialog replaces them)
delete ReaperDevices, setKey, resolveDevice, keyOfDevice, parseDeviceKeys, and the DeviceKeys alias of control_surface.zig
createFunc: replace the last two lines with devices.rememberKeys(in_dev, out_dev, keys)
dlgProc WM_INITDIALOG: devices.dialog.in.set(...), and devices.resolveDevice(...)
dlgProc WM_USER + 1024 and zGetConfigString: read the keys with devices.surface.in.get() and devices.dialog.in.get()
```

In `reaziglib/build.zig`:

```
const midi_device_config_mod = b.addModule("midi_device_config", .{ .root_source_file = b.path("src/midi_device_config.zig") })
midi_device_config_mod.addImport("reaper_helpers", reaper_helpers_mod)
midi_device_config_mod.addImport("midi_device_names", midi_device_names_mod)
add "midi_device_config" to module_names of addSharedModules
add "src/midi_device_config.zig" to test_files, and { .name = "midi_device_names", .mod = midi_device_names_mod } to test_imports
```

Two tests go in `midi_device_config.zig`:

```
test "two scopes do not share their keys"
    MidiDeviceConfig(.first).surface.in.set("a")
    expectEqual(0, MidiDeviceConfig(.second).surface.in.get().len)
    expectEqualStrings("a", MidiDeviceConfig(.first).surface.in.get())

test "the keys of the devices follow the four numbers of the config, and an older config has none"
    (the part of the existing test of control_surface.zig that is about the keys)
```

The part of the existing test that is about the numbers calls `parseParms`, which stays in the surfaces until step 4, so it stays in `control_surface.zig` until then.

## Step 4: the dialog

`console1/src/csurf/midi_device_dialog.zig` imports `c` (the module of `cBindings`, which stays in console1), `reaper`, `midi_device_names` and `midi_device_config`. Because `dlgProc` is a C callback and cannot take a parameter, the file exposes a function of the type that step 3 makes, so that each surface gets a callback that reaches the state of its own surface:

```
pub fn Dialog(comptime Devices: type) type            // Devices is a MidiDeviceConfig(scope)
    return struct
        pub fn dlgProc(hwndDlg: c.HWND, uMsg: c_uint, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.c) c.WDL_DLGRET
            // reads and writes Devices.surface and Devices.dialog, and calls Devices.resolveDevice
        pub fn configFunc(type_string: [*c]const u8, parent: c.HWND, initConfigString: [*c]const u8) callconv(.c) c.HWND

pub fn parseParms(str: [*c]const c_char, parms: *[4]i32) void
fn sendDlgItemMessage(...) c.LRESULT
fn makeIntResource(x: anytype) [*c]const u8
```

Each surface keeps `createFunc`, `init` and its registration, and sets `.ShowConfig = &Dialog(devices).configFunc`, where `devices` is the constant of step 3. The bodies of `dlgProc` and `configFunc` come from `control_surface.zig` (lines 576 and 689), where the commented-out `WDL_UTF8_HookComboBox` note stays. Before the move we diff the two copies of every function, and if they differ in more than the names that the state changes, we stop and report the difference, because the plan assumes they are the same.

`control_surface.zig` imports the file by relative path. Because `control_surface_mft.zig` lives in `src/mft/csurf/` and cannot import files outside `src/mft`, `addMftTarget` in `console1/build.zig` makes a named module for it, as the build did before for `midi_device_names`:

```
const dialog_mod = b.createModule(.{ .root_source_file = b.path("src/csurf/midi_device_dialog.zig") })
dialog_mod.addImport("c", c_mod)
reaziglib.addSharedModules(reazig_dep, dialog_mod)      // gives it reaper, midi_device_names and midi_device_config
lib.root_module.addImport("midi_device_dialog", dialog_mod)
mft_test.root_module.addImport("midi_device_dialog", dialog_mod)
```

The `c` module stays where it is, in `console1/build.zig`, and reaziglib gets no WDL or SWELL dependency. The tests of `midi_device_dialog.zig` are the part of the config test about `parseParms` and the test `parseParms`, and the file is added to the test block at the end of `console1/src/console1_extension.zig`.

The alternative, to move the dialog into reaziglib, is not part of this plan. It would need a `c` module in reaziglib with WDL and SWELL, and the dialog template and its ids (`resource.rc` and `resource.h`) would stay in console1. It becomes worth doing when a surface outside console1 needs the same dialog.

## How we check

- We use the Zig 0.17.0 toolchain, because the `zig` alias is 0.14.1 and fails.
- After each step we run `zig build -Dtest=true` in `console1`, the `zig build test` step of `reaziglib`, the test step of `vr09`, and the `mft_test` step. Because `zig build test` of console1 is broken at HEAD, we note in the commit message which steps we ran and which we could not.
- The dialog can only be exercised by opening the configuration window of each surface in REAPER. After step 4 we do that by hand for both surfaces: the selected devices must be the ones of the saved config, and pressing OK with a device that is unplugged must keep its key.
- At the end we search for `GetMIDIInputName` and `GetMIDIOutputName` in the sources of the three extensions. Only `reaziglib`, the generated bindings, and `console1/src/pReaper.zig` should remain.
