//! The engine that talks to the keyboard from the audio thread.
//!
//! Every call into `Engine` happens inside the plugin's process callback, so
//! nothing here allocates, blocks or waits. The user interface reaches it
//! through `Shared`: atomic arrays for the values it displays and edits, and
//! queues for commands and parameter changes.
//!
//! What the engine keeps:
//!
//! - `desired`, in `Shared`: the state the project wants the keyboard to have.
//!   A knob moves one byte of it, a preset replaces all of it, and a change
//!   made on the keyboard's panel follows into it.
//! - `mirror`: what the keyboard last told us it holds, from reads, from its
//!   own change messages and from our writes. Because a recall only writes
//!   what differs between `desired` and `mirror`, a recall takes about 0.15
//!   seconds when the mirror is known, and about 3 seconds when it is not.
//!
//! The unit's buffer overflows when messages come back to back, so the engine
//! spaces its messages by `gap_ms` and spreads them over the process blocks.
const std = @import("std");
const roland = @import("roland.zig");
const dump = @import("dump.zig");
const catalog = @import("catalog.zig");
const Spsc = @import("spsc.zig").Spsc;

const Atomic = std.atomic.Value;

pub const param_count = catalog.params.len;

/// Seconds between two messages. 0 overflows the unit's buffer, 1 to 20 ms
/// all worked.
pub const gap_seconds = 0.002;
/// The unit stays silent for a moment after a Registration recall, so a read
/// that gets no reply is sent again after this long.
pub const reply_timeout_seconds = 0.5;
pub const max_read_tries = 5;
/// How long the engine waits for an Identity Reply before it writes the
/// restored patch blindly, and how often it asks again after that.
pub const identity_timeout_seconds = 3.0;
pub const identity_retry_seconds = 3.0;

/// A parameter's id is a hash of its catalog name, so that reordering the
/// catalog never changes the ids the host saved in automation.
pub fn hashId(name: []const u8) u32 {
    var h: u32 = 2166136261;
    for (name) |c| {
        h ^= c;
        h *%= 16777619;
    }
    return h;
}

pub const param_ids = blk: {
    @setEvalBranchQuota(100_000);
    var ids: [param_count]u32 = undefined;
    for (catalog.params, 0..) |p, i| ids[i] = hashId(p.id);
    break :blk ids;
};

pub fn paramIndexOfId(id: u32) ?usize {
    for (param_ids, 0..) |pid, i| {
        if (pid == id) return i;
    }
    return null;
}

/// The index of the DT1 parameter at a keyboard-part address.
pub fn paramIndexOfAddress(address: u32) ?usize {
    for (catalog.params, 0..) |p, i| {
        if (p.kind == .dt1 and p.address == address) return i;
    }
    return null;
}

comptime {
    @setEvalBranchQuota(100_000);
    // A parameter inside a group that the unit only accepts as a whole (the
    // reverb type and level) is written with its group, see `nextMessage`.
    for (catalog.params) |p| {
        if (p.kind != .dt1) continue;
        _ = dump.locate(.kb, p.address) orelse @compileError("parameter outside the block table: " ++ p.id);
    }
    // The host identifies parameters by id, so two names must not collide.
    for (param_ids, 0..) |a, i| {
        for (param_ids[i + 1 ..]) |b| {
            if (a == b) @compileError("parameter id collision");
        }
    }
}

pub const Command = enum(u8) {
    /// Read every block into the mirror.
    read_all,
    /// Write what differs between the desired state and the mirror.
    recall,
    /// Make the mirror (what the keyboard last said) the desired state.
    capture,
    /// Read the keyboard, then make its state the desired state, so that the
    /// project holds the patch the keyboard has now.
    capture_keyboard,
    /// Look for the keyboard again, and read it if it answers.
    reconnect,
    /// Drop the pending writes and stop reading.
    cancel,
};

/// A parameter change made in the user interface.
pub const UiChange = struct {
    index: u16,
    value: u8,
};

pub const JobKind = enum(u8) { idle, reading, writing };

pub const midi_log_capacity = 8;

pub const MidiRecord = struct {
    flags: u16,
    port: u16,
    status: u8,
    d1: u8,
    d2: u8,
    time: u8,
};

/// The first bytes of one message, written once by the audio thread.
pub const Trace = struct {
    pub const capacity = 24;
    bytes: [capacity]Atomic(u8) = [_]Atomic(u8){Atomic(u8).init(0)} ** capacity,
    /// Zero until a message was captured; the total length of the message in
    /// its low bits, so that the reader knows how much of it it holds.
    length: Atomic(u32) = Atomic(u32).init(0),

    pub fn capture(self: *Trace, message: []const u8) void {
        if (self.length.load(.monotonic) != 0 or message.len == 0) return;
        const n = @min(message.len, capacity);
        for (message[0..n], 0..) |b, i| self.bytes[i].store(b, .monotonic);
        self.length.store(@intCast(message.len), .release);
    }

    /// Formats the captured bytes as hexadecimal text.
    pub fn format(self: *const Trace, buf: []u8) []const u8 {
        const total = self.length.load(.acquire);
        if (total == 0) return "none yet";
        var n: usize = 0;
        const shown = @min(total, capacity);
        for (0..shown) |i| {
            const written = std.fmt.bufPrint(buf[n..], "{x:0>2} ", .{self.bytes[i].load(.monotonic)}) catch break;
            n += written.len;
        }
        if (total > capacity) {
            const more = std.fmt.bufPrint(buf[n..], "... ({d} bytes)", .{total}) catch "";
            n += more.len;
        }
        return buf[0..n];
    }
};

