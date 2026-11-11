# The Console 1 sysex protocol, as found so far

This file records what the tools in this folder found out about how the Softube application talks to a Console 1. It was
found by listening to the unit, by spying on the application with MIDI Monitor, and by replaying and changing what the
application sends. The unit is a class-compliant USB MIDI device (USB id 0483:a0f6, Softube AB) with one cable. Nothing
here comes from Softube documentation, so every statement is what was seen, and the open questions are at the end.

## Two modes

Before the application connects, the unit is in a legacy mode: it sends the knobs as CC messages (for example CC 47 for a
knob, in steps of 3), it lights its own LEDs as you turn a knob, and it says nothing when shift is pressed.

After the handshake below, the unit sends everything as sysex, and it stops sending CCs. In this mode a knob only sends one
relative tick per message, it does not light its own LEDs, and the host must send the state of the LEDs and the meters. The
tool handshake_replay.py puts the unit in this mode without the application.

## Frame format

Every message is a sysex that starts with F0 7D (the manufacturer id for non-commercial use):

```
F0 7D <kind> 00 00 00 <length> 00 <length payload bytes> <5 checksum bytes> F7
```

All bytes between F0 and F7 are 7-bit. The checksum is a 32-bit value sent as five 7-bit bytes, the least significant first
(the fifth byte is never above 0F). It is not a standard CRC-32, and the unit drops a frame whose checksum is wrong. See
the section on the checksum.

## Handshake

The application sends these four requests, and the unit answers each. They were identical in every capture, so
handshake_replay.py replays them verbatim, waiting for each answer before it sends the next request.

| Host sends | Unit answers | Looks like |
|---|---|---|
| kind 20, payload 7F (sent twice) | kind 21, payload 7F | hello |
| kind 02, 74 bytes | kind 03, 74 bytes | a challenge and its response, but the same bytes every time; the answer takes about half a second |
| kind 05, payload 7F | kind 06, payload 31 2E 31 39 | version request, answered with the text 1.19 |
| kind 01, 97 bytes (a state frame) | kind 24, payload 01 | the first state frame, acknowledged |

## From the unit to the host

Control event, kind 00, two payload bytes: the control id and a value.

- A button sends 7F when it is pressed and 00 when it is released.
- A knob sends one message per tick: 7F for a tick clockwise and 00 for a tick counter-clockwise. A message carries no
  magnitude, so the speed of a turn is the number of messages.
- Shift is the control id 02. It sends 7F and 00 like a button and it never changes the message of another control, so
  the shift functions (Bypass, Save Preset, OK, Cancel, Select, Send) are assigned by the host. When shift is held with
  another control, the events come in this order: shift pressed, the control, shift released.

Acknowledgement, kind 24, one payload byte: the counter of the state frame that it acknowledges. The unit answers every
state frame within about 7 ms. Kinds 21, 03 and 06 are the handshake answers. Kind 23 (payload 7F) was seen when the
on-screen display of the application was switched off, after the host sent kind 22 (payload 7F) twice.

## From the host to the unit: the state frame

The state frame is kind 01 with 97 payload bytes. The application sends one about every 30 ms while something changes, and
none while nothing does, so the unit keeps showing the last state it received. Payload byte numbers below start at 0.

| Payload bytes | Content |
|---|---|
| 0 | a counter that goes up by one per frame and wraps from 7F to 00; the unit repeats it in its acknowledgement |
| 1 to 72 | the value of the control with the id (byte number minus one): a ring position from 00 to 7F for a knob, and 7F for a lit button; the meters are the ids 66 to 71 |
| 73 to 83 | flag bank A, one bit per id, seven ids to a byte |
| 84 to 94 | flag bank B, laid out like bank A: the controls with the bit set go dark when byte 95 is low, see below |
| 95 | the global switch of the LEDs: the application sends 20; 00 and 01 darken everything but the input and output knobs |
| 96 | the application sends 03; no effect that could be reproduced, see below |

The flag of an id is in byte 73 + id div 7 (bank A) or 84 + id div 7 (bank B), and the bits inside a byte are in reverse
order: the flag of the id is bit 6 - (id mod 7). The reversal was found when blinking an id lit another control of the same
group, for example the id 2A lit the control 30.

A control is dark unless its bank A bit is set, whatever its value byte is. With the bank A bit set, a button is lit when
its value byte is not zero (7F), and a knob ring is shown at the position of its value, so that a ring at 00 is shown at
the start of its range and a ring at 40 is shown at noon. This was checked with a chase of all 65 controls and the 6
meters (led_chase.py), and with a table of the combinations of value byte, bank A bit and bank B bit on three controls
(flag_states.py). In the quiet frame of the application, the rings of the knobs are at 3F (the center), and the flags of
the sections that are switched off are clear, which is why changing only the value byte of an EQ ring or of a track button
shows nothing.

