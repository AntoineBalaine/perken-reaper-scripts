#!/usr/bin/env python3
"""Blinks the LED or the ring of each control of a Console 1, one control at a time, until you say whether you see it.

The hypothesis that this checks is that the LED state of a control is the payload byte (sysex control id + 1) of the
state frame: 7F lights a button, and a knob ring takes a position from 00 to 7F. The app's own quiet frame has 3F (the
center) at the bytes of the knobs and 7F at the buttons that are on, which is where the hypothesis comes from. The
control ids come from the table that map_controls.py wrote (the latest captures/console1-controls-*.json).

The LED of a control is also gated by flag bits: the payload bytes 73 to 83 (bank A) and 84 to 94 (bank B) hold one bit per
control id, seven bits to a byte, in reverse order inside each byte: the bit of an id is bit (6 - id mod 7) of the byte
(bank start + id div 7). The reversal was found from a chase that blinked the wrong LED: blinking the id 0x2A lit the
control 0x30, the id 0x2B lit 0x2F, and so on. The --flags option says which of these bits are blinked with the value byte.

Each control blinks alone and keeps blinking, while the others stay at the quiet frame, until you answer:
  y  (and Enter)   yes, I see that control blinking
  n  (and Enter)   no, I do not see it (or something else blinked instead: type n and the name, for example "n gain")
  any other text   is kept as your label, and listed at the end ("y and eq lo gain too" is listed, because it is not a plain y)
  r  (and Enter)   go back one control
  q  (and Enter)   stop
A button alternates between off and the test value. A knob ring sweeps up and down between 00 and the test value.

With --vary the control stays lit (its value byte and the bit of the other bank stay set) and only the bit of the given
bank alternates between 1 and 0. You then say what changes on the unit between the two states: nothing, or a label such as
"dimmer", "color" or "blinks". The point is to find out what the bank B bit does, which the application's frames do not
say: it is never set without the bank A bit, it is always off for the input and output sections, and it follows the
bank A bit for the other sections.
Every answer is written to captures/console1-led-*.json, and the ones that were not seen are listed at the end.

The Softube application must be closed.

Usage (with the python of the environment that listen-macos.sh sets up):
  led_chase.py                       go through all 65 controls (everything but shift) and the 6 meters, in the order of their ids
  led_chase.py --only Eq_,Phase      only the controls whose name contains one of these texts (separated by commas)
  led_chase.py --value 40            the lit value, in hexadecimal (the default is 7F)
  led_chase.py --flags a             blink the bank A flag bit with the value (a, b, ab or none; the default is a)
  led_chase.py --vary b              keep the control lit and alternate only the bank B bit (a or b)
  led_chase.py --port NAME           use the ports whose name contains NAME (the default is "Console 1")
"""

import glob
import json
import os
import select
import sys
import time

import mido

import state_frame
from handshake_replay import DEFAULT_PORT, find_port, replay
from probe_destinations import Probe, check_model, send_frame

FLAG_BANKS = {"a": 73, "b": 84}
BUTTON_PERIOD = 0.4
VARY_PERIOD = 0.8
RING_STEPS = 8
RING_STEP_TIME = 0.09
# Some controls were pressed in the other order during the mapping session, so their names and kinds are corrected here:
# the two display buttons, and the shape button and the gate knob (the chase showed the shape button at 0x21).
RENAMED = {
    0: ("Inpt_disp_on", "button"),
    1: ("Inpt_disp_mode", "button"),
    0x21: ("Shp_shape", "button"),
    0x22: ("Shp_Gate", "knob"),
}

# The meters have no button of their own, but they follow the controls in the ids and in the flags of the LED banks: the
# value byte of id 66 to 71 is the payload byte 67 to 72. Their order is that of the legacy CCs 0x6E to 0x73 in c1.zig.
# This is the hypothesis that the chase checks for them.
METERS = [
    (66, "Inpt_MtrLft", "knob"),
    (67, "Inpt_MtrRgt", "knob"),
    (68, "Out_MtrLft", "knob"),
    (69, "Out_MtrRgt", "knob"),
    (70, "Shp_Mtr", "knob"),
    (71, "Comp_Mtr", "knob"),
]


def load_controls():
    """The controls and the meters as (id, name, kind), in the order of their ids. Shift has no entry, because it has no LED."""
    here = os.path.dirname(os.path.abspath(__file__))
    paths = sorted(glob.glob(os.path.join(here, "captures", "console1-controls-*.json")))
    assert paths, "no console1-controls-*.json in captures/: run map_controls.py first"
    controls = {}
    for entry in json.load(open(paths[-1])):
        if entry["id"] is not None:
            controls[entry["id"]] = RENAMED.get(entry["id"], (entry["name"], entry["kind"]))
    for meter_id, meter_name, kind in METERS:
        assert meter_id not in controls, "the id of a meter must not be the id of a control"
        controls[meter_id] = (meter_name, kind)
    return [(i, controls[i][0], controls[i][1]) for i in sorted(controls)]


