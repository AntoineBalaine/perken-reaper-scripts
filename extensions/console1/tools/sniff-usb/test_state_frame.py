#!/usr/bin/env python3
"""Checks that state_frame.py rebuilds, byte for byte, every state frame that the Softube application sent.

testdata/state_frames.hex holds the 778 distinct state frames (kind 01) that were captured from the application, one per
line in hexadecimal, with their checksums. Because the checksum model was solved from these frames, a rebuilt frame that
differs means that the model or the base frame was changed by mistake.

Usage (with the python of the environment that listen-macos.sh sets up):
  .venv/bin/python -m unittest test_state_frame
"""

import os
import unittest

import state_frame

FRAMES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testdata", "state_frames.hex")


class StateFrameTest(unittest.TestCase):
    def load_frames(self):
        with open(FRAMES) as handle:
            return [list(bytes.fromhex(line)) for line in handle.read().split()]

    def test_every_captured_frame_is_rebuilt_exactly(self):
        frames = self.load_frames()
        self.assertEqual(len(frames), 778)
        for frame in frames:
            payload = frame[state_frame.PAYLOAD_START:state_frame.CHECKSUM_START]
            changes = {i: payload[i] for i in range(1, state_frame.PAYLOAD_LENGTH) if payload[i] != state_frame.BASE[state_frame.PAYLOAD_START + i]}
            self.assertEqual(state_frame.build_frame(payload[state_frame.COUNTER], changes), frame)

    def test_the_base_frame_is_rebuilt_with_its_own_counter(self):
        base = list(state_frame.BASE)
        self.assertEqual(state_frame.build_frame(base[state_frame.PAYLOAD_START], {}), base)

    def test_every_sysex_byte_stays_seven_bit(self):
        frame = state_frame.build_frame(5, {i: 0x7F for i in range(1, state_frame.PAYLOAD_LENGTH)})
        self.assertTrue(all(b < 0x80 for b in frame[1:-1]))
        self.assertEqual((frame[0], frame[-1], len(frame)), (0xF0, 0xF7, 111))

    def test_the_checksum_depends_on_the_counter(self):
        self.assertNotEqual(state_frame.build_frame(1, {})[105:110], state_frame.build_frame(2, {})[105:110])

    def test_a_value_that_is_not_seven_bit_is_refused(self):
        with self.assertRaises(AssertionError):
            state_frame.build_frame(1, {10: 0x80})

    def test_a_byte_outside_the_payload_is_refused(self):
        with self.assertRaises(AssertionError):
            state_frame.build_frame(1, {97: 1})


if __name__ == "__main__":
    unittest.main()
