#!/bin/sh
# Boot the portable REAPER under a headless X server for automated testing.
# Usage: ./run-headless.sh [project.RPP]
# Sends no GUI clicks itself beyond dismissing the startup dialogs.
set -e

TOOLS=/tank/projects/.toolchains/xtools/prefix
HERE=/tank/projects/reaper-portable
export LD_LIBRARY_PATH="$TOOLS/usr/lib/x86_64-linux-gnu"
export DISPLAY=:99
X="$TOOLS/usr/bin/xdotool"

# Start Xvfb on :99 if not already serving.
if ! "$X" getdisplaygeometry >/dev/null 2>&1; then
  "$TOOLS/usr/bin/Xvfb.patched" :99 -screen 0 1600x900x24 \
    -xkbdir "$TOOLS/usr/share/X11/xkb" >/tmp/xvfb.log 2>&1 &
  sleep 2
fi

pkill -x reaper 2>/dev/null || true
sleep 2
( cd "$HERE" && nohup ./reaper "$@" >/tmp/reaper-test.log 2>&1 & )
sleep 9

# Dismiss "Error opening audio device" if it appeared.
A=$("$X" search --name "Error opening" 2>/dev/null | head -1 || true)
if [ -n "$A" ]; then "$X" windowfocus "$A"; "$X" mousemove 420 195 click 1; sleep 1; fi

# Dismiss the evaluation nag (only if unlicensed): wait out the countdown, click.
W=$("$X" search --name "EVALUATION" 2>/dev/null | head -1 || true)
if [ -n "$W" ]; then
  "$X" windowfocus "$W"; sleep 5
  "$X" mousemove 230 818 click 1; "$X" mousemove 480 818 click 1; sleep 1
fi

echo "reaper pid(s): $(pgrep -x reaper | tr '\n' ' ')"
grep -E "extension|engine" /tmp/reaper-test.log | tail -3
