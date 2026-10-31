#!/usr/bin/env python3
"""Builds state frames (kind 0x01) for the Console 1 with a valid checksum, for any value of any byte of the payload.

The checksum of a frame is a 32-bit value that is sent as five 7-bit bytes, the least significant first. It is not a
standard CRC-32, but it is a linear feedback shift register: it is affine over GF(2), and the effect of one bit of the
payload on the checksum is a fixed 32x32 matrix STEP applied as many times as the bit is far from the start of the
payload. Because of that, with the position p of a payload byte (the counter is at position 0) and the bit j of that
byte, the effect of flipping that bit on the checksum is STEP applied (8 * p + j) times to EFFECT_OF_FIRST_BIT.

This was found from 778 distinct frames of the Softube application, and it predicts the checksum of every one of them,
from a single base frame, exactly. 472 of those frames differ from the base in bytes that the data alone could not fix,
so the prediction of those bytes is a test of the structure and not only a fit. The matrix is not documented anywhere:
it was solved from the captures, so a frame of a kind other than 0x01 (another length) is not covered.
"""

PAYLOAD_START = 8
PAYLOAD_LENGTH = 97
CHECKSUM_START = PAYLOAD_START + PAYLOAD_LENGTH
COUNTER = 0

# The 32x32 matrix over GF(2), as the 32 rows; bit r of (STEP times v) is the parity of (STEP_ROWS[r] and v).
STEP_ROWS = [
    0xC0000000,
    0x80000001,
    0x00000002,
    0x80000004,
    0x80000008,
    0x00000010,
    0x80000020,
    0xA0000000,
    0x00000080,
    0x00000100,
    0x00000200,
    0x80000400,
    0x80000800,
    0x80001000,
    0x10000000,
    0x80004000,
    0x80008000,
    0x00010000,
    0x00020000,
    0x00040000,
    0x00080000,
    0x80000000,
    0x00200000,
    0x00400000,
    0x00800000,
    0x01000000,
    0x02000000,
    0x84000000,
    0x08000000,
    0x00100000,
    0x00002000,
    0x80000040,
]
EFFECT_OF_FIRST_BIT = 0x62295AF5

# A frame of the application with the meters at zero. Its other bytes are what the application sends then.
BASE = [
    0xF0, 0x7D, 0x01, 0x00, 0x00, 0x00, 0x61, 0x00, 0x26, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x7F, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x3F, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F, 0x3F, 0x3F,
    0x00, 0x3F, 0x3F, 0x3F, 0x3F, 0x00, 0x3F, 0x3F, 0x00, 0x3F, 0x3F, 0x3F, 0x3F, 0x7F, 0x69, 0x7F,
    0x7F, 0x3F, 0x7F, 0x3F, 0x00, 0x00, 0x3F, 0x3F, 0x00, 0x00, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x3F,
    0x65, 0x62, 0x00, 0x00, 0x01, 0x7A, 0x04, 0x00, 0x0F, 0x7F, 0x7F, 0x20, 0x62, 0x00, 0x00, 0x00,
    0x02, 0x04, 0x00, 0x0F, 0x78, 0x0F, 0x20, 0x20, 0x03, 0x1E, 0x12, 0x11, 0x0C, 0x08, 0xF7,
]


def apply_step(vector):
    result = 0
    for row, mask in enumerate(STEP_ROWS):
        result |= (bin(mask & vector).count("1") & 1) << row
    return result


def make_effects():
    """EFFECT[(position, bit)] is what the checksum changes by when that bit of the payload is flipped."""
    effects = {}
    vector = EFFECT_OF_FIRST_BIT
    for step in range(8 * PAYLOAD_LENGTH):
        position, bit = divmod(step, 8)
        if bit < 7:
            effects[(position, bit)] = vector
        vector = apply_step(vector)
    return effects


EFFECT = make_effects()


def checksum_of(frame):
    """The 32 bits of the checksum of a whole frame, from its five septets (least significant first)."""
    return sum(v << (7 * i) for i, v in enumerate(frame[CHECKSUM_START:CHECKSUM_START + 5])) & 0xFFFFFFFF


def build_frame(counter, changes):
    """The BASE frame with the counter set and the given payload bytes changed, with the checksum worked out."""
    assert 0 <= counter < 128, "the counter is a 7-bit value"
    frame = list(BASE)
    assert len(frame) == CHECKSUM_START + 5 + 1, "the base frame must be 111 bytes"
    checksum = checksum_of(BASE)
    wanted = dict(changes)
    wanted[COUNTER] = counter
    for index, value in wanted.items():
        assert 0 <= index < PAYLOAD_LENGTH, "payload byte %d does not exist" % index
        assert 0 <= value < 128, "a sysex byte has 7 bits"
        difference = BASE[PAYLOAD_START + index] ^ value
        for bit in range(7):
            if (difference >> bit) & 1:
                checksum ^= EFFECT[(index, bit)]
        frame[PAYLOAD_START + index] = value
    for i in range(5):
        frame[CHECKSUM_START + i] = (checksum >> (7 * i)) & 0x7F
    return frame
