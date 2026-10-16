//! Fuzzy matching for the action palette, in the spirit of fzf: the letters
//! of a query must appear in the text in order, not necessarily next to each
//! other, and the score favours matches that look intended.
//!
//! A query is split into words on whitespace, and every word must match
//! (so "item col" finds "Item: Set to default color"). Each word is scored
//! by the best way of laying its letters over the text:
//!
//!   * every matched letter earns a base score;
//!   * a letter right after the previous matched one earns a bonus, because
//!     whole fragments ("def" in "default") are what people mean;
//!   * a letter at the start of a word (after a space, punctuation, or a
//!     lowercase-to-uppercase step) earns a bonus, and the first letter of
//!     the text a larger one;
//!   * each skipped letter between matches costs a little.
//!
//! The letters are compared ignoring case. Only the first `MAX_TEXT` bytes of
//! the text and `MAX_WORD` bytes of a word take part.
const std = @import("std");

pub const MAX_TEXT = 256;
pub const MAX_WORD = 64;

const base_score: i32 = 16;
const consecutive_bonus: i32 = 24;
const boundary_bonus: i32 = 20;
const first_letter_bonus: i32 = 12;
const gap_penalty: i32 = 2;
const lead_penalty: i32 = 1;
const lead_penalty_cap: i32 = 8;
const impossible: i32 = std.math.minInt(i32) / 2;

/// Because penalties keep being subtracted from "impossible", it drifts
/// below its starting value; anything below half of it still counts as
/// impossible.
fn possible(s: i32) bool {
    return s > impossible / 2;
}

fn lower(c: u8) u8 {
    return std.ascii.toLower(c);
}

/// Whether the byte at `i` begins a word of `text`.
fn isBoundary(text: []const u8, i: usize) bool {
    if (i == 0) return true;
    const prev = text[i - 1];
    const cur = text[i];
    if (!std.ascii.isAlphanumeric(prev)) return true;
    return std.ascii.isLower(prev) and std.ascii.isUpper(cur);
}

/// The best score of laying `word` over `text` as an ordered subsequence, or
/// null when it does not fit.
pub fn scoreWord(word: []const u8, text_full: []const u8) ?i32 {
    if (word.len == 0) return 0;
    const text = text_full[0..@min(text_full.len, MAX_TEXT)];
    const w = word[0..@min(word.len, MAX_WORD)];
    if (w.len > text.len) return null;

    // Because most texts fail a plain subsequence test, it runs first: it is
    // linear, while the scoring below is not.
    var at: usize = 0;
    for (text) |c| {
        if (at < w.len and lower(c) == lower(w[at])) at += 1;
    }
    if (at < w.len) return null;

    // prev[j]: the best score with the previous letter of the word matched at
    // text[j]; cur[j] likewise for the current letter.
    var prev: [MAX_TEXT]i32 = undefined;
    var cur: [MAX_TEXT]i32 = undefined;

    for (w, 0..) |wc, i| {
        const want = lower(wc);
        // gap_best: the best prev[k] - gap_penalty * (j - 1 - k) over k <= j - 2,
        // that is, over every earlier match that is not directly adjacent.
        var gap_best: i32 = impossible;
        var j: usize = 0;
        while (j < text.len) : (j += 1) {
            cur[j] = impossible;
            if (i > 0 and j >= 2) {
                gap_best = @max(gap_best - gap_penalty, prev[j - 2] - gap_penalty);
            }
            if (lower(text[j]) != want) continue;

            var gain = base_score;
            if (isBoundary(text, j)) gain += boundary_bonus;
            if (j == 0) gain += first_letter_bonus;

            if (i == 0) {
                const lead: i32 = @min(@as(i32, @intCast(j)) * lead_penalty, lead_penalty_cap);
                cur[j] = gain - lead;
            } else {
                var best: i32 = impossible;
                if (j >= 1 and possible(prev[j - 1])) best = prev[j - 1] + consecutive_bonus;
                if (possible(gap_best)) best = @max(best, gap_best);
                if (possible(best)) cur[j] = best + gain;
            }
        }
        @memcpy(prev[0..text.len], cur[0..text.len]);
    }

    var best: i32 = impossible;
    for (prev[0..text.len]) |s| best = @max(best, s);
    return if (possible(best)) best else null;
}

/// The score of a whole query: the sum over its words, or null when any word
/// does not match. An empty query matches everything with score 0.
pub fn score(query: []const u8, text: []const u8) ?i32 {
    var total: i32 = 0;
    var words = std.mem.tokenizeAny(u8, query, " \t");
    while (words.next()) |word| {
        total += scoreWord(word, text) orelse return null;
    }
    return total;
}