def levels(kind, value):
    """The values that the byte takes in one cycle of the blinking, each held for the returned time."""
    if kind == "knob":
        up = [value * step // RING_STEPS for step in range(RING_STEPS + 1)]
        return up + up[-2:0:-1], RING_STEP_TIME
    return [value, 0], BUTTON_PERIOD


def flag_change(control_id, bank, on):
    """The (payload byte, new value) that sets or clears the bit of the control id in the flag bank."""
    flag_index = FLAG_BANKS[bank] + control_id // 7
    assert flag_index < state_frame.PAYLOAD_LENGTH, "the flag byte of a control id must be inside the payload"
    base = state_frame.BASE[state_frame.PAYLOAD_START + flag_index]
    bit = 1 << (6 - control_id % 7)
    return flag_index, ((base | bit) if on else (base & ~bit))


def lit_changes(control_id, level, banks):
    """The payload bytes to change so that the control shows `level`: its value byte, and the bit of its id in each flag bank."""
    index = control_id + 1
    assert 0 < index < state_frame.PAYLOAD_LENGTH, "the byte of a control id must be inside the payload"
    changes = {index: level}
    for bank in banks:
        flag_index, value = flag_change(control_id, bank, level > 0)
        changes[flag_index] = value
    return changes


def vary_changes(control_id, value, fixed_banks, vary_bank, on):
    """The control stays lit (value byte and the bits of the fixed banks set), and the bit of the varied bank is `on`."""
    changes = lit_changes(control_id, value, fixed_banks)
    flag_index, flag_value = flag_change(control_id, vary_bank, on)
    changes[flag_index] = flag_value
    return changes


def blink_until_answer(probe, control_id, kind, value, banks, vary):
    """Blinks the control until a line is typed, then puts the quiet frame back and returns the line."""
    cycle, hold = levels(kind, value)
    step = 0
    next_change = 0.0
    while True:
        if time.time() >= next_change:
            if vary:
                send_frame(probe, vary_changes(control_id, value, banks, vary, step % 2 == 0))
                next_change = time.time() + VARY_PERIOD
            else:
                send_frame(probe, lit_changes(control_id, cycle[step % len(cycle)], banks))
                next_change = time.time() + hold
            step += 1
        for _ in probe.port_in.iter_pending():
            pass
        ready, _, _ = select.select([sys.stdin], [], [], 0.02)
        if ready:
            line = sys.stdin.readline()
            if line == "":
                return "q"
            break
    send_frame(probe, {})
    return line.strip()


def run_chase(probe, controls, value, banks, vary, results):
    """Goes through the controls; returns when all are answered or the user stops."""
    position = 0
    while position < len(controls):
        control_id, name, kind = controls[position]
        head = "[%d/%d] id 0x%02X  payload byte %2d  %-18s %s" % (position + 1, len(controls), control_id, control_id + 1, name, kind)
        if vary:
            print("%s: the bank %s bit alternates. What changes between the two states? (n = nothing, or type it) " % (head, vary.upper()), end="", flush=True)
        else:
            print("%s: blinking. Do you see it? (y/n) " % head, end="", flush=True)
        answer = blink_until_answer(probe, control_id, kind, value, banks, vary)
        lowered = answer.lower()
        if lowered == "q":
            return
        if lowered == "r":
            position = max(0, position - 1)
            continue
        results[name] = {"id": control_id, "byte": control_id + 1, "flags": "".join(banks), "vary": vary, "answer": answer}
        position += 1


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    value = int(argv[argv.index("--value") + 1], 16) if "--value" in argv else 0x7F
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    flags = argv[argv.index("--flags") + 1] if "--flags" in argv else "a"
    assert flags in ("a", "b", "ab", "none"), "--flags is a, b, ab or none"
    banks = [] if flags == "none" else list(flags)
    vary = argv[argv.index("--vary") + 1] if "--vary" in argv else None
    assert vary in (None, "a", "b"), "--vary is a or b"
    if vary:
        # Because the varied bank must not also be fixed, the other bank is the one that stays set.
        banks = ["b" if vary == "a" else "a"]
    assert 0 < value <= 0x7F, "the lit value is a 7-bit value above zero"
    wanted = [part.strip().lower() for part in only.split(",")] if only else None
    controls = [c for c in load_controls() if wanted is None or any(part in c[1].lower() for part in wanted)]
    assert controls, "no control name contains %r" % only
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name." % name)
        return 1

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    path = os.path.join(here, "captures", "console1-led-%s.json" % time.strftime("%Y%m%d-%H%M%S"))
    results = {}
    with mido.open_input(in_name) as port_in, mido.open_output(out_name) as port_out:
        probe = Probe(port_in, port_out, open(os.devnull, "w"), value, 0)
        if not replay(port_in, port_out):
            print("The handshake failed. Is the Softube application closed?")
            return 1
        print()
        if not check_model(probe):
            print("The unit did not acknowledge a frame built with the model.")
            return 1
        print("\nEach control blinks until you answer: y = I see it, n = I do not (or n and a name), r = back, q = stop.\n", flush=True)
        try:
            run_chase(probe, controls, value, banks, vary, results)
        except KeyboardInterrupt:
            print("\nStopped.")
            send_frame(probe, {})
    json.dump(results, open(path, "w"), indent=2)

    if vary:
        changed = [(n, r) for n, r in results.items() if r["answer"].lower() != "n"]
        print("\nNo difference: %d. Something changed: %d" % (len(results) - len(changed), len(changed)))
        for control_name, record in changed:
            print("  id 0x%02X byte %2d  %-18s %r" % (record["id"], record["byte"], control_name, record["answer"]))
    else:
        # Because an answer that carries a label ("y and eq lo gain too") says more than a plain y, only a bare y is counted as seen.
        missed = [(n, r) for n, r in results.items() if r["answer"].lower() != "y"]
        print("\nSeen with a plain y: %d. Not seen, or with a label: %d" % (len(results) - len(missed), len(missed)))
        for control_name, record in missed:
            print("  id 0x%02X byte %2d  %-18s answered %r" % (record["id"], record["byte"], control_name, record["answer"]))
    print("\nThe answers are in %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
