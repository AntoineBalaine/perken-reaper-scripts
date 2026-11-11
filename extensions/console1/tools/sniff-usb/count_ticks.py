#!/usr/bin/env python3
"""Counts the ticks that a knob of a Console 1 sends for one full revolution, to tell how fine a step of a tick should be.

In the sysex mode every tick of a knob is one message, so the number of messages for a turn is the resolution of the
knob. This script replays the handshake, then asks you to turn one knob a full revolution clockwise, and press Enter,
and then a full revolution counter-clockwise, and press Enter. It does this three times for each knob and prints the
counts, with the time of each turn and the fastest burst, so that the speed of a turn can be read as well.

The Softube application must be closed.

Usage (with the python of the environment, not the system python, because mido is installed there):
  .venv/bin/python count_ticks.py                      the input Gain knob
  .venv/bin/python count_ticks.py --knobs Gain,Out_Vol the knobs whose name contains one of these (separated by commas)
  .venv/bin/python count_ticks.py --port NAME          use the ports whose name contains NAME (the default is "Console 1")
"""

import select
import sys
import time

import mido

from handshake_replay import DEFAULT_PORT, find_port, replay
from led_chase import load_controls
from map_controls import parse_control

TURNS = 3


def count_turn(port_in, control_id, direction_value):
    """Counts the ticks of the control with the value 7F (clockwise) or 00 (counter-clockwise) until Enter is pressed."""
    for _ in port_in.iter_pending():
        pass
    times = []
    while True:
        for message in port_in.iter_pending():
            control = parse_control(message)
            if control is not None and control[0] == control_id and control[1] == direction_value:
                times.append(time.time())
        ready, _, _ = select.select([sys.stdin], [], [], 0.01)
        if ready:
            sys.stdin.readline()
            break
    return times


def burst(times, window=0.2):
    """The most ticks that fall inside one window of 200 ms."""
    best = 0
    for start in range(len(times)):
        end = start
        while end + 1 < len(times) and times[end + 1] - times[start] <= window:
            end += 1
        best = max(best, end - start + 1)
    return best


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    wanted = [part.strip().lower() for part in (argv[argv.index("--knobs") + 1] if "--knobs" in argv else "Inpt_Gain").split(",")]
    knobs = [c for c in load_controls() if c[2] == "knob" and any(part in c[1].lower() for part in wanted)]
    assert knobs, "no knob has a name that contains any of %r" % wanted
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name." % name)
        return 1
    with mido.open_input(in_name) as port_in, mido.open_output(out_name) as port_out:
        if not replay(port_in, port_out):
            print("The handshake failed. Is the Softube application closed?")
            return 1
        print("\nFor each turn: turn the knob one full revolution at the speed that you would normally use, and press Enter.\n")
        results = {}
        try:
            for control_id, knob_name, _ in knobs:
                counts = {"clockwise": [], "counter-clockwise": []}
                for turn in range(1, TURNS + 1):
                    for label, value in (("clockwise", 0x7F), ("counter-clockwise", 0x00)):
                        input("%s, turn %d of %d: Enter, then turn one revolution %s, then Enter again. " % (knob_name, turn, TURNS, label))
                        times = count_turn(port_in, control_id, value)
                        seconds = (times[-1] - times[0]) if len(times) > 1 else 0.0
                        counts[label].append((len(times), seconds, burst(times)))
                        print("   %d ticks in %.2f s, at most %d inside 200 ms" % (len(times), seconds, burst(times)))
                results[knob_name] = counts
        except (EOFError, KeyboardInterrupt):
            print("\nStopped.")
    print("\nTicks for one revolution:")
    for knob_name, counts in results.items():
        for label, turns in counts.items():
            ticks = [t for t, _, _ in turns]
            if ticks:
                print("  %-14s %-18s %s  (min %d, max %d)" % (knob_name, label, ticks, min(ticks), max(ticks)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
