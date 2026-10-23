#!/usr/bin/env python3
"""Generates ui-lab/tones.lua from the roland-vr09 project's docs/tones.json, so that the Lua design
lab shows the keyboard's real tone list.

  tools/gen_lua_tones.py <path to roland-vr09>/docs/tones.json > ui-lab/tones.lua

The lab reads the file once, when it starts. The result has one list for each section of the tone
list (`piano`, `synth` and `drum`), and each tone holds its name, its group, the three bytes that
select it (`number`, `msb`, `lsb`) and the Program Change number.
"""
import json
import sys


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    tones = json.load(open(sys.argv[1], encoding="utf-8"))
    sections = {}
    for tone in tones:
        sections.setdefault(tone["section"], []).append(tone)
    print("-- The keyboard's tones, generated from roland-vr09's docs/tones.json by tools/gen_lua_tones.py. Do not edit by hand.")
    print("return {")
    for name, rows in sections.items():
        print("  %s = {" % name)
        for t in rows:
            group = lua_string(t["group"]) if t["group"] else lua_string(name)
            print("    { name = %s, group = %s, number = %d, msb = %d, lsb = %d, program = %d }," % (
                lua_string(t["name"]), group, t["tone_number"], t["bank_msb"], t["bank_lsb"], t["program_number"]))
        print("  },")
    print("}")


main()
