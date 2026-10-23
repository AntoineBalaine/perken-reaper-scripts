//! CopyItemsAsAbc and OpenItemsAsAbc: convert the selected MIDI items to ABC
//! notation, one tune per item, then either copy the text to the clipboard or
//! open it in an editor.
//!
//! Because the goal is a scratch pad that carries recorded notes into an ABC
//! score, the conversion only goes one way. Each item's notes are written to a
//! temporary standard MIDI file, the abcls CLI turns that file into ABC, and
//! the tunes are joined into one document. Nothing is read back into REAPER,
//! so the project and the score cannot drift apart. Because the CLI takes the
//! note lengths literally, a note a few ticks off the grid turns into ties
//! with tiny leftover notes, so the notes are snapped to a fixed grid of sixteenth
//! notes and triplets first (the [abc] quantize setting). The CLI does the key handling.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const config = @import("config.zig");
const commit = @import("beat/commit.zig");
const batch_rename = @import("batch_rename.zig");
const helpers = @import("reaper_helpers");
const timemap = @import("timemap.zig");

const log = std.log.scoped(.abc_export);

const dialog_title = "Perken: copy item as ABC";

/// The longest stderr text we read back from the CLI to show to the user.
const max_error_bytes = 4096;

/// One MIDI channel event of the exported track, positioned in ticks from the
/// start of the item.
pub const Event = struct {
    tick: u32,
    is_on: bool,
    channel: u8,
    pitch: u8,
    velocity: u8,

    /// Because a note that ends exactly where the next one of the same pitch
    /// begins would otherwise be cut short, at an equal tick the note-offs
    /// come before the note-ons.
    pub fn lessThan(_: void, a: Event, b: Event) bool {
        if (a.tick != b.tick) return a.tick < b.tick;
        return !a.is_on and b.is_on;
    }
};

/// A time signature taking effect at a tick. A meta event is written for
/// each, so an item whose meter changes partway exports with the change
/// rather than with its first signature applied throughout.
pub const SigChange = struct {
    tick: u32,
    numerator: u8,
    denominator: u8,
};

pub const Timing = struct {
    /// Ticks per quarter note, as the take reports them.
    ticks_per_qn: u16,
    /// Quarter notes per minute at the start of the item.
    bpm: f64,
    /// Signatures in tick order, the first at tick 0. One entry is the
    /// common case; more describe an item with meter changes in it.
    sigs: []const SigChange,
};

/// Because a MIDI file stores delays as variable-length quantities, the value
/// is split into 7-bit groups, with the high bit set on every group but the last.
pub fn writeVlq(w: anytype, value: u32) !void {
    var groups: [5]u8 = undefined;
    var n: usize = 0;
    var rest = value;
    groups[0] = @intCast(rest & 0x7F);
    n = 1;
    rest >>= 7;
    while (rest > 0) : (rest >>= 7) {
        groups[n] = @intCast((rest & 0x7F) | 0x80);
        n += 1;
    }
    while (n > 0) {
        n -= 1;
        try w.writeByte(groups[n]);
    }
}

/// Writes a format 0 standard MIDI file holding one track: the tempo, then
/// the time signatures and note events interleaved in tick order. The
/// caller sorts `events` first.
pub fn writeSmf(w: anytype, alloc: std.mem.Allocator, timing: Timing, events: []const Event) !void {
    var track = std.ArrayList(u8).init(alloc);
    defer track.deinit();
    const t = track.writer();

    const micros_per_qn: u24 = @intFromFloat(@round(60_000_000.0 / timing.bpm));
    try t.writeAll(&.{ 0x00, 0xFF, 0x51, 0x03 });
    try t.writeInt(u24, micros_per_qn, .big);

    var previous_tick: u32 = 0;
    var next_sig: usize = 0;

    // A signature meta event goes in before any note at its tick, so the
    // notes of a bar are read under the signature that bar is in.
    for (events) |e| {
        while (next_sig < timing.sigs.len and timing.sigs[next_sig].tick <= e.tick) {
            const sig = timing.sigs[next_sig];
            next_sig += 1;
            try writeVlq(t, sig.tick - previous_tick);
            previous_tick = sig.tick;
            const denominator_power: u8 = @intCast(std.math.log2_int(u8, sig.denominator));
            try t.writeAll(&.{ 0xFF, 0x58, 0x04, sig.numerator, denominator_power, 24, 8 });
        }
        try writeVlq(t, e.tick - previous_tick);
        previous_tick = e.tick;
        try t.writeByte((if (e.is_on) @as(u8, 0x90) else 0x80) | (e.channel & 0x0F));
        try t.writeByte(e.pitch);
        try t.writeByte(if (e.is_on) e.velocity else 0);
    }
    // Any signature after the last note still belongs in the file: it says
    // what meter the trailing bars are in.
    while (next_sig < timing.sigs.len) {
        const sig = timing.sigs[next_sig];
        next_sig += 1;
        try writeVlq(t, sig.tick - previous_tick);
        previous_tick = sig.tick;
        const denominator_power: u8 = @intCast(std.math.log2_int(u8, sig.denominator));
        try t.writeAll(&.{ 0xFF, 0x58, 0x04, sig.numerator, denominator_power, 24, 8 });
    }
    try t.writeAll(&.{ 0x00, 0xFF, 0x2F, 0x00 });

    try w.writeAll("MThd");
    try w.writeInt(u32, 6, .big);
    try w.writeInt(u16, 0, .big);
    try w.writeInt(u16, 1, .big);
    try w.writeInt(u16, timing.ticks_per_qn, .big);
    try w.writeAll("MTrk");
    try w.writeInt(u32, @intCast(track.items.len), .big);
    try w.writeAll(track.items);
}

