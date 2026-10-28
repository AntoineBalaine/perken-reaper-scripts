//! The audio loop: the plugin sends the track's audio to the keyboard's
//! input and takes the keyboard's output back, as REAPER's own ReaInsert does
//! for outboard gear.
//!
//! Two threads are involved, and neither may wait for the other:
//!
//! - REAPER's hardware hook runs on the audio device thread, twice per block.
//!   Before REAPER mixes, it copies the chosen input channels into the slot's
//!   `in_ring`. After REAPER mixes, it takes the slot's `out_ring` and adds it
//!   to the chosen output channels.
//! - The plugin's process callback runs on an FX thread. It pushes the track's
//!   audio into `out_ring` and pops the returned audio from `in_ring`.
//!
//! Because the plugin pushes and pops exactly one block per call, the number
//! of frames it has pushed and popped counts its own processing time. A click
//! pushed at frame `k` and popped back at frame `p` therefore proves a
//! round trip of `p - k` frames, which is the latency the plugin reports so
//! that REAPER's delay compensation lines the track up.
const std = @import("std");

const Atomic = std.atomic.Value;

pub const Frame = [2]f32;

/// A ring of stereo frames, one producer and one consumer.
pub fn FrameRing(comptime capacity: usize) type {
    comptime std.debug.assert(std.math.isPowerOfTwo(capacity));
    return struct {
        const Self = @This();

        frames: [capacity]Frame = [_]Frame{.{ 0, 0 }} ** capacity,
        head: Atomic(usize) = Atomic(usize).init(0),
        tail: Atomic(usize) = Atomic(usize).init(0),

        pub fn available(self: *const Self) usize {
            return self.tail.load(.acquire) -% self.head.load(.acquire);
        }

        pub fn space(self: *const Self) usize {
            return capacity - self.available();
        }

        /// Pushes `left.len` frames, or none when they do not fit. Returns
        /// whether they fit.
        pub fn push(self: *Self, left: []const f32, right: []const f32) bool {
            const n = left.len;
            const tail = self.tail.load(.monotonic);
            const head = self.head.load(.acquire);
            if (capacity - (tail -% head) < n) return false;
            for (0..n) |i| self.frames[(tail +% i) & (capacity - 1)] = .{ left[i], right[i] };
            self.tail.store(tail +% n, .release);
            return true;
        }

        /// Pops `left.len` frames, or none when fewer are available.
        pub fn pop(self: *Self, left: []f32, right: []f32) bool {
            const n = left.len;
            const head = self.head.load(.monotonic);
            const tail = self.tail.load(.acquire);
            if (tail -% head < n) return false;
            for (0..n) |i| {
                const f = self.frames[(head +% i) & (capacity - 1)];
                left[i] = f[0];
                right[i] = f[1];
            }
            self.head.store(head +% n, .release);
            return true;
        }

        /// Drops the oldest `n` frames. Only the consumer calls this.
        pub fn discard(self: *Self, n: usize) void {
            const head = self.head.load(.monotonic);
            const tail = self.tail.load(.acquire);
            const count = @min(n, tail -% head);
            self.head.store(head +% count, .release);
        }

        /// Empties the ring. Only the consumer calls this.
        pub fn clear(self: *Self) void {
            self.discard(self.available());
        }
    };
}

pub const ring_capacity = 16384;
pub const Ring = FrameRing(ring_capacity);

/// The channel indexes of a stereo pair on the audio device, or -1 for none.
pub const no_channel: i32 = -1;

/// One plugin instance's side of the loop.
pub const Slot = struct {
    /// Set by the plugin while it processes with the loop on; the hook ignores
    /// a slot that is not active.
    active: Atomic(bool) = Atomic(bool).init(false),
    out_ring: Ring = .{},
    in_ring: Ring = .{},
    out_channel: Atomic(i32) = Atomic(i32).init(no_channel),
    in_channel: Atomic(i32) = Atomic(i32).init(no_channel),
    /// Whether the hook has filled `out_ring` enough to start taking from it.
    out_primed: bool = false,
    in_overruns: Atomic(u32) = Atomic(u32).init(0),
    out_underruns: Atomic(u32) = Atomic(u32).init(0),

    /// Puts the slot back to its initial state without building a second
    /// copy on the stack: its rings are far too big for that, and the host's
    /// thread may have a small stack. Every field's initial value is zero
    /// except the channels.
    pub fn reset(self: *Slot) void {
        @memset(std.mem.asBytes(self), 0);
        self.out_channel.store(no_channel, .monotonic);
        self.in_channel.store(no_channel, .monotonic);
    }
};

