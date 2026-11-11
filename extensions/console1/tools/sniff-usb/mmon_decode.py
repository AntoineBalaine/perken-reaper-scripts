#!/usr/bin/env python3
"""Decodes a MIDI Monitor document (.mmon) into one line per message: time, port, kind of message, and the bytes in hexadecimal.

Because MIDI Monitor saves its window as an archive that is not readable as text, the messages are read out of the
property list. The time is the wall-clock time of the machine that ran MIDI Monitor, with milliseconds, so that it can be
read against the markers of feedback_session.py. The columns are separated by tabs.

MIDI Monitor keeps only the last 1000 messages of its window, and a keyboard that sends active sensing or notes can push
the traffic of the unit out of it. Turn off the sources that are not needed before a capture.

Usage:
  mmon_decode.py capture.mmon > capture.tsv
"""
import datetime
import plistlib
import sys

COCOA_EPOCH = datetime.datetime(2001, 1, 1)


def resolve(objects, value):
    return objects[value.data] if isinstance(value, plistlib.UID) else value


def main(path):
    document = plistlib.load(open(path, "rb"))
    archive = plistlib.loads(document["messageData"])
    objects = archive["$objects"]
    root = objects[archive["$top"]["root"].data]
    for ref in root["NS.objects"]:
        message = objects[ref.data]
        klass = objects[message["$class"].data]["$classname"]
        base = objects[message["timeBase"].data]
        seconds = base["timeInterval"] + (message["timeStampInNanos"] - base["hostTimeInNanos"]) / 1e9
        when = COCOA_EPOCH + datetime.timedelta(seconds=seconds)
        when = when.replace(tzinfo=datetime.timezone.utc).astimezone()
        endpoint = resolve(objects, message["originatingEndpoint"])
        if "dataBytes" in message:
            data = message["dataBytes"]
        elif "data" in message:
            data = bytes([0xF0]) + resolve(objects, message["data"]) + bytes([0xF7])
        else:
            data = bytes([message["statusByte"]])
        print("%s\t%s\t%s\t%s" % (when.strftime("%H:%M:%S.%f")[:-3], endpoint, klass, data.hex(" ")))


if __name__ == "__main__":
    main(sys.argv[1])