pub const Shared = struct {
    desired: [dump.total_bytes]Atomic(u8) = [_]Atomic(u8){Atomic(u8).init(0)} ** dump.total_bytes,
    desired_known: [dump.total_bytes]Atomic(bool) = [_]Atomic(bool){Atomic(bool).init(false)} ** dump.total_bytes,
    /// The last value sent for each control change parameter. A CC changes no
    /// stored parameter, so it lives only here.
    cc_values: [param_count]Atomic(u8) = [_]Atomic(u8){Atomic(u8).init(0)} ** param_count,

    /// The user interface bumps this after it replaces `desired`, and the
    /// engine then recalls the new state.
    scene_gen: Atomic(u32) = Atomic(u32).init(0),
    /// Set when the project restored `desired`; the engine recalls it once the
    /// keyboard has answered.
    restored: Atomic(bool) = Atomic(bool).init(false),
    follow_panel: Atomic(bool) = Atomic(bool).init(true),
    recall_on_load: Atomic(bool) = Atomic(bool).init(true),

    /// How many reads started by `capture_keyboard` have finished, and whether the last one was answered
    /// by the keyboard. A caller that wants the keyboard's state counts the reads before it asks, and
    /// waits for the count to move.
    captures_done: Atomic(u32) = Atomic(u32).init(0),
    capture_answered: Atomic(bool) = Atomic(bool).init(false),

    commands: Spsc(Command, 16) = .{},
    ui_changes: Spsc(UiChange, 256) = .{},

    // What the user interface displays.
    connected: Atomic(bool) = Atomic(bool).init(false),
    mode: Atomic(u8) = Atomic(u8).init(@intFromEnum(roland.MidiInMode.unknown)),
    job: Atomic(u8) = Atomic(u8).init(@intFromEnum(JobKind.idle)),
    progress_done: Atomic(u32) = Atomic(u32).init(0),
    progress_total: Atomic(u32) = Atomic(u32).init(0),
    pending_writes: Atomic(u32) = Atomic(u32).init(0),
    tx_count: Atomic(u32) = Atomic(u32).init(0),
    rx_count: Atomic(u32) = Atomic(u32).init(0),
    bad_count: Atomic(u32) = Atomic(u32).init(0),
    blocks_failed: Atomic(u32) = Atomic(u32).init(0),
    mirror_known: Atomic(u32) = Atomic(u32).init(0),

    // What passes between the plugin and the host, to tell the user whether
    // the host delivers and accepts SysEx at all.
    host_sysex_in: Atomic(u32) = Atomic(u32).init(0),
    host_sysex_out: Atomic(u32) = Atomic(u32).init(0),
    host_sysex_refused: Atomic(u32) = Atomic(u32).init(0),
    /// Channel messages that were not passed on, for the interface to say so.
    midi_dropped: Atomic(u32) = Atomic(u32).init(0),
    /// The first bytes of the first SysEx message received from the host and
    /// sent to it, for the log and the MIDI tab.
    trace_in: Trace = .{},
    trace_out: Trace = .{},
    /// The last MIDI events the host delivered, packed in one word each:
    /// flags (16 bits), port (16), status, two data bytes, and the low byte of
    /// the time offset. They show the user, and the log, what the host sends.
    midi_log: [midi_log_capacity]Atomic(u64) = [_]Atomic(u64){Atomic(u64).init(0)} ** midi_log_capacity,
    midi_log_count: Atomic(u32) = Atomic(u32).init(0),

    pub fn setDesired(self: *Shared, kind: roland.Kind, address: u32, value: u8) bool {
        const slot = dump.locate(kind, address) orelse return false;
        self.desired[slot.index()].store(value, .monotonic);
        self.desired_known[slot.index()].store(true, .release);
        return true;
    }

    pub fn getDesired(self: *const Shared, kind: roland.Kind, address: u32) ?u8 {
        const slot = dump.locate(kind, address) orelse return null;
        if (!self.desired_known[slot.index()].load(.acquire)) return null;
        return self.desired[slot.index()].load(.monotonic);
    }

    /// The raw value of a parameter, or its lowest value when nothing is known.
    pub fn paramValue(self: *const Shared, index: usize) u8 {
        const p = catalog.params[index];
        return switch (p.kind) {
            .dt1 => self.getDesired(.kb, p.address) orelse p.low,
            .cc => self.cc_values[index].load(.monotonic),
        };
    }

    pub fn desiredSnapshot(self: *const Shared, out: *dump.Dump) void {
        for (0..dump.total_bytes) |i| {
            out.known[i] = self.desired_known[i].load(.acquire);
            out.values[i] = self.desired[i].load(.monotonic);
        }
    }

    /// Replaces the desired state. The caller then bumps `scene_gen` when it
    /// wants the keyboard to follow.
    pub fn loadDesired(self: *Shared, from: *const dump.Dump) void {
        for (0..dump.total_bytes) |i| {
            self.desired[i].store(from.values[i], .monotonic);
            self.desired_known[i].store(from.known[i], .release);
        }
    }

    /// Writes the bytes that `from` knows into the desired state, and leaves every other byte as it was. The
    /// caller then bumps `scene_gen`, as it does after `loadDesired`.
    pub fn mergeDesired(self: *Shared, from: *const dump.Dump) void {
        for (0..dump.total_bytes) |i| {
            if (!from.known[i]) continue;
            self.desired[i].store(from.values[i], .monotonic);
            self.desired_known[i].store(true, .release);
        }
    }

    pub fn desiredKnownCount(self: *const Shared) usize {
        var n: usize = 0;
        for (&self.desired_known) |*k| {
            if (k.load(.acquire)) n += 1;
        }
        return n;
    }

    pub fn recordMidi(self: *Shared, record: MidiRecord) void {
        const word: u64 = @as(u64, record.flags) | @as(u64, record.port) << 16 | @as(u64, record.status) << 32 |
            @as(u64, record.d1) << 40 | @as(u64, record.d2) << 48 | @as(u64, record.time) << 56;
        const n = self.midi_log_count.load(.monotonic);
        self.midi_log[n % midi_log_capacity].store(word, .monotonic);
        self.midi_log_count.store(n +% 1, .release);
    }

    /// The `n`th event ever recorded, if it is still in the log.
    pub fn midiRecord(self: *const Shared, n: u32) ?MidiRecord {
        const count = self.midi_log_count.load(.acquire);
        if (n >= count or count - n > midi_log_capacity) return null;
        const word = self.midi_log[n % midi_log_capacity].load(.monotonic);
        return .{
            .flags = @truncate(word),
            .port = @truncate(word >> 16),
            .status = @truncate(word >> 32),
            .d1 = @truncate(word >> 40),
            .d2 = @truncate(word >> 48),
            .time = @truncate(word >> 56),
        };
    }

    pub fn sendCommand(self: *Shared, command: Command) bool {
        return self.commands.push(command);
    }

    pub fn changeParam(self: *Shared, index: usize, value: u8) bool {
        return self.ui_changes.push(.{ .index = @intCast(index), .value = value });
    }
};