/// The widest gap, in ticks, between the end of a note and the start of a later
/// note that the export closes. Because the Legato action ends every chord one
/// tick before the next one, to keep the notes from overlapping, the lengths
/// it leaves are one tick short of the grid, and the CLI would turn such a
/// length into a tie with a tiny leftover note. A gap this small cannot be
/// heard, so we close it.
pub const gap_tolerance_ticks: u32 = 2;

/// The first start in the ascending `starts` that is later than `tick`.
pub fn firstStartAfter(starts: []const u32, tick: u32) ?u32 {
    var low: usize = 0;
    var high: usize = starts.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (starts[mid] <= tick) low = mid + 1 else high = mid;
    }
    return if (low < starts.len) starts[low] else null;
}

/// Turns the take's notes into sorted events. Because the item can be
/// trimmed, only the notes that start inside it are kept. Muted notes are
/// dropped. Because the file has to start on a bar line, the positions are
/// made relative to `origin_ppq`, the start of the bar that holds the item's
/// start, so that a note keeps its offset inside the bar even when the item
/// begins in the middle of one.
pub fn isKept(n: helpers.Note, item_start_ppq: f64, item_end_ppq: f64) bool {
    if (n.muted) return false;
    return n.start_ppq >= item_start_ppq - 0.5 and n.start_ppq < item_end_ppq;
}

pub fn collectEvents(
    alloc: std.mem.Allocator,
    notes: []const helpers.Note,
    item_start_ppq: f64,
    item_end_ppq: f64,
    origin_ppq: f64,
) !std.ArrayList(Event) {
    var events = std.ArrayList(Event).init(alloc);
    errdefer events.deinit();

    // Because closing a gap needs to know where the later notes start, we
    // first collect the start of every kept note, in ascending order.
    var starts = std.ArrayList(u32).init(alloc);
    defer starts.deinit();
    for (notes) |n| {
        if (!isKept(n, item_start_ppq, item_end_ppq)) continue;
        try starts.append(@intFromFloat(@max(0, @round(n.start_ppq - origin_ppq))));
    }
    // Because Legato runs the last chord up to the end of the item, that end
    // counts as a boundary too.
    try starts.append(@intFromFloat(@max(0, @round(item_end_ppq - origin_ppq))));
    std.mem.sort(u32, starts.items, {}, std.sort.asc(u32));

    for (notes) |n| {
        if (!isKept(n, item_start_ppq, item_end_ppq)) continue;
        const start: u32 = @intFromFloat(@max(0, @round(n.start_ppq - origin_ppq)));
        // Because a zero-length note would turn into a note-off before its note-on, we keep at least one tick.
        var end: u32 = @max(start + 1, @as(u32, @intFromFloat(@max(0, @round(n.end_ppq - origin_ppq)))));
        if (firstStartAfter(starts.items, end)) |next| {
            if (next - end <= gap_tolerance_ticks) end = next;
        }
        const channel: u8 = @intCast(std.math.clamp(n.chan, 0, 15));
        const pitch: u8 = @intCast(std.math.clamp(n.pitch, 0, 127));
        const velocity: u8 = @intCast(std.math.clamp(n.vel, 1, 127));
        try events.append(.{ .tick = start, .is_on = true, .channel = channel, .pitch = pitch, .velocity = velocity });
        try events.append(.{ .tick = end, .is_on = false, .channel = channel, .pitch = pitch, .velocity = 0 });
    }
    std.mem.sort(Event, events.items, {}, Event.lessThan);
    return events;
}

/// The most items one run converts, and the biggest ABC text we read back.
pub const max_items = 64;
pub const max_abc_bytes = 4 * 1024 * 1024;

/// Where the CLI's launcher can live when REAPER's own PATH does not hold it.
/// REAPER started from the Finder only sees /usr/bin:/bin:/usr/sbin:/sbin.
pub const global_bin_dirs = [_][]const u8{
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/bin",
};
/// Directories under $HOME that npm-based version managers install into.
pub const home_bin_dirs = [_][]const u8{
    ".volta/bin",
    ".local/bin",
    ".npm-global/bin",
};

/// Joins the converted tunes into one document. Because every conversion
/// numbers its tune "X:1", and ABC wants each tune of a file numbered
/// differently, the reference number of tune `index` is replaced by
/// `index + 1`, and a blank line separates it from the previous tune.
pub fn appendTune(w: anytype, abc: []const u8, index: usize) !void {
    if (index > 0) try w.writeByte('\n');
    const body = if (std.mem.startsWith(u8, abc, "X:"))
        abc[(std.mem.indexOfScalar(u8, abc, '\n') orelse abc.len)..]
    else
        abc;
    try w.print("X:{d}", .{index + 1});
    if (!std.mem.startsWith(u8, abc, "X:")) try w.writeByte('\n');
    try w.writeAll(body);
    if (body.len == 0 or body[body.len - 1] != '\n') try w.writeByte('\n');
}

