#!/usr/bin/env bash
set -uo pipefail

# Runs the unit tests of the extensions and of reaziglib, and reports which
# suites passed.
#
#   extensions/test-all.sh [-z /path/to/zig] [suite ...]
#
# Suites: reaziglib, reavim-ext, perken-utilities, vr09, console1, mft (the
# MIDI Fighter Twister tests, which live in console1). Without names, every
# suite runs. Every suite runs even when an earlier one fails, and the script
# exits with a non-zero status when any of them failed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG="zig"
ALL_SUITES="reaziglib reavim-ext perken-utilities vr09 console1 mft"

usage() {
  echo "Usage: $0 [-z /path/to/zig] [suite ...]" >&2
  echo "  -z   path to the zig compiler to use (default: 'zig' from PATH)" >&2
  echo "  suites: $ALL_SUITES (default: all)" >&2
}

while getopts "z:h" opt; do
  case "$opt" in
    z) ZIG="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
  # Because the word splitting of the list is what we want here, it is unquoted.
  # shellcheck disable=SC2086
  set -- $ALL_SUITES
fi

for name in "$@"; do
  case " $ALL_SUITES " in
    *" $name "*) ;;
    *)
      echo "Unknown suite: $name" >&2
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

dir_of() {
  case "$1" in
    mft) echo "$SCRIPT_DIR/console1" ;;
    *) echo "$SCRIPT_DIR/$1" ;;
  esac
}

# The extensions pin their zig series in .zigversion; reaziglib, which has no
# such file, follows the extensions. Only the major.minor series is compared,
# so any patch release is accepted.
for name in "$@"; do
  version_file="$(dir_of "$name")/.zigversion"
  [ -f "$version_file" ] || continue
  required="$(cat "$version_file")"
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

passed=()
failed=()
# Because zig builds from the working directory, each suite runs from its
# extension's folder.
for name in "$@"; do
  echo "== $name"
  case "$name" in
    mft) step="mft-test" ;;
    *) step="test" ;;
  esac
  if (cd "$(dir_of "$name")" && "$ZIG" build "$step" --summary all); then
    passed+=("$name")
  else
    failed+=("$name")
  fi
done

echo
echo "passed: ${passed[*]:-none}"
echo "failed: ${failed[*]:-none}"
[ ${#failed[@]} -eq 0 ]
