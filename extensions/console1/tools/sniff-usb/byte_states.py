#!/usr/bin/env python3
"""Sets one byte of the state frame of a Console 1 to a list of values, one at a time, and asks what the unit looks like.

The state frame has two bytes at the end (95 and 96) that the application always sends as 20 and 03, and whose meaning
is not known: blinking byte 95 between 00 and 7F made every section go dark but the input and output, and byte 96 lit
some LEDs when the blinking stopped. For each byte this script shows, in this order: the application's value (the
reference), 00, each single bit (01, 02, 04, 08, 10, 20, 40) and 7F. Each value is held until you have looked, and you
describe it in a few words. The other bytes stay at the quiet frame, so the differences are those of the byte.

The Softube application must be closed.

With --ramp the byte is not shown at a few values but swept slowly from 00 to 7F and back, so that a gradual change such as
a brightness can be seen. You press Enter each time that you notice any change, and the script writes down the value at
that moment, so the values where the unit changes are known.

Usage (with the python of the environment that listen-macos.sh sets up):
  byte_states.py                       the bytes 95 and 96
  byte_states.py --bytes 95            only these payload byte numbers (separated by commas)
  byte_states.py --ramp 96             sweep this byte up and down, and press Enter at each change that you notice
  byte_states.py --step 0.15           seconds per value in the ramp (the default is 0.15, so a sweep is about 19 s)
  byte_states.py --port NAME           use the ports whose name contains NAME (the default is "Console 1")
At each prompt: type the description and press Enter, r to show the same value again, q to stop.
"""

import json
import os
import select
import sys
import time

import mido

import state_frame
from handshake_replay import DEFAULT_PORT, find_port, replay
from probe_destinations import Probe, check_model, send_frame

SINGLE_BITS = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x7F]


def values_for(index):
    """The application's value first, as the reference, and then the others without repeating it."""
    reference = state_frame.BASE[state_frame.PAYLOAD_START + index]
    return [reference] + [v for v in SINGLE_BITS if v != reference]


def show(probe, changes):
    """Sends the state twice, because the unit keeps the last state that it received."""
    for _ in range(2):
        send_frame(probe, changes)
        time.sleep(0.05)


def run(probe, indexes, results):
    for index in indexes:
        values = values_for(index)
        position = 0
        while position < len(values):
            value = values[position]
            show(probe, {index: value})
            tag = "the application's value" if position == 0 else "                       "
            answer = input("byte %2d = %02X (%s)  : what does the unit look like? " % (index, value, tag)).strip()
            if answer.lower() == "q":
                send_frame(probe, {})
                return
            if answer.lower() == "r":
                continue
            results.append({"byte": index, "value": value, "reference": position == 0, "answer": answer})
            position += 1
        send_frame(probe, {})
        print()


def run_ramp(probe, index, step_time, results):
    """Sweeps the byte from 00 to 7F and back, and records the value at each Enter press."""
    sweep = list(range(0, 128)) + list(range(126, -1, -1))
    print("Sweeping byte %d from 00 to 7F and back (%.0f s). Press Enter each time you notice a change.\n" % (index, len(sweep) * step_time))
    noticed = []
    for position, value in enumerate(sweep):
        send_frame(probe, {index: value})
        direction = "up" if position < 128 else "down"
        print("\r  value %02X (%s)   " % (value, direction), end="", flush=True)
        deadline = time.time() + step_time
        while time.time() < deadline:
            ready, _, _ = select.select([sys.stdin], [], [], 0.01)
            if ready:
                if sys.stdin.readline() == "":
                    return
                noticed.append({"value": value, "direction": direction})
                results.append({"byte": index, "value": value, "direction": direction, "answer": "change noticed"})
                print("\n  noticed a change at %02X (%s)" % (value, direction), flush=True)
    print("\n\nValues where you noticed a change: %s" % (", ".join("%02X %s" % (n["value"], n["direction"]) for n in noticed) or "none"))


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    indexes = [int(part) for part in argv[argv.index("--bytes") + 1].split(",")] if "--bytes" in argv else [95, 96]
    ramp = int(argv[argv.index("--ramp") + 1]) if "--ramp" in argv else None
    step_time = float(argv[argv.index("--step") + 1]) if "--step" in argv else 0.15
    assert all(0 < i < state_frame.PAYLOAD_LENGTH for i in indexes + ([ramp] if ramp else [])), "a payload byte number is between 1 and 96"
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name." % name)
        return 1

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    path = os.path.join(here, "captures", "console1-bytes-%s.json" % time.strftime("%Y%m%d-%H%M%S"))
    results = []
    with mido.open_input(in_name) as port_in, mido.open_output(out_name) as port_out:
        probe = Probe(port_in, port_out, open(os.devnull, "w"), 0x7F, 0)
        if not replay(port_in, port_out):
            print("The handshake failed. Is the Softube application closed?")
            return 1
        print()
        if not check_model(probe):
            print("The unit did not acknowledge a frame built with the model.")
            return 1
        try:
            if ramp:
                run_ramp(probe, ramp, step_time, results)
            else:
                print("\nDescribe the unit for each value and press Enter. The first value of each byte is the reference. r = again, q = stop.\n")
                run(probe, indexes, results)
        except (KeyboardInterrupt, EOFError):
            print("\nStopped.")
        send_frame(probe, {})
    json.dump(results, open(path, "w"), indent=2)
    print("\nThe answers are in %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