pub const max_slots = 16;
const slot_free: u8 = 0;
const slot_preparing: u8 = 1;
const slot_claimed: u8 = 2;

/// What the hook needs from REAPER's `audio_hook_register_t`, so that the
/// tests can stand in for it.
pub const HostBuffers = struct {
    ctx: *anyopaque,
    input_nch: usize,
    output_nch: usize,
    get: *const fn (ctx: *anyopaque, is_output: bool, index: usize) ?[*]f64,
};

/// The slots of every plugin instance in this process, and the hook that
/// serves them.
pub const Bridge = struct {
    slots: [max_slots]Slot = [_]Slot{.{}} ** max_slots,
    /// The state of each slot: free, being made ready by `claim`, or claimed. Because the hook acts on a slot as
    /// soon as it sees it claimed, `claim` resets the slot while it is only being prepared.
    claimed: [max_slots]Atomic(u8) = [_]Atomic(u8){Atomic(u8).init(slot_free)} ** max_slots,
    /// Counts the hook's post callbacks, so that a plugin can tell whether the
    /// audio device is running (it is not during an offline render).
    ticks: Atomic(u32) = Atomic(u32).init(0),
    /// Scratch for the conversion between REAPER's doubles and the rings'
    /// floats; only the hook thread uses it.
    scratch_l: [4096]f32 = undefined,
    scratch_r: [4096]f32 = undefined,

    /// Allocates a bridge in place, for the same stack reason as `Slot.reset`.
    pub fn create(allocator: std.mem.Allocator) !*Bridge {
        const b = try allocator.create(Bridge);
        @memset(std.mem.asBytes(b), 0);
        for (&b.slots) |*slot| slot.reset();
        return b;
    }

    pub fn claim(self: *Bridge) ?*Slot {
        for (&self.claimed, 0..) |*c, i| {
            if (c.cmpxchgStrong(slot_free, slot_preparing, .acq_rel, .monotonic) == null) {
                self.slots[i].reset();
                c.store(slot_claimed, .release);
                return &self.slots[i];
            }
        }
        return null;
    }

    pub fn release(self: *Bridge, slot: *Slot) void {
        slot.active.store(false, .release);
        for (&self.slots, 0..) |*s, i| {
            if (s == slot) self.claimed[i].store(slot_free, .release);
        }
    }

    /// The hook's work for one callback. `is_post` is false before REAPER
    /// mixes and true after it.
    pub fn onBuffer(self: *Bridge, is_post: bool, len: usize, host: HostBuffers) void {
        if (len == 0 or len > self.scratch_l.len) return;
        for (&self.slots, 0..) |*slot, i| {
            if (self.claimed[i].load(.acquire) != slot_claimed) continue;
            if (!slot.active.load(.acquire)) {
                // The hook is the consumer of `out_ring` and owns `out_primed`, so it is the one that forgets what
                // the plugin pushed before it stopped, which would otherwise play late when the loop starts again.
                if (is_post) {
                    slot.out_primed = false;
                    slot.out_ring.clear();
                }
                continue;
            }
            if (is_post) {
                self.sendToDevice(slot, len, host);
            } else {
                self.receiveFromDevice(slot, len, host);
            }
        }
        if (is_post) _ = self.ticks.fetchAdd(1, .release);
    }

    pub fn receiveFromDevice(self: *Bridge, slot: *Slot, len: usize, host: HostBuffers) void {
        const ch = slot.in_channel.load(.monotonic);
        if (ch < 0) return;
        const c: usize = @intCast(ch);
        if (c + 1 >= host.input_nch) return;
        const l = host.get(host.ctx, false, c) orelse return;
        const r = host.get(host.ctx, false, c + 1) orelse return;
        for (0..len) |k| {
            self.scratch_l[k] = @floatCast(l[k]);
            self.scratch_r[k] = @floatCast(r[k]);
        }
        if (!slot.in_ring.push(self.scratch_l[0..len], self.scratch_r[0..len])) {
            _ = slot.in_overruns.fetchAdd(1, .monotonic);
        }
    }

    pub fn sendToDevice(self: *Bridge, slot: *Slot, len: usize, host: HostBuffers) void {
        const ch = slot.out_channel.load(.monotonic);
        if (ch < 0) return;
        const c: usize = @intCast(ch);
        if (c + 1 >= host.output_nch) return;
        // The plugin pushes whole blocks, so the ring is primed with two of
        // them before the hook starts taking, which absorbs the jitter
        // between the two threads.
        if (!slot.out_primed) {
            if (slot.out_ring.available() < len * 2) return;
            slot.out_primed = true;
        }
        if (!slot.out_ring.pop(self.scratch_l[0..len], self.scratch_r[0..len])) {
            slot.out_primed = false;
            _ = slot.out_underruns.fetchAdd(1, .monotonic);
            return;
        }
        const l = host.get(host.ctx, true, c) orelse return;
        const r = host.get(host.ctx, true, c + 1) orelse return;
        for (0..len) |k| {
            l[k] += self.scratch_l[k];
            r[k] += self.scratch_r[k];
        }
    }
};

