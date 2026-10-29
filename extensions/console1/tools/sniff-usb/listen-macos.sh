#!/bin/bash
# Listens to the Console 1 on macOS, at the level of its MIDI port, while the Softube application runs.
# It sets up what it needs on the first run (a python environment in .venv, with mido and python-rtmidi).
#
#   ./listen-macos.sh          listen, with labels from the keyboard, and report at the end
#   ./listen-macos.sh --list   list the MIDI input ports
#
# It is written for the bash that macOS ships with, which is version 3.2.

set -u
here=$(cd "$(dirname "$0")" && pwd)

if ! command -v python3 >/dev/null 2>&1; then
  echo "missing: python3 (xcode-select --install, or brew install python)"
  exit 1
fi

if [ ! -x "$here/.venv/bin/python" ]; then
  echo "First run: setting up the python environment in $here/.venv"
  python3 -m venv "$here/.venv" || exit 1
  "$here/.venv/bin/pip" install --quiet mido python-rtmidi || exit 1
fi

cd "$here" && exec "$here/.venv/bin/python" "$here/listen_coremidi.py" "$@"