/// Builds the shell command that converts `midi_path`. Because the paths and
/// the title can hold any character, they are single-quoted for /bin/sh.
/// When the CLI was found by search (`path_dir` is set), that directory is put
/// first on PATH, because the launcher is a `#!/usr/bin/env node` script and
/// node usually sits in the same directory.
pub fn writeConvertCommand(w: anytype, cli: Cli, midi_path: []const u8, title: []const u8) !void {
    if (cli.path_dir) |dir| {
        try w.writeAll("PATH=");
        try batch_rename.writeShellQuoted(w, dir);
        try w.writeAll(":\"$PATH\" ");
    }
    try w.writeAll(cli.command);
    try w.writeAll(" midi2abc ");
    try batch_rename.writeShellQuoted(w, midi_path);
    if (title.len > 0) {
        try w.writeAll(" --title ");
        try batch_rename.writeShellQuoted(w, title);
    }
}

/// How to start the abcls CLI: a command line for /bin/sh, and the directory
/// to put on PATH when the command was found by search.
pub const Cli = struct {
    command: []const u8,
    path_dir: ?[]const u8 = null,
};

pub fn fileExists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

/// Looks for the abcls launcher in `dir`; on success the full path is
/// written to `buf`.
pub fn launcherIn(buf: []u8, dir: []const u8) ?[]const u8 {
    const path = std.fmt.bufPrint(buf, "{s}/abcls", .{dir}) catch return null;
    return if (fileExists(path)) path else null;
}

/// Searches for the CLI without any configuration: first the usual global
/// install directories, then the version managers' directories under $HOME
/// (the newest nvm node version wins), and at last the user's login shell,
/// whose PATH is the one the user sees in a terminal.
pub fn findCli(alloc: std.mem.Allocator, out: *std.ArrayList(u8)) ?Cli {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    for (global_bin_dirs) |dir| {
        if (launcherIn(&path_buf, dir)) |p| return rememberCli(out, p);
    }
    const home = std.posix.getenv("HOME") orelse return findInLoginShell(alloc, out);

    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    for (home_bin_dirs) |rel| {
        const dir = std.fmt.bufPrint(&dir_buf, "{s}/{s}", .{ home, rel }) catch continue;
        if (launcherIn(&path_buf, dir)) |p| return rememberCli(out, p);
    }

    var nvm_buf: [std.fs.max_path_bytes]u8 = undefined;
    const nvm = std.fmt.bufPrint(&nvm_buf, "{s}/.nvm/versions/node", .{home}) catch return findInLoginShell(alloc, out);
    if (newestNodeBin(alloc, nvm, &dir_buf)) |dir| {
        if (launcherIn(&path_buf, dir)) |p| return rememberCli(out, p);
    }
    return findInLoginShell(alloc, out);
}

/// Stores the launcher path as the command, and its directory as the PATH entry.
pub fn rememberCli(out: *std.ArrayList(u8), launcher: []const u8) ?Cli {
    out.clearRetainingCapacity();
    out.appendSlice(launcher) catch return null;
    const dir = std.fs.path.dirname(out.items) orelse return null;
    return .{ .command = out.items, .path_dir = dir };
}

/// The bin directory of the highest node version under an nvm versions
/// directory, written to `buf`. Version names compare as text, which is good
/// enough to prefer a recent version.
pub fn newestNodeBin(alloc: std.mem.Allocator, versions_dir: []const u8, buf: []u8) ?[]const u8 {
    _ = alloc;
    var dir = std.fs.openDirAbsolute(versions_dir, .{ .iterate = true }) catch return null;
    defer dir.close();
    var best: [64]u8 = undefined;
    var best_len: usize = 0;
    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (entry.kind != .directory or entry.name.len > best.len) continue;
        if (best_len == 0 or std.mem.order(u8, entry.name, best[0..best_len]) == .gt) {
            @memcpy(best[0..entry.name.len], entry.name);
            best_len = entry.name.len;
        }
    }
    if (best_len == 0) return null;
    return std.fmt.bufPrint(buf, "{s}/{s}/bin", .{ versions_dir, best[0..best_len] }) catch null;
}

/// Asks the user's login shell where `abcls` is.
pub fn findInLoginShell(alloc: std.mem.Allocator, out: *std.ArrayList(u8)) ?Cli {
    const shell = std.posix.getenv("SHELL") orelse "/bin/sh";
    var captured = runCapture(alloc, &.{ shell, "-lc", "command -v abcls" }) catch return null;
    defer captured.deinit(alloc);
    if (!captured.ok) return null;
    const line = std.mem.trim(u8, captured.stdout, " \t\r\n");
    if (line.len == 0 or line[0] != '/') return null;
    return rememberCli(out, line);
}

pub const Captured = struct {
    stdout: []u8,
    stderr: []u8,
    ok: bool,

    pub fn deinit(self: *Captured, alloc: std.mem.Allocator) void {
        alloc.free(self.stdout);
        alloc.free(self.stderr);
    }
};

