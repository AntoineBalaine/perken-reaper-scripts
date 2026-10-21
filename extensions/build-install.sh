#!/usr/bin/env bash
set -euo pipefail

# Builds extensions of this repository and installs them into REAPER's
# UserPlugins directory.
#
#   extensions/build-install.sh [-z /path/to/zig] [-n] [extension ...]
#
# Extensions: reavim-ext, perken-utilities, console1 (Console1 and its UI
# library), mft (MIDI Fighter Twister), vr09 (the Roland VR-09 plugin, a CLAP
# plugin that goes to the CLAP folder, not to UserPlugins). Without names,
# reavim-ext and perken-utilities are installed.
#
# reavim-ext also installs its default keymap, through install-bindings.sh,
# which keeps a keymap you have edited.
#
# Set REAPER_RESOURCE_PATH to install somewhere other than REAPER's own
# resource folder (the script then never launches REAPER).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG="zig"
LAUNCH=1
ALL_EXTENSIONS="reavim-ext perken-utilities console1 mft vr09"

usage() {
  echo "Usage: $0 [-z /path/to/zig] [-n] [extension ...]" >&2
  echo "  -z   path to the zig compiler to use (default: 'zig' from PATH)" >&2
  echo "  -n   do not launch REAPER after installing" >&2
  echo "  extensions: $ALL_EXTENSIONS (default: reavim-ext perken-utilities)" >&2
}

while getopts "z:nh" opt; do
  case "$opt" in
    z) ZIG="$OPTARG" ;;
    n) LAUNCH=0 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
  set -- reavim-ext perken-utilities
fi

for name in "$@"; do
  case " $ALL_EXTENSIONS " in
    *" $name "*) ;;
    *)
      echo "Unknown extension: $name" >&2
      usage
      exit 1
      ;;
  esac
done

# Resolve the compiler before doing anything else so we fail early on a bad -z.
if ! command -v "$ZIG" >/dev/null 2>&1; then
  echo "zig compiler not found: $ZIG" >&2
  exit 1
fi
ZIG_VERSION="$("$ZIG" version)"

# Each extension pins its zig series in its own .zigversion. Only the
# major.minor series is compared, so any patch release is accepted.
dir_of() {
  case "$1" in
    mft) echo "$SCRIPT_DIR/console1" ;;
    *) echo "$SCRIPT_DIR/$1" ;;
  esac
}
for name in "$@"; do
  required="$(cat "$(dir_of "$name")/.zigversion")"
  series="${required%.*}"
  case "$ZIG_VERSION" in
    "$series" | "$series".*) ;;
    *)
      echo "$name needs zig $series.x, but '$ZIG' reports $ZIG_VERSION" >&2
      echo "Pass a matching compiler with -z /path/to/zig" >&2
      exit 1
      ;;
  esac
done

case "$(uname -s)" in
  Darwin)
    RESOURCE="$HOME/Library/Application Support/REAPER"
    REAPER_BIN="/Applications/REAPER.app/Contents/MacOS/REAPER"
    ;;
  Linux)
    RESOURCE="$HOME/.config/REAPER"
    REAPER_BIN=""
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac
if [ -n "${REAPER_RESOURCE_PATH:-}" ]; then
  RESOURCE="$REAPER_RESOURCE_PATH"
  REAPER_BIN=""
fi

PREFIX="$RESOURCE/UserPlugins"
mkdir -p "$PREFIX"

# CLAP plugins live in their own folders. With REAPER_RESOURCE_PATH set, the
# plugin goes under that folder instead, and REAPER finds it through CLAP_PATH.
case "$(uname -s)" in
  Darwin) CLAP_DIR="$HOME/Library/Audio/Plug-Ins/CLAP" ;;
  *) CLAP_DIR="$HOME/.clap" ;;
esac
if [ -n "${REAPER_RESOURCE_PATH:-}" ]; then
  CLAP_DIR="$RESOURCE/clap"
fi

# Because zig builds from the working directory, each extension is built from
# its own folder.
for name in "$@"; do
  echo "== $name"
  cd "$(dir_of "$name")"
  case "$name" in
    reavim-ext)
      "$ZIG" build --prefix "$PREFIX"
      "$SCRIPT_DIR/install-bindings.sh" src/default_bindings.ini "$RESOURCE/Data/Perken"
      ;;
    perken-utilities)
      # Its C++ (the control surface shim, qm-dsp) is compiled with REAPER's
      # own toolchain, so Apple clang or gcc must be on PATH.
      "$ZIG" build --prefix "$PREFIX"
      ;;
    console1)
      # The panel is a separate, hot-reloadable library; both must be
      # installed for it to load.
      "$ZIG" build -Dtest=true --prefix "$PREFIX"
      "$ZIG" build ui --prefix "$PREFIX"
      ;;
    mft)
      "$ZIG" build mft --prefix "$PREFIX"
      ;;
    vr09)
      # A CLAP plugin: a bundle on macOS, a file elsewhere. The old copy goes
      # first, because a bundle is a folder and would not be replaced.
      mkdir -p "$CLAP_DIR"
      rm -rf "$CLAP_DIR/vr09.clap"
      "$ZIG" build -Doptimize=ReleaseSafe --prefix "$CLAP_DIR"
      if [ -n "${REAPER_RESOURCE_PATH:-}" ]; then
        echo "Installed in $CLAP_DIR: start REAPER with CLAP_PATH=$CLAP_DIR"
      fi
      ;;
  esac
done

# On macOS we additionally launch a fresh REAPER instance once the builds land.
if [ "$LAUNCH" -eq 1 ] && [ -n "$REAPER_BIN" ]; then
  "$REAPER_BIN" new
fi
