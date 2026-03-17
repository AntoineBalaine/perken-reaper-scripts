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

zig build --prefix "$REAPER_PLUGINS"
zig build ui --prefix "$REAPER_PLUGINS"

"$REAPER_BIN" new