/// Runs a program, waits for it and returns what it wrote. A run is good when
/// the exit code is zero.
pub fn runCapture(alloc: std.mem.Allocator, argv: []const []const u8) !Captured {
    var child = std.process.Child.init(argv, alloc);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    var out = std.ArrayListUnmanaged(u8){};
    var err = std.ArrayListUnmanaged(u8){};
    errdefer out.deinit(alloc);
    errdefer err.deinit(alloc);
    try child.collectOutput(alloc, &out, &err, max_abc_bytes);
    const term = try child.wait();
    return .{
        .stdout = try out.toOwnedSlice(alloc),
        .stderr = try err.toOwnedSlice(alloc),
        .ok = switch (term) {
            .Exited => |code| code == 0,
            else => false,
        },
    };
}

/// Starts the clipboard program, feeds it the text on its standard input and
/// waits for it.
pub fn copyToClipboard(alloc: std.mem.Allocator, clipboard: []const u8, text: []const u8) !void {
    var child = std.process.Child.init(&.{ "/bin/sh", "-c", clipboard }, alloc);
    child.stdin_behavior = .Pipe;
    try child.spawn();
    child.stdin.?.writeAll(text) catch {};
    child.stdin.?.close();
    child.stdin = null;
    const term = try child.wait();
    if (term != .Exited or term.Exited != 0) return error.ClipboardFailed;
}

pub fn showError(message: []const u8) void {
    var buf: [max_error_bytes + 256:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, "{s}", .{message}) catch return;
    _ = Reaper.ShowMessageBox(text, dialog_title, 0);
}

pub fn tempPath(buf: []u8, name: []const u8) ?[]const u8 {
    const dir = std.posix.getenv("TMPDIR") orelse "/tmp";
    const trimmed = std.mem.trimRight(u8, dir, "/");
    return std.fmt.bufPrint(buf, "{s}/perken_abc_{s}", .{ trimmed, name }) catch null;
}

/// The name of the ABC file of one conversion, made unique by the time of the
/// conversion. Because VS Code keeps showing the text it already has for a
/// path it has opened, reusing one file name made a new conversion look like
/// the previous one; a new name per conversion makes it open as a new file.
pub fn conversionFileName(buf: []u8, millis: i64) ?[]const u8 {
    return std.fmt.bufPrint(buf, "items_{d}.abc", .{millis}) catch null;
}

/// Selected MIDI items in timeline order, so that the tunes of the document
/// follow the order of the recordings.
pub fn selectedMidiItems(buf: []*Reaper.MediaItem) []*Reaper.MediaItem {
    var n: usize = 0;
    const count = Reaper.CountSelectedMediaItems(null);
    var i: c_int = 0;
    while (i < count and n < buf.len) : (i += 1) {
        const item = Reaper.GetSelectedMediaItem(null, i) orelse continue;
        const take = helpers.getActiveTake(item) orelse continue;
        if (!Reaper.TakeIsMIDI(take)) continue;
        buf[n] = item;
        n += 1;
    }
    std.mem.sort(*Reaper.MediaItem, buf[0..n], {}, itemStartsEarlier);
    return buf[0..n];
}

pub fn itemStartsEarlier(_: void, a: *Reaper.MediaItem, b: *Reaper.MediaItem) bool {
    return Reaper.GetMediaItemInfo_Value(a, "D_POSITION") < Reaper.GetMediaItemInfo_Value(b, "D_POSITION");
}

/// The finest steps, in quarter notes, that a note position may snap to: the
/// sixteenth note and the sixteenth-note triplet. Because the two grids share
/// the eighth-note triplet and every eighth note, straight and triplet
/// rhythms both survive the snap.
///
/// rhythm_action snaps to a different grid (96ths of a whole note, exact
/// rationals, no tuplets) because its tiling needs exact arithmetic. The
/// difference is known and accepted — see the note on `snap_den` there.
pub const straight_step_qn: f64 = 0.25;
pub const triplet_step_qn: f64 = 1.0 / 6.0;

/// The position, in quarter notes, nearest to `qn` among the straight and the
/// triplet steps.
pub fn snapPositionQn(qn: f64) f64 {
    const straight = @round(qn / straight_step_qn) * straight_step_qn;
    const triplet = @round(qn / triplet_step_qn) * triplet_step_qn;
    return if (@abs(qn - triplet) < @abs(qn - straight)) triplet else straight;
}

/// The start and end, in quarter notes, of a note snapped to the steps above.
/// Because a note needs some length, an end that would land on or before the
/// start moves one step after the start.
pub fn snapNoteQn(start_qn: f64, end_qn: f64) struct { start: f64, end: f64 } {
    const start = snapPositionQn(start_qn);
    var end = snapPositionQn(end_qn);
    if (end <= start + 1e-9) end = start + triplet_step_qn;
    return .{ .start = start, .end = end };
}

/// Snaps every note to the steps above. Because the result must not depend
/// on the grid division that happens to be set in REAPER's MIDI editor, the
/// steps are fixed. The positions are converted to project quarter notes and
/// back, so that tempo changes are respected.
pub fn quantizeNotes(take: *Reaper.MediaItem_Take, notes: []helpers.Note) void {
    for (notes) |*n| {
        const snapped = snapNoteQn(
            Reaper.MIDI_GetProjQNFromPPQPos(take, n.start_ppq),
            Reaper.MIDI_GetProjQNFromPPQPos(take, n.end_ppq),
        );
        n.start_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, snapped.start);
        n.end_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, snapped.end);
    }
}

