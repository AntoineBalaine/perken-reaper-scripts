#!/usr/bin/env python3
"""Asks for each control of the Console 1 by its name, one at a time, and records the sysex control id that it sends.

Because the unit only reports its controls in sysex after the handshake of the Softube application, this script first
replays that handshake (see handshake_replay.py), and then walks through the controls. Because shift never changes
the message of another control, every control is asked for once, without shift.

For each step, the script says what to do and moves to the next step by itself, as soon as it has seen the control
do both of the things that were asked: a button must be pressed and released (7F and then 00), and a knob must be
turned clockwise and counter-clockwise (7F ticks and 00 ticks). A control that does not exist on the unit, or that
cannot be found, is skipped by pressing Enter.

The Softube application must be closed. When all steps are done, anything that is pressed afterwards and that does not
belong to a known control is printed, until Ctrl-C, so that controls missing from the list are found as well.

Usage (with the python of the environment that listen-macos.sh sets up):
  map_controls.py                 replay the handshake and walk through the controls
  map_controls.py --only NAME     ask only for the controls whose name contains NAME (for a repeat of a few steps)
  map_controls.py --port NAME     use the ports whose name contains NAME (the default is "Console 1")
"""

import json
import os
import select
import sys
import time

import mido

from handshake_replay import DEFAULT_PORT, describe, find_port, replay

SETTLE_SECONDS = 0.6

BUTTON = "button"
KNOB = "knob"

# The names follow the CCs and Btns of src/c1.zig, so that the table that comes out can be read against them.
CONTROLS = [
    ("Inpt_Gain", KNOB, "the input Gain knob"),
    ("Inpt_phase_inv", BUTTON, "the Phase Inv button"),
    ("Inpt_LoCut", KNOB, "the input Low Cut knob"),
    ("Inpt_HiCut", KNOB, "the input High Cut knob"),
    ("Inpt_filt_to_comp", BUTTON, "the button that sends the filters to the compressor"),
    ("Inpt_preset", BUTTON, "the Preset button"),
    ("Inpt_disp_mode", BUTTON, "the display Mode button"),
    ("Inpt_disp_on", BUTTON, "the display On button"),
    ("Shp_Gate", KNOB, "the Gate knob of the shape section"),
    ("Shp_GateRelease", KNOB, "the Gate Release knob"),
    ("Shp_Punch", KNOB, "the Punch knob"),
    ("Shp_sustain", KNOB, "the Sustain knob"),
    ("Shp_shape", BUTTON, "the Shape button"),
    ("Shp_hard_gate", BUTTON, "the Hard Gate button"),
    ("Eq_eq", BUTTON, "the EQ button"),
    ("Eq_hp_shape", BUTTON, "the high-pass Shape button of the EQ"),
    ("Eq_lp_shape", BUTTON, "the low-pass Shape button of the EQ"),
    ("Eq_HiGain", KNOB, "the EQ high Gain knob"),
    ("Eq_HiFrq", KNOB, "the EQ high Frequency knob"),
    ("Eq_HiMidGain", KNOB, "the EQ high-mid Gain knob"),
    ("Eq_HiMidFrq", KNOB, "the EQ high-mid Frequency knob"),
    ("Eq_HiMidQ", KNOB, "the EQ high-mid Q knob"),
    ("Eq_LoMidGain", KNOB, "the EQ low-mid Gain knob"),
    ("Eq_LoMidFrq", KNOB, "the EQ low-mid Frequency knob"),
    ("Eq_LoMidQ", KNOB, "the EQ low-mid Q knob"),
    ("Eq_LoGain", KNOB, "the EQ low Gain knob"),
    ("Eq_LoFrq", KNOB, "the EQ low Frequency knob"),
    ("Comp_comp", BUTTON, "the Comp button"),
    ("Comp_Thresh", KNOB, "the compressor Threshold knob"),
    ("Comp_Ratio", KNOB, "the compressor Ratio knob"),
    ("Comp_Attack", KNOB, "the compressor Attack knob"),
    ("Comp_Release", KNOB, "the compressor Release knob"),
    ("Comp_DryWet", KNOB, "the compressor Dry/Wet knob"),
    ("Out_Drive", KNOB, "the Drive knob"),
    ("Out_DriveChar", KNOB, "the Character knob"),
    ("Out_Pan", KNOB, "the Pan knob"),
    ("Out_Vol", KNOB, "the Volume knob"),
    ("Out_mute", BUTTON, "the Mute button"),
    ("Out_solo", BUTTON, "the Solo button"),
    ("Tr_order", BUTTON, "the Order button"),
    ("Tr_ext_sidechain", BUTTON, "the External Sidechain button"),
    ("Tr_pg_up", BUTTON, "the Page Up button"),
    ("Tr_pg_dn", BUTTON, "the Page Down button"),
    ("Tr_tr_copy", BUTTON, "the Copy button"),
    ("Tr_tr_grp", BUTTON, "the Group button"),
] + [("Tr_tr%d" % n, BUTTON, "the track button %d" % n) for n in range(1, 21)]