pub const PingState = enum(u8) { idle, listening_noise, sending, listening, done, failed };

/// What the loop is doing, for the user interface.
pub const LoopState = enum(u8) {
    /// The user turned the loop off.
    off,
    /// The audio device's hook has not been called lately, as in an offline
    /// render, so the audio passes through.
    no_device,
    /// A pair of channels is missing, so the audio passes through.
    no_channels,
    running,
};

/// Measures the round trip with a click.
pub const Ping = struct {
    state: PingState = .idle,
    /// Frames since the measurement started.
    elapsed: u64 = 0,
    noise_peak: f32 = 0,
    threshold: f32 = 0,
    click_at: u64 = 0,
    /// The result, in frames.
    latency: u32 = 0,

    pub const noise_frames = 4800;
    pub const timeout_seconds = 1.0;
    pub const click_level: f32 = 0.5;
    pub const min_threshold: f32 = 0.02;
};

/// The audio thread's side of the loop for one plugin instance.
pub const Loop = struct {
    slot: *Slot,
    bridge: *Bridge,

    /// The send and return levels, as gains.
    send_gain: f32 = 1,
    return_gain: f32 = 1,

    /// The frames pushed and popped since the loop started. Lockstep keeps
    /// them equal, which is what makes a round trip countable.
    frames: u64 = 0,
    in_primed: bool = false,
    last_tick: u32 = 0,
    stalled_blocks: u32 = 0,
    ping: Ping = .{},
    /// Set by `startPing`; the next block starts the measurement.
    ping_requested: Atomic(bool) = Atomic(bool).init(false),
    state: LoopState = .off,
    /// Counts the blocks that could not keep lockstep, which invalidates a
    /// measurement made across them.
    glitches: u32 = 0,

    scratch_l: [4096]f32 = undefined,
    scratch_r: [4096]f32 = undefined,

    pub fn init(bridge: *Bridge, slot: *Slot) Loop {
        return .{ .slot = slot, .bridge = bridge, .last_tick = bridge.ticks.load(.acquire) };
    }

    /// Asks for a measurement. Any thread may call it: the measurement begins at the start of the next block,
    /// because only the audio thread may write `ping`.
    pub fn startPing(self: *Loop) void {
        self.ping_requested.store(true, .release);
    }

    /// Whether the audio device is running: the hook's tick advances with it.
    pub fn deviceRunning(self: *Loop) bool {
        const tick = self.bridge.ticks.load(.acquire);
        if (tick != self.last_tick) {
            self.last_tick = tick;
            self.stalled_blocks = 0;
            return true;
        }
        self.stalled_blocks += 1;
        // The hook and the plugin's blocks do not interleave one to one, so
        // a few blocks without a tick are normal.
        return self.stalled_blocks < 8;
    }

    /// Processes one block. The plugin passes the track's audio in `in_l` and
    /// `in_r` and gets what to output in `out_l` and `out_r`. Without a
    /// running device the track's audio passes through unchanged.
    pub fn process(self: *Loop, enabled: bool, in_l: []const f32, in_r: []const f32, out_l: []f32, out_r: []f32) void {
        const n = in_l.len;
        const running = self.deviceRunning();
        const has_channels = self.slot.out_channel.load(.monotonic) >= 0 and self.slot.in_channel.load(.monotonic) >= 0;
        self.state = if (!enabled) .off else if (!running) .no_device else if (!has_channels) .no_channels else .running;
        const bypass = self.state != .running or n > self.scratch_l.len;
        if (self.ping_requested.swap(false, .acq_rel)) self.ping = .{ .state = .listening_noise };
        if (bypass) {
            // The plugin is the consumer of `in_ring` and the producer of `out_ring`. It clears the first, and tells
            // the hook to drop the second by deactivating the slot: `out_primed` and the consumer's end of
            // `out_ring` belong to the hook.
            self.slot.active.store(false, .release);
            self.in_primed = false;
            self.slot.in_ring.clear();
            // The host may hand over the same buffer for input and output.
            if (out_l.ptr != in_l.ptr) @memcpy(out_l[0..n], in_l);
            if (out_r.ptr != in_r.ptr) @memcpy(out_r[0..n], in_r);
            if (self.ping.state != .idle and self.ping.state != .done) self.ping.state = .failed;
            return;
        }
        self.slot.active.store(true, .release);

        // The block to send: the track's audio, or the click while measuring.
        var send_l = self.scratch_l[0..n];
        var send_r = self.scratch_r[0..n];
        if (self.ping.state == .idle or self.ping.state == .done or self.ping.state == .failed) {
            for (0..n) |i| {
                send_l[i] = in_l[i] * self.send_gain;
                send_r[i] = in_r[i] * self.send_gain;
            }
        } else {
            @memset(send_l, 0);
            @memset(send_r, 0);
            if (self.ping.state == .sending) {
                send_l[0] = Ping.click_level;
                send_r[0] = Ping.click_level;
                self.ping.click_at = self.frames;
                self.ping.state = .listening;
            }
        }
        if (!self.slot.out_ring.push(send_l, send_r)) self.glitches += 1;

        // The returned block. The ring is primed with two blocks first, so
        // that the jitter between the threads never empties it.
        const have = self.slot.in_ring.available();
        if (!self.in_primed) {
            if (have >= n * 2) self.in_primed = true;
        }
        var got = false;
        if (self.in_primed) {
            got = self.slot.in_ring.pop(out_l[0..n], out_r[0..n]);
            if (!got) {
                self.in_primed = false;
                self.glitches += 1;
            } else {
                // A ring that has grown far past its prime would add latency
                // for as long as the session lasts, so the excess is dropped.
                const extra = self.slot.in_ring.available();
                if (extra > n * 4) {
                    self.slot.in_ring.discard(extra - n * 2);
                    self.glitches += 1;
                }
            }
        }
        if (!got) {
            @memset(out_l[0..n], 0);
            @memset(out_r[0..n], 0);
            if (self.ping.state == .listening or self.ping.state == .sending) self.ping.state = .failed;
        } else {
            self.measure(out_l[0..n], out_r[0..n]);
            for (0..n) |i| {
                out_l[i] *= self.return_gain;
                out_r[i] *= self.return_gain;
            }
        }
        self.frames += n;
    }

    /// Looks at the returned block for the click.
    pub fn measure(self: *Loop, l: []const f32, r: []const f32) void {
        const p = &self.ping;
        switch (p.state) {
            .idle, .done, .failed, .sending => {},
            .listening_noise => {
                for (l, r) |a, b| p.noise_peak = @max(p.noise_peak, @max(@abs(a), @abs(b)));
                p.elapsed += l.len;
                if (p.elapsed >= Ping.noise_frames) {
                    p.threshold = @max(Ping.min_threshold, p.noise_peak * 6);
                    p.state = .sending;
                    p.elapsed = 0;
                }
            },
            .listening => {
                const start = self.frames;
                for (l, r, 0..) |a, b, i| {
                    if (@max(@abs(a), @abs(b)) > p.threshold) {
                        p.latency = @intCast(start + i - p.click_at);
                        p.state = .done;
                        return;
                    }
                }
                p.elapsed += l.len;
                // One second without the click means the loop is not wired.
                if (p.elapsed > ring_capacity) p.state = .failed;
            },
        }
    }
};