/// Converts a QN position to a tick relative to `base_ppq`, the same base
/// `collectEvents` counts note ticks from.
fn tickAtQn(take: *Reaper.MediaItem_Take, base_ppq: f64, qn: f64) u32 {
    const ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, qn);
    if (ppq <= base_ppq) return 0;
    return @intFromFloat(@round(ppq - base_ppq));
}

/// The signatures the item spans, as ticks into the exported file: one at
/// tick 0 for the meter the item opens in, plus one wherever the meter
/// changes before the item ends.
///
/// Reading a single signature at the item start — which is what this did
/// before — silently exported every later bar of the item in the wrong
/// meter whenever the project changed meter partway through.
pub fn itemSignatures(
    alloc: std.mem.Allocator,
    take: *Reaper.MediaItem_Take,
    src: timemap.BarSource,
    from_qn: f64,
    to_qn: f64,
    base_ppq: f64,
) ![]SigChange {
    var out = std.ArrayList(SigChange).init(alloc);
    errdefer out.deinit();

    var it = timemap.walkBars(src, from_qn, to_qn);
    var previous: ?timemap.Signature = null;
    while (it.next()) |bar| {
        if (previous) |p| {
            if (p.num == bar.sig.num and p.denom == bar.sig.denom) continue;
        }
        previous = bar.sig;
        try out.append(.{
            // The opening signature belongs at tick 0 even when the item
            // starts mid-bar, so the file never begins without one.
            .tick = if (out.items.len == 0) 0 else tickAtQn(take, base_ppq, bar.start_qn),
            .numerator = @intCast(std.math.clamp(bar.sig.num, 1, 255)),
            .denominator = @intCast(std.math.clamp(bar.sig.denom, 1, 128)),
        });
    }
    if (out.items.len == 0) try out.append(.{ .tick = 0, .numerator = 4, .denominator = 4 });
    return out.toOwnedSlice();
}

/// Writes the item's notes to `path` as a standard MIDI file. Returns false
/// when the item holds no audible note, so there is nothing to convert.
pub fn writeItemMidi(alloc: std.mem.Allocator, item: *Reaper.MediaItem, path: []const u8, quantize: bool) !bool {
    const take = helpers.getActiveTake(item) orelse return false;
    const item_start = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    const item_end = item_start + Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
    const qn_start = timemap.timeToQn(item_start);
    const ppq_start = Reaper.MIDI_GetPPQPosFromProjQN(take, qn_start);
    const ppq_end = Reaper.MIDI_GetPPQPosFromProjQN(take, timemap.timeToQn(item_end));
    const ticks_per_qn = Reaper.MIDI_GetPPQPosFromProjQN(take, qn_start + 1) - ppq_start;

    const notes = try helpers.collectNotes(alloc, take);
    defer alloc.free(notes);
    if (quantize) quantizeNotes(take, notes);
    // Because the item can start in the middle of a bar, the ticks count from
    // the bar line before it, which keeps every note at its place in the bar.
    const bar_start_ppq = timemap.barStartPpq(take, ppq_start + 0.5);
    var events = try collectEvents(alloc, notes, ppq_start, ppq_end, @min(bar_start_ppq, ppq_start));
    defer events.deinit();
    if (events.items.len == 0) return false;

    const base_ppq = @min(bar_start_ppq, ppq_start);
    const sigs = try itemSignatures(alloc, take, timemap.reaperBarSource(), qn_start, timemap.timeToQn(item_end), base_ppq);
    defer alloc.free(sigs);

    var bytes = std.ArrayList(u8).init(alloc);
    defer bytes.deinit();
    try writeSmf(bytes.writer(), alloc, .{
        .ticks_per_qn = @intFromFloat(@round(ticks_per_qn)),
        .bpm = commit.tempoAt(item_start),
        .sigs = sigs,
    }, events.items);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = bytes.items });
    return true;
}

/// Converts every selected MIDI item and returns the joined ABC document, or
/// null after telling the user why there is none.
pub fn convertSelection(alloc: std.mem.Allocator, settings: config.Settings) ?[]u8 {
    var item_buf: [max_items]*Reaper.MediaItem = undefined;
    const selected = selectedMidiItems(&item_buf);
    if (selected.len == 0) {
        showError("Because no MIDI item is selected, there is nothing to convert.");
        return null;
    }

    var found = std.ArrayList(u8).init(alloc);
    defer found.deinit();
    const cli: Cli = if (settings.abc_command.len > 0)
        .{ .command = settings.abc_command }
    else
        findCli(alloc, &found) orelse {
            showError("Because the abcls CLI was not found, nothing was converted.\n\nInstall it with `npm install -g abcls`, or set `command` in the [abc] section of perken-utilities.ini.");
            return null;
        };

    var document = std.ArrayList(u8).init(alloc);
    errdefer document.deinit();
    var tunes: usize = 0;
    for (selected) |item| {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = tempPath(&path_buf, "item.mid") orelse continue;
        const has_notes = writeItemMidi(alloc, item, path, settings.abc_quantize) catch |err| {
            log.warn("cannot write {s}: {s}", .{ path, @errorName(err) });
            continue;
        };
        if (!has_notes) continue;

        const take = helpers.getActiveTake(item) orelse continue;
        var cmd_buf: [std.fs.max_path_bytes * 2 + 1024]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&cmd_buf);
        writeConvertCommand(fbs.writer(), cli, path, std.mem.span(Reaper.GetTakeName(take))) catch continue;
        var captured = runCapture(alloc, &.{ "/bin/sh", "-c", fbs.getWritten() }) catch |err| {
            log.warn("cannot run the CLI: {s}", .{@errorName(err)});
            continue;
        };
        defer captured.deinit(alloc);
        if (!captured.ok) {
            var msg: [max_error_bytes + 128]u8 = undefined;
            const text = std.fmt.bufPrint(&msg, "Because the conversion failed, nothing was produced.\n\n{s}", .{captured.stderr}) catch "Because the conversion failed, nothing was produced.";
            showError(text);
            document.deinit();
            return null;
        }
        appendTune(document.writer(), captured.stdout, tunes) catch continue;
        tunes += 1;
    }
    if (tunes == 0) {
        document.deinit();
        showError("Because the selected items hold no audible notes, there is nothing to convert.");
        return null;
    }
    return document.toOwnedSlice() catch null;
}