SHIFT_ID = 0x02


class Session:
    """What the steps share, grouped here because the helpers of a step cannot be nested functions."""

    def __init__(self, port_in, log):
        self.port_in = port_in
        self.log = log
        self.start = time.time()
        self.found = {}  # control id -> name
        self.results = []  # one dictionary per step


def parse_control(message):
    """Returns (control id, value) for a control event of the unit, and None for any other message."""
    if message.type != "sysex":
        return None
    data = bytes(message.data)
    if len(data) < 9 or data[1] != 0x00 or data[5] != 2:
        return None
    return data[7], data[8]


def write_log(session, text):
    session.log.write("%8.3f  %s\n" % (time.time() - session.start, text))
    session.log.flush()


def enter_was_pressed():
    """Because a skip must not stop the listening, the keyboard is only looked at, without waiting for it."""
    ready, _, _ = select.select([sys.stdin], [], [], 0)
    if ready:
        # Because a closed keyboard returns an empty string without a newline, only a real line is a skip.
        return sys.stdin.readline().endswith("\n")
    return False


def run_step(session, name, kind, what, number, total):
    """Waits until the control of the step has been seen doing what the kind asks, and returns the result."""
    asked = "pressed and released" if kind == BUTTON else "turned clockwise and then counter-clockwise"
    print("[%d/%d] %s: please use %s (%s). Enter skips." % (number, total, name, what, asked), flush=True)
    write_log(session, "step: %s" % name)
    seen = {}  # control id -> set of values
    last_event = None
    while True:
        for message in session.port_in.iter_pending():
            control = parse_control(message)
            write_log(session, describe(message) if control is None else "event id 0x%02X value %02X" % control)
            if control is None or control[0] == SHIFT_ID:
                continue
            seen.setdefault(control[0], set()).add(control[1])
            last_event = time.time()
        if last_event is not None and time.time() - last_event > SETTLE_SECONDS:
            complete = [c for c, values in seen.items() if values == {0x7F, 0x00}]
            if complete:
                break
            print("        saw only part of it (%s): please do the other half." % describe_seen(seen), flush=True)
            last_event = None
        if enter_was_pressed():
            return {"name": name, "kind": kind, "id": None, "skipped": True, "seen": describe_seen(seen)}
        time.sleep(0.005)
    control_id = complete[0]
    note = ""
    if control_id in session.found:
        note = "  WARNING: the id was already taken by %s" % session.found[control_id]
    if len(seen) > 1:
        note += "  WARNING: other ids were also seen: %s" % describe_seen(seen)
    session.found[control_id] = name
    print("        %s = 0x%02X%s" % (name, control_id, note), flush=True)
    return {"name": name, "kind": kind, "id": control_id, "skipped": False, "seen": describe_seen(seen)}


def describe_seen(seen):
    return ", ".join("0x%02X:%s" % (c, "/".join("%02X" % v for v in sorted(values))) for c, values in sorted(seen.items()))


def run_free(session):
    """Prints the controls that were not asked for, so that what the list misses shows up."""
    print("\nAll steps are done. Now press anything that was not on the list. Ctrl-C ends the session.\n", flush=True)
    try:
        while True:
            for message in session.port_in.iter_pending():
                control = parse_control(message)
                if control is None or control[0] == SHIFT_ID:
                    continue
                write_log(session, "free: id 0x%02X value %02X" % control)
                if control[0] not in session.found:
                    print("   unknown control: id 0x%02X value %02X" % control, flush=True)
            time.sleep(0.005)
    except KeyboardInterrupt:
        print()


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name." % name)
        return 1

    steps = [s for s in CONTROLS if only is None or only.lower() in s[0].lower()]
    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    base = os.path.join(here, "captures", "console1-controls-%s" % stamp)

    with open(base + ".log", "w") as log, mido.open_input(in_name) as port_in, mido.open_output(out_name) as port_out:
        session = Session(port_in, log)
        if not replay(port_in, port_out):
            print("The handshake failed, so the controls would stay silent. Is the Softube application closed?")
            return 1
        print("\nShift is not asked for: it sends its own id, and it never changes the message of another control.\n")
        try:
            for number, (control, kind, what) in enumerate(steps, 1):
                session.results.append(run_step(session, control, kind, what, number, len(steps)))
        except KeyboardInterrupt:
            print("\nStopped early.")
        else:
            run_free(session)

    with open(base + ".json", "w") as out:
        json.dump(session.results, out, indent=2)
    print("\nControl ids found (sysex), against the CC names of c1.zig:")
    for r in session.results:
        print("  %-18s %s" % (r["name"], "skipped" if r["skipped"] else "0x%02X" % r["id"]))
    print("\nThe log is in %s.log and the table is in %s.json" % (base, base))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
