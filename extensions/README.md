# REAPER extensions

The compiled REAPER extensions in this repository. Each one is a separate Zig
package with its own `build.zig`, `build.zig.zon`, CI workflow
(`.github/workflows/<name>.yml`) and release tags (`<name>-v*`).

| Extension | What it is |
|---|---|
| [`reavim-ext`](reavim-ext) | Vim mode for REAPER |
| [`perken-utilities`](perken-utilities) | Editing helpers (drums, chord voicings, item/track/envelope tools, batch rename, auto lane watcher, ...) |
| [`console1`](console1) | Softube Console1 MKII and MIDI Fighter Twister integrations |
| [`reaziglib`](reaziglib) | Shared Zig modules (REAPER API bindings, helpers, UI) used by the others |

Extensions depend on `reaziglib` by path (`.path = "../reaziglib"`), so a
change to the library and to the code using it lands in one commit.

## Releases and tags

Each extension is versioned and released on its own, from its own tags:

| Extension | Tag | Workflow |
|---|---|---|
| reavim-ext | `reavim-ext-v<version>` | `.github/workflows/reavim-ext.yml` |
| perken-utilities | `perken-utilities-v<version>` | `.github/workflows/perken-utilities.yml` |
| Console1 (`reaper_c1`, `reaper_c1_ui`) | `console1-v<version>` | `.github/workflows/console1.yml` |
| MIDI Fighter Twister (`reaper_mft`) | `mft-v<version>` | `.github/workflows/mft.yml` |

- A tag triggers only its own workflow, which builds only that extension and
  publishes a GitHub release with only its binaries. reaziglib is not
  released; the extensions build it from source.
- Branch pushes and pull requests build an extension when its folder,
  reaziglib or its workflow changes; they never release.
- The version in the tag is baked into the binary (`-Dversion`, `dev` for
  untagged builds) and logged when the extension loads.
- Releases do not claim GitHub's "Latest" badge, because several extensions
  release from this repository. To list one extension's releases, filter the
  releases page by its tag prefix.
- Each extension keeps its own `CHANGELOG.md`.

## Building and installing into REAPER

`build-install.sh` builds extensions and installs them into REAPER's
`UserPlugins` folder (and launches REAPER on macOS, unless `-n` is given):

```sh
extensions/build-install.sh                          # reavim-ext and perken-utilities
extensions/build-install.sh console1 mft             # the Console1 pair and MFT
extensions/build-install.sh -z /path/to/zig -n reavim-ext
```

reavim-ext also installs its default keymap as `Data/Perken/bindings.ini`,
through `install-bindings.sh`, which never destroys edits:

- a missing file, or one that is still exactly what the last install wrote,
  is replaced by the new defaults;
- an edited file is kept, and the new defaults are written beside it as
  `bindings.ini.new`, with a `diff` command to compare the two. Merge the
  lines you want, or delete `bindings.ini` to take the new defaults.

`extensions/install-bindings.test.sh` tests this in a temporary folder. Set
`REAPER_RESOURCE_PATH` to install somewhere other than REAPER's own folder
(the script then does not launch REAPER).

## Running the Linux CI locally

Extensions with C++ (perken-utilities, console1) must build their Linux
binaries on Linux with gcc, so a Mac can not check them directly.
`linux-ci/linux-ci.sh` runs the Linux steps of every workflow in a Docker
container matching GitHub's `ubuntu-latest` (Ubuntu 24.04, gcc, PHP, the
pinned Zig):

```sh
extensions/linux-ci/linux-ci.sh            # arm64 Linux, native on Apple silicon
extensions/linux-ci/linux-ci.sh --amd64    # x86_64 Linux, emulated (slower)
```

Each step prints PASS or FAIL; full output is in
`linux-ci/logs/<arch>/<package>-<step>.log` (not committed). Docker Desktop
must be running. The steps are listed in `linux-ci/run-steps.sh` and should
follow the workflows when those change.

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

reaziglib provides `reaperCxxObject`, which compiles a C++ file this way and
returns the object file, and `addCsurf`, which uses it for the control
surface shim (`reaziglib/src/csurf/`). A build that needs such C++ must run on
the target's own OS with that compiler on `PATH` (on Windows, inside a Visual
Studio developer environment); asking for another OS stops with an error.
macOS builds can still target both architectures from one Mac.