pub fn copyItemsAsAbc(_: *actions.RunCtx) void {
    if (builtin.os.tag == .windows) return showError("Because this action runs through /bin/sh, it is not available on Windows.");
    const alloc = std.heap.c_allocator;
    var settings = config.load(alloc);
    defer settings.deinit();
    const document = convertSelection(alloc, settings) orelse return;
    defer alloc.free(document);
    copyToClipboard(alloc, settings.abc_clipboard, document) catch |err| {
        log.warn("copy to clipboard failed: {s}", .{@errorName(err)});
        showError("Because the clipboard program failed, nothing was copied.");
    };
}

/// Writes the document to a temporary .abc file and opens it with the
/// editor program, which for VS Code hands the file to the running window.
pub fn openItemsAsAbc(_: *actions.RunCtx) void {
    if (builtin.os.tag == .windows) return showError("Because this action runs through /bin/sh, it is not available on Windows.");
    const alloc = std.heap.c_allocator;
    var settings = config.load(alloc);
    defer settings.deinit();
    const document = convertSelection(alloc, settings) orelse return;
    defer alloc.free(document);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var name_buf: [64]u8 = undefined;
    const name = conversionFileName(&name_buf, std.time.milliTimestamp()) orelse return;
    const path = tempPath(&path_buf, name) orelse return;
    std.fs.cwd().writeFile(.{ .sub_path = path, .data = document }) catch |err| {
        log.warn("cannot write {s}: {s}", .{ path, @errorName(err) });
        return showError("Because the temporary ABC file could not be written, nothing was opened.");
    };

    var cmd_buf: [std.fs.max_path_bytes + 512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&cmd_buf);
    fbs.writer().print("{s} ", .{settings.abc_editor}) catch return;
    batch_rename.writeShellQuoted(fbs.writer(), path) catch return;
    var captured = runCapture(alloc, &.{ "/bin/sh", "-c", fbs.getWritten() }) catch return;
    defer captured.deinit(alloc);
    if (!captured.ok) showError("Because the editor could not be started, the file was not opened. Check `editor` in the [abc] section of perken-utilities.ini.");
}

/// The percent-encoded form of `s`, for the query of a link. Every byte that
/// is not an unreserved URL character is escaped, so that the path survives
/// spaces, slashes and non-ASCII names.
pub fn writePercentEncoded(w: anytype, s: []const u8) !void {
    for (s) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            try w.writeByte(c);
        } else {
            try w.print("%{X:0>2}", .{c});
        }
    }
}

/// The link that makes the abcls VS Code extension open `path` and show its
/// preview. Because the link carries a vscode:// scheme, the operating system
/// delivers it to the VS Code that is already running.
pub fn writeOpenLink(w: anytype, path: []const u8) !void {
    try w.writeAll(open_link_prefix);
    try writePercentEncoded(w, path);
    try w.writeAll("&preview=1");
}

pub const open_link_prefix = "vscode://antoinebalaine.abc-ls/open?file=";

/// Writes the document to a temporary .abc file, then asks the system to
/// open the preview link for it.
pub fn previewItemsAsAbc(_: *actions.RunCtx) void {
    if (builtin.os.tag == .windows) return showError("Because this action runs through /bin/sh, it is not available on Windows.");
    const alloc = std.heap.c_allocator;
    var settings = config.load(alloc);
    defer settings.deinit();
    const document = convertSelection(alloc, settings) orelse return;
    defer alloc.free(document);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var name_buf: [64]u8 = undefined;
    const name = conversionFileName(&name_buf, std.time.milliTimestamp()) orelse return;
    const path = tempPath(&path_buf, name) orelse return;
    std.fs.cwd().writeFile(.{ .sub_path = path, .data = document }) catch |err| {
        log.warn("cannot write {s}: {s}", .{ path, @errorName(err) });
        return showError("Because the temporary ABC file could not be written, nothing was opened.");
    };

    var link_buf: [std.fs.max_path_bytes * 3 + 128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&link_buf);
    writeOpenLink(fbs.writer(), path) catch return;
    const opener = if (builtin.os.tag == .macos) "open" else "xdg-open";
    var captured = runCapture(alloc, &.{ opener, fbs.getWritten() }) catch return;
    defer captured.deinit(alloc);
    if (!captured.ok) showError("Because the preview link could not be opened, the preview was not shown. VS Code and the abc-ls extension (a version with link support) must be installed.");
}

