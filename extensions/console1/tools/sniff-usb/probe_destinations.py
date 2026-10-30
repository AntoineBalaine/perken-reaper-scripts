#!/usr/bin/env python3
"""Blinks bytes of the state frame of a Console 1, so that you can see which part of the unit each one drives.

The state frame (kind 0x01) holds what the unit shows: the meters, and the LEDs. This script replays the handshake of the
Softube application, and then blinks one byte of the payload (or a group of them) between two values, about twice a
second, until you press Enter. Then it puts the quiet frame back, and asks what was blinking. state_frame.py works out
the checksum, so any byte of the payload can be blinked.

The first step sends the quiet frame unchanged. If the unit does not acknowledge it, the checksum model does not hold
on the unit, and the script stops. The Softube application must be closed.

Usage (with the python of the environment that listen-macos.sh sets up):
  probe_destinations.py                      blink every byte that is not known yet, one after the other
  probe_destinations.py --bytes 10,11,12     blink only these payload byte numbers
  probe_destinations.py --group 8            blink 8 bytes at a time, and then split a group that did something in halves
  probe_destinations.py --on 7F --off 00     the two values that are alternated (in hexadecimal; these are the defaults)
  probe_destinations.py --all                also blink the bytes that are known (counter, meters)
  probe_destinations.py --port NAME          use the ports whose name contains NAME (the default is "Console 1")

At each prompt: type what blinked (or Enter for nothing), r to see it again, s to split the group in halves, q to stop.
"""

import json
import os
import select
import sys
import time

import mido

import state_frame
from handshake_replay import DEFAULT_PORT, find_port, replay

ACK_KIND = 0x24
ACK_TIMEOUT = 0.5
BLINK_PERIOD = 0.4
FRAMES_PER_CHANGE = 2
FRAME_SPACING = 0.03

# The payload bytes whose meaning is already known, so that they are not blinked unless --all is given.
KNOWN = [0, 67, 68, 69, 70, 72]


class Probe:
    """What the steps share: the ports, the counter, and the answers, grouped because functions cannot be nested."""

    def __init__(self, port_in, port_out, log, on, off):
        self.port_in = port_in
        self.port_out = port_out
        self.log = log
        self.on = on
        self.off = off
        self.counter = 1  # the handshake already used the counter 1
        self.answers = []


def send_frame(probe, changes):
    probe.counter = (probe.counter + 1) % 128
    probe.port_out.send(mido.Message.from_bytes(state_frame.build_frame(probe.counter, changes)))
    return probe.counter


def send_repeated(probe, changes):
    for _ in range(FRAMES_PER_CHANGE):
        send_frame(probe, changes)
        time.sleep(FRAME_SPACING)


def acknowledged(probe, counter):
    """Waits for the acknowledgement of the unit (kind 0x24) with the counter, and returns whether it came."""
    deadline = time.time() + ACK_TIMEOUT
    while time.time() < deadline:
        for message in probe.port_in.iter_pending():
            if message.type == "sysex" and message.data[1] == ACK_KIND and message.data[7] == counter:
                return True
        time.sleep(0.002)
    return False


def check_model(probe):
    """The unchanged quiet frame must be acknowledged, or the checksum model does not hold on the unit."""
    for _ in probe.port_in.iter_pending():
        pass
    ok = acknowledged(probe, send_frame(probe, {}))
    print("Step 0: the quiet frame, built with the checksum model, was acknowledged: %s" % ok)
    probe.log.write("model check: acked=%s\n" % ok)
    return ok


def blink(probe, indexes):
    """Alternates the bytes between the two values until Enter is pressed, and then puts the quiet frame back."""
    lit = False
    next_change = 0.0
    while True:
        if time.time() >= next_change:
            lit = not lit
            send_repeated(probe, {i: probe.on if lit else probe.off for i in indexes})
            next_change = time.time() + BLINK_PERIOD
        for _ in probe.port_in.iter_pending():
            pass
        ready, _, _ = select.select([sys.stdin], [], [], 0.02)
        if ready:
            sys.stdin.readline()
            break
    send_repeated(probe, {})


def describe(indexes):
    return "payload byte %d" % indexes[0] if len(indexes) == 1 else "payload bytes %d to %d (%d bytes)" % (indexes[0], indexes[-1], len(indexes))


def run_step(probe, indexes, position, total):
    """Blinks the bytes until the user answers, repeating on request, and returns (answer, quit)."""
    while True:
        print("[%s] %s is blinking. Press Enter when you have seen it." % (position, describe(indexes)), flush=True)
        blink(probe, indexes)
        prompt = "        what blinked? (Enter = nothing, r = again, %sq = stop) " % ("s = split, " if len(indexes) > 1 else "")
        answer = input(prompt).strip()
        if answer.lower() == "r":
            continue
        record = {"bytes": indexes, "label": answer}
        probe.log.write(json.dumps(record) + "\n")
        probe.log.flush()
        probe.answers.append(record)
        return answer.lower()


def probe_group(probe, indexes, position, total):
    """Blinks a group; if the user says to split it, probes each half; returns True when the user stops."""
    answer = run_step(probe, indexes, position, total)
    if answer == "q":
        return True
    if answer == "s" and len(indexes) > 1:
        middle = len(indexes) // 2
        return probe_group(probe, indexes[:middle], position + ".1", total) or probe_group(probe, indexes[middle:], position + ".2", total)
    return False


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    on = int(argv[argv.index("--on") + 1], 16) if "--on" in argv else 0x7F
    off = int(argv[argv.index("--off") + 1], 16) if "--off" in argv else 0x00
    group = int(argv[argv.index("--group") + 1]) if "--group" in argv else 1
    if "--bytes" in argv:
        indexes = [int(part) for part in argv[argv.index("--bytes") + 1].split(",")]
    else:
        indexes = [i for i in range(state_frame.PAYLOAD_LENGTH) if "--all" in argv or i not in KNOWN]
    assert 0 <= on <= 0x7F and 0 <= off <= 0x7F, "a value of a sysex byte has 7 bits"
    assert group >= 1, "a group has at least one byte"
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name." % name)
        return 1

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    path = os.path.join(here, "captures", "console1-probe-%s.log" % time.strftime("%Y%m%d-%H%M%S"))
    groups = [indexes[i:i + group] for i in range(0, len(indexes), group)]
    with open(path, "w") as log, mido.open_input(in_name) as port_in, mido.open_output(out_name) as port_out:
        probe = Probe(port_in, port_out, log, on, off)
        if not replay(port_in, port_out):
            print("The handshake failed. Is the Softube application closed?")
            return 1
        print()
        if not check_model(probe):
            print("The unit did not acknowledge a frame built with the model, so the model is wrong for the unit.")
            print("The log is in %s" % path)
            return 1
        print("\nEach step blinks between %02X and %02X until you press Enter.\n" % (off, on))
        try:
            for number, members in enumerate(groups, 1):
                if probe_group(probe, members, "%d/%d" % (number, len(groups)), len(groups)):
                    break
        except (EOFError, KeyboardInterrupt):
            print("\nStopped early.")

    print("\nWhat blinked:")
    for answer in probe.answers:
        if answer["label"] and answer["label"].lower() not in ("r", "s", "q"):
            print("  %s: %s" % (describe(answer["bytes"]), answer["label"]))
    print("\nThe log is in %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