The bank B bit is never set without the bank A bit of the same id, in any of the 778 frames of the application. It is
set together with bank A for the display, track, shape, EQ, compressor, order and sidechain controls and the meters,
and it is clear for the input and output sections (gain, the cuts, filter-to-comp, phase inversion, drive, character,
pan, solo, mute; volume follows the output meter). The bank B bit makes no visible difference while byte 95 is at the
application's value 20, which is what the combinations test on Gain, Phase Inv and the Comp button showed. It matters
when byte 95 is low: see the next paragraph.

Byte 95 is a global switch of the LEDs. With the values 02 to 7F, including the application's 20 and each single bit,
the unit shows the state of the frame. With 00 or 01 every LED goes dark except the rings of the input and output knobs,
which are the controls that have bank A set and bank B clear. Bank B is therefore, as far as this test shows, the bit
that makes a control follow the global switch, and a control with it clear stays lit whatever byte 95 is. The switch was
tried with the single bits only, so the exact rule (a threshold at 02, or any of the bits 1 to 6) is not known.

Byte 96 has no effect that could be reproduced. The application sends 03 and never changes it in any capture. In a test
of 00, each single bit and 7F, the user saw the ring of the drive knob move at 02 and the brightness of the output
knobs change at 7F, and nothing at the other values. A slow sweep of the whole range from 00 to 7F and back (0.15 s per
value) showed no change at all, so the first two observations were not confirmed: they may have been too brief to see in
the sweep, or left over from the previous test. The extension sends 03, like the application.

The meters are the values at the ids 66 to 71: input left (byte 67), input right (68), output left (69), output right
(70), the shape meter (71) and the compressor meter (72). The compressor meter rests at 7F and falls toward 00 as gain
reduction grows, the opposite of the other meters. The order of the meters is the order of the legacy CC numbers 6E to 73
in src/c1.zig, which is the reason for the guess that was then confirmed by the chase. The pairs 67 and 68, and 69 and
70, were first taken for a peak and a slower value; they are the left and the right channel.

## The checksum

How it was found, so that it can be done again for another kind of frame. The acknowledgements, which have one payload byte
that takes all 128 values, showed that the checksum is affine over GF(2) (an xor of the effects of the bits that are set,
plus a constant), with no exception in 128 values. The 778 state frames, in which the counter and several meter bytes
vary, showed the same for the whole payload. No standard CRC-32 matched, in any byte range, byte or word order, or
packing of the five bytes, and a search for a polynomial from the effect of a shift of one bit found none. What did work was
solving for one 32x32 matrix STEP that takes the effect of a bit to the effect of the next bit of the same byte (it held
for all 48 pairs that the data gave), and then finding that the effect of a byte is STEP applied 8 times to the effect of
the byte before it. All the effects of the 97 bytes follow from the effect of the lowest bit of the counter.

The checksum of a state frame is a linear function of the payload over GF(2): the checksum of a frame is the checksum of
another frame xor the effect of every bit that differs. The effect of a bit is a fixed 32x32 matrix applied (8 * byte
number + bit number) times to the effect of the lowest bit of the counter. The matrix was solved from 778 distinct frames
of the application. The model rebuilds every one of them exactly from a single base frame, and a model that was fitted on
one capture predicted all the reachable frames of an independent capture. It is in state_frame.py. It covers the state
frame only: the same function is probably used by the other kinds, but another length was not tested, and the
algorithm that the matrix comes from is not known.

## Capturing the application with MIDI Monitor

The traffic from the application to the unit can only be seen with MIDI Monitor in spy mode (the spying on the output to
the destinations turned on, with the unit selected as a destination and as a source). The window keeps only the last 1000
messages, and a keyboard that is also a source, with its notes and its active sensing, pushes the traffic of the unit out
of it, so only the unit should be a source. The saved document is read with mmon_decode.py. Because the application stops
sending when nothing changes, a capture needs something to change, and a timeline of what was done
(feedback_session.py) is needed to tie the bytes to the actions, since the unit does not say what it is showing.

## Behavior that was tested

A soak test (soak_test.py) checked what the extension relies on beyond single controls.

- A full moving state: every control lit, every ring sweeping and the six meters moving, in state frames sent about every
  35 ms for 60 seconds. 1707 frames were sent and every one was acknowledged, the unit sent nothing else, and the user saw
  every LED stay lit and every meter follow.
