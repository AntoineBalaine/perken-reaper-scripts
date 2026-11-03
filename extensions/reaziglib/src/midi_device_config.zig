//! The state of the MIDI devices that a control surface is set to, and how the surface finds them again. Because REAPER numbers its
//! devices from a list that goes stale, the config string of a surface keeps the key of each device (see `midi_device_names`), and the
//! surface looks for the key among the devices that are there each time that it is made. Every control surface of an extension
//! calls `MidiDeviceConfig` with its own log scope, which gives it a type of its own, and so a state of its own.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const reaper_helpers = @import("reaper_helpers");
const device_names = @import("midi_device_names");

/// One key of a device, which stays the same when the device is not there, so that it is found again when it is plugged in.
pub const KeyStore = struct {
    buf: [device_names.max_key]u8 = undefined,
    len: usize = 0,

    pub fn set(self: *KeyStore, key: []const u8) void {
        self.len = @min(key.len, self.buf.len);
        @memcpy(self.buf[0..self.len], key[0..self.len]);
    }

    pub fn get(self: *const KeyStore) []const u8 {
        return self.buf[0..self.len];
    }
};

/// The keys of the input and of the output of a surface.
pub const SurfaceKeys = struct {
    in: KeyStore = .{},
    out: KeyStore = .{},
};

/// The MIDI devices of REAPER, in the form that `midi_device_names.find` reads.
pub const ReaperDevices = struct {
    input: bool,

    pub fn count(self: ReaperDevices) c_int {
        return if (self.input) Reaper.GetNumMIDIInputs() else Reaper.GetNumMIDIOutputs();
    }

    /// The name of a device, or null when the number has none: the numbers that REAPER keeps for devices that are not there.
    pub fn name(self: ReaperDevices, dev: c_int, buf: []u8) ?[]const u8 {
        return reaper_helpers.deviceName(buf, self.input, dev, false);
    }
};

/// The key of the device that has this number, or null for none.
pub fn keyOfDevice(input: bool, dev: c_int, buf: *[512]u8) ?[]const u8 {
    if (dev < 0) return null;
    const name = (ReaperDevices{ .input = input }).name(dev, buf) orelse return null;
    return device_names.key(name);
}

/// Reads the keys of a config string that REAPER gives as a C string.
pub fn parseDeviceKeys(str: [*c]const c_char, keys: *device_names.Keys) void {
    device_names.parseKeys(std.mem.span(@as([*:0]const u8, @ptrCast(str))), keys);
}

/// The state and the functions of one control surface. Because every scope gives a distinct type, the `var` declarations of a type
/// belong to the surface that made it, and the callbacks of REAPER, which have no context pointer, reach them without a parameter.
pub fn MidiDeviceConfig(comptime scope: @TypeOf(.enum_literal)) type {
    return struct {
        const log = std.log.scoped(scope);

        /// The keys of the devices that the surface is set to now, which are kept in its config string.
        pub var surface: SurfaceKeys = .{};

        /// The keys that the open dialog was given and did not find among the devices: the device is not plugged in today, and what
        /// the dialog saves keeps them, so that opening it and pressing OK does not forget the device.
        pub var dialog: SurfaceKeys = .{};

        /// The number of the device that a surface is set to now. A config that has the key of the device finds it among the devices
        /// that are there, whatever its number is, and none when it is not there; a config that has only a number, which is one that
        /// an older version saved, has that number.
        pub fn resolveDevice(input: bool, id: c_int, key: ?[]const u8) c_int {
            const wanted = key orelse return id;
            const found = device_names.find(ReaperDevices{ .input = input }, wanted);
            if (found) |dev| {
                log.info("midi {s} {s}: is the device {d}", .{ if (input) "in" else "out", wanted, dev });
                return dev;
            }
            log.warn("midi {s} {s}: is not there", .{ if (input) "in" else "out", wanted });
            return -1;
        }

        /// The surface keeps the key of each device that it has now, and of the others the key that its config named, so that a
        /// device that is not plugged in today is found when it is.
        pub fn rememberKeys(in_dev: c_int, out_dev: c_int, named: device_names.Keys) void {
            var name_buf: [512]u8 = undefined;
            if (keyOfDevice(true, in_dev, &name_buf)) |key| surface.in.set(key) else surface.in.set(named.in orelse "");
            if (keyOfDevice(false, out_dev, &name_buf)) |key| surface.out.set(key) else surface.out.set(named.out orelse "");
        }
    };
}

test "two scopes do not share their keys" {
    const First = MidiDeviceConfig(.first);
    const Second = MidiDeviceConfig(.second);
    First.surface.in.set("(capture_0) Console 1 MIDI 1");
    try std.testing.expectEqualStrings("(capture_0) Console 1 MIDI 1", First.surface.in.get());
    try std.testing.expectEqual(@as(usize, 0), Second.surface.in.get().len);
    First.surface.in.set("");
}

test "a key that is longer than the buffer is cut" {
    var store: KeyStore = .{};
    var long: [device_names.max_key + 10]u8 = undefined;
    @memset(&long, 'x');
    store.set(&long);
    try std.testing.expectEqual(device_names.max_key, store.get().len);
}

test "the keys of the devices follow the four numbers of the config, and an older config has none" {
    var keys: device_names.Keys = .{};
    const older: [*c]const c_char = @ptrCast("0 0 87 91");
    parseDeviceKeys(older, &keys);
    try std.testing.expect(keys.in == null and keys.out == null);

    var in_word_buf: [3 * device_names.max_key]u8 = undefined;
    var config_buf: [512:0]u8 = undefined;
    const config = std.mem.printSentinel(&config_buf, "0 0 87 91 {s} -", .{device_names.encode(&in_word_buf, "(capture_0) Console 1 MIDI 1")}, 0) catch unreachable;
    parseDeviceKeys(@ptrCast(config.ptr), &keys);
    try std.testing.expectEqualStrings("(capture_0) Console 1 MIDI 1", keys.in.?);
    // A device that is set to none has no key.
    try std.testing.expect(keys.out == null);
}
