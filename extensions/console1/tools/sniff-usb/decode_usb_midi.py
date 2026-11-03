#!/usr/bin/env python3
"""Decodes the USB traffic of a Console 1 from a capture, and says what is unusual in it.

The Console 1 is a class-compliant USB MIDI device, so everything it says to the host, and everything that the
host says to it, is made of USB-MIDI event packets of four bytes. This script reads a capture file with tshark,
finds the traffic of the Console 1, unpacks the MIDI messages (including the sysex, which spans packets), lists
the control requests of the class or vendor kind (the standard ones are enumeration), and prints:

  1. the host to device messages of the first seconds after the unit was seen: the handshake, if there is one;
  2. a table of every kind of message with how many times it came, and the values it took;
  3. what is not a plain note or a known CC: sysex, other CCs, other message kinds, class and vendor requests;
  4. with a markers file, the messages that came after each marker.

Usage:
  decode_usb_midi.py capture.pcapng            decode a capture file (needs tshark)
  decode_usb_midi.py capture.pcapng --all      also list every message in order
  decode_usb_midi.py capture.pcapng --markers markers.tsv
                                               also list what happened after each marker (see sniff-macos.sh)
  decode_usb_midi.py --selftest                check the decoder on made-up packets

Only the standard library is used.
"""

import subprocess
import sys

VENDOR_ID = 0x0483
PRODUCT_ID = 0xA0F6

# The CC numbers that the extension knows (console1/src/c1.zig).
KNOWN_CCS = {
    0x07, 0x0A, 0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x12, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E,
    0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x35, 0x36,
    0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3D, 0x41, 0x50, 0x52, 0x53, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C,
    0x5D, 0x60, 0x61, 0x66, 0x67, 0x68, 0x69, 0x6B, 0x6C, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x78, 0x7B, 0x7C,
    0x7D,
}

# How many of the three data bytes of a USB-MIDI packet are meaningful, by code index number.
CIN_BYTES = {0x2: 2, 0x3: 3, 0x4: 3, 0x5: 1, 0x6: 2, 0x7: 3, 0x8: 3, 0x9: 3, 0xA: 3, 0xB: 3, 0xC: 2, 0xD: 2, 0xE: 3, 0xF: 1}
SYSEX_CONTINUES = 0x4
SYSEX_ENDS = {0x5: 1, 0x6: 2, 0x7: 3}

KIND_NAMES = {0x80: "note off", 0x90: "note on", 0xA0: "poly pressure", 0xB0: "CC", 0xC0: "program", 0xD0: "channel pressure", 0xE0: "pitch bend"}

STARTUP_SECONDS = 4.0


class Message:
    """One MIDI message: when it was seen, which way it went, and what it said."""

    def __init__(self, time, direction, kind, number, value, channel=None, payload=b""):
        self.time = time
        self.direction = direction  # "IN" is device to host, "OUT" is host to device
        self.kind = kind
        self.number = number
        self.value = value
        self.channel = channel
        self.payload = payload

    def known(self):
        if self.kind in ("note on", "note off"):
            return True
        return self.kind == "CC" and self.number in KNOWN_CCS

    def signature(self):
        return (self.direction, self.kind, self.number if self.kind != "sysex" else None)

    def text(self):
        if self.kind == "sysex":
            return "sysex  " + " ".join("%02X" % b for b in self.payload)
        where = "" if self.channel is None else "ch%-2d " % (self.channel + 1)
        if self.kind == "CC":
            return "%sCC %-3d = %d" % (where, self.number, self.value)
        if self.kind in ("note on", "note off"):
            return "%s%s %d vel %d" % (where, self.kind, self.number, self.value)
        return "%s%s %s %s" % (where, self.kind, self.number, self.value)


class UsbMidiDecoder:
    """Unpacks USB-MIDI event packets. A sysex is kept across packets, per direction and per cable."""

    def __init__(self):
        self.sysex = {}

    def feed(self, time, direction, data):
        messages = []
        for i in range(0, len(data) - len(data) % 4, 4):
            header, b1, b2, b3 = data[i], data[i + 1], data[i + 2], data[i + 3]
            cable, cin = header >> 4, header & 0x0F
            if cin not in CIN_BYTES:
                continue
            body = bytes([b1, b2, b3])
            key = (direction, cable)
            if cin == SYSEX_CONTINUES:
                self.sysex.setdefault(key, bytearray()).extend(body)
            elif cin in SYSEX_ENDS:
                buffer = self.sysex.pop(key, bytearray())
                buffer.extend(body[: SYSEX_ENDS[cin]])
                messages.append(Message(time, direction, "sysex", None, None, payload=bytes(buffer)))
            else:
                status = b1
                kind = KIND_NAMES.get(status & 0xF0)
                if kind is not None:
                    messages.append(Message(time, direction, kind, b2, b3, channel=status & 0x0F))
                else:
                    messages.append(Message(time, direction, "system 0x%02X" % status, b2 if CIN_BYTES[cin] > 1 else None, b3 if CIN_BYTES[cin] > 2 else None))
        return messages


