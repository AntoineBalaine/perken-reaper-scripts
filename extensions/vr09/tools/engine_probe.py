#!/usr/bin/env python3
"""Probes the VR-09's synth engine (the synth tone that Roland documents at 19 21, 19 41 and 1A 21).

The unit answers nothing at those addresses, and it is not known why. This script asks the unit, step by
step and with the care that `scan.py` of the roland-vr09 project takes, so that what it learns can say
whether the engine can be reached from MIDI at all.

  engine_probe.py reads              read every documented engine block, with several sizes (reads only)
  engine_probe.py watch              show which bytes of the live Synth Set change while you play the
                                     panel (reads only; stop with Ctrl-C)
  engine_probe.py write-test --yes   write one engine parameter, ask whether the sound changed, and put
                                     the part's tone back (the only command that writes)

It talks to the keyboard through the raw ALSA device, as vr09.py does, so it runs on Linux, with the
keyboard on USB. Because it uses vr09.py and scan.py, it needs the roland-vr09 project: give its folder
with --roland-vr09 or the environment variable ROLAND_VR09 (default ~/projects/roland-vr09).

Why it is careful: a burst of reads to undefined addresses once made the unit stop answering until it was
restarted. So every probe is followed by a pause, the unit's identity is checked every few probes, and the
script stops at the first sign that the unit no longer answers.
"""
import argparse
import os
import select
import sys
import time

GAP = 0.25  # seconds between two probes of an address that is expected to stay silent
IDENTITY_EVERY = 4  # the unit is asked who it is after this many probes

# The temporary synth tone of each part (the document's "Temporary Synth Tone"), and the Synth Set Part
# whose offset 06 to 08 holds the part's tone (bank MSB, bank LSB, program number).
PARTS = {
    "upper2": {"tone": (0x19, 0x21, 0x00, 0x00), "set": (0x18, 0x00, 0x21, 0x00)},
    "upper1": {"tone": (0x19, 0x41, 0x00, 0x00), "set": (0x18, 0x00, 0x22, 0x00)},
    "lower": {"tone": (0x1A, 0x21, 0x00, 0x00), "set": (0x18, 0x00, 0x25, 0x00)},
}

# The blocks of a synth tone, as offsets from its start: the common block, then the three partials. The
# document writes the offsets in 7-bit bytes, 00 00 00, 00 01 00, 00 02 00 and 00 03 00, that is 0, 128,
# 256 and 384.
BLOCKS = {"common": 0 * 128, "partial1": 1 * 128, "partial2": 2 * 128, "partial3": 3 * 128}

# What the document gives for the sizes: a tone block is 0x40 bytes in total. 1 asks for a single byte,
# which is the smallest read, and 0x3D is the size that a partial's last parameter ends at.
SIZES = (1, 0x3D, 0x40)

# Parameters of a partial, as offsets in the partial (document: Synth Tone Partial). Cutoff is 0C.
PARTIAL_CUTOFF = 0x0C


def load_vr09(folder):
    """Imports vr09.py and scan.py from the roland-vr09 project."""
    folder = os.path.expanduser(folder)
    if not os.path.exists(os.path.join(folder, "vr09.py")):
        sys.exit(f"vr09.py not found in {folder}: give the roland-vr09 folder with --roland-vr09")
    sys.path.insert(0, folder)
    import scan
    import vr09
    return vr09, scan


def pack(address):
    """The four 7-bit bytes of an address given as a number."""
    return tuple((address >> (7 * i)) & 0x7F for i in reversed(range(4)))


def unpack(address):
    """The number of an address given as four 7-bit bytes."""
    value = 0
    for byte in address:
        value = (value << 7) | byte
    return value


def block_address(part, block):
    """The address of a block of a part's temporary tone."""
    return pack(unpack(PARTS[part]["tone"]) + BLOCKS[block])


def parameter_address(part, partial, offset):
    """The address of a parameter of a partial (1 to 3) of a part's tone."""
    return pack(unpack(PARTS[part]["tone"]) + BLOCKS["partial%d" % partial] + offset)


def ask(vr09, fd, address, size):
    """Sends one RQ1 to the synth section and returns {address: byte}; no retry, so that a silent address
    is asked once."""
    body = list(address) + vr09.to_bytes(size, 4)
    message = vr09.header("synth", 0x11) + body + [vr09.checksum(body), 0xF7]
    while select.select([fd], [], [], 0)[0]:
        os.read(fd, 4096)
    os.write(fd, bytes(message))
    raw = b""
    deadline = time.time() + 1
    while time.time() < deadline and select.select([fd], [], [], 0.2)[0]:
        raw += os.read(fd, 4096)
        if raw.endswith(b"\xf7"):
            break
    low = unpack(address)
    return {a: v for a, v in vr09.parse_dt1(raw, "synth").items() if low <= a < low + size}


def label(address):
    return " ".join("%02X" % byte for byte in address)


