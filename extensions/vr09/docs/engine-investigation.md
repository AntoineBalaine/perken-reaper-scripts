# Reaching the VR-09's synth engine

The lab's Engine tab shows the synth tone that Roland documents (an oscillator, a filter, an amplifier and an LFO for each of three
partials), with every control disabled. Because the unit answers nothing at the documented addresses, the plugin cannot read or write
the engine today. This note says what is known, and how to find out whether and how it can be reached.

## What is known

All of this comes from Roland's MIDI Implementation (`docs/VR-09_VR-730_MIDI_Implementation.pdf`) and from `docs/midi-capabilities.md`,
both in the `roland-vr09` project.

- The document puts a temporary synth tone for each part at `19 21 00 00` (upper 2), `19 41 00 00` (upper 1) and `1A 21 00 00`
  (lower), model `00 00 71`. A tone has a common block at offset `00 00 00` and three partials at `00 01 00`, `00 02 00` and
  `00 03 00`. The document gives a partial a total size of 0x40 bytes, and does not say what the common block's total is.
- Reads (RQ1) there get no reply. `scan.py probe` asked for `19 41 00 00` with sizes 1, 0x3D and 0x40, for `19 41 01 00`, and for
  `19 21` and `1A 21` with size 1. So the silence does not come from a wrong size at `19 41`. Writing there has not been tried.
- The live Synth Set at `18 00 00 00` answers, and its three parts at `18 00 21 00`, `18 00 22 00` and `18 00 25 00` hold only a tone
  selection (bank MSB, bank LSB, program number) and a few switches. The stored entries at `10` to `17` are all at their initial values.
- Registrations store which tone a part uses, not the tone's parameters. So the oscillator, filter and LFO data probably come from the
  unit's sound memory, and the temporary tone is probably an edit buffer.
- Some documented addresses are refused: a write leaves the value at 0 (see "Documented addresses that this unit refuses" in
  `docs/midi-capabilities.md`). The synth part's cutoff (`01 03 3A`) is one of them; the document's alternative is CC 74, which the plugin's catalog uses.
- The iPad app, VR-09 Editor, edits the synth parameters, so they can be reached somehow.

The simplest explanation, and only a guess, is that the edit buffer is not readable, and may only be written to, or only after the
editor has done something first.

## The three steps

Each step needs the keyboard on USB on a Linux machine, because `vr09.py` uses the raw ALSA devices. All of them use the roland-vr09
project: give its folder with `--roland-vr09` or `ROLAND_VR09`.

1. **Read every documented block, again and carefully** (reads only):

   ```
   tools/engine_probe.py reads
   ```

   It asks for the common block and the three partials of each part, with the three sizes, 0.25 seconds apart, and checks that the unit
   still answers every fourth probe. If any block answers, the engine is readable and the script prints the bytes.

2. **Watch the live Synth Set while you play the panel** (reads only):

   ```
   tools/engine_probe.py watch
   ```

   Change a synth tone, a part and a registration on the keyboard, and the script prints every byte of the Synth Set that moves. This
   shows what the panel changes, and whether any tone data is mirrored there.

3. **Try one write** (the only step that writes):

   ```
   tools/engine_probe.py write-test --yes --part upper1 --value 0
   ```

   It reads the part's tone selection, writes the cutoff of partial 1 at `19 41 01 0C`, asks whether the sound changed, and then selects
   the part's tone again, which loads the tone afresh and puts the parameter back. Because the area cannot be read, listening is the only
   check. Use a patch with a synth sound on the upper part, play a held note, and choose `--value 0` and then `--value 127`.

If steps 1 to 3 show nothing, the editor's traffic is the way to learn the protocol.

## Capturing the iPad editor

The editor must read and write the tone somehow, so a log of its messages gives the addresses, and any message it sends first.

**What is needed:** a Raspberry Pi 4 with a Linux that has the `dwc2` gadget driver, the USB cable to the iPad (with the camera adapter if
the iPad has a Lightning port), and the cable of the keyboard. The Pi 4 is a good choice because its USB-C port can be a device and its
USB-A ports are hosts.

**The idea:** the Pi appears to the iPad as a USB MIDI device, and acts as the USB host of the keyboard. `tools/midi_bridge.py` passes
every byte in both directions, so that the editor and the keyboard work as if they were connected, and writes each SysEx message to a log,
with its direction and, for a Roland message, what it asks (`RQ1`) or sets (`DT1`).

**Setup, as an outline.** I have not tried this on a Pi, so check each step against Raspberry Pi's and the kernel's documentation.

- The USB-C port of the Pi 4 carries the iPad's connection, and the Pi's power must not fight it. Power the Pi through the 40-pin
  header, and use a data-only cable or a power-blocking adapter on the USB-C port. Check this before connecting both power sources.
- In `/boot/firmware/config.txt`, add `dtoverlay=dwc2,dr_mode=peripheral`, and restart.
- Create a MIDI gadget with `configfs` and `f_midi` (the kernel's `libcomposite` module), with one input port and one output port. For
  the iPad to accept it, give it the identity of the keyboard: copy the vendor and the product ID from `lsusb` on the keyboard, and set
  the product name to "VR-09". The editor probably looks for a port with that name, but I do not know that.
- `amidi -l` then lists two devices: the gadget, and the keyboard. Start the bridge with their names:

  ```
  tools/midi_bridge.py --ipad hw:1,0,0 --keyboard hw:2,0,0 --log capture.log
  ```

  `tools/midi_bridge.py --selftest` checks the bridge without any device.

**What to capture**, one action at a time, with a note of the time of each, so that the log can be read against the notes:

1. Open the editor and connect: this shows the handshake, and the first reads.
2. Select a synth tone for the upper part: this shows how the editor loads a tone.
3. Move one control at a time: the cutoff, the resonance, the oscillator wave, an envelope time, the LFO rate.
4. Switch to partial 2 and 3, and to the lower part.

Use a registration that you can recall again, and save a dump first with `vr09.py dump`: the editor may write tone data to the keyboard.

## After the protocol is known

- **The lab:** the Engine tab stays as it is. Each card is enabled once its addresses are proven, by removing the `disabled` reason from
  its parameters in `ui-lab/extras.lua`.
- **The catalog:** its entries are for the keyboard part today. The synth model uses four-byte addresses, which `roland.zig` already
  handles for the dump code, so a parameter would need to say which model it belongs to.
- **The number of parameters:** the engine has about 40 parameters for each of three partials of each of three parts, about 360 in all.
  That is a lot of CLAP parameters. The panel could instead expose the 40 parameters of one selected part and partial, with two
  selectors, which is what the Engine tab shows.
