#!/usr/bin/env python3
"""Forwards MIDI between two raw ALSA devices and logs every System Exclusive message.

It is the middle of a capture of the VR-09 Editor, the iPad app: a Linux board (a Raspberry Pi 4) acts as
a USB MIDI device for the iPad, and as the USB host of the keyboard, and this script passes every byte
from one to the other, so that the editor and the keyboard work as if they were connected directly.
Each SysEx message that goes by is written to the log, with its direction and, for Roland messages, what
it asks or sets, so that the addresses that the editor uses can be read from the log.

  midi_bridge.py --ipad hw:1,0,0 --keyboard hw:2,0,0 --log capture.log
  midi_bridge.py --selftest

The device names are those of `amidi -l`. The log has one line for each message:

  12.345  IPAD>KB    DT1  model 00 00 71  addr 19 41 01 0C  data 00    F0 41 10 00 00 71 12 ...

Nothing is changed on the way: the bytes are passed as they come, the realtime bytes too.
"""
import argparse
import os
import select
import socket
import sys
import time


class Splitter:
    """Cuts a stream of MIDI bytes into the System Exclusive messages in it."""

    def __init__(self):
        self.current = None

    def feed(self, data):
        """Returns the SysEx messages that the new bytes complete, each as a list of bytes (F0 to F7)."""
        found = []
        for byte in data:
            # Realtime bytes (the clock, F8 and above) may come anywhere, even inside a message.
            if byte >= 0xF8:
                continue
            if byte == 0xF0:
                self.current = [byte]
            elif self.current is not None:
                self.current.append(byte)
                if byte == 0xF7:
                    found.append(self.current)
                    self.current = None
                elif byte >= 0x80:
                    # Another status byte ends the message without an F7: it is dropped.
                    self.current = None
        return found


def describe(message):
    """Says in a few words what a SysEx message is, for the log."""
    hexa = lambda part: " ".join("%02X" % b for b in part)
    if message[1:4] == [0x7E, 0x7F, 0x06] or message[1:3] == [0x7E, 0x10] and message[3] == 0x06:
        return "IDENTITY"
    if message[1] != 0x41 or len(message) < 8:
        return "SYSEX"
    # A Roland message: 41, device, the model (62, or 00 00 71 for the synth section), the command, an address.
    for model, length in (([0x62], 3), ([0x00, 0x00, 0x71], 4)):
        start = 3
        if message[start:start + len(model)] != model:
            continue
        command = message[start + len(model)]
        body = message[start + len(model) + 1:-2]
        if command not in (0x11, 0x12) or len(body) < length:
            continue
        address, rest = body[:length], body[length:]
        name = "RQ1" if command == 0x11 else "DT1"
        what = "size" if command == 0x11 else "data"
        return "%s  model %s  addr %s  %s %s" % (name, hexa(model), hexa(address), what, hexa(rest))
    return "ROLAND"


def log_line(started, direction, message, out):
    line = "%8.3f  %-8s %s    %s" % (time.time() - started, direction, describe(message), " ".join("%02X" % b for b in message))
    print(line, flush=True)
    if out:
        out.write(line + "\n")
        out.flush()


def open_raw(port):
    """Opens the raw ALSA device behind an amidi port name such as hw:2,0,0."""
    card, device, _ = port[3:].split(",")
    return os.open("/dev/snd/midiC%sD%s" % (card, device), os.O_RDWR | os.O_NONBLOCK)


def write_all(fd, data):
    view = memoryview(data)
    while view:
        try:
            view = view[os.write(fd, view):]
        except BlockingIOError:
            select.select([], [fd], [], 0.1)


def bridge(ipad, keyboard, out, stop=lambda: False):
    """Passes the bytes between the two descriptors, and logs the SysEx messages, until `stop` says so."""
    started = time.time()
    sides = {ipad: (keyboard, "IPAD>KB", Splitter()), keyboard: (ipad, "KB>IPAD", Splitter())}
    while not stop():
        ready, _, _ = select.select([ipad, keyboard], [], [], 0.2)
        for fd in ready:
            target, direction, splitter = sides[fd]
            try:
                data = os.read(fd, 4096)
            except BlockingIOError:
                continue
            if not data:
                continue
            write_all(target, data)
            for message in splitter.feed(data):
                log_line(started, direction, message, out)


def selftest():
    """Runs the bridge over two pairs of sockets, which stand for the two devices."""
    ipad_end, ipad_bridge = socket.socketpair()
    keyboard_end, keyboard_bridge = socket.socketpair()
    for s in (ipad_end, ipad_bridge, keyboard_end, keyboard_bridge):
        s.setblocking(False)

    class Log:
        def __init__(self):
            self.lines = []

        def write(self, text):
            self.lines.append(text)

        def flush(self):
            pass

    log = Log()
    rounds = [0]

    def stop():
        rounds[0] += 1
        return rounds[0] > 6

    cutoff_write = bytes([0xF0, 0x41, 0x10, 0x00, 0x00, 0x71, 0x12, 0x19, 0x41, 0x01, 0x0C, 0x00, 0x19, 0xF7])
    reply = bytes([0xF0, 0x41, 0x10, 0x62, 0x12, 0x01, 0x01, 0x01, 0x38, 0x02, 0x00, 0x43, 0xF7])
    ipad_end.send(b"\xF8" + cutoff_write[:6])  # a clock byte, and the start of a message
    time.sleep(0.05)
    ipad_end.send(cutoff_write[6:])
    keyboard_end.send(reply)
    bridge(ipad_bridge.fileno(), keyboard_bridge.fileno(), log, stop)

    assert keyboard_end.recv(4096) == b"\xF8" + cutoff_write, "the keyboard did not receive what the iPad sent"
    assert ipad_end.recv(4096) == reply, "the iPad did not receive what the keyboard sent"
    text = "".join(log.lines)
    assert "IPAD>KB" in text and "DT1  model 00 00 71  addr 19 41 01 0C  data 00" in text, text
    assert "KB>IPAD" in text and "DT1  model 62  addr 01 01 01" in text, text
    print("self-test passed. The log held:")
    print(text, end="")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ipad", help="the port of the Pi's USB MIDI gadget, such as hw:1,0,0")
    parser.add_argument("--keyboard", help="the port of the VR-09, such as hw:2,0,0")
    parser.add_argument("--log", help="a file that gets a copy of the log")
    parser.add_argument("--selftest", action="store_true", help="check the bridge without any device")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return
    if not (args.ipad and args.keyboard):
        sys.exit("give --ipad and --keyboard (see `amidi -l`), or --selftest")
    ipad, keyboard = open_raw(args.ipad), open_raw(args.keyboard)
    out = open(args.log, "a") if args.log else None
    print("Bridging %s (iPad) and %s (keyboard). Ctrl-C stops." % (args.ipad, args.keyboard), flush=True)
    try:
        bridge(ipad, keyboard, out)
    except KeyboardInterrupt:
        print("\nstopped.")


if __name__ == "__main__":
    main()