// ---- tests ----

test "a ring hands frames back in order and refuses to overflow" {
    var ring = FrameRing(8){};
    const a = [_]f32{ 1, 2, 3 };
    const b = [_]f32{ 4, 5, 6 };
    try std.testing.expect(ring.push(&a, &b));
    try std.testing.expectEqual(@as(usize, 3), ring.available());
    var l: [2]f32 = undefined;
    var r: [2]f32 = undefined;
    try std.testing.expect(ring.pop(&l, &r));
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1, 2 }, &l);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 4, 5 }, &r);
    var big_l: [8]f32 = undefined;
    var big_r: [8]f32 = undefined;
    try std.testing.expect(!ring.push(&big_l, &big_r));
    try std.testing.expect(!ring.pop(&big_l, &big_r));
    ring.discard(10);
    try std.testing.expectEqual(@as(usize, 0), ring.available());
}

/// A pretend audio device: what the hook sends to the output comes back on
/// the input after `delay` frames, the way a cable through a keyboard would
/// return it. One call to `cycle` is one device block: the hook runs before
/// REAPER mixes, the plugin processes, and the hook runs after.
const FakeDevice = struct {
    const block = 256;
    const channels = 4;

    delay: usize,
    /// Everything the device has output on the returning channel, by frame.
    history: std.ArrayList(f64),
    time: usize = 0,
    out_bufs: [channels][block]f64 = undefined,
    in_bufs: [channels][block]f64 = undefined,
    channel: usize = 2,

    pub fn get(ctx: *anyopaque, is_output: bool, index: usize) ?[*]f64 {
        const self: *FakeDevice = @ptrCast(@alignCast(ctx));
        if (index >= channels) return null;
        return if (is_output) &self.out_bufs[index] else &self.in_bufs[index];
    }

    pub fn host(self: *FakeDevice) HostBuffers {
        return .{ .ctx = self, .input_nch = channels, .output_nch = channels, .get = get };
    }

    pub fn before(self: *FakeDevice, bridge: *Bridge) void {
        for (0..channels) |c| {
            @memset(&self.out_bufs[c], 0);
            @memset(&self.in_bufs[c], 0);
        }
        for (0..block) |i| {
            const t = self.time + i;
            if (t >= self.delay) self.in_bufs[self.channel][i] = self.history.items[t - self.delay];
        }
        bridge.onBuffer(false, block, self.host());
    }

    pub fn after(self: *FakeDevice, bridge: *Bridge) !void {
        bridge.onBuffer(true, block, self.host());
        for (0..block) |i| try self.history.append(self.out_bufs[self.channel][i]);
        self.time += block;
    }
};

