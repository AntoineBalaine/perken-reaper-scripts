#!/usr/bin/env python3
"""Replays the handshake that the Softube application sends to a Console 1, and then listens to what the unit says.

The four requests below were copied, byte for byte, from a MIDI Monitor capture of the application starting up. They
were identical in the two startups that were captured, so they are replayed as they are, without computing anything.
Because the unit answers each request, the script waits for the answer before it sends the next request.

The Softube application must be closed, because it would otherwise run its own handshake on the same port.

Usage (through listen-macos.sh, which sets up the libraries):
  handshake_replay.py                 replay the handshake, then listen until Ctrl-C
  handshake_replay.py --no-handshake  only listen, to compare with the unit that has not been set up
  handshake_replay.py --port NAME     use the ports whose name contains NAME (the default is "Console 1")
"""

import sys
import time

import mido

DEFAULT_PORT = "Console 1"
ANSWER_TIMEOUT = 2.0

# The kind of message is the third byte of the frame, after F0 and 7D. The requests are sent in this order, and the
# kind that the unit answers with is next to each of them.
HELLO = bytes.fromhex("""
    F0 7D 20 00 00 00 01 00 7F 49 6F 6C 73 00 F7
""")
CHALLENGE = bytes.fromhex("""
    F0 7D 02 00 00 00 4A 00 00 21 41 75 08 38 0C 14
    2D 2D 6F 62 04 54 08 76 0D 07 2B 01 62 11 6A 30
    2F 16 6E 58 06 17 27 7D 6A 33 69 43 43 0C 3C 39
    54 21 41 7D 5D 3F 7B 39 39 40 26 12 21 62 45 76
    6F 44 7A 3C 46 5B 2A 20 7C 65 68 0F 67 01 04 37
    51 00 77 36 40 0D 02 F7
""")
VERSION_REQUEST = bytes.fromhex("""
    F0 7D 05 00 00 00 01 00 7F 54 6A 7A 48 0C F7
""")
STATE_PUSH = bytes.fromhex("""
    F0 7D 01 00 00 00 61 00 01 7F 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 60 00 00 00 00 00 00 00 00 00 00 60 00 00 00
    00 00 00 00 00 00 00 20 03 56 78 2A 6C 0C F7
""")

REQUESTS = [
    ("hello", HELLO, 0x21),
    ("hello again", HELLO, 0x21),
    ("challenge", CHALLENGE, 0x03),
    ("version request", VERSION_REQUEST, 0x06),
    ("state push", STATE_PUSH, 0x24),
]

CONTROLS = {
    0x02: "shift",
    0x1B: "gain",
    0x1F: "phase inv",
    0x20: "preset",
    0x3C: "drive",
    0x3D: "character",
    0x3E: "pan",
    0x3F: "solo",
    0x40: "mute",
    0x41: "volume",
}


def find_port(names, name):
    matches = [n for n in names if name.lower() in n.lower()]
    return matches[0] if matches else None


def describe(message):
    """Because the frames of the unit are hard to read as hex, a control event is shown with the name of its control."""
    if message.type != "sysex":
        return "%s %s" % (message.type, message.bytes())
    # message.data holds the frame without F0 and F7: 7D, the kind, three zeros, the length, a zero, and then the payload.
    data = bytes(message.data)
    kind, length, payload = data[1], data[5], data[7:7 + data[5]]
    if kind == 0x00 and length == 2:
        control, value = payload
        return "control %-10s %s" % (CONTROLS.get(control, "0x%02X" % control), "7F" if value else "00")
    if kind == 0x06:
        return "version " + payload.decode("ascii", "replace")
    return "sysex kind 0x%02X, %d bytes" % (kind, len(data) + 2)


def wait_for_answer(port_in, kind, timeout):
    """Returns the first sysex of the wanted kind, and prints anything else that arrives while waiting."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        message = port_in.poll()
        if message is None:
            time.sleep(0.005)
            continue
        print("      %s" % describe(message))
        if message.type == "sysex" and message.data[1] == kind:
            return message
    return None


def replay(port_in, port_out):
    for name, frame, answer_kind in REQUESTS:
        print("sending %-16s (%d bytes), waiting for kind 0x%02X" % (name, len(frame), answer_kind))
        port_out.send(mido.Message.from_bytes(list(frame)))
        if wait_for_answer(port_in, answer_kind, ANSWER_TIMEOUT) is None:
            print("  no answer within %.0f seconds: the handshake stops here." % ANSWER_TIMEOUT)
            return False
        time.sleep(0.05)
    print("\nThe unit answered every request.")
    return True


def main(argv):
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    in_name = find_port(mido.get_input_names(), name)
    out_name = find_port(mido.get_output_names(), name)
    if in_name is None or out_name is None:
        print("No input and output port has %r in its name. The inputs are %s, the outputs are %s." % (name, mido.get_input_names(), mido.get_output_names()))
        return 1
    with mido.open_input(in_name) as port_in, mido.open_output(out_name) as port_out:
        if "--no-handshake" not in argv:
            replay(port_in, port_out)
        print("\nListening. Press shift, the buttons and the knobs, and Ctrl-C to stop.\n")
        start = time.time()
        try:
            while True:
                for message in port_in.iter_pending():
                    print("%8.3f  %s" % (time.time() - start, describe(message)), flush=True)
                time.sleep(0.005)
        except KeyboardInterrupt:
            print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
