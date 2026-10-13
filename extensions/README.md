# REAPER extensions

The compiled REAPER extensions in this repository. Each one is a separate Zig
package with its own `build.zig`, `build.zig.zon`, CI workflow
(`.github/workflows/<name>.yml`) and release tags (`<name>-v*`).

| Extension | What it is |
|---|---|
| [`reavim-ext`](reavim-ext) | Vim mode for REAPER |
| [`cajun-extensions`](cajun-extensions) | Editing helpers (drums, chord voicings, item/track/envelope tools, batch rename, auto lane watcher, ...) |
| [`console1`](console1) | Softube Console1 MKII and MIDI Fighter Twister integrations |
| [`reaziglib`](reaziglib) | Shared Zig modules (REAPER API bindings, helpers, UI) used by the others |

Extensions depend on `reaziglib` by path (`.path = "../reaziglib"`), so a
change to the library and to the code using it lands in one commit.

## Toolchain rule: C++ that REAPER calls must use REAPER's toolchain

REAPER calls some extension code through **C++ virtual methods**: a control
surface (`IReaperControlSurface`), MIDI devices (`midi_Input`, `midi_Output`),
and any other class from the SDK that REAPER invokes. REAPER reaches those
methods through the object's C++ virtual table, so the extension's object
must have exactly the layout and calling conventions of the compiler REAPER
itself was built with. **Such C++ must be compiled with REAPER's
toolchain**:

| Platform | Compiler |
|---|---|
| Windows | MSVC (`cl`) |
| macOS | Apple clang (`clang`) |
| Linux | `gcc` |

Zig's bundled clang is not a substitute, even where it looks compatible. On
Windows REAPER uses the MSVC C++ ABI; the SDK header itself says so
(`reaper_plugin.h`: "the C++ interfaces used require MSVC on win32, or at
least the MSVC-compatible C++ ABI"). Building such code with Zig's clang has
been tried and does not work.

`console1` follows the rule: its C++ is compiled through `addSystemCommand`
with the compilers above, and its CI therefore builds natively on each OS.

What the rule does **not** cover:

- **C interfaces.** REAPER's API functions, `plugin_register` structs whose
  callbacks are plain C function pointers (actions, `hookcommand2`, timers,
  the `<accelerator` hook), and SWELL's C functions are the same for every
  compiler. Zig code may implement them directly; `reavim-ext` contains no
  C++ at all and cross-compiles every platform from one runner.
- Only the parts REAPER calls. The rule is about who calls the code, not
  where the code lives: a Zig extension that registers a control surface
  needs just that C++ class built with REAPER's toolchain, behind a C
  interface to the Zig side.

When an extension needs C++, it uses the same toolchain for all of its C++,
so that the repository has one C++ toolchain, not two.

> **Known exception, to be fixed:** reaziglib's control surface shim
> (`reaziglib/src/csurf/`) is currently compiled with Zig's clang, with a
> workaround for the MSVC virtual-table layout on Windows. It works on macOS,
> but violates this rule and is unverified on Windows.
