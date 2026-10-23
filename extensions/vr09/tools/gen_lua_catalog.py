#!/usr/bin/env python3
"""Generates ui-lab/catalog.lua from src/catalog.zig, so that the Lua design lab shows the plugin's
own parameters.

  tools/gen_lua_catalog.py > ui-lab/catalog.lua
"""
import os
import re
import sys

LINE = re.compile(r"^\s*\.\{ \.id = (\"(?:[^\"\\]|\\.)*\"), \.label = (\"(?:[^\"\\]|\\.)*\"), \.group = (\"(?:[^\"\\]|\\.)*\"), "
                  r"\.kind = \.(\w+), \.address = (\d+), \.low = (\d+), \.high = (\d+), \.channel = (\d+), \.cc = (\d+)(?:, \.names = &\.\{ (.*) \})? \},$")


def lua_string(zig_string):
    # Both languages write a plain string between double quotes, with the same escapes for what the
    # catalog holds (quotes, backslashes, UTF-8).
    return zig_string


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    source = open(os.path.join(here, "..", "src", "catalog.zig"), encoding="utf-8").read()
    rows = []
    for line in source.splitlines():
        m = LINE.match(line)
        if not m:
            if line.strip().startswith(".{ .id"):
                sys.exit("a catalog line this script does not understand: " + line)
            continue
        ident, label, group, kind, address, low, high, channel, cc, names = m.groups()
        names_lua = "nil"
        if names:
            names_lua = "{ " + names + " }"
        rows.append(
            "  { id = %s, label = %s, group = %s, kind = \"%s\", address = %s, low = %s, high = %s, channel = %s, cc = %s, names = %s },"
            % (lua_string(ident), lua_string(label), lua_string(group), kind, address, low, high, channel, cc, names_lua)
        )
    print("-- The plugin's parameters, generated from src/catalog.zig by tools/gen_lua_catalog.py. Do not edit by hand.")
    print("return {")
    print("\n".join(rows))
    print("}")


main()