/// What the engine writes its output to: the plugin's output events in the
/// host, or a recorder in the tests. Every call carries the offset in samples
/// from the start of the block.
pub const Sink = struct {
    ctx: *anyopaque,
    /// A complete SysEx message, F0 and F7 included. False when the host
    /// refused it, in which case the engine tries again in the next block.
    sysex: *const fn (ctx: *anyopaque, time: u32, bytes: []const u8) bool,
    /// A three-byte channel message.
    midi: *const fn (ctx: *anyopaque, time: u32, status: u8, d1: u8, d2: u8) bool,
    /// A parameter whose value changed on the keyboard or in the user
    /// interface, for the host to display and record. `gesture` is true for a
    /// change made with the interface's own controls, which the host should
    /// record as a touch of the knob.
    param: *const fn (ctx: *anyopaque, time: u32, index: u32, value: u8, gesture: bool) void,
};

const AutoStep = enum { start, waiting_identity, searching, syncing, done };

const ReadThen = enum {
    /// Only refresh the mirror (and adopt it when nothing is desired yet).
    nothing,
    /// The start-up flow: adopt the keyboard when nothing is desired,
    /// otherwise recall the desired state.
    auto,
    /// Recall once the mirror is known.
    recall,
    /// Make the keyboard's state the desired one once it has been read.
    capture,
};