- A long idle: after one last frame, nothing was sent for 120 seconds. The unit sent nothing either, so it does not send
  anything on its own while idle, and the LEDs and the meters kept the last state without being refreshed.
- A reconnection: after the unit was unplugged and plugged in again, it was back in the legacy CC mode (the Gain knob sent
  CC 107, in steps of 3, and in steps of 1 after shift was pressed, which is the fine adjust of the legacy mode). After
  the handshake was replayed, the sysex events were back. The extension must therefore send the handshake every time that
  the unit appears, and not only once.

## The controls

The id is the control id of the unit. The value byte is the payload byte of the state frame that holds the value of the
control. The flag columns are payload byte and bit, for bank A and for bank B. The names follow src/c1.zig. The two
display buttons, and the shape button and the gate knob, were found to be the other way round than the first mapping
session had them, and are corrected here. Knobs and meters are shown as knob.

| Id | Name | Kind | Value byte | Flag A | Flag B |
|---|---|---|---|---|---|
| 0x00 | Inpt_disp_on | button | 1 | 73.6 | 84.6 |
| 0x01 | Inpt_disp_mode | button | 2 | 73.5 | 84.5 |
| 0x03 | Tr_pg_dn | button | 4 | 73.3 | 84.3 |
| 0x04 | Tr_pg_up | button | 5 | 73.2 | 84.2 |
| 0x05 | Tr_tr1 | button | 6 | 73.1 | 84.1 |
| 0x06 | Tr_tr2 | button | 7 | 73.0 | 84.0 |
| 0x07 | Tr_tr3 | button | 8 | 74.6 | 85.6 |
| 0x08 | Tr_tr4 | button | 9 | 74.5 | 85.5 |
| 0x09 | Tr_tr5 | button | 10 | 74.4 | 85.4 |
| 0x0A | Tr_tr6 | button | 11 | 74.3 | 85.3 |
| 0x0B | Tr_tr7 | button | 12 | 74.2 | 85.2 |
| 0x0C | Tr_tr8 | button | 13 | 74.1 | 85.1 |
| 0x0D | Tr_tr9 | button | 14 | 74.0 | 85.0 |
| 0x0E | Tr_tr10 | button | 15 | 75.6 | 86.6 |
| 0x0F | Tr_tr11 | button | 16 | 75.5 | 86.5 |
| 0x10 | Tr_tr12 | button | 17 | 75.4 | 86.4 |
| 0x11 | Tr_tr13 | button | 18 | 75.3 | 86.3 |
| 0x12 | Tr_tr14 | button | 19 | 75.2 | 86.2 |
| 0x13 | Tr_tr15 | button | 20 | 75.1 | 86.1 |
| 0x14 | Tr_tr16 | button | 21 | 75.0 | 86.0 |
| 0x15 | Tr_tr17 | button | 22 | 76.6 | 87.6 |
| 0x16 | Tr_tr18 | button | 23 | 76.5 | 87.5 |
| 0x17 | Tr_tr19 | button | 24 | 76.4 | 87.4 |
| 0x18 | Tr_tr20 | button | 25 | 76.3 | 87.3 |
| 0x19 | Tr_tr_copy | button | 26 | 76.2 | 87.2 |
| 0x1A | Tr_tr_grp | button | 27 | 76.1 | 87.1 |
| 0x1B | Inpt_Gain | knob | 28 | 76.0 | 87.0 |
| 0x1C | Inpt_HiCut | knob | 29 | 77.6 | 88.6 |
| 0x1D | Inpt_LoCut | knob | 30 | 77.5 | 88.5 |
| 0x1E | Inpt_filt_to_comp | button | 31 | 77.4 | 88.4 |
| 0x1F | Inpt_phase_inv | button | 32 | 77.3 | 88.3 |
| 0x20 | Inpt_preset | button | 33 | 77.2 | 88.2 |
| 0x21 | Shp_shape | button | 34 | 77.1 | 88.1 |
| 0x22 | Shp_Gate | knob | 35 | 77.0 | 88.0 |
| 0x23 | Shp_hard_gate | button | 36 | 78.6 | 89.6 |
| 0x24 | Shp_GateRelease | knob | 37 | 78.5 | 89.5 |
| 0x25 | Shp_sustain | knob | 38 | 78.4 | 89.4 |
| 0x26 | Shp_Punch | knob | 39 | 78.3 | 89.3 |
| 0x27 | Eq_eq | button | 40 | 78.2 | 89.2 |
| 0x28 | Eq_lp_shape | button | 41 | 78.1 | 89.1 |
| 0x29 | Eq_LoFrq | knob | 42 | 78.0 | 89.0 |
| 0x2A | Eq_LoGain | knob | 43 | 79.6 | 90.6 |
| 0x2B | Eq_LoMidFrq | knob | 44 | 79.5 | 90.5 |
| 0x2C | Eq_LoMidQ | knob | 45 | 79.4 | 90.4 |
| 0x2D | Eq_LoMidGain | knob | 46 | 79.3 | 90.3 |
| 0x2E | Eq_HiMidFrq | knob | 47 | 79.2 | 90.2 |
| 0x2F | Eq_HiMidQ | knob | 48 | 79.1 | 90.1 |
| 0x30 | Eq_HiMidGain | knob | 49 | 79.0 | 90.0 |
| 0x31 | Eq_hp_shape | button | 50 | 80.6 | 91.6 |
| 0x32 | Eq_HiFrq | knob | 51 | 80.5 | 91.5 |
| 0x33 | Eq_HiGain | knob | 52 | 80.4 | 91.4 |
| 0x34 | Comp_comp | button | 53 | 80.3 | 91.3 |
| 0x35 | Comp_Ratio | knob | 54 | 80.2 | 91.2 |
| 0x36 | Comp_DryWet | knob | 55 | 80.1 | 91.1 |
| 0x37 | Comp_Attack | knob | 56 | 80.0 | 91.0 |
| 0x38 | Comp_Release | knob | 57 | 81.6 | 92.6 |
| 0x39 | Comp_Thresh | knob | 58 | 81.5 | 92.5 |
| 0x3A | Tr_order | button | 59 | 81.4 | 92.4 |
| 0x3B | Tr_ext_sidechain | button | 60 | 81.3 | 92.3 |
| 0x3C | Out_Drive | knob | 61 | 81.2 | 92.2 |
| 0x3D | Out_DriveChar | knob | 62 | 81.1 | 92.1 |
| 0x3E | Out_Pan | knob | 63 | 81.0 | 92.0 |
| 0x3F | Out_solo | button | 64 | 82.6 | 93.6 |
| 0x40 | Out_mute | button | 65 | 82.5 | 93.5 |
| 0x41 | Out_Vol | knob | 66 | 82.4 | 93.4 |
| 0x42 | Inpt_MtrLft | knob | 67 | 82.3 | 93.3 |
| 0x43 | Inpt_MtrRgt | knob | 68 | 82.2 | 93.2 |
| 0x44 | Out_MtrLft | knob | 69 | 82.1 | 93.1 |
| 0x45 | Out_MtrRgt | knob | 70 | 82.0 | 93.0 |
| 0x46 | Shp_Mtr | knob | 71 | 83.6 | 94.6 |
| 0x47 | Comp_Mtr | knob | 72 | 83.5 | 94.5 |