pub const entries = [_]actions.Entry{
    .{
        .name = "CopyItemsAsAbc",
        .def = .{
            .steps = &.{.{ .func = &copyItemsAsAbc }},
            .desc = "Copy the selected MIDI items as ABC notation",
        },
    },
    .{
        .name = "OpenItemsAsAbc",
        .def = .{
            .steps = &.{.{ .func = &openItemsAsAbc }},
            .desc = "Open the selected MIDI items as ABC notation in the editor",
        },
    },
    .{
        .name = "PreviewItemsAsAbc",
        .def = .{
            .steps = &.{.{ .func = &previewItemsAsAbc }},
            .desc = "Open the selected MIDI items as ABC notation, with the score preview",
        },
    },
};

test "writeVlq encodes the MIDI examples" {
    var buf: [8]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeVlq(fbs.writer(), 0);
    try writeVlq(fbs.writer(), 0x80);
    try writeVlq(fbs.writer(), 0x3FFF);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x81, 0x00, 0xFF, 0x7F }, fbs.getWritten());
}

test "an item produces a one-track file with ordered events" {
    const alloc = std.testing.allocator;
    const notes = [_]helpers.Note{
        // a note before the item's start (trimmed away), a muted note, and two kept notes
        .{ .selected = false, .muted = false, .start_ppq = 0, .end_ppq = 100, .chan = 0, .pitch = 50, .vel = 90 },
        .{ .selected = false, .muted = true, .start_ppq = 960, .end_ppq = 1440, .chan = 0, .pitch = 51, .vel = 90 },
        .{ .selected = false, .muted = false, .start_ppq = 960, .end_ppq = 1440, .chan = 0, .pitch = 60, .vel = 96 },
        .{ .selected = false, .muted = false, .start_ppq = 1440, .end_ppq = 1920, .chan = 0, .pitch = 60, .vel = 96 },
    };
    var events = try collectEvents(alloc, &notes, 960, 3840, 960);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 4), events.items.len);
    // the first note ends where the second begins: its off comes before the on
    try std.testing.expect(!events.items[1].is_on);
    try std.testing.expect(events.items[2].is_on);
    try std.testing.expectEqual(@as(u32, 480), events.items[2].tick);

    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();
    try writeSmf(out.writer(), alloc, .{
        .ticks_per_qn = 960,
        .bpm = 120,
        .sigs = &.{.{ .tick = 0, .numerator = 4, .denominator = 4 }},
    }, events.items);
    try std.testing.expectEqualSlices(u8, "MThd", out.items[0..4]);
    try std.testing.expectEqual(@as(u16, 960), std.mem.readInt(u16, out.items[12..14], .big));
    try std.testing.expectEqualSlices(u8, "MTrk", out.items[14..18]);
    // tempo of 120 bpm is 500000 microseconds per quarter note
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20 }, out.items[22..29]);
}

test "tunes are numbered one after the other" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try appendTune(fbs.writer(), "X:1\nK:C\nCDE\n", 0);
    try appendTune(fbs.writer(), "X:1\nK:G\nGAB", 1);
    try std.testing.expectEqualStrings("X:1\nK:C\nCDE\n\nX:2\nK:G\nGAB\n", fbs.getWritten());
}

test "the convert command quotes its arguments and extends PATH for a found CLI" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeConvertCommand(fbs.writer(), .{ .command = "/opt/bin/abcls", .path_dir = "/opt/bin" }, "/tmp/a.mid", "Joe's riff");
    try std.testing.expectEqualStrings(
        "PATH='/opt/bin':\"$PATH\" /opt/bin/abcls midi2abc '/tmp/a.mid' --title 'Joe'\\''s riff'",
        fbs.getWritten(),
    );
}

test "a configured command is used as it is" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeConvertCommand(fbs.writer(), .{ .command = "node cli.js" }, "/tmp/a.mid", "");
    try std.testing.expectEqualStrings("node cli.js midi2abc '/tmp/a.mid'", fbs.getWritten());
}

test "the preview link escapes the path" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeOpenLink(fbs.writer(), "/var/T/my tune.abc");
    try std.testing.expectEqualStrings(
        "vscode://antoinebalaine.abc-ls/open?file=%2Fvar%2FT%2Fmy%20tune.abc&preview=1",
        fbs.getWritten(),
    );
}

test "snapNoteQn snaps both ends and keeps a length" {
    const off = snapNoteQn(1.98, 3.49);
    try std.testing.expectEqual(@as(f64, 2), off.start);
    try std.testing.expectEqual(@as(f64, 3.5), off.end);
    const short = snapNoteQn(1.02, 1.08);
    try std.testing.expectEqual(@as(f64, 1), short.start);
    try std.testing.expect(short.end > short.start);
}

test "snapping keeps both straight and triplet positions and ignores the editor grid" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), snapPositionQn(0.52), 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), snapPositionQn(0.34), 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), snapPositionQn(0.74), 1e-9);
}