test "the loop measures the true round trip and returns the audio with that delay" {
    const allocator = std.testing.allocator;
    const bridge = try Bridge.create(allocator);
    defer allocator.destroy(bridge);
    const slot = bridge.claim().?;
    slot.out_channel.store(2, .monotonic);
    slot.in_channel.store(2, .monotonic);
    var loop = Loop.init(bridge, slot);
    var device = FakeDevice{ .delay = 300, .history = std.ArrayList(f64).init(allocator) };
    defer device.history.deinit();

    const B = FakeDevice.block;
    var in_l: [B]f32 = [_]f32{0} ** B;
    var in_r: [B]f32 = [_]f32{0} ** B;
    var out_l: [B]f32 = undefined;
    var out_r: [B]f32 = undefined;

    loop.startPing();
    var cycles: usize = 0;
    while (loop.ping.state != .done and loop.ping.state != .failed and cycles < 200) : (cycles += 1) {
        device.before(bridge);
        loop.process(true, &in_l, &in_r, &out_l, &out_r);
        try device.after(bridge);
    }
    try std.testing.expectEqual(PingState.done, loop.ping.state);
    const measured = loop.ping.latency;

    // A ramp through the same path must come back exactly `measured` frames
    // later. The first values are skipped while the rings settle.
    var sent = std.ArrayList(f32).init(allocator);
    defer sent.deinit();
    var received = std.ArrayList(f32).init(allocator);
    defer received.deinit();
    var k: usize = 0;
    for (0..60) |_| {
        for (0..B) |i| {
            in_l[i] = @as(f32, @floatFromInt(k + i + 1)) * 1e-5;
            in_r[i] = in_l[i];
        }
        device.before(bridge);
        loop.process(true, &in_l, &in_r, &out_l, &out_r);
        try device.after(bridge);
        for (0..B) |i| {
            try sent.append(in_l[i]);
            try received.append(out_l[i]);
        }
        k += B;
    }
    var checked: usize = 0;
    var t: usize = 20 * B;
    while (t < received.items.len) : (t += 1) {
        try std.testing.expectApproxEqAbs(sent.items[t - measured], received.items[t], 1e-6);
        checked += 1;
    }
    try std.testing.expect(checked > 1000);
    try std.testing.expect(measured >= 300);
}

