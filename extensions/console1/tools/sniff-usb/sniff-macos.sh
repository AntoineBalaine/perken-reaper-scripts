#!/bin/bash
# Captures the USB traffic of a Console 1 on macOS, while the Softube application talks to it, and decodes it.
#
#   ./sniff-macos.sh               capture, then decode
#   ./sniff-macos.sh --decode FILE decode a capture that is already made
#
# It needs Wireshark's command line tools (brew install --cask wireshark) and python3 (xcode-select --install).
# It is written for the bash that macOS ships with, which is version 3.2.

set -u
here=$(cd "$(dirname "$0")" && pwd)

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is for macOS. The capture of a Linux machine is made with usbmon."
  exit 1
fi

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing: $1 ($2)"
    exit 1
  fi
}
need tshark "brew install --cask wireshark"
need dumpcap "brew install --cask wireshark"
need python3 "xcode-select --install"

if [ "${1:-}" = "--decode" ]; then
  [ -n "${2:-}" ] || { echo "usage: $0 --decode FILE [MARKERS_FILE]"; exit 1; }
  if [ -n "${3:-}" ]; then
    python3 -I "$here/decode_usb_midi.py" "$2" --markers "$3"
  else
    python3 -I "$here/decode_usb_midi.py" "$2"
  fi
  exit $?
fi

if ! system_profiler SPUSBDataType 2>/dev/null | grep -q "Console 1"; then
  echo "The Console 1 is not found on the USB bus: plug it in first."
  exit 1
fi

# The capture interfaces of the USB controllers. They only exist on some Macs and some versions of macOS.
interfaces=$(ifconfig -l | tr ' ' '\n' | grep -E '^(XHC|EHC|OHC|UHC)' | tr '\n' ' ')
if [ -z "$interfaces" ]; then
  cat <<'EOF'
This Mac has no USB capture interface (XHC20 and its like), so Wireshark cannot see the USB bus here.
That is the case on Macs with Apple silicon. Read the section "When there is no capture interface" of the README:
the same information can be had at the level of CoreMIDI, with MIDI Monitor.
EOF
  exit 2
fi

echo "USB capture interfaces: $interfaces"
for name in $interfaces; do
  if ! sudo ifconfig "$name" up; then
    cat <<EOF
Could not bring $name up. On recent versions of macOS, the capture of the USB bus needs the debug protection of
the system to be off: restart in recovery mode and run  csrutil enable --without debug  (see the README).
EOF
    exit 2
  fi
done

mkdir -p "$here/captures"
stamp=$(date +%Y%m%d-%H%M%S)
capture="$here/captures/console1-$stamp.pcapng"
markers="$here/captures/console1-$stamp.markers.tsv"
: > "$markers"

interface_args=""
for name in $interfaces; do interface_args="$interface_args -i $name"; done

cat <<EOF

The capture starts now, into
  $capture

Do this, in this order:
  1. Unplug the Console 1 and plug it in again (the capture needs to see it start up).
  2. Start the Softube Console 1 application, and wait until it has found the unit.
  3. For each thing that you do next, type a short label and press Enter, BEFORE you do it:
       shift alone
       shift+phase
       shift+preset
       shift+solo, shift+mute, shift+volume, shift+drive, shift+character, shift+pan
       shift+gain knob
     and look at what the application does at each step.
  4. When you are done, press Enter on an empty line.

EOF

# shellcheck disable=SC2086
sudo dumpcap -q $interface_args -w "$capture" &
dumpcap_pid=$!
sleep 2
echo "(capturing)"

while true; do
  printf "label> "
  IFS= read -r label
  [ -n "$label" ] || break
  now=$(python3 -I -c 'import time; print("%.6f" % time.time())')
  printf '%s\t%s\n' "$now" "$label" >> "$markers"
done

sudo kill -INT "$dumpcap_pid" 2>/dev/null
wait "$dumpcap_pid" 2>/dev/null
sudo chown "$USER" "$capture" 2>/dev/null

echo
echo "Capture: $capture"
echo "Markers: $markers"
echo
python3 -I "$here/decode_usb_midi.py" "$capture" --markers "$markers" | tee "$here/captures/console1-$stamp.report.txt"
echo
echo "The report is also in captures/console1-$stamp.report.txt. Send it, and the .pcapng file, back."
