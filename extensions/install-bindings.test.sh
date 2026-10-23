#!/usr/bin/env bash
set -euo pipefail

# Tests install-bindings.sh in a temporary folder; nothing outside it is
# touched. Run it with: extensions/install-bindings.test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/install-bindings.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

check() { # description, expected, actual
  if [ "$2" = "$3" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1 (expected '$2', got '$3')"
    FAILED=1
  fi
}

DEST="$TMP/dest"
printf 'a = 1\nb = 2\n' > "$TMP/v1.ini"
printf 'a = 1\nb = 2\nc = 3\n' > "$TMP/v2.ini"

"$INSTALL" "$TMP/v1.ini" "$DEST" >/dev/null
check "a missing file is installed" "$(cat "$TMP/v1.ini")" "$(cat "$DEST/bindings.ini")"

"$INSTALL" "$TMP/v2.ini" "$DEST" >/dev/null
check "an unmodified file is updated to the new defaults" "$(cat "$TMP/v2.ini")" "$(cat "$DEST/bindings.ini")"
check "no .new file is left after an update" "no" "$([ -e "$DEST/bindings.ini.new" ] && echo yes || echo no)"

printf 'a = 1\nb = 2\nc = 3\nmine = 4\n' > "$DEST/bindings.ini"
printf 'a = 1\nb = 2\nc = 3\nd = 5\n' > "$TMP/v3.ini"
"$INSTALL" "$TMP/v3.ini" "$DEST" >/dev/null
check "an edited file is kept" "mine = 4" "$(tail -1 "$DEST/bindings.ini")"
check "the new defaults are written beside it" "$(cat "$TMP/v3.ini")" "$(cat "$DEST/bindings.ini.new")"

"$INSTALL" "$TMP/v3.ini" "$DEST" >/dev/null
check "an edited file stays kept on the next run" "mine = 4" "$(tail -1 "$DEST/bindings.ini")"

cp "$TMP/v3.ini" "$DEST/bindings.ini"
"$INSTALL" "$TMP/v3.ini" "$DEST" >/dev/null
check "a file equal to the defaults needs no change" "no" "$([ -e "$DEST/bindings.ini.new" ] && echo yes || echo no)"

# A file from before anything was recorded is treated as the user's own.
LEGACY="$TMP/legacy"
mkdir -p "$LEGACY"
printf 'old = 1\n' > "$LEGACY/bindings.ini"
"$INSTALL" "$TMP/v1.ini" "$LEGACY" >/dev/null
check "a file with no record is kept" "old = 1" "$(cat "$LEGACY/bindings.ini")"
check "and the defaults go beside it" "$(cat "$TMP/v1.ini")" "$(cat "$LEGACY/bindings.ini.new")"

exit "$FAILED"