test "without a running device or channels the audio passes through" {
    const allocator = std.testing.allocator;
    const bridge = try Bridge.create(allocator);
    defer allocator.destroy(bridge);
    const slot = bridge.claim().?;
    var loop = Loop.init(bridge, slot);
    const in_l = [_]f32{ 0.1, 0.2, 0.3 };
    const in_r = [_]f32{ 0.4, 0.5, 0.6 };
    var out_l: [3]f32 = undefined;
    var out_r: [3]f32 = undefined;
    loop.process(true, &in_l, &in_r, &out_l, &out_r);
    try std.testing.expectEqualSlices(f32, &in_l, &out_l);
    try std.testing.expectEqualSlices(f32, &in_r, &out_r);
    try std.testing.expect(!slot.active.load(.acquire));
}

fn noBuffers(_: *anyopaque, _: bool, _: usize) ?[*]f64 {
    return null;
}

test "turning the loop off leaves the hook's side of the ring to the hook" {
    const allocator = std.testing.allocator;
    const bridge = try Bridge.create(allocator);
    defer allocator.destroy(bridge);
    const slot = bridge.claim().?;
    var loop = Loop.init(bridge, slot);
    // The loop was running: the plugin pushed a block, and the hook had started taking from the ring.
    const block = [_]f32{0.25} ** 64;
    slot.active.store(true, .release);
    try std.testing.expect(slot.out_ring.push(&block, &block));
    slot.out_primed = true;

    var out_l: [64]f32 = undefined;
    var out_r: [64]f32 = undefined;
    loop.process(false, &block, &block, &out_l, &out_r);
    // The plugin only says that the slot is not active: it does not take from the producer's ring, or the hook's flag.
    try std.testing.expect(!slot.active.load(.acquire));
    try std.testing.expectEqual(@as(usize, 64), slot.out_ring.available());
    try std.testing.expect(slot.out_primed);

    // The hook drops them at its next callback, so that they do not play late when the loop starts again.
    var unused: u8 = 0;
    bridge.onBuffer(true, 64, .{ .ctx = &unused, .input_nch = 0, .output_nch = 0, .get = noBuffers });
    try std.testing.expectEqual(@as(usize, 0), slot.out_ring.available());
    try std.testing.expect(!slot.out_primed);
}

test "a measurement is asked for by any thread and begins in the audio thread" {
    const allocator = std.testing.allocator;
    const bridge = try Bridge.create(allocator);
    defer allocator.destroy(bridge);
    const slot = bridge.claim().?;
    var loop = Loop.init(bridge, slot);
    loop.startPing();
    try std.testing.expectEqual(PingState.idle, loop.ping.state);
    try std.testing.expect(loop.ping_requested.load(.acquire));
    const block = [_]f32{0} ** 16;
    var out_l: [16]f32 = undefined;
    var out_r: [16]f32 = undefined;
    loop.process(true, &block, &block, &out_l, &out_r);
    try std.testing.expect(!loop.ping_requested.load(.acquire));
}

test "the hook leaves a slot alone while it is being prepared" {
    const allocator = std.testing.allocator;
    const bridge = try Bridge.create(allocator);
    defer allocator.destroy(bridge);
    // A claim that has reserved the slot and has not finished resetting it: the hook must not clear its ring.
    bridge.claimed[0].store(slot_preparing, .release);
    const block = [_]f32{0.5} ** 32;
    try std.testing.expect(bridge.slots[0].out_ring.push(&block, &block));
    var unused: u8 = 0;
    bridge.onBuffer(true, 32, .{ .ctx = &unused, .input_nch = 0, .output_nch = 0, .get = noBuffers });
    try std.testing.expectEqual(@as(usize, 32), bridge.slots[0].out_ring.available());
    // Once the slot is claimed, an inactive one is cleared by the hook.
    bridge.claimed[0].store(slot_claimed, .release);
    bridge.onBuffer(true, 32, .{ .ctx = &unused, .input_nch = 0, .output_nch = 0, .get = noBuffers });
    try std.testing.expectEqual(@as(usize, 0), bridge.slots[0].out_ring.available());
}

test "slots are claimed and released" {
    const allocator = std.testing.allocator;
    const bridge = try Bridge.create(allocator);
    defer allocator.destroy(bridge);
    const a = bridge.claim().?;
    const b = bridge.claim().?;
    try std.testing.expect(a != b);
    bridge.release(a);
    const c = bridge.claim().?;
    try std.testing.expect(c == a);
    for (0..max_slots - 2) |_| _ = bridge.claim().?;
    try std.testing.expect(bridge.claim() == null);
}