def reads(vr09, scan, fd):
    """Asks for every block of every part, with every size, and prints what answers."""
    answered = 0
    probes = 0
    for part in PARTS:
        for block in BLOCKS:
            address = block_address(part, block)
            for size in SIZES:
                values = ask(vr09, fd, address, size)
                probes += 1
                if values:
                    answered += 1
                    shown = [values[a] for a in sorted(values)][:16]
                    print("%s %-8s %s size %02X: %d bytes %s" % (part, block, label(address), size, len(values), shown), flush=True)
                else:
                    print("%s %-8s %s size %02X: no reply" % (part, block, label(address), size), flush=True)
                time.sleep(GAP)
                if probes % IDENTITY_EVERY == 0 and not scan.alive(fd):
                    sys.exit("the unit stopped answering: restart it before going on")
    print("\n%d of %d probes answered." % (answered, probes))
    if answered == 0:
        print("Nothing answers: the engine is not readable at its documented addresses.")
    print("unit still answers:", scan.alive(fd))


# The windows of the live Synth Set that `watch` reads, as (address, size): the set itself and its
# three parts.
WATCH = (
    ((0x18, 0x00, 0x00, 0x00), 0x40),
    (PARTS["upper2"]["set"], 9),
    (PARTS["upper1"]["set"], 9),
    (PARTS["lower"]["set"], 9),
)


def watch(vr09, scan, fd):
    """Reads the live Synth Set twice a second and prints every byte that changes."""
    previous = {}
    print("Watching the Synth Set. Change a synth tone, a part, a registration on the panel; Ctrl-C stops.", flush=True)
    rounds = 0
    try:
        while True:
            for address, size in WATCH:
                for a, v in ask(vr09, fd, address, size).items():
                    if a in previous and previous[a] != v:
                        print("%s: %02X -> %02X" % (label(pack(a)), previous[a], v), flush=True)
                    previous[a] = v
                time.sleep(0.05)
            rounds += 1
            if rounds % 20 == 0 and not scan.alive(fd):
                sys.exit("the unit stopped answering: restart it before going on")
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nstopped.")


def write_test(vr09, scan, fd, part, value):
    """Writes the cutoff of partial 1 of a part's tone, asks whether the sound changed, and puts the
    part's tone back. The tone cannot be read back, so what restores it is selecting the tone again."""
    if not scan.alive(fd):
        sys.exit("the unit does not answer: nothing was written")
    chosen = ask(vr09, fd, PARTS[part]["set"], 9)
    base = unpack(PARTS[part]["set"])
    tone = [chosen.get(base + 6), chosen.get(base + 7), chosen.get(base + 8)]
    if None in tone:
        sys.exit("could not read the part's tone (bank and program) from the Synth Set: nothing was written")
    print("The part's tone is bank %d.%d, program %d." % (tone[0], tone[1], tone[2]))
    address = parameter_address(part, 1, PARTIAL_CUTOFF)
    print("Writing %d at %s (the cutoff of partial 1). Listen to the part while you play a note." % (value, label(address)))
    vr09.dt1(fd, "synth", unpack(address), [value])
    time.sleep(0.3)
    print("Read back:", ask(vr09, fd, address, 1) or "no reply (expected: this area is silent)")
    answer = input("Did the sound change? [y/n] ").strip().lower()
    # Selecting the tone again loads it afresh, which puts every parameter of it back.
    vr09.dt1(fd, "synth", unpack(PARTS[part]["set"]) + 6, tone)
    time.sleep(0.5)
    print("The part's tone was selected again.")
    print("unit still answers:", scan.alive(fd))
    print("RESULT: the engine %s a write at its documented address." % ("takes" if answer == "y" else "did not visibly take"))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("reads", "watch", "write-test"))
    parser.add_argument("--roland-vr09", default=os.environ.get("ROLAND_VR09", "~/projects/roland-vr09"))
    parser.add_argument("--part", choices=sorted(PARTS), default="upper1", help="the part for write-test")
    parser.add_argument("--value", type=int, default=0, help="the value for write-test (0 to 127)")
    parser.add_argument("--yes", action="store_true", help="allow write-test to write")
    args = parser.parse_args()

    if args.command == "write-test" and not args.yes:
        sys.exit("write-test writes to the keyboard: add --yes if you want that")
    if not 0 <= args.value <= 127:
        sys.exit("--value goes from 0 to 127")

    vr09, scan = load_vr09(args.roland_vr09)
    fd = vr09.open_device(vr09.find_port())
    if not scan.alive(fd):
        sys.exit("the keyboard does not answer an identity request: nothing was sent")
    if args.command == "reads":
        reads(vr09, scan, fd)
    elif args.command == "watch":
        watch(vr09, scan, fd)
    else:
        write_test(vr09, scan, fd, args.part, args.value)


if __name__ == "__main__":
    main()
