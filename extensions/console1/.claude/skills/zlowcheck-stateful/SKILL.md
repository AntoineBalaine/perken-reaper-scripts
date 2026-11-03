---
name: zlowcheck-stateful
description: Guide for model-based stateful testing with zlowcheck. Use when testing stateful systems by defining commands that execute on both a simple model and your system under test.
---

# zlowcheck Stateful Testing

This guide shows you how to test stateful systems using zlowcheck's model-based testing approach.

Source: `/home/antoine/Documents/Experiments/zig/zlowcheck/`

---

## Core Concepts

### Model-Based Testing

Model-based testing verifies that a system under test (SUT) behaves like a simplified model. The model is a reference implementation with correct behavior, while the SUT is your actual implementation. Commands are operations that modify both the model and SUT. After each command, the model and SUT must remain equivalent.

### How zlowcheck Works

zlowcheck generates random command sequences from byte entropy. For each command, it checks if the precondition is met on the model, executes the command on both model and SUT, then verifies they remain synchronized. When a test fails, zlowcheck shrinks the command sequence to find the minimal failing case and captures the bytes for regression testing.

This approach catches state transition bugs, race conditions, incorrect state management, and edge cases in complex workflows.

---

## Command Pattern

Commands implement a three-method interface:

```zig
const MyCommand = struct {
    // Required: Command name for debugging
    pub const name = "command_name";

    // Optional: Command-specific parameters
    value: i32,

    // Method 1: Can this command run given current model state?
    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        // Return true if command is valid
        // Return false to skip this command in the sequence
        return true;
    }

    // Method 2: Update model (used during command generation phase)
    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Modify model state
        model.counter += self.value;
    }

    // Method 3: Execute on both and verify synchronization
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute command on SUT
        try sut.add(self.value);

        // Update model to match
        model.counter += self.value;

        // Return true if they're still in sync
        return model.counter == sut.getCounter();
    }
};
```

The `checkPrecondition()` method validates command applicability, `onModelOnly()` is called during command generation, and `onPair()` is called during test execution. Commands can have parameters as struct fields and are type-erased via `Command(Model, System)`.

---

## Quick Start

This example tests a simple counter:

```zig
const std = @import("std");
const zlowcheck = @import("zlowcheck");
const state = zlowcheck;

// 1. Define the Model (simplified reference)
const Model = struct {
    value: u32 = 0,
};

// 2. Define the System Under Test
const System = struct {
    value: u32 = 0,

    pub fn increment(self: *@This()) void {
        if (self.value >= 5) return;  // Bug: stops at 5
        self.value += 1;
    }

    pub fn decrement(self: *@This()) void {
        if (self.value > 0) {
            self.value -= 1;
        }
    }

    pub fn reset(self: *@This()) void {
        self.value = 0;
    }
};

// 3. Define Commands
const IncrementCommand = struct {
    pub const name = "increment";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        _ = model;
        return true;  // Always valid
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
        return model.value > 0;  // Only valid if counter > 0
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

const ResetCommand = struct {
    pub const name = "reset";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.value = 0;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        _ = self;
        sut.reset();
        model.value = 0;
        return model.value == sut.value;
    }
};

// 4. Run the test
test "counter stateful test" {
    // Initialize command instances
    var inc_cmd = IncrementCommand{};
    var dec_cmd = DecrementCommand{};
    var reset_cmd = ResetCommand{};

    // Register commands
    const commands = [_]state.Command(Model, System){
        state.Command(Model, System).init(&inc_cmd),
        state.Command(Model, System).init(&dec_cmd),
        state.Command(Model, System).init(&reset_cmd),
    };

    // Initialize model and SUT
    var model = Model{};
    var sut = System{};

    // Create entropy for command generation
    var bytes: [4096]u8 = undefined;
    std.crypto.random.bytes(&bytes);
    var prng = zlowcheck.FinitePrng.init(&bytes);
    var random = prng.random();

    // Generate command sequence (max 50 commands)
    var cmd_seq = state.CommandList(Model, System).init(
        &commands,
        &random,
        50,
        std.testing.allocator,
    ) catch return error.SkipZigTest;
    defer cmd_seq.deinit(std.testing.allocator);

    // Execute stateful test
    const config = state.StatefulConfig{ .verbose = false };
    const result = try state.assertStateful(
        Model,
        System,
        &cmd_seq,
        &model,
        &sut,
        config,
    );

    // Should fail due to bug (counter stops at 5)
    if (result) |failure| {
        std.debug.print("Found bug! Failing command sequence:\n", .{});
        // Command sequence has been shrunk to minimal failing case
    }
}
```

---

## Key APIs

### Command Type

`Command(ModelType, SystemType)` - Type-erased command wrapper (Location: `src/state.zig:20`)

Create via `Command(Model, System).init(&command_instance)`. This provides a uniform interface for heterogeneous commands.

### CommandList Type

`CommandList(ModelType, SystemType)` - Iterator over command sequences (Location: `src/state.zig`)

Create via `.init(commands, random, max_len, allocator)`. This generates valid command sequences respecting preconditions. You must call `.deinit(allocator)` when done.

### Main Test Function

`assertStateful(Model, System, cmd_list, model, sut, config)` - Execute stateful test (Location: `src/state.zig`)

This function executes the command sequence and verifies model/SUT synchronization. It returns `null` on success or failure info on divergence, and automatically shrinks failing sequences.

### Configuration

`StatefulConfig` - Test configuration (Location: `src/state.zig`)

Fields: `.verbose = bool` (print command execution)

---

## Advanced Topics

### Combining with Property-Based Testing

You can use property-based testing to generate command parameters:

```zig
const AddCommand = struct {
    value: i32,
    pub const name = "add";

    // Generate many AddCommand instances with different values
    pub fn generate(allocator: Allocator) ![]AddCommand {
        const value_gen = zlowcheck.gen(i32, .{ .min = -100, .max = 100 });
        // Generate array of commands with different values
        // ...
    }
};
```

This combines both approaches for more thorough testing.

---

## Additional Resources

Source code locations:
- Stateful testing implementation: `src/state.zig`
- Complete example: `src/fuzz_stateful.zig:35`
- Command interface: `src/state.zig:20`

For basic property-based testing, see the `zlowcheck-pbt` skill.

For fuzzer integration, stateful tests work with fuzzers by using fuzzer-provided bytes for command generation.
