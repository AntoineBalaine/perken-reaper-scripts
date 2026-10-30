#!/bin/bash

case "$(uname)" in
  Darwin)
    REAPER_PLUGINS="$HOME/Library/Application Support/REAPER/UserPlugins"
    REAPER_BIN="/Applications/REAPER.app/Contents/MacOS/REAPER"
    ;;
  Linux)
    REAPER_PLUGINS="$HOME/.config/REAPER/UserPlugins"
    REAPER_BIN="reaper"
    ;;
  *)
    echo "Unsupported platform: $(uname)"
    exit 1
    ;;
esac

REAPER_PATH="$(dirname "$REAPER_PLUGINS")"

DO_BUILD=true
DO_UI=true
DO_REAPER=true
DO_INSTALL=false
HEADLESS=false

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "Usage: cmp.sh [options]"
      echo "  (no args)      Build host + UI, then launch REAPER"
      echo "  -ui            Build only the UI library"
      echo "  -b, --build    Build host + UI, skip REAPER"
      echo "  -r, --reaper   Skip builds, just launch REAPER"
      echo "  -i, --install  Copy map files to REAPER resource path"
      echo "  -hd            Build in headless mode"
      echo "  -h, --help     Show this help"
      exit 0
      ;;
    -ui)          DO_BUILD=false; DO_UI=true; DO_REAPER=false ;;
    --build|-b)   DO_BUILD=true; DO_UI=true; DO_REAPER=false ;;
    --reaper|-r)  DO_BUILD=false; DO_UI=false; DO_REAPER=true ;;
    --install|-i) DO_INSTALL=true; DO_BUILD=false; DO_UI=false; DO_REAPER=false ;;
    -hd)          HEADLESS=true ;;
  esac
done

HEADLESS_FLAG=""
if $HEADLESS; then
  HEADLESS_FLAG="-Dheadless=true"
fi

if $DO_BUILD; then
  zig build -Dtest=true $HEADLESS_FLAG --prefix "$REAPER_PLUGINS" || exit 1
fi

if $DO_UI; then
  zig build ui --prefix "$REAPER_PLUGINS" || exit 1
fi

if $DO_INSTALL; then
  MAPS_DEST="$REAPER_PATH/Data/Perken/Console1/maps"
  mkdir -p "$MAPS_DEST"
  cp -r Perken/Console1/maps/* "$MAPS_DEST/"
  echo "Maps installed to $MAPS_DEST"

  JSFX_DEST="$REAPER_PATH/Effects/Perken"
  mkdir -p "$JSFX_DEST"
  cp -r src/resources/jsfx/* "$JSFX_DEST/"
  echo "JSFX files installed to $JSFX_DEST"
fi

if $DO_REAPER; then
  "$REAPER_BIN" new
fi