test "the one-tick gaps that Legato leaves are closed" {
    const alloc = std.testing.allocator;
    const notes = [_]helpers.Note{
        // a chord of two notes ending one tick before the next chord, then a note ending one tick before a rest
        .{ .selected = false, .muted = false, .start_ppq = 0, .end_ppq = 959, .chan = 0, .pitch = 60, .vel = 90 },
        .{ .selected = false, .muted = false, .start_ppq = 0, .end_ppq = 959, .chan = 0, .pitch = 64, .vel = 90 },
        .{ .selected = false, .muted = false, .start_ppq = 960, .end_ppq = 1439, .chan = 0, .pitch = 62, .vel = 90 },
        // a real rest of a sixteenth note stays
        .{ .selected = false, .muted = false, .start_ppq = 1680, .end_ppq = 1900, .chan = 0, .pitch = 65, .vel = 90 },
    };
    var events = try collectEvents(alloc, &notes, 0, 9999, 0);
    defer events.deinit();
    var ends = std.ArrayList(u32).init(alloc);
    defer ends.deinit();
    for (events.items) |e| if (!e.is_on) try ends.append(e.tick);
    try std.testing.expectEqualSlices(u32, &.{ 960, 960, 1439, 1900 }, ends.items);
}

test "a last note one tick short of the item end is closed" {
    const alloc = std.testing.allocator;
    const notes = [_]helpers.Note{
        .{ .selected = false, .muted = false, .start_ppq = 0, .end_ppq = 1919, .chan = 0, .pitch = 60, .vel = 90 },
    };
    var events = try collectEvents(alloc, &notes, 0, 1920, 0);
    defer events.deinit();
    try std.testing.expectEqual(@as(u32, 1920), events.items[1].tick);
}

test "an item that starts inside a bar keeps the offset of its notes in the bar" {
    const alloc = std.testing.allocator;
    const notes = [_]helpers.Note{
        .{ .selected = false, .muted = false, .start_ppq = 1920, .end_ppq = 2400, .chan = 0, .pitch = 60, .vel = 90 },
    };
    // The item starts at tick 1920, one half note after its bar line at 0.
    var events = try collectEvents(alloc, &notes, 1920, 9999, 0);
    defer events.deinit();
    try std.testing.expectEqual(@as(u32, 1920), events.items[0].tick);
    try std.testing.expectEqual(@as(u32, 2400), events.items[1].tick);
}

test "each conversion gets its own file name" {
    var a: [64]u8 = undefined;
    var b: [64]u8 = undefined;
    const first = conversionFileName(&a, 1760000000000).?;
    const second = conversionFileName(&b, 1760000000001).?;
    try std.testing.expectEqualStrings("items_1760000000000.abc", first);
    try std.testing.expect(!std.mem.eql(u8, first, second));
}

test "a meter change inside the item is written as a second signature event" {
    const alloc = std.testing.allocator;
    // Two notes, one in each bar.
    const events = [_]Event{
        .{ .tick = 0, .is_on = true, .channel = 0, .pitch = 60, .velocity = 96 },
        .{ .tick = 480, .is_on = false, .channel = 0, .pitch = 60, .velocity = 0 },
        .{ .tick = 3840, .is_on = true, .channel = 0, .pitch = 62, .velocity = 96 },
        .{ .tick = 4320, .is_on = false, .channel = 0, .pitch = 62, .velocity = 0 },
    };
    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();
    try writeSmf(out.writer(), alloc, .{
        .ticks_per_qn = 960,
        .bpm = 120,
        .sigs = &.{
            .{ .tick = 0, .numerator = 4, .denominator = 4 },
            .{ .tick = 3840, .numerator = 3, .denominator = 4 },
        },
    }, &events);

    // Both signature meta events are present: 4/4 (denominator power 2)
    // and then 3/4 at the change.
    const four_four = [_]u8{ 0xFF, 0x58, 0x04, 4, 2, 24, 8 };
    const three_four = [_]u8{ 0xFF, 0x58, 0x04, 3, 2, 24, 8 };
    try std.testing.expect(std.mem.indexOf(u8, out.items, &four_four) != null);
    const at = std.mem.indexOf(u8, out.items, &three_four);
    try std.testing.expect(at != null);
    // And the second one comes after the first note, not bunched at the top.
    try std.testing.expect(at.? > std.mem.indexOf(u8, out.items, &four_four).?);
}

test "a signature past the last note is still written, for the trailing bars" {
    const alloc = std.testing.allocator;
    const events = [_]Event{
        .{ .tick = 0, .is_on = true, .channel = 0, .pitch = 60, .velocity = 96 },
        .{ .tick = 480, .is_on = false, .channel = 0, .pitch = 60, .velocity = 0 },
    };
    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();
    try writeSmf(out.writer(), alloc, .{
        .ticks_per_qn = 960,
        .bpm = 120,
        .sigs = &.{
            .{ .tick = 0, .numerator = 4, .denominator = 4 },
            .{ .tick = 3840, .numerator = 7, .denominator = 8 },
        },
    }, &events);

    const seven_eight = [_]u8{ 0xFF, 0x58, 0x04, 7, 3, 24, 8 };
    try std.testing.expect(std.mem.indexOf(u8, out.items, &seven_eight) != null);
}
