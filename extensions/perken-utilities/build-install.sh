#!/usr/bin/env bash
set -euo pipefail

# Build the project and install into REAPER's UserPlugins directory.
# The destination differs between Linux and macOS, so we detect the OS first.

# The expected compiler version lives in .zigversion next to this script so it
# stays in sync with the toolchain the project is pinned to.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_ZIG="$(cat "$SCRIPT_DIR/.zigversion")"
ZIG="zig"

usage() {
  echo "Usage: $0 [-z /path/to/zig]" >&2
  echo "  -z   path to the zig compiler to use (default: 'zig' from PATH)" >&2
}

# The build only works with zig $REQUIRED_ZIG, so we let the user point us at a
# specific compiler via -z when the one on PATH is the wrong version.
while getopts "z:h" opt; do
  case "$opt" in
    z) ZIG="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# Resolve the compiler before doing anything else so we fail early on a bad -z.
if ! command -v "$ZIG" >/dev/null 2>&1; then
  echo "zig compiler not found: $ZIG" >&2
  exit 1
fi

# We refuse to build with anything other than zig $REQUIRED_ZIG because other
# versions are known to break the build. We only pin to the major.minor series,
# so any patch release (0.17.0, 0.17.1, ...) is accepted.
REQUIRED_SERIES="${REQUIRED_ZIG%.*}"
ZIG_VERSION="$("$ZIG" version)"
case "$ZIG_VERSION" in
  "$REQUIRED_SERIES" | "$REQUIRED_SERIES".*)
    ;;
  *)
    echo "zig $REQUIRED_SERIES.x is required, but '$ZIG' reports $ZIG_VERSION" >&2
    echo "Pass a matching compiler with -z /path/to/zig" >&2
    exit 1
    ;;
esac

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

PREFIX="$RESOURCE/UserPlugins"

# Because zig builds from the working directory, we run it from the repo root so
# the script also works when it is called from elsewhere.
cd "$SCRIPT_DIR"

# The control surface shim and qm-dsp are C++ compiled with REAPER's own
# toolchain (Apple clang on macOS, gcc on Linux), so that compiler must be on
# PATH; see ../README.md.
"$ZIG" build --prefix "$PREFIX"

# On macOS we additionally launch a fresh REAPER instance once the build lands.
if [ -n "$REAPER_BIN" ]; then
  "$REAPER_BIN" new
fi
