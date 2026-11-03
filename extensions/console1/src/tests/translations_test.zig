//! Every key of the translations needs an entry in each language pack that ships with the extension. Because a key that a pack
//! does not have shows its English default to a user of that language, the test names the keys that a pack is missing.
const std = @import("std");
const translations = @import("../translations.zig");
const TranslationKey = translations.TranslationKey;

const Pack = struct { name: []const u8, text: []const u8 };

const packs = [_]Pack{
    .{ .name = "en", .text = @embedFile("../resources/langPacks/en.ini") },
    .{ .name = "fr", .text = @embedFile("../resources/langPacks/fr.ini") },
};

/// Whether a pack has an entry for a key. Because the key of a translation is the name of its section, an underscore and the name of
/// the entry, the entry `title` of the section `fx_sel` is the key `fx_sel_title`.
fn packHasKey(pack: []const u8, key: []const u8) bool {
    var section: []const u8 = "";
    var lines = std.mem.splitScalar(u8, pack, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, "\r");
        if (line.len > 2 and line[0] == '[' and line[line.len - 1] == ']') {
            section = line[1 .. line.len - 1];
            continue;
        }
        const equals = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const name = line[0..equals];
        if (key.len != section.len + 1 + name.len) continue;
        if (!std.mem.startsWith(u8, key, section) or key[section.len] != '_') continue;
        if (std.mem.eql(u8, key[section.len + 1 ..], name)) return true;
    }
    return false;
}

test "every translation key has an entry in each language pack" {
    var missing: usize = 0;
    for (packs) |pack| {
        for (std.meta.tags(TranslationKey)) |key| {
            if (packHasKey(pack.text, @tagName(key))) continue;
            std.debug.print("the language pack {s} has no entry for {s}\n", .{ pack.name, @tagName(key) });
            missing += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), missing);
}

test "a pack entry is found by its section and its name, and not by a part of them" {
    const pack = "[fx_sel]\ntitle=FX Browser\n\n[mapping]\nsave=Save\n";
    try std.testing.expect(packHasKey(pack, "fx_sel_title"));
    try std.testing.expect(packHasKey(pack, "mapping_save"));
    try std.testing.expect(!packHasKey(pack, "fx_sel_save"));
    try std.testing.expect(!packHasKey(pack, "fx_title"));
    try std.testing.expect(!packHasKey(pack, "mapping_sav"));
}