# ---- reading the capture ----

WANTED_FIELDS = [
    "frame.time_epoch", "frame.time_relative", "usb.bus_id", "usb.device_address", "usb.endpoint_address", "usb.transfer_type",
    "usb.capdata", "usb.idVendor", "usb.idProduct", "usb.bmRequestType", "usb.setup.bRequest", "usb.setup.wValue",
    "usb.setup.wIndex", "usb.setup.wLength",
]


def valid_fields():
    """The fields of the installed tshark, so that a field that this version does not have is left out, not fatal."""
    out = subprocess.run(["tshark", "-G", "fields"], capture_output=True, text=True, check=True).stdout
    names = set()
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) > 2 and parts[0] == "F":
            names.add(parts[2])
    return names


def read_capture(path):
    fields = [f for f in WANTED_FIELDS if f in valid_fields()]
    command = ["tshark", "-r", path, "-T", "fields", "-E", "separator=\t", "-E", "occurrence=f"]
    for field in fields:
        command += ["-e", field]
    out = subprocess.run(command, capture_output=True, text=True, check=True).stdout
    rows = []
    for line in out.splitlines():
        cells = line.split("\t")
        cells += [""] * (len(fields) - len(cells))
        rows.append(dict(zip(fields, cells)))
    return rows


def to_int(text):
    if not text:
        return None
    try:
        return int(text, 0)
    except ValueError:
        return None


def to_bytes(text):
    text = (text or "").replace(":", "").strip()
    try:
        return bytes.fromhex(text) if len(text) % 2 == 0 else b""
    except ValueError:
        return b""


def find_device(rows):
    """The (bus, address) of the Console 1, from the descriptor that it sent when it was enumerated."""
    for row in rows:
        if to_int(row.get("usb.idVendor")) == VENDOR_ID and to_int(row.get("usb.idProduct")) == PRODUCT_ID:
            return row.get("usb.bus_id", ""), row.get("usb.device_address", "")
    return None


def first_epoch(rows):
    for row in rows:
        epoch = row.get("frame.time_epoch")
        if epoch:
            return float(epoch)
    return None


def read_markers(path, start_epoch):
    """The markers of the file written by sniff-macos.sh, as (seconds since the start of the capture, label)."""
    markers = []
    with open(path) as handle:
        for line in handle:
            epoch, _, label = line.rstrip("\n").partition("\t")
            if epoch.replace(".", "", 1).isdigit():
                markers.append((float(epoch) - (start_epoch or 0.0), label))
    return sorted(markers)


def decode(rows):
    device = find_device(rows)
    decoder = UsbMidiDecoder()
    messages, requests = [], []
    for row in rows:
        time = float(row.get("frame.time_relative") or 0)
        if device is not None and (row.get("usb.bus_id", ""), row.get("usb.device_address", "")) != device:
            continue
        request_type = to_int(row.get("usb.bmRequestType"))
        if request_type is not None and ((request_type >> 5) & 3) != 0:
            requests.append((time, request_type, row.get("usb.setup.bRequest", ""), row.get("usb.setup.wValue", ""),
                             row.get("usb.setup.wIndex", ""), row.get("usb.setup.wLength", ""), to_bytes(row.get("usb.capdata"))))
            continue
        endpoint = to_int(row.get("usb.endpoint_address"))
        data = to_bytes(row.get("usb.capdata"))
        if endpoint is None or not data:
            continue
        # Bulk endpoints of the MIDI streaming interface: 0x81 is the input, 0x02 the output.
        if endpoint == 0x81:
            messages += decoder.feed(time, "IN", data)
        elif endpoint == 0x02:
            messages += decoder.feed(time, "OUT", data)
    return device, messages, requests


# ---- the report ----

