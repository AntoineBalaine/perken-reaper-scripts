#!/usr/bin/env python3
"""Guides a session in which the Softube application talks to the Console 1, and writes the timeline of the steps.

What the application sends to the unit (the LEDs, the meters, the display) cannot be heard from a script, because only
the application is the sender. MIDI Monitor, in spy mode, shows it. Because the two files must be read side by side, this
script writes a marker with the wall-clock time of each step, in the same HH:MM:SS.mmm form that MIDI Monitor uses.

It does not open any MIDI port, so the Softube application keeps the unit to itself, and it needs no libraries.

Before it starts:
  1. Open MIDI Monitor, with the spying on the output to the destinations turned on, the Console 1 selected as a
     destination and as a source, and the window cleared.
  2. Start the Softube application and wait until it has found the unit, with the plugin on a track that can play audio.

Usage:
  feedback_session.py
"""

import os
import sys
import time

STEPS = [
    "silence: no audio is playing and nothing is touched (the meters at rest)",
    "audio: play a steady signal through the plugin, without touching the unit",
    "audio: play the signal loud, then quiet it down, with the input Gain knob",
    "audio: turn the Drive knob up and down while the signal plays",
    "compressor: switch the Comp button on, lower the Threshold until the compressor works, then raise it again",
    "compressor: switch the Comp button off",
    "gate: switch the Shape button on, raise the Gate until it cuts the signal, then lower it again",
    "gate: switch the Shape button off",
    "output meters: play the signal clipping loud, then stop the audio",
    "LEDs: switch Phase Inv on and off with the button on the unit",
    "LEDs: switch Mute on and off with the button on the unit",
    "LEDs: switch Solo on and off with the button on the unit",
    "LEDs: switch Phase Inv on and off with the mouse, on the screen of the plugin",
    "LEDs: switch Mute on and off with the mouse, on the screen of the plugin",
    "LEDs: select another track with a track button, and then back to the first one",
    "LEDs: press the Page Down and then the Page Up button",
    "LEDs: switch the EQ button on and off",
    "knobs: turn the EQ Low Gain knob slowly clockwise to its end, and then back to its start",
    "display: press the display On button, wait, and press it again",
    "display: press the display Mode button three times",
    "preset: press the Preset button, and press it again to leave",
    "shift: hold shift and, for each of them, press the buttons that print a function with shift (Bypass, Save Preset, OK, Cancel, Select, Send 1 to 3), looking at what the screen and the unit do",
    "OSD: switch the on-screen display of the Softube application off, and then on",
]


def stamp(now):
    return time.strftime("%H:%M:%S", time.localtime(now)) + ".%03d" % int((now % 1) * 1000)


def mark(log, label):
    line = "%s  %s" % (stamp(time.time()), label)
    log.write(line + "\n")
    log.flush()


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    path = os.path.join(here, "captures", "console1-feedback-%s.log" % time.strftime("%Y%m%d-%H%M%S"))
    print("For each step, read what to do, press Enter, do it, and press Enter again when it is done.")
    print("The markers carry the wall-clock time, so they can be read against MIDI Monitor.\n")
    with open(path, "w") as log:
        try:
            for number, step in enumerate(STEPS, 1):
                input("[%d/%d] Next: %s.\n        Press Enter, then do it. " % (number, len(STEPS), step))
                mark(log, "begin: " + step)
                input("        Press Enter when it is done. ")
                mark(log, "end: " + step)
        except (EOFError, KeyboardInterrupt):
            print("\nStopped early.")
        else:
            print("\nAll steps are done.")
    print("The markers are in %s. Save the MIDI Monitor window next to it (File, Save As)." % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
