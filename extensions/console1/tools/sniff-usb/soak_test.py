#!/usr/bin/env python3
"""Tests what the extension relies on beyond single controls: a full frame, a long idle, and a reconnection.

Phase 1, everything at once: every button is lit, every ring sweeps slowly and the six meters move, in frames of the
state kind sent every 30 ms like the application does, for a minute. Each frame is counted against the acknowledgement of
the unit, so that a frame that the unit drops shows. You say at the end whether anything looked wrong.

Phase 2, a long idle: the last frame of phase 1 is sent once and then nothing is sent for two minutes, while everything
that the unit says is logged with its time. You say at the end whether the LEDs and the meters still show the state.

Phase 3, reconnection: you unplug the unit and plug it in again. The script then listens without any handshake, to see
whether the unit is back in its legacy CC mode (you turn a knob and press shift), and then replays the handshake and
listens again, to see that the sysex events are back.

The Softube application must be closed. All the buttons are lit at once, which is a bright and heavy state for the unit:
if it looks wrong or the unit heats up, stop with Ctrl-C.

Usage (with the python of the environment that listen-macos.sh sets up):
  soak_test.py                    all three phases
  soak_test.py --phases 1,2       only these phases
  soak_test.py --animate 60       seconds of phase 1 (the default is 60)
  soak_test.py --idle 120         seconds of phase 2 (the default is 120)
  soak_test.py --port NAME        use the ports whose name contains NAME (the default is "Console 1")
"""

import json
import math
import os
import sys
import time

import mido

import state_frame
from handshake_replay import DEFAULT_PORT, describe, find_port, replay
from led_chase import load_controls
from probe_destinations import Probe, check_model, send_frame

FRAME_PERIOD = 0.03
ACK_KIND = 0x24
FLAG_BANK_A = 73
METER_FIRST_ID = 66
COMP_METER_ID = 71


class Soak:
    """What the phases share: the ports, the probe, the frames that were sent, and the results."""

    def __init__(self, name):
        self.name = name
        self.port_in = None
        self.port_out = None
        self.probe = None
        self.sent = set()
        self.acked = set()
        self.unexpected = []
        self.results = {}


def open_ports(soak):
    soak.port_in = mido.open_input(find_port(mido.get_input_names(), soak.name))
    soak.port_out = mido.open_output(find_port(mido.get_output_names(), soak.name))
    soak.probe = Probe(soak.port_in, soak.port_out, open(os.devnull, "w"), 0x7F, 0)


def close_ports(soak):
    soak.port_in.close()
    soak.port_out.close()


def set_flag(changes, control_id):
    """Sets the bank A bit of the control id, keeping the bits that other controls of the same byte already set."""
    index = FLAG_BANK_A + control_id // 7
    current = changes.get(index, state_frame.BASE[state_frame.PAYLOAD_START + index])
    changes[index] = current | (1 << (6 - control_id % 7))


def full_state(controls, seconds):
    """Every control lit, the rings at a position that moves with the time, and the meters moving."""
    changes = {}
    for control_id, _, kind in controls:
        set_flag(changes, control_id)
        if control_id >= METER_FIRST_ID:
            phase = control_id * 0.9
            level = 0.5 + 0.5 * math.sin(seconds * 2.1 + phase)
            if control_id == COMP_METER_ID:
                # Because the compressor meter rests at 7F and falls with the reduction, it is drawn from the top.
                changes[control_id + 1] = 0x7F - int(0x50 * level)
            else:
                changes[control_id + 1] = int(0x60 * level)
        elif kind == "knob":
            changes[control_id + 1] = int(0x7F * (0.5 + 0.5 * math.sin(seconds * 0.8 + control_id)))
        else:
            changes[control_id + 1] = 0x7F
    return changes


def collect_acks(soak):
    """Moves the acknowledgements that arrived into the set of acknowledged counters, and keeps anything else."""
    for message in soak.port_in.iter_pending():
        if message.type == "sysex" and message.data[1] == ACK_KIND:
            soak.acked.add(message.data[7])
        else:
            soak.unexpected.append((time.time(), describe(message)))


def animate(soak, controls, seconds):
    """Phase 1: sends the full moving state every 30 ms, and counts acknowledgements by counter."""
    print("Phase 1: everything lit, rings sweeping and meters moving for %d s. Watch the whole unit.\n" % seconds, flush=True)
    start = time.time()
    frames = missing = 0
    window = []
    changes = {}
    while time.time() - start < seconds:
        changes = full_state(controls, time.time() - start)
        counter = send_frame(soak.probe, changes)
        window.append(counter)
        frames += 1
        time.sleep(FRAME_PERIOD)
        collect_acks(soak)
        # Because a counter wraps every 128 frames, only the counters that are old enough to have been answered are checked.
        while len(window) > 8:
            old = window.pop(0)
            if old not in soak.acked:
                missing += 1
            soak.acked.discard(old)
        if frames % 100 == 0:
            print("  %3d s: %d frames sent, %d without an acknowledgement" % (time.time() - start, frames, missing), flush=True)
    print("\nPhase 1 done: %d frames sent, %d without an acknowledgement, %d other messages from the unit." % (frames, missing, len(soak.unexpected)))
    soak.results["phase1"] = {"frames": frames, "missing_acks": missing, "other_messages": [d for _, d in soak.unexpected][:50]}
    return changes