/// A scored candidate: its index in the caller's list, its score, and the
/// length of its text (the tie-break, shorter first).
pub const Ranked = struct { index: u32, score: i32, len: u32 };

/// Whether `a` ranks above `b`: higher score first, then shorter text, then
/// the earlier index, so the order never depends on the order of arrival.
pub fn rankedBefore(a: Ranked, b: Ranked) bool {
    if (a.score != b.score) return a.score > b.score;
    if (a.len != b.len) return a.len < b.len;
    return a.index < b.index;
}

/// Keeps `list[0..count.*]` sorted best-first and at most `list.len` long,
/// inserting `cand` where it belongs and dropping the worst entry when full.
pub fn insertRanked(list: []Ranked, count: *usize, cand: Ranked) void {
    var pos = count.*;
    while (pos > 0 and rankedBefore(cand, list[pos - 1])) pos -= 1;
    if (pos >= list.len) return;
    const end = @min(count.*, list.len - 1);
    var i = end;
    while (i > pos) : (i -= 1) list[i] = list[i - 1];
    list[pos] = cand;
    count.* = @min(count.* + 1, list.len);
}

test "letters must appear in order" {
    try std.testing.expect(score("itmdefcol", "Item: Set to default color") != null);
    try std.testing.expect(score("xyz", "Item: Set to default color") == null);
    try std.testing.expect(score("loc", "color") == null); // 'l' before 'o', but no 'c' after it
    try std.testing.expect(score("ITEM", "item: set") != null); // case is ignored
}

test "an empty query matches everything" {
    try std.testing.expectEqual(@as(?i32, 0), score("", "anything"));
    try std.testing.expectEqual(@as(?i32, 0), score("  ", "anything"));
}

test "every word of the query must match" {
    try std.testing.expect(score("item col", "Item: Set to default color") != null);
    try std.testing.expect(score("col item", "Item: Set to default color") != null);
    try std.testing.expect(score("item zzz", "Item: Set to default color") == null);
}

test "a fragment kept whole beats the same letters scattered" {
    const whole = score("def", "Set to default color").?;
    const scattered = score("def", "Delete every file").?;
    try std.testing.expect(whole > scattered);
}

test "word starts are preferred" {
    // "tr" starts the word Track in the first text, and sits inside a word in the second.
    const start = score("tr", "Go to Track").?;
    const inside = score("tr", "Go to Mastering").?;
    try std.testing.expect(start > inside);
}

test "camel case humps count as word starts" {
    const hump = score("sn", "SetNote").?;
    const flat = score("sn", "Basnap").?;
    try std.testing.expect(hump > flat);
}

test "the first letters of the text are preferred" {
    try std.testing.expect(score("it", "Item: Set").? > score("it", "Set Item").?);
}

test "long texts and words are cut instead of overflowing" {
    var text: [400]u8 = undefined;
    @memset(&text, 'a');
    try std.testing.expect(score("aaa", &text) != null);
    var word: [100]u8 = undefined;
    @memset(&word, 'a');
    try std.testing.expect(scoreWord(&word, &text) != null);
}

test "insertRanked keeps the best entries in order" {
    var list: [3]Ranked = undefined;
    var count: usize = 0;
    insertRanked(&list, &count, .{ .index = 0, .score = 10, .len = 5 });
    insertRanked(&list, &count, .{ .index = 1, .score = 30, .len = 5 });
    insertRanked(&list, &count, .{ .index = 2, .score = 20, .len = 5 });
    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqual(@as(u32, 1), list[0].index);
    try std.testing.expectEqual(@as(u32, 2), list[1].index);
    try std.testing.expectEqual(@as(u32, 0), list[2].index);

    // A better entry pushes the worst one out; a worse one is dropped.
    insertRanked(&list, &count, .{ .index = 3, .score = 25, .len = 5 });
    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqual(@as(u32, 3), list[1].index);
    try std.testing.expectEqual(@as(u32, 2), list[2].index);
    insertRanked(&list, &count, .{ .index = 4, .score = 1, .len = 5 });
    try std.testing.expectEqual(@as(u32, 2), list[2].index);
}

test "ties go to the shorter text, then the earlier index" {
    var list: [3]Ranked = undefined;
    var count: usize = 0;
    insertRanked(&list, &count, .{ .index = 5, .score = 10, .len = 9 });
    insertRanked(&list, &count, .{ .index = 6, .score = 10, .len = 4 });
    insertRanked(&list, &count, .{ .index = 2, .score = 10, .len = 4 });
    try std.testing.expectEqual(@as(u32, 2), list[0].index);
    try std.testing.expectEqual(@as(u32, 6), list[1].index);
    try std.testing.expectEqual(@as(u32, 5), list[2].index);
}
