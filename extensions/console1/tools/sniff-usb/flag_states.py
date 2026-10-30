#!/usr/bin/env python3
"""Shows a control of a Console 1 in each combination of its value byte and its two flag bits, one at a time, and asks what it looks like.

The chase found that the LED of a control shows when its value byte is not zero and its bank A bit is set, and that the
bank B bit visibly changes it, but blinking could not say how: dimmer, brighter, another color, or on and off. This script
holds one combination until you have looked at it, and you describe it in a few words ("dark", "lit", "dim", "bright", "red"
or whatever you see). Nothing blinks and nothing is timed.

The combinations, in the order that they are shown, are (value byte, bank A bit, bank B bit):
  1  value 00,  A 0, B 0     everything off
  2  value on,  A 0, B 0     only the value
  3  value on,  A 1, B 0     the state that the chase called lit
  4  value on,  A 0, B 1     only the bank B bit with the value
  5  value on,  A 1, B 1     both bits
  6  value 00,  A 1, B 1     both bits without the value

For a knob ring, "value on" is the middle of the ring (40), so that a ring that shows a position shows a partial ring.

The Softube application must be closed.

Usage (with the python of the environment that listen-macos.sh sets up):
  flag_states.py --only Phase,Inpt_Gain,Comp_comp   the controls to show (names separated by commas)
  flag_states.py --port NAME                        use the ports whose name contains NAME (the default is "Console 1")
At each prompt: type the description and press Enter, r to show the same combination again, q to stop.
"""

import json
import os
import sys
import time

import mido

import state_frame
from handshake_replay import DEFAULT_PORT, find_port, replay
from led_chase import flag_change, load_controls
from probe_destinations import Probe, check_model, send_frame

COMBINATIONS = [
    ("1  value 00,  A 0, B 0", False, 0, 0),
    ("2  value on,  A 0, B 0", True, 0, 0),
    ("3  value on,  A 1, B 0", True, 1, 0),
    ("4  value on,  A 0, B 1", True, 0, 1),
    ("5  value on,  A 1, B 1", True, 1, 1),
    ("6  value 00,  A 1, B 1", False, 1, 1),
]


def combination_changes(control_id, kind, value_on, a_bit, b_bit):
    """The payload bytes for one combination: the value byte, and the bit of the id in bank A and in bank B."""
    value = (0x40 if kind == "knob" else 0x7F) if value_on else 0
    changes = {control_id + 1: value}
    for bank, on in (("a", a_bit), ("b", b_bit)):
        flag_index, flag_value = flag_change(control_id, bank, bool(on))
        changes[flag_index] = flag_value
    return changes


def show(probe, changes):
    """Sends the combination twice, because the unit keeps the last state that it received."""
    for _ in range(2):
        send_frame(probe, changes)
        time.sleep(0.05)


def run(probe, controls, results):
    for control_id, name, kind in controls:
        position = 0
        while position < len(COMBINATIONS):
            label, value_on, a_bit, b_bit = COMBINATIONS[position]
            show(probe, combination_changes(control_id, kind, value_on, a_bit, b_bit))
            answer = input("%-18s %s  : what does it look like? " % (name, label)).strip()
            if answer.lower() == "q":
                return
            if answer.lower() == "r":
                continue
            results.append({"control": name, "id": control_id, "combination": label, "answer": answer})
            position += 1
        send_frame(probe, {})
        print()


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    assert "--only" in argv, "name the controls to show with --only, for example --only Phase,Inpt_Gain"
    wanted = [part.strip().lower() for part in argv[argv.index("--only") + 1].split(",")]
    controls = [c for c in load_controls() if any(part in c[1].lower() for part in wanted)]
    assert controls, "no control name contains any of %r" % wanted
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name." % name)
        return 1

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    path = os.path.join(here, "captures", "console1-flags-%s.json" % time.strftime("%Y%m%d-%H%M%S"))
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
        print("\nLook at the control, describe what you see, and press Enter for the next combination. r = again, q = stop.\n")
        try:
            run(probe, controls, results)
        except (KeyboardInterrupt, EOFError):
            print("\nStopped.")
        send_frame(probe, {})
    json.dump(results, open(path, "w"), indent=2)
    print("\nThe answers are in %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
