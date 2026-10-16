# Perken Console1

A REAPER control surface extension for the Softube Console1 MKII hardware controller. This extension replaces Softube's proprietary plugin dependency, allowing you to use any REAPER-compatible plugin with the Console1 hardware on macOS, Linux, and Windows.

## What it does

The Console1 hardware has five module sections (Input, Gate, EQ, Compressor, Output) with dedicated knobs and buttons for each. This extension maps those physical controls to parameters of any plugin you choose, organized by module. You can browse and assign plugins per module, create custom parameter mappings, and switch between different configurations.

The extension includes:

- FX Control mode: control plugin parameters from the Console1 knobs and buttons, with per-module assignment and visual feedback in a GUI overlay.
- FX Selection panel: browse available plugins by type, category, or developer, and assign them to Console1 modules. Plugins with predefined mappings appear at the top of the list.
- Transport mode: control playback, recording, navigation, zoom, and other REAPER functions from the Console1.
- Mapping panel: create custom parameter mappings for any plugin.
- Settings panel: configure preferences, default FX assignments, and module order.
- Track list: select and navigate tracks from the GUI.
- Channel strip mode: assign a single multi-section plugin (like Tukan SumChannel S2) across all five modules.

## Supported platforms

- macOS (x86_64 and arm64)
- Linux (x86_64 and aarch64)
- Windows (x86_64)

## Installation

### From release artifacts

Download the release archive for your platform from the GitHub releases page. The archive contains:

- The host extension binary (`reaper_c1.dylib`/`.so`/`.dll`)
- The UI library (`reaper_c1_ui.dylib`/`.so`/`.dll`)
- Map files (predefined parameter mappings for common plugins)
- A patched version of Tukan SumChannel S2 JSFX with full parameter exposure

Copy the binaries to your REAPER `UserPlugins/` directory and the map files to `Data/Perken/Console1/maps/` inside your REAPER resource path.

Default resource path locations:
- macOS: `~/Library/Application Support/REAPER/`
- Linux: `~/.config/REAPER/`
- Windows: `%APPDATA%\REAPER\`

### Building from source

Requirements: Zig 0.14.0, clang (macOS) or gcc (Linux/Windows).

```bash
# macOS
zig build --prefix "$HOME/Library/Application Support/REAPER/UserPlugins"
zig build ui --prefix "$HOME/Library/Application Support/REAPER/UserPlugins"

# Linux
zig build --prefix "$HOME/.config/REAPER/UserPlugins"
zig build ui --prefix "$HOME/.config/REAPER/UserPlugins"
```

Then install the map files:

```bash
./cmp.sh --install
```

## Getting started

See [docs/getting-started.md](docs/getting-started.md) for a walkthrough of the first launch and basic usage.

## REAPER setup

After installing, start REAPER and configure the Console1:

1. Go to `Preferences > MIDI Devices` and disable the Console1's MIDI input (so REAPER doesn't treat it as a generic MIDI controller).
2. Go to `Preferences > Control/OSC/Web > Add` and select "Softube Console1" as the control surface. Map the Console1's MIDI input and output ports.
3. The Console1 GUI should appear. If it doesn't, check `Extensions > Console1` in the REAPER menu.

## Predefined mappings

The extension ships with parameter mappings for common plugins including ReaComp, ReaEQ, ReaGate, and several Tukan Studios plugins. The map files are INI-based and live in `Data/Perken/Console1/maps/` inside your REAPER resource path.

You can create your own mappings using the mapping panel (accessible from the FX selection workflow when a plugin has no existing mapping).

## Reporting issues

Please report bugs at the GitHub issues page. Include your REAPER version, operating system, and steps to reproduce the issue.

## License

This project is under development. License terms will be finalized before the public release.