pub const Engine = struct {
    shared: *Shared,
    sample_rate: f64 = 48000,
    /// The number of samples processed since the engine was created.
    now: u64 = 0,
    next_send: u64 = 0,
    gap: u64 = 96,

    mirror: dump.Dump = .{},
    dirty: [param_count]bool = [_]bool{false} ** param_count,

    job: JobKind = .idle,
    auto: AutoStep = .start,
    auto_deadline: u64 = 0,
    identify_pending: bool = false,

    // The read job.
    read_block: usize = 0,
    read_tries: u8 = 0,
    read_deadline: u64 = 0,
    read_request_pending: bool = false,
    read_seen: [dump.total_bytes]bool = [_]bool{false} ** dump.total_bytes,
    read_then: ReadThen = .nothing,
    read_any_answer: bool = false,

    // The write job.
    ops: [dump.max_writes]dump.WriteOp = undefined,
    op_len: usize = 0,
    op_idx: usize = 0,

    applied_gen: u32 = 0,
    tx: [roland.max_message]u8 = undefined,

    // A notification raised outside a block waits here until `run` can hand
    // it to the sink.
    notify_list: [param_count]u8 = [_]u8{0} ** param_count,
    notify_pending: [param_count]bool = [_]bool{false} ** param_count,
    notify_gesture: [param_count]bool = [_]bool{false} ** param_count,

    // What `nextMessage` built, which `afterSend` needs once the host took it.
    sent_kind: Sent = .none,
    sent_index: usize = 0,
    /// The group that the parameter message just sent wrote: its address, its
    /// length (1 for most parameters) and its bytes.
    sent_group_address: u32 = 0,
    sent_group_len: usize = 1,
    sent_group_data: [3]u8 = .{ 0, 0, 0 },

    const Sent = enum { none, identity, rq1, dt1_param, dt1_op };

    pub fn init(shared: *Shared, sample_rate: f64) Engine {
        var e = Engine{ .shared = shared };
        e.setSampleRate(sample_rate);
        e.applied_gen = shared.scene_gen.load(.acquire);
        return e;
    }

    pub fn setSampleRate(self: *Engine, sample_rate: f64) void {
        self.sample_rate = sample_rate;
        self.gap = @max(1, @as(u64, @intFromFloat(@ceil(gap_seconds * sample_rate))));
    }

    pub fn seconds(self: *const Engine, s: f64) u64 {
        return @intFromFloat(s * self.sample_rate);
    }

    // ---- input from the host ----

    /// A SysEx message that arrived from the keyboard.
    pub fn onSysex(self: *Engine, bytes: []const u8) void {
        if (roland.identityMode(bytes)) |mode| {
            self.shared.rx_count.store(self.shared.rx_count.load(.monotonic) +% 1, .monotonic);
            self.shared.mode.store(@intFromEnum(mode), .monotonic);
            self.shared.connected.store(true, .release);
            return;
        }
        const dt1 = roland.parseDt1(bytes) catch |err| {
            // Other makers' messages are not ours to count.
            if (err == error.BadChecksum) self.shared.bad_count.store(self.shared.bad_count.load(.monotonic) +% 1, .monotonic);
            return;
        };
        self.shared.rx_count.store(self.shared.rx_count.load(.monotonic) +% 1, .monotonic);
        self.shared.connected.store(true, .release);
        self.onDt1(&dt1);
    }

    pub fn onDt1(self: *Engine, msg: *const roland.Dt1) void {
        const reading = self.job == .reading;
        for (msg.bytes(), 0..) |value, i| {
            const address = msg.address + @as(u32, @intCast(i));
            const slot = dump.locate(msg.kind, address) orelse continue;
            const idx = slot.index();
            self.mirror.values[idx] = value;
            self.mirror.known[idx] = true;
            if (reading) {
                self.read_seen[idx] = true;
                self.read_any_answer = true;
                continue;
            }
            self.followPanel(msg.kind, address, value);
        }
    }

    /// A change on the keyboard's panel moves the desired state with it, so
    /// that the knobs show what the keyboard does and a later recall does not
    /// undo the change.
    pub fn followPanel(self: *Engine, kind: roland.Kind, address: u32, value: u8) void {
        if (!self.shared.follow_panel.load(.monotonic)) return;
        const current = self.shared.getDesired(kind, address);
        if (current != null and current.? == value) return;
        const param = if (kind == .kb) paramIndexOfAddress(address) else null;
        // The user is moving this control right now; its own write wins.
        if (param) |pi| {
            if (self.dirty[pi]) return;
        }
        if (self.shared.desiredKnownCount() == 0) return;
        _ = self.shared.setDesired(kind, address, value);
        if (param) |pi| self.notify(pi, value, false);
    }

    pub fn notify(self: *Engine, index: usize, value: u8, gesture: bool) void {
        self.notify_list[index] = value;
        self.notify_pending[index] = true;
        self.notify_gesture[index] = gesture;
    }

    /// A parameter value that the host sent (automation, or its own generic
    /// editor). The host already knows the value, so there is no notification.
    pub fn onHostParam(self: *Engine, index: usize, raw: f64, sink: Sink, time: u32) void {
        if (index >= param_count) return;
        const p = catalog.params[index];
        const value = clampValue(p, raw);
        self.applyParam(index, value, sink, time);
    }

    pub fn applyParam(self: *Engine, index: usize, value: u8, sink: Sink, time: u32) void {
        const p = catalog.params[index];
        switch (p.kind) {
            .dt1 => {
                const current = self.shared.getDesired(.kb, p.address);
                if (current != null and current.? == value) return;
                _ = self.shared.setDesired(.kb, p.address, value);
                self.dirty[index] = true;
            },
            .cc => {
                self.shared.cc_values[index].store(value, .monotonic);
                _ = sink.midi(sink.ctx, time, 0xB0 | (p.channel - 1), p.cc, value);
            },
        }
    }

    // ---- the block ----

    /// Runs the engine for one block of `frames` samples.
    pub fn run(self: *Engine, frames: u32, sink: Sink) void {
        self.drainCommands();
        self.drainUiChanges(sink);
        self.checkScene();
        self.driveAuto();
        self.checkRead();

        const block_start = self.now;
        const block_end = block_start + frames;
        while (self.next_send < block_end) {
            const msg = self.nextMessage() orelse break;
            const offset: u32 = if (self.next_send > block_start) @intCast(self.next_send - block_start) else 0;
            if (!sink.sysex(sink.ctx, offset, msg)) {
                self.unsend();
                break;
            }
            self.afterSend(block_start + offset);
            self.next_send = block_start + offset + self.gap;
        }
        self.flushNotifications(sink);
        self.now = block_end;
        self.publish();
    }

    pub fn flushNotifications(self: *Engine, sink: Sink) void {
        for (0..param_count) |i| {
            if (!self.notify_pending[i]) continue;
            self.notify_pending[i] = false;
            sink.param(sink.ctx, 0, @intCast(i), self.notify_list[i], self.notify_gesture[i]);
        }
    }

    pub fn drainCommands(self: *Engine) void {
        while (self.shared.commands.pop()) |command| {
            switch (command) {
                .read_all => self.startRead(.nothing),
                .recall => self.recallNow(),
                .capture => self.capture(),
                .capture_keyboard => self.startRead(.capture),
                .reconnect => {
                    self.auto = .start;
                    self.shared.connected.store(false, .release);
                },
                .cancel => {
                    self.job = .idle;
                    self.op_len = 0;
                    self.op_idx = 0;
                },
            }
        }
    }

    pub fn drainUiChanges(self: *Engine, sink: Sink) void {
        while (self.shared.ui_changes.pop()) |change| {
            const index: usize = change.index;
            if (index >= param_count) continue;
            const p = catalog.params[index];
            const value = std.math.clamp(change.value, p.low, p.high);
            self.applyParam(index, value, sink, 0);
            self.notify(index, value, true);
        }
    }

    pub fn checkScene(self: *Engine) void {
        const gen = self.shared.scene_gen.load(.acquire);
        if (gen == self.applied_gen) return;
        self.applied_gen = gen;
        self.recallNow();
    }

    /// The start-up flow: ask the keyboard who it is, read it when it
    /// answers, and then adopt or recall. If it does not answer, the restored
    /// patch is written blindly once, because writes may work where reads do
    /// not, and the question is asked again every few seconds, because the
    /// keyboard may be plugged in or routed later.
    pub fn driveAuto(self: *Engine) void {
        switch (self.auto) {
            .start => {
                self.identify_pending = true;
                self.auto_deadline = self.now + self.seconds(identity_timeout_seconds);
                self.auto = .waiting_identity;
            },
            .waiting_identity => {
                if (self.keyboardAnswered()) {
                    self.beginSync();
                } else if (self.now >= self.auto_deadline) {
                    // The patch stays pending: when the keyboard does answer,
                    // the sync recalls whatever differs from what it holds.
                    if (self.shared.restored.load(.acquire) and self.shared.recall_on_load.load(.monotonic)) self.recallNow();
                    self.auto_deadline = self.now + self.seconds(identity_retry_seconds);
                    self.identify_pending = true;
                    self.auto = .searching;
                }
            },
            .searching => {
                if (self.keyboardAnswered()) {
                    self.beginSync();
                } else if (self.now >= self.auto_deadline) {
                    self.identify_pending = true;
                    self.auto_deadline = self.now + self.seconds(identity_retry_seconds);
                }
            },
            .syncing, .done => {},
        }
    }

    pub fn keyboardAnswered(self: *const Engine) bool {
        return self.shared.connected.load(.acquire);
    }

    pub fn beginSync(self: *Engine) void {
        const mode: roland.MidiInMode = @enumFromInt(self.shared.mode.load(.monotonic));
        if (mode == .mode1) {
            self.auto = .done;
            return;
        }
        self.startRead(.auto);
        self.auto = .syncing;
    }

    // ---- reading ----

    pub fn startRead(self: *Engine, then: ReadThen) void {
        self.job = .reading;
        self.read_then = then;
        self.read_block = 0;
        self.read_tries = 0;
        self.read_any_answer = false;
        self.shared.blocks_failed.store(0, .monotonic);
        self.beginBlock();
    }

    pub fn beginBlock(self: *Engine) void {
        @memset(self.read_seen[dump.block_offsets[self.read_block]..dump.block_offsets[self.read_block + 1]], false);
        self.read_request_pending = true;
        self.read_tries = 0;
    }

    pub fn blockComplete(self: *const Engine) bool {
        const seen = self.read_seen[dump.block_offsets[self.read_block]..dump.block_offsets[self.read_block + 1]];
        for (seen) |s| {
            if (!s) return false;
        }
        return true;
    }

    pub fn checkRead(self: *Engine) void {
        if (self.job != .reading) return;
        if (self.blockComplete()) {
            self.advanceBlock();
            return;
        }
        if (!self.read_request_pending and self.now >= self.read_deadline) {
            self.read_tries += 1;
            if (self.read_tries >= max_read_tries) {
                self.shared.blocks_failed.store(self.shared.blocks_failed.load(.monotonic) + 1, .monotonic);
                self.advanceBlock();
            } else {
                self.read_request_pending = true;
            }
        }
    }

    pub fn advanceBlock(self: *Engine) void {
        self.read_block += 1;
        if (self.read_block >= dump.block_count) {
            self.finishRead();
        } else {
            self.beginBlock();
        }
    }

    pub fn finishRead(self: *Engine) void {
        self.job = .idle;
        const answered = self.read_any_answer;
        // The first answer proves the keyboard is there; none after five tries
        // of every block means it is not reading us.
        if (!answered) self.shared.connected.store(false, .release);
        const then = self.read_then;
        self.read_then = .nothing;
        const desired_empty = self.shared.desiredKnownCount() == 0;
        switch (then) {
            .nothing => {
                if (answered and desired_empty) self.capture();
            },
            .auto => {
                const restore = self.shared.restored.load(.acquire);
                self.shared.restored.store(false, .release);
                if (!desired_empty and restore and self.shared.recall_on_load.load(.monotonic)) {
                    self.recallNow();
                } else if (answered and desired_empty) {
                    self.capture();
                }
            },
            .recall => self.recallNow(),
            .capture => {
                if (answered) self.capture();
                self.shared.capture_answered.store(answered, .monotonic);
                _ = self.shared.captures_done.fetchAdd(1, .release);
            },
        }
        self.auto = .done;
    }

    // ---- writing ----

    /// Computes what differs between the desired state and the mirror, and
    /// queues it for sending.
    pub fn recallNow(self: *Engine) void {
        var desired: dump.Dump = undefined;
        self.shared.desiredSnapshot(&desired);
        if (desired.knownCount() == 0) return;
        self.op_len = dump.diff(&desired, &self.mirror, .mapped_only, &self.ops);
        self.op_idx = 0;
        self.job = if (self.op_len > 0) .writing else .idle;
    }

    /// Makes the mirror (the keyboard's state) the desired state, and tells
    /// the host the new parameter values.
    pub fn capture(self: *Engine) void {
        for (0..dump.total_bytes) |i| {
            if (!self.mirror.known[i]) continue;
            self.shared.desired[i].store(self.mirror.values[i], .monotonic);
            self.shared.desired_known[i].store(true, .release);
        }
        for (catalog.params, 0..) |p, i| {
            if (p.kind != .dt1) continue;
            if (self.mirror.get(.kb, p.address)) |v| self.notify(i, v, false);
        }
    }

    // ---- the next message ----

    /// Builds the next message into `tx` and returns it, without marking it
    /// as sent; `afterSend` does that once the host has taken it.
    pub fn nextMessage(self: *Engine) ?[]const u8 {
        if (self.identify_pending) {
            @memcpy(self.tx[0..roland.identity_request.len], &roland.identity_request);
            self.sent_kind = .identity;
            return self.tx[0..roland.identity_request.len];
        }
        if (self.job == .reading and self.read_request_pending) {
            const b = dump.blocks[self.read_block];
            const n = roland.encodeRq1(&self.tx, b.kind, b.start, b.size) catch return null;
            self.sent_kind = .rq1;
            return self.tx[0..n];
        }
        for (0..param_count) |i| {
            if (!self.dirty[i]) continue;
            const p = catalog.params[i];
            if (p.kind != .dt1) continue;
            // The unit takes some parameters only together with their
            // neighbours, so the whole group is sent, from the desired state.
            const slot = dump.locate(.kb, p.address) orelse {
                self.dirty[i] = false;
                continue;
            };
            const group = dump.groupOf(slot.block, slot.offset);
            const start = p.address - @as(u32, @intCast(slot.offset)) + @as(u32, @intCast(group.start));
            var data: [3]u8 = .{ 0, 0, 0 };
            var known = true;
            for (0..group.len) |k| {
                if (self.shared.getDesired(.kb, start + @as(u32, @intCast(k)))) |v| {
                    data[k] = v;
                } else known = false;
            }
            if (!known) {
                self.dirty[i] = false;
                continue;
            }
            const n = roland.encodeDt1(&self.tx, .kb, start, data[0..group.len]) catch return null;
            self.sent_kind = .dt1_param;
            self.sent_index = i;
            self.sent_group_address = start;
            self.sent_group_len = group.len;
            self.sent_group_data = data;
            return self.tx[0..n];
        }
        if (self.job == .writing and self.op_idx < self.op_len) {
            const op = &self.ops[self.op_idx];
            const n = roland.encodeDt1(&self.tx, op.kind, op.address, op.bytes()) catch return null;
            self.sent_kind = .dt1_op;
            return self.tx[0..n];
        }
        return null;
    }

    pub fn unsend(self: *Engine) void {
        self.sent_kind = .none;
    }

    pub fn afterSend(self: *Engine, at: u64) void {
        self.shared.tx_count.store(self.shared.tx_count.load(.monotonic) +% 1, .monotonic);
        switch (self.sent_kind) {
            .none => {},
            .identity => self.identify_pending = false,
            .rq1 => {
                self.read_request_pending = false;
                self.read_deadline = at + self.seconds(reply_timeout_seconds);
            },
            .dt1_param => {
                // Every parameter of the group is now written.
                for (0..self.sent_group_len) |k| {
                    const address = self.sent_group_address + @as(u32, @intCast(k));
                    _ = self.mirror.set(.kb, address, self.sent_group_data[k]);
                    if (paramIndexOfAddress(address)) |pi| self.dirty[pi] = false;
                }
                self.dirty[self.sent_index] = false;
            },
            .dt1_op => {
                const op = &self.ops[self.op_idx];
                for (op.bytes(), 0..) |v, i| _ = self.mirror.set(op.kind, op.address + @as(u32, @intCast(i)), v);
                self.op_idx += 1;
                if (self.op_idx >= self.op_len) {
                    self.job = .idle;
                    self.op_len = 0;
                    self.op_idx = 0;
                }
            },
        }
        self.sent_kind = .none;
    }

    pub fn publish(self: *Engine) void {
        const s = self.shared;
        s.job.store(@intFromEnum(self.job), .monotonic);
        switch (self.job) {
            .reading => {
                s.progress_done.store(@intCast(self.read_block), .monotonic);
                s.progress_total.store(dump.block_count, .monotonic);
            },
            .writing => {
                s.progress_done.store(@intCast(self.op_idx), .monotonic);
                s.progress_total.store(@intCast(self.op_len), .monotonic);
            },
            .idle => {},
        }
        s.pending_writes.store(@intCast(if (self.job == .writing) self.op_len - self.op_idx else 0), .monotonic);
        s.mirror_known.store(@intCast(self.mirror.knownCount()), .monotonic);
    }
};

