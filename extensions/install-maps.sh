#!/usr/bin/env bash
set -euo pipefail

# Installs the factory maps of a controller without destroying the user's edits.
#
#   install-maps.sh <source maps folder> <destination maps folder>
#
# Every default.ini of the source folder (<MODULE>/<plugin folder>/default.ini)
# goes to the same place in the destination. Because a map in the destination
# is the user's to edit, it is replaced only when it is still exactly what a
# previous run installed. The checksum of every installed map is recorded next
# to it (default.ini.installed-sha), and four cases follow:
#
#   * the map is not there yet: it is installed;
#   * the map already equals the new one: nothing changes;
#   * the map is unmodified since the last install: the new one replaces it;
#   * the map was edited, or comes from before this script recorded anything:
#     it is kept, and the new one is written beside it as default.ini.new.

if [ $# -ne 2 ]; then
  echo "Usage: $0 <source maps folder> <destination maps folder>" >&2
  exit 1
fi
SOURCE="${1%/}"
DEST="${2%/}"

if [ ! -d "$SOURCE" ]; then
  echo "maps folder not found: $SOURCE" >&2
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

installed=0
unchanged=0
kept=0
while IFS= read -r -d '' file; do
  target="$DEST/${file#"$SOURCE"/}"
  record="$target.installed-sha"
  new_sum="$(checksum "$file")"
  mkdir -p "$(dirname "$target")"
  if [ ! -e "$target" ]; then
    cp "$file" "$target"
    echo "$new_sum" > "$record"
    rm -f "$target.new"
    installed=$((installed + 1))
    continue
  fi
  current_sum="$(checksum "$target")"
  if [ "$current_sum" = "$new_sum" ]; then
    echo "$new_sum" > "$record"
    rm -f "$target.new"
    unchanged=$((unchanged + 1))
  elif [ -f "$record" ] && [ "$current_sum" = "$(cat "$record")" ]; then
    cp "$file" "$target"
    echo "$new_sum" > "$record"
    rm -f "$target.new"
    installed=$((installed + 1))
  else
    cp "$file" "$target.new"
    kept=$((kept + 1))
  fi
done < <(find "$SOURCE" -name default.ini -print0 | sort -z)

echo "maps: $installed installed, $unchanged already up to date, $kept kept because they were edited (the new ones are beside them as default.ini.new)"