Shift (id 02) has no LED, so it has no entry.

## Open questions

- Whether bank B is really the bit that makes a control follow byte 95. It fits both tests that were made, but it was not
  tested by changing B with byte 95 low. An earlier test that alternated only the B bit made the user report a change on
  all 15 controls tried while byte 95 was at 20, which no later test reproduced.
- What byte 96 is. The application never changes it, a sweep of its whole range showed no visible change, and the
  extension sends 03 like the application.
- Whether a value between 00 and 7F means something for a button LED (a dim level or a color) and not only on and off. Only 00, 40 and 7F were tried.
- How the checksum is really computed, and whether the other kinds of frame use the same function.
- What the challenge in the handshake is for. The unit accepts the bytes that the application sent, whatever the session.
- What kind 22 and kind 23 are exactly. Nothing is sent by the unit while idle, which was tested for 120 seconds.

## The tools

- listen_coremidi.py and listen-macos.sh listen to the unit with labels from a guided session (see README.md).
- handshake_replay.py replays the handshake and prints what the unit sends, with the names of the controls.
- map_controls.py asks for each control and writes its id (the table above).
- feedback_session.py guides a session of the application with MIDI Monitor, with timestamps for the steps.
- state_frame.py builds a state frame with a valid checksum, and test_state_frame.py rebuilds the 778 captured frames in
  testdata/state_frames.hex with it (run it with .venv/bin/python -m unittest test_state_frame).
- mmon_decode.py turns a MIDI Monitor document into one line per message.
- decode_usb_midi.py and sniff-macos.sh are for a capture of the USB bus, which an Apple silicon Mac cannot do.
- soak_test.py tests a full moving frame, a long idle and a reconnection.
- probe_destinations.py blinks bytes of the state frame, led_chase.py blinks the LED of each control and the meters, and
  flag_states.py shows one control in each combination of its value byte and its two flag bits, and byte_states.py sets one
  byte to a list of values (it was used on bytes 95 and 96).