pub fn clampValue(p: catalog.Param, raw: f64) u8 {
    const rounded = @round(raw);
    const clamped = std.math.clamp(rounded, @as(f64, @floatFromInt(p.low)), @as(f64, @floatFromInt(p.high)));
    return @intFromFloat(clamped);
}

// ---- tests ----

/// A pretend keyboard: it answers RQ1 from `state` and applies DT1 to it.
const FakeKeyboard = struct {
    state: dump.Dump,
    answers: bool = true,
    writes: usize = 0,
    reads: usize = 0,
    identity_requests: usize = 0,
    /// Messages the keyboard wants to send to the engine in the next block.
    outbox: std.ArrayList([]u8),
    last_write_time: u64 = 0,
    min_gap: u64 = std.math.maxInt(u64),

    pub fn init(allocator: std.mem.Allocator) FakeKeyboard {
        return .{ .state = .{}, .outbox = std.ArrayList([]u8).init(allocator) };
    }

    pub fn deinit(self: *FakeKeyboard) void {
        for (self.outbox.items) |m| self.outbox.allocator.free(m);
        self.outbox.deinit();
    }

    pub fn receive(self: *FakeKeyboard, bytes: []const u8, at: u64) !void {
        if (std.mem.eql(u8, bytes, &roland.identity_request)) {
            self.identity_requests += 1;
            if (!self.answers) return;
            const reply = [_]u8{ 0xF0, 0x7E, 0x10, 0x06, 0x02, 0x41, 0x62, 0x00, 0x00, 0x06, 0x00, 0x01, 0x00, 0x00, 0xF7 };
            try self.outbox.append(try self.outbox.allocator.dupe(u8, &reply));
            return;
        }
        const body = roland.stripFraming(bytes);
        // 41 10 <model> <command> ...
        const kind: roland.Kind = if (body[2] == 0x62) .kb else .synth;
        const model_len = kind.model().len;
        const command = body[2 + model_len];
        const payload = body[3 + model_len .. body.len - 1];
        const addr_len = kind.addressLen();
        const address = roland.unpackSevenBit(payload[0..addr_len]);
        if (command == 0x12) {
            self.writes += 1;
            if (self.last_write_time != 0) self.min_gap = @min(self.min_gap, at - self.last_write_time);
            self.last_write_time = at;
            for (payload[addr_len..], 0..) |v, i| _ = self.state.set(kind, address + @as(u32, @intCast(i)), v);
        } else if (command == 0x11) {
            self.reads += 1;
            if (!self.answers) return;
            const size = roland.unpackSevenBit(payload[addr_len .. addr_len * 2]);
            var data: [roland.max_message]u8 = undefined;
            for (0..size) |i| data[i] = self.state.get(kind, address + @as(u32, @intCast(i))) orelse 0;
            var out: [roland.max_message]u8 = undefined;
            const n = try roland.encodeDt1(&out, kind, address, data[0..size]);
            try self.outbox.append(try self.outbox.allocator.dupe(u8, out[0..n]));
        }
    }
};

