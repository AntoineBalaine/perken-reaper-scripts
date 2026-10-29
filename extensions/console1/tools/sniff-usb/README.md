# Looking for what the Console 1 does not say

The Console 1 shows nothing on its MIDI port when the shift button is pressed, and its face prints functions that
only exist with shift (Bypass, Save Preset, OK, Cancel, Select, Send 1 to 3). The Softube application gets them
somehow, so it either hears a message that a plain MIDI monitor does not show, or it sends the unit something at
startup that turns them on. The tools in this folder look for both.

What is already known, from the probe of the unit: it is a class-compliant USB MIDI device (USB id 0483:a0f6, made
by Softube AB) with one MIDI interface, one input and one output endpoint, one cable, and no HID or vendor
interface. It does not answer the universal Device Inquiry. Shift alone sends nothing, and shift held with a knob
makes the knob move in steps of 1 instead of 3, so the firmware handles shift as a fine adjust.

## Which tool, on which Mac

| Mac | what to run |
|---|---|
| Apple silicon | `listen-macos.sh` and MIDI Monitor, as described below |
| Intel | `sniff-macos.sh`, which captures the USB bus itself (see the end of this file) |

The USB bus cannot be captured on Apple silicon, so the two directions are seen at the level of CoreMIDI, through
which the Softube application reaches the unit: `listen-macos.sh` hears what the unit sends, and MIDI Monitor's
spy mode shows what the application sends to the unit.

## On a Mac with Apple silicon

Do the steps below once, with both tools running at the same time.

1. Install MIDI Monitor, free, from Snoize (snoize.com). In its preferences, turn on the spying on the output to the
   destinations, then select the destination of the Console 1 in its source list, and the Console 1 as a source
   too. Leave its window open, and clear it.
2. In a terminal in this folder, run `./listen-macos.sh`. The first run sets up a python environment. It prints the
   port it listens to (the name has "Console 1" in it) and asks for labels.
3. Unplug the Console 1 and plug it in again, so that its startup is seen by both. Then start the Softube
   application, and wait until it has found the unit.
4. For each thing that you do next, type a short label in the terminal and press Enter before you do it, then do it,
   then wait three seconds, so that the MIDI Monitor window can be read against the labels:
   - shift alone, three times
   - shift held with Phase Inv, then Phase Inv alone
   - shift held with Preset, then Preset alone
   - shift held with Solo, Mute, Volume, Drive, Character and Pan, one after the other
   - shift held while turning the Gain knob, then the Gain knob alone

   Look at what the application does at each step, and write down any that it reacts to.
5. Press Enter on an empty line. The terminal prints a report and writes a log into `captures/`.
6. In MIDI Monitor, save the window (File, Save As), or select everything and copy it into a text file.
7. Send back the log, the MIDI Monitor file, and the notes of what the application did.

What to look for:

- in MIDI Monitor, what the application sends to the unit in the first seconds: a sysex, or a fixed series of CCs,
  is a handshake that may switch features on;
- in the report, any sysex, any CC that the extension does not know, any kind of message that is not a note or a
  CC, next to a label that has to do with shift;
- a difference between the messages of a button with shift and without it.

## Files

- `listen-macos.sh` starts `listen_coremidi.py`, which listens to the port of the unit. It uses mido and
  python-rtmidi, which `listen-macos.sh` installs into `.venv` on the first run.
- `decode_usb_midi.py` decodes USB capture files, and makes the report that `listen_coremidi.py` prints. It runs
  anywhere that has python3, and a capture file also needs tshark: `python3 decode_usb_midi.py capture.pcapng`.
- `sniff-macos.sh` captures the USB bus on the Macs that can (see below).
- `captures/` is where the captures and the reports are written. It is not kept in git.

The listener was tried on the real unit on Linux, where it found the port and recorded the knob and button
messages with their labels. What was not tried is the MIDI Monitor part and the run on macOS itself.

## On an Intel Mac

`sniff-macos.sh` captures the USB bus with Wireshark's command line tools (`brew install --cask wireshark`), and
decodes the capture. It sees the USB control requests too, which no MIDI tool can show. It needs the USB capture
interfaces (`XHC20` and its like) that Intel Macs have, and on a recent macOS they need the debug protection of the
system to be off:

```
restart in recovery mode, then, in the terminal:   csrutil enable --without debug
after the restart:                                 sudo ifconfig XHC20 up
```

The script says what it needs if one of these is missing.
