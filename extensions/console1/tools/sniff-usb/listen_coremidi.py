#!/usr/bin/env python3
"""Listens to everything that a Console 1 sends, at the level of the MIDI port, and reports what is unusual.

On a Mac with Apple silicon the USB bus cannot be captured, but a MIDI port can be listened to by several programs
at once, so this listens to the unit while the Softube application talks to it. If the unit only starts to send
something (the shift button, say) once the application has set it up, it shows here. What the application sends TO
the unit is not visible from here: MIDI Monitor's spy mode shows that (see the README).

Usage (through listen-macos.sh, which sets up the libraries):
  listen_coremidi.py                 listen, take labels from the keyboard, and report when a blank line is entered
  listen_coremidi.py --list          list the MIDI input ports
  listen_coremidi.py --port NAME     listen to the port whose name contains NAME (the default is "Console 1")

It needs mido and python-rtmidi.
"""

import os
import sys
import time

import mido

from decode_usb_midi import Message, report

DEFAULT_PORT = "Console 1"


def to_message(start, message):
    """A mido message as a Message of the decoder, with the time since the start of the listening."""
    when = time.time() - start
    kind = message.type
    if kind == "control_change":
        return Message(when, "IN", "CC", message.control, message.value, channel=message.channel)
    if kind == "note_on":
        return Message(when, "IN", "note on", message.note, message.velocity, channel=message.channel)
    if kind == "note_off":
        return Message(when, "IN", "note off", message.note, message.velocity, channel=message.channel)
    if kind == "sysex":
        return Message(when, "IN", "sysex", None, None, payload=bytes([0xF0]) + bytes(message.data) + bytes([0xF7]))
    # Anything else, by its name and its raw bytes: nothing is dropped.
    return Message(when, "IN", kind, None, None, payload=bytes(message.bytes()))


def find_port(name):
    ports = [p for p in mido.get_input_names() if name.lower() in p.lower()]
    return ports[0] if ports else None


def main(argv):
    if "--list" in argv:
        for port in mido.get_input_names():
            print(port)
        return 0
    name = argv[argv.index("--port") + 1] if "--port" in argv else DEFAULT_PORT
    port_name = find_port(name)
    if port_name is None:
        print("No MIDI input port has %r in its name. The ports are:" % name)
        for port in mido.get_input_names():
            print("  " + port)
        return 1

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, "captures"), exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    log_path = os.path.join(here, "captures", "console1-midi-%s.log" % stamp)

    start = time.time()
    messages = []
    log = open(log_path, "w")

    def on_message(message):
        m = to_message(start, message)
        messages.append(m)
        line = "%8.3f  IN   %s" % (m.time, m.text())
        if m.payload and m.kind != "sysex":
            line += "  raw " + m.payload.hex(" ")
        log.write(line + "\n")
        log.flush()
        print(line, flush=True)

    markers = []
    print("Listening to %r. Type a label and press Enter BEFORE each thing that you do, and a blank line to finish.\n" % port_name)
    # sysex, timing and active sensing are all received: nothing is filtered out.
    with mido.open_input(port_name, callback=on_message):
        while True:
            try:
                label = input("label> ")
            except (EOFError, KeyboardInterrupt):
                break
            if not label.strip():
                break
            markers.append((time.time() - start, label.strip()))
            log.write("%8.3f  --   marker: %s\n" % (markers[-1][0], label.strip()))
            log.flush()
    log.close()

    print()
    intro = "Listened to the port %r for %.0f seconds: %d messages from the unit to the computer." % (port_name, time.time() - start, len(messages))
    report("coremidi", messages, [], False, markers, intro=intro, host_visible=False)
    print("\nThe log is in %s" % log_path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