const ParamSeen = struct { index: u32, value: u8 };

const Harness = struct {
    shared: *Shared,
    engine: Engine,
    keyboard: FakeKeyboard,
    params_seen: std.ArrayList(ParamSeen),
    midi_seen: std.ArrayList([3]u8),
    block_start: u64 = 0,
    frames: u32 = 512,

    pub fn sinkSysex(ctx: *anyopaque, time: u32, bytes: []const u8) bool {
        const self: *Harness = @ptrCast(@alignCast(ctx));
        self.keyboard.receive(bytes, self.block_start + time) catch unreachable;
        return true;
    }

    pub fn sinkMidi(ctx: *anyopaque, time: u32, status: u8, d1: u8, d2: u8) bool {
        _ = time;
        const self: *Harness = @ptrCast(@alignCast(ctx));
        self.midi_seen.append(.{ status, d1, d2 }) catch unreachable;
        return true;
    }

    pub fn sinkParam(ctx: *anyopaque, time: u32, index: u32, value: u8, gesture: bool) void {
        _ = time;
        _ = gesture;
        const self: *Harness = @ptrCast(@alignCast(ctx));
        self.params_seen.append(.{ .index = index, .value = value }) catch unreachable;
    }

    pub fn sink(self: *Harness) Sink {
        return .{ .ctx = self, .sysex = sinkSysex, .midi = sinkMidi, .param = sinkParam };
    }

    pub fn step(self: *Harness) void {
        // The keyboard's answers to the last block reach the engine first.
        for (self.keyboard.outbox.items) |m| {
            self.engine.onSysex(m);
            self.keyboard.outbox.allocator.free(m);
        }
        self.keyboard.outbox.clearRetainingCapacity();
        self.engine.run(self.frames, self.sink());
        self.block_start += self.frames;
    }

    pub fn runSeconds(self: *Harness, s: f64) void {
        const blocks: usize = @intFromFloat(s * self.engine.sample_rate / @as(f64, @floatFromInt(self.frames)));
        for (0..blocks) |_| self.step();
    }
};

