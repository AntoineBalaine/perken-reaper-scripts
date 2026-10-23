const std = @import("std");
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const StatefulConfig = zlowcheck.StatefulConfig;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

test "assertStateful" {
    // Define a simple model
    const Model = struct {
        value: u32 = 0,

        pub fn reset(self: *@This()) void {
            self.value = 0;
        }
    };

    // Define a simple system under test
    const System = struct {
        value: u32 = 0,

        pub fn reset(self: *@This()) void {
            self.value = 0;
        }

        pub fn increment(self: *@This()) void {
            if (self.value >= 5) return;
            self.value += 1;
        }

        pub fn decrement(self: *@This()) void {
            if (self.value > 0) {
                self.value -= 1;
            }
        }
    };

    // Define commands
    const IncrementCommand = struct {
        pub const name = "increment";
        pub fn checkPrecondition(self: *@This(), model: *Model) bool {
            _ = self;
            _ = model;
            return true;
        }

        pub fn onModelOnly(self: *@This(), model: *Model) void {
            _ = self;
            model.value += 1;
        }

        pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
            _ = self;
            sut.increment();

            model.value += 1;
            return model.value == sut.value;
        }
    };

    const DecrementCommand = struct {
        pub const name = "decrement";
        pub fn checkPrecondition(self: *@This(), model: *Model) bool {
            _ = self;
            return model.value > 0;
        }

        pub fn onModelOnly(self: *@This(), model: *Model) void {
            _ = self;
            model.value -= 1;
        }

        pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
            _ = self;
            sut.decrement();

            model.value -= 1;
            return model.value == sut.value;
        }
    };

    var inc_cmd = IncrementCommand{};
    var dec_cmd = DecrementCommand{};
    // Create commands array
    const commands = [_]Command(Model, System){
        Command(Model, System).init(&inc_cmd),
        Command(Model, System).init(&dec_cmd),
    };

    // Create test configuration
    const config: StatefulConfig = .{ .verbose = false };

    // Initialize model and system
    var model = Model{};
    var sut = System{};

    // Create random source
    // var random_bytes: [1024]u8 = undefined;
    // @import("test_helpers").load_bytes(&random_bytes);
    var random_bytes = [_]u8{
        0x8B, 0xBE, 0x02, 0x2C, 0x87, 0x0A, 0xF6, 0x54, 0x4A, 0x59, 0x73, 0xA8, 0x12, 0xF7, 0x2B, 0x85,
        //
        0xAD, 0x95, 0x90, 0x8A, 0x21, 0xF1, 0xAC, 0x64, 0x42, 0x32, 0xA5, 0x0D, 0x10, 0x1F, 0xBA, 0xE7,
        //
        0x0F, 0xEE, 0xF9, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62,
    };
    var prng = FinitePrng.init(&random_bytes);
    var random = prng.random();

    // Create command sequence
    var cmd_seq = try CommandList(Model, System).init(&commands, &random, 50, std.testing.allocator);
    defer cmd_seq.deinit(std.testing.allocator);

    // Run the test
    const rv = try assertStateful(Model, System, &cmd_seq, &model, &sut, config);
    try std.testing.expect(rv != null);
}
