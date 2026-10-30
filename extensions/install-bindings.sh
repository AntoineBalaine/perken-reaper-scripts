#!/usr/bin/env bash
set -euo pipefail

# Installs a default keymap as <dest-dir>/bindings.ini without destroying the
# user's edits.
#
#   install-bindings.sh <default-bindings.ini> <dest-dir>
#
# Because the installed file is the user's to edit, it is replaced only when
# it is still exactly what a previous run installed. The checksum of every
# installed default is recorded next to it, and three cases follow:
#
#   * no bindings.ini yet, or it is unmodified: the new defaults are installed;
#   * the file already equals the new defaults: nothing changes;
#   * the file was edited (or comes from before this script recorded
#     anything): it is kept, and the new defaults are written beside it as
#     bindings.ini.new, with a pointer to compare the two.

if [ $# -ne 2 ]; then
  echo "Usage: $0 <default-bindings.ini> <dest-dir>" >&2
  exit 1
fi
SOURCE="$1"
DEST_DIR="$2"
DEST="$DEST_DIR/bindings.ini"
RECORD="$DEST_DIR/.bindings.ini.installed-sha"

if [ ! -f "$SOURCE" ]; then
  echo "default bindings not found: $SOURCE" >&2
  exit 1
fi

# macOS ships shasum, most Linux systems sha256sum.
checksum() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

mkdir -p "$DEST_DIR"
NEW_SUM="$(checksum "$SOURCE")"

if [ ! -e "$DEST" ]; then
  cp "$SOURCE" "$DEST"
  echo "$NEW_SUM" > "$RECORD"
  rm -f "$DEST.new"
  echo "bindings: installed the default keymap at $DEST"
  exit 0
fi

CURRENT_SUM="$(checksum "$DEST")"
RECORDED_SUM=""
if [ -f "$RECORD" ]; then
  RECORDED_SUM="$(cat "$RECORD")"
fi

if [ "$CURRENT_SUM" = "$NEW_SUM" ]; then
  echo "$NEW_SUM" > "$RECORD"
  rm -f "$DEST.new"
  echo "bindings: $DEST already matches the defaults"
elif [ "$CURRENT_SUM" = "$RECORDED_SUM" ]; then
  cp "$SOURCE" "$DEST"
  echo "$NEW_SUM" > "$RECORD"
  rm -f "$DEST.new"
  echo "bindings: updated $DEST (it had no edits of yours)"
else
  cp "$SOURCE" "$DEST.new"
  CHANGED="$(diff "$DEST" "$DEST.new" | grep -c '^[<>]' || true)"
  echo "bindings: KEPT your edited $DEST ($CHANGED lines differ from the new defaults)"
  echo "bindings: compare with:  diff -u \"$DEST\" \"$DEST.new\""
fi