fn makeHarness(allocator: std.mem.Allocator, shared: *Shared) Harness {
    return .{
        .shared = shared,
        .engine = Engine.init(shared, 48000),
        .keyboard = FakeKeyboard.init(allocator),
        .params_seen = std.ArrayList(ParamSeen).init(allocator),
        .midi_seen = std.ArrayList([3]u8).init(allocator),
    };
}

fn fillKeyboard(d: *dump.Dump, seed: u8) void {
    for (dump.blocks, 0..) |b, bi| {
        for (0..b.size) |i| {
            d.known[dump.block_offsets[bi] + i] = true;
            d.values[dump.block_offsets[bi] + i] = @intCast((seed + i) % 90);
        }
    }
}

test "start-up reads the keyboard and adopts it when nothing is desired" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);

    h.runSeconds(2.0);
    try std.testing.expect(shared.connected.load(.acquire));
    try std.testing.expectEqual(roland.MidiInMode.mode2, @as(roland.MidiInMode, @enumFromInt(shared.mode.load(.monotonic))));
    try std.testing.expectEqual(@as(u32, dump.total_bytes), shared.mirror_known.load(.monotonic));
    try std.testing.expectEqual(@as(usize, dump.total_bytes), shared.desiredKnownCount());
    // The knobs show the keyboard's values.
    const idx = paramIndexOfAddress(catalog.params[0].address).?;
    try std.testing.expectEqual(h.keyboard.state.get(.kb, catalog.params[0].address).?, shared.paramValue(idx));
    try std.testing.expect(h.params_seen.items.len > 0);
}

test "a restored scene is recalled with only the groups that differ" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);

    var scene = h.keyboard.state;
    _ = scene.set(.kb, 0x02 << 14 | 0x00 << 7 | 0x05, 1); // a drawbar
    _ = scene.set(.kb, 0x01 << 14 | 0x03 << 7 | 0x02, 55); // a tone byte, so the triple is sent
    shared.loadDesired(&scene);
    shared.restored.store(true, .release);

    h.runSeconds(3.0);
    try std.testing.expectEqual(@as(usize, 2), h.keyboard.writes);
    try std.testing.expectEqual(scene.get(.kb, 0x02 << 14 | 0x05).?, h.keyboard.state.get(.kb, 0x02 << 14 | 0x05).?);
    try std.testing.expectEqual(@as(u8, 55), h.keyboard.state.get(.kb, 0x01 << 14 | 0x03 << 7 | 0x02).?);
    // The messages are at least the pacing gap apart.
    try std.testing.expect(h.keyboard.min_gap >= h.engine.gap);
}

test "a silent keyboard gets a blind recall of the restored scene" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    h.keyboard.answers = false;

    var scene = Dump0.make();
    shared.loadDesired(&scene);
    shared.restored.store(true, .release);
    h.runSeconds(12.0);
    try std.testing.expect(!shared.connected.load(.acquire));
    // Every mapped byte is written, except those the groups save.
    const expected = dump.diff(&scene, null, .mapped_only, &h.engine.ops);
    try std.testing.expectEqual(expected, h.keyboard.writes);
}

const Dump0 = struct {
    pub fn make() dump.Dump {
        var d = dump.Dump{};
        fillKeyboard(&d, 9);
        return d;
    }
};

test "turning a knob writes one byte and the panel can move it back" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.runSeconds(2.0);
    const writes_before = h.keyboard.writes;

    const drawbar = paramIndexOfId(hashId("organ-upper-d8")).?;
    h.engine.onHostParam(drawbar, 7, h.sink(), 0);
    h.runSeconds(0.1);
    try std.testing.expectEqual(writes_before + 1, h.keyboard.writes);
    try std.testing.expectEqual(@as(u8, 7), h.keyboard.state.get(.kb, catalog.params[drawbar].address).?);

    // The same value again writes nothing.
    h.engine.onHostParam(drawbar, 7, h.sink(), 0);
    h.runSeconds(0.1);
    try std.testing.expectEqual(writes_before + 1, h.keyboard.writes);

    // A change on the panel arrives as a DT1 and moves the knob.
    var msg: [32]u8 = undefined;
    const n = try roland.encodeDt1(&msg, .kb, catalog.params[drawbar].address, &.{2});
    h.params_seen.clearRetainingCapacity();
    h.engine.onSysex(msg[0..n]);
    h.runSeconds(0.05);
    try std.testing.expectEqual(@as(u8, 2), shared.paramValue(drawbar));
    try std.testing.expectEqual(@as(usize, 1), h.params_seen.items.len);
    try std.testing.expectEqual(@as(u32, @intCast(drawbar)), h.params_seen.items[0].index);
}

test "a control change parameter sends a CC and writes no SysEx" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.runSeconds(2.0);
    const writes_before = h.keyboard.writes;

    const cutoff = paramIndexOfId(hashId("cc-upper-cutoff")).?;
    h.engine.onHostParam(cutoff, 100, h.sink(), 0);
    h.runSeconds(0.1);
    try std.testing.expectEqual(writes_before, h.keyboard.writes);
    try std.testing.expectEqual(@as(usize, 1), h.midi_seen.items.len);
    try std.testing.expectEqual([3]u8{ 0xB3, 74, 100 }, h.midi_seen.items[0]);
    try std.testing.expectEqual(@as(u8, 100), shared.paramValue(cutoff));
}

test "the interface's knob move reaches the keyboard and the host" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.runSeconds(2.0);
    h.params_seen.clearRetainingCapacity();

    const drawbar = paramIndexOfId(hashId("organ-lower-d4")).?;
    try std.testing.expect(shared.changeParam(drawbar, 6));
    h.runSeconds(0.1);
    try std.testing.expectEqual(@as(u8, 6), h.keyboard.state.get(.kb, catalog.params[drawbar].address).?);
    try std.testing.expectEqual(@as(usize, 1), h.params_seen.items.len);
}