def report(device, messages, requests, show_all, markers=(), intro=None, host_visible=True):
    if intro is not None:
        print(intro + "\n")
    elif device is None:
        print("The enumeration of the Console 1 is not in this capture, so its traffic was found by its endpoints.")
        print("Unplug the unit and plug it in again after the capture has started, to have it in the capture.\n")
    elif device is not None:
        print("Console 1 found on bus %s, address %s.\n" % device)

    if show_all:
        print("== every message, in order ==")
        for m in messages:
            print("%8.3f  %-3s  %s" % (m.time, m.direction, m.text()))
        print()

    first_out = next((m.time for m in messages if m.direction == "OUT"), None)
    print("== host to device, in the first %.0f seconds of its talking (the handshake, if there is one) ==" % STARTUP_SECONDS)
    if not host_visible:
        print("not visible from here: a listener on the port of the unit only hears the unit. MIDI Monitor's spy mode shows it.")
    elif first_out is None:
        print("nothing: the host sent no MIDI to the unit in this capture")
    else:
        for m in messages:
            if m.direction == "OUT" and m.time <= first_out + STARTUP_SECONDS:
                print("%8.3f  %s" % (m.time, m.text()))
    print()

    print("== every kind of message ==")
    table = {}
    for m in messages:
        entry = table.setdefault(m.signature(), {"count": 0, "values": set(), "first": m})
        entry["count"] += 1
        if m.value is not None:
            entry["values"].add(m.value)
    for signature in sorted(table, key=lambda s: (s[0], s[1], -1 if s[2] is None else s[2])):
        direction, kind, number = signature
        entry = table[signature]
        values = sorted(entry["values"])
        shown = ",".join(map(str, values[:8])) + ("..." if len(values) > 8 else "")
        flag = "" if entry["first"].known() else "   <-- not a note, and not a CC that the extension knows"
        what = kind if number is None else "%s %d" % (kind, number)
        print("%-3s  %-22s x%-5d values: %s%s" % (direction, what, entry["count"], shown, flag))
    print()

    if markers:
        print("== what happened after each marker ==")
        for i, (time, label) in enumerate(markers):
            end = markers[i + 1][0] if i + 1 < len(markers) else float("inf")
            print("-- %s (at %.3f)" % (label, time))
            shown = [m for m in messages if time <= m.time < end]
            for m in shown[:40]:
                print("   %8.3f  %-3s  %s" % (m.time, m.direction, m.text()))
            if len(shown) > 40:
                print("   ... and %d more" % (len(shown) - 40))
            if not shown:
                print("   nothing")
        print()

    print("== what is unusual ==")
    unusual = False
    for m in messages:
        if m.kind == "sysex":
            print("%8.3f  %-3s  %s" % (m.time, m.direction, m.text()))
            unusual = True
    for time, request_type, request, value, index, length, data in requests:
        print("%8.3f  control request  type 0x%02X  request %s  value %s  index %s  length %s  data %s" % (
            time, request_type, request, value, index, length, data.hex(" ")))
        unusual = True
    if not unusual:
        print("no sysex and no class or vendor request: everything is plain MIDI")


# ---- the check of the decoder itself ----

def selftest():
    decoder = UsbMidiDecoder()
    # CC 108 = 127 on channel 1, a note on, a sysex F0 01 02 03 04 05 F7 over three packets, and a clock byte.
    packets = bytes.fromhex("0bb06c7f" "0990 3c40".replace(" ", "") + "04f00102" + "04030405" + "05f70000" + "0ff80000")
    messages = decoder.feed(1.0, "IN", packets)
    assert [m.kind for m in messages] == ["CC", "note on", "sysex", "system 0xF8"], [m.kind for m in messages]
    assert messages[0].number == 108 and messages[0].value == 127 and messages[0].channel == 0
    assert messages[2].payload == bytes.fromhex("f0010203040" "5f7"), messages[2].payload.hex()
    assert messages[0].known() and not messages[2].known()
    unknown = decoder.feed(2.0, "OUT", bytes.fromhex("0bb0097f"))[0]
    assert not unknown.known()
    print("selftest passed")


def main(argv):
    if "--selftest" in argv:
        selftest()
        return 0
    paths = [a for a in argv if not a.startswith("--")]
    if "--markers" in argv:
        paths = [p for p in paths if p != argv[argv.index("--markers") + 1]]
    if len(paths) != 1:
        print(__doc__)
        return 2
    rows = read_capture(paths[0])
    device, messages, requests = decode(rows)
    markers = ()
    if "--markers" in argv:
        markers_path = argv[argv.index("--markers") + 1]
        paths = [p for p in paths if p != markers_path]
        markers = read_markers(markers_path, first_epoch(rows))
    report(device, messages, requests, "--all" in argv, markers)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