def idle(soak, last_changes, seconds):
    """Phase 2: one last frame, then silence, with a log of everything that the unit sends."""
    send_frame(soak.probe, last_changes)
    time.sleep(0.2)
    collect_acks(soak)
    soak.unexpected.clear()
    print("\nPhase 2: nothing is sent for %d s now. Keep watching the unit: do the LEDs and the meters hold?\n" % seconds, flush=True)
    start = time.time()
    last_print = start
    while time.time() - start < seconds:
        for message in soak.port_in.iter_pending():
            soak.unexpected.append((time.time() - start, describe(message)))
            print("  %5.1f s: the unit sent: %s" % (time.time() - start, describe(message)), flush=True)
        if time.time() - last_print >= 15:
            last_print = time.time()
            print("  %3d s of %d" % (time.time() - start, seconds), flush=True)
        time.sleep(0.05)
    print("\nPhase 2 done: the unit sent %d messages while idle." % len(soak.unexpected))
    soak.results["phase2"] = {"seconds": seconds, "messages_from_unit": [d for _, d in soak.unexpected]}


def wait_for_port(soak, present, timeout):
    """Waits until the port of the unit is in the list of inputs (present) or is gone from it, and returns whether it happened."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        if (find_port(mido.get_input_names(), soak.name) is not None) == present:
            return True
        time.sleep(0.3)
    return False


def listen(soak, seconds):
    """Returns what the unit sends for `seconds`, as (kind of message, text)."""
    heard = []
    end = time.time() + seconds
    while time.time() < end:
        for message in soak.port_in.iter_pending():
            kind = "cc" if message.type == "control_change" else message.type
            heard.append((kind, describe(message)))
        time.sleep(0.02)
    return heard


def reconnect(soak):
    """Phase 3: unplug, plug, listen without a handshake, then handshake, and listen again."""
    print("\nPhase 3: reconnection.")
    close_ports(soak)
    input("  Unplug the Console 1 now, then press Enter. ")
    if not wait_for_port(soak, False, 30):
        print("  The port did not go away within 30 s. Is the unit unplugged?")
    print("  Plug the Console 1 in again. Waiting for it...", flush=True)
    if not wait_for_port(soak, True, 90):
        print("  The port did not come back within 90 s.")
        return
    time.sleep(2.0)
    soak.port_in = mido.open_input(find_port(mido.get_input_names(), soak.name))
    print("\n  Without any handshake: turn the Gain knob and press shift for 10 seconds, starting now.", flush=True)
    before = listen(soak, 10)
    for _, text in before[:20]:
        print("    ", text)
    legacy = any(kind == "cc" for kind, _ in before)
    sysex = any(kind == "sysex" for kind, _ in before)
    print("  heard %d messages: %s" % (len(before), "legacy CC mode (CC messages)" if legacy and not sysex else "sysex messages" if sysex else "nothing"))
    soak.port_in.close()

    open_ports(soak)
    print("\n  Replaying the handshake...")
    if not replay(soak.port_in, soak.port_out):
        print("  The handshake failed after the reconnection.")
        soak.results["phase3"] = {"before_handshake": [t for _, t in before], "handshake_after_reconnect": False}
        return
    print("\n  After the handshake: turn the Gain knob and press shift for 10 seconds, starting now.", flush=True)
    after = listen(soak, 10)
    for _, text in after[:20]:
        print("    ", text)
    print("  heard %d messages: %s" % (len(after), "sysex events are back" if any(k == "sysex" for k, _ in after) else "no sysex events"))
    soak.results["phase3"] = {
        "before_handshake": [t for _, t in before],
        "legacy_mode_after_reconnect": legacy and not sysex,
        "handshake_after_reconnect": True,
        "after_handshake": [t for _, t in after],
    }


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    phases = [int(p) for p in argv[argv.index("--phases") + 1].split(",")] if "--phases" in argv else [1, 2, 3]
    seconds = int(argv[argv.index("--animate") + 1]) if "--animate" in argv else 60
    idle_seconds = int(argv[argv.index("--idle") + 1]) if "--idle" in argv else 120
    assert all(p in (1, 2, 3) for p in phases), "the phases are 1, 2 and 3"
    if find_port(mido.get_input_names(), name) is None:
        print("No input port has %r in its name." % name)
        return 1

    soak = Soak(name)
    open_ports(soak)
    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    path = os.path.join(here, "captures", "console1-soak-%s.json" % time.strftime("%Y%m%d-%H%M%S"))
    last = {}
    try:
        if not replay(soak.port_in, soak.port_out):
            print("The handshake failed. Is the Softube application closed?")
            return 1
        print()
        if not check_model(soak.probe):
            print("The unit did not acknowledge a frame built with the model.")
            return 1
        controls = load_controls()
        if 1 in phases:
            last = animate(soak, controls, seconds)
            soak.results["phase1"]["observation"] = input("\nDid every LED stay lit and every meter follow? Describe anything wrong (Enter = all fine): ").strip() or "all fine"
        if 2 in phases:
            idle(soak, last or full_state(controls, 0.0), idle_seconds)
            soak.results["phase2"]["observation"] = input("\nDo the LEDs and the meters still show the last state? Describe any change (Enter = no change): ").strip() or "no change"
        if 3 in phases:
            reconnect(soak)
    except KeyboardInterrupt:
        print("\nStopped.")
    try:
        send_frame(soak.probe, {})
    except Exception:
        pass
    json.dump(soak.results, open(path, "w"), indent=2)
    print("\nThe results are in %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