test "capturing the keyboard replaces what the project wanted" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.runSeconds(2.0);

    // The keyboard changes on its own and the project still wants the old state.
    _ = h.keyboard.state.set(.kb, 0x02 << 14 | 5, 1);
    try std.testing.expect(shared.getDesired(.kb, 0x02 << 14 | 5).? != 1);
    try std.testing.expect(shared.sendCommand(.capture_keyboard));
    h.runSeconds(2.0);
    try std.testing.expectEqual(@as(?u8, 1), shared.getDesired(.kb, 0x02 << 14 | 5));
}

test "a capture says when it is done, and whether the keyboard answered" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.runSeconds(2.0);

    // The start-up read is not a capture, so the count has not moved.
    try std.testing.expectEqual(@as(u32, 0), shared.captures_done.load(.acquire));
    _ = h.keyboard.state.set(.kb, 0x02 << 14 | 5, 1);
    try std.testing.expect(shared.sendCommand(.capture_keyboard));
    h.runSeconds(2.0);
    try std.testing.expectEqual(@as(u32, 1), shared.captures_done.load(.acquire));
    try std.testing.expect(shared.capture_answered.load(.monotonic));
    try std.testing.expectEqual(@as(?u8, 1), shared.getDesired(.kb, 0x02 << 14 | 5));

    // A keyboard that stops answering still ends the capture, and says so.
    h.keyboard.answers = false;
    _ = h.keyboard.state.set(.kb, 0x02 << 14 | 5, 2);
    try std.testing.expect(shared.sendCommand(.capture_keyboard));
    h.runSeconds(60.0);
    try std.testing.expectEqual(@as(u32, 2), shared.captures_done.load(.acquire));
    try std.testing.expect(!shared.capture_answered.load(.monotonic));
    // What the plugin knew is kept.
    try std.testing.expectEqual(@as(?u8, 1), shared.getDesired(.kb, 0x02 << 14 | 5));
}

test "a keyboard that shows up late is found, read and given the restored patch" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.keyboard.answers = false;

    var scene = h.keyboard.state;
    _ = scene.set(.kb, 0x02 << 14 | 0x00 << 7 | 0x05, 1);
    shared.loadDesired(&scene);
    shared.restored.store(true, .release);
    h.runSeconds(7.0);
    try std.testing.expect(!shared.connected.load(.acquire));
    // It asked at the start and again every three seconds.
    try std.testing.expect(h.keyboard.identity_requests >= 3);

    // The keyboard appears: the next question gets an answer.
    h.keyboard.answers = true;
    h.runSeconds(8.0);
    try std.testing.expect(shared.connected.load(.acquire));
    try std.testing.expectEqual(@as(u32, dump.total_bytes), shared.mirror_known.load(.monotonic));
    try std.testing.expectEqual(@as(u8, 1), h.keyboard.state.get(.kb, 0x02 << 14 | 0x05).?);
    try std.testing.expect(!shared.restored.load(.acquire));
}

test "loading a preset from the interface recalls it at once" {
    const allocator = std.testing.allocator;
    var shared = try allocator.create(Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var h = makeHarness(allocator, shared);
    defer h.keyboard.deinit();
    defer h.params_seen.deinit();
    defer h.midi_seen.deinit();
    fillKeyboard(&h.keyboard.state, 3);
    h.runSeconds(2.0);

    var preset: dump.Dump = undefined;
    shared.desiredSnapshot(&preset);
    _ = preset.set(.kb, 0x00 << 14 | 0x00 << 7 | 0x60, 11);
    shared.loadDesired(&preset);
    _ = shared.scene_gen.fetchAdd(1, .release);
    h.runSeconds(0.5);
    try std.testing.expectEqual(@as(u8, 11), h.keyboard.state.get(.kb, 0x60).?);
}

test "parameter ids are stable hashes and unique" {
    try std.testing.expectEqual(hashId("organ-upper-d16"), param_ids[0]);
    try std.testing.expect(paramIndexOfId(0) == null);
    try std.testing.expectEqual(@as(usize, 74), param_count);
}

/// What the panel shows for a value of a parameter: its name when the catalog
/// has names, else the number.
pub fn valueText(buf: []u8, p: catalog.Param, value: f64) ?[:0]const u8 {
    const v: i64 = @intFromFloat(@round(value));
    if (p.names.len > 0 and v >= p.low and v - p.low < @as(i64, @intCast(p.names.len))) {
        return std.fmt.bufPrintZ(buf, "{s}", .{p.names[@intCast(v - p.low)]}) catch null;
    }
    return std.fmt.bufPrintZ(buf, "{d}", .{v}) catch null;
}

test "every list of names covers the range of its parameter" {
    for (catalog.params) |p| {
        if (p.names.len == 0) continue;
        try std.testing.expectEqual(@as(usize, p.high) - p.low + 1, p.names.len);
    }
}

test "a type shows its name, a level its number" {
    var buf: [48]u8 = undefined;
    const reverb = catalog.params[paramIndexOfId(hashId("reverb-type")).?];
    try std.testing.expectEqualStrings("Plate", valueText(&buf, reverb, 5).?);
    try std.testing.expectEqualStrings("Spring", valueText(&buf, reverb, 7).?);
    const level = catalog.params[paramIndexOfId(hashId("reverb-level")).?];
    try std.testing.expectEqualStrings("90", valueText(&buf, level, 90).?);
    // A value outside the names falls back to the number.
    try std.testing.expectEqualStrings("12", valueText(&buf, reverb, 12).?);
}

test "the effects are catalogued at the addresses of the spec" {
    const expect = [_]struct { id: []const u8, address: u32 }{
        .{ .id = "reverb-type", .address = 0x00 },
        .{ .id = "reverb-level", .address = 0x01 },
        .{ .id = "reverb-variation", .address = 0x2A },
        .{ .id = "vibrato-chorus-type", .address = 0x38 },
        .{ .id = "mfx-type", .address = 0x5D },
        .{ .id = "mfx-level", .address = 0x5E },
        .{ .id = "delay-type", .address = 0x5F },
        .{ .id = "delay-level", .address = 0x60 },
        .{ .id = "compressor-level", .address = 0x62 },
    };
    for (expect) |e| {
        const p = catalog.params[paramIndexOfId(hashId(e.id)).?];
        try std.testing.expectEqual(e.address, p.address);
        try std.testing.expectEqualStrings("Effects", p.group);
    }
}
