---
name: zlowcheck-pbt
description: A guide for property-based testing using zlowcheck, a Zig library that combines finite-entropy random generation with automatic shrinking. Use this skill when working with zlowcheck property tests.
---

# zlowcheck Property-Based Testing Guide

This guide provides practical patterns for property-based testing with zlowcheck, which is a Zig library that combines finite-entropy random generation with automatic shrinking.

You need Zig 0.14.0 or later and zlowcheck installed to use this guide.

The source code is located at `/home/antoine/Documents/Experiments/zig/zlowcheck/`.

---

## Core Concepts

zlowcheck has three key features that distinguish it from other property-based testing libraries.

### 1. Finite Entropy Model

Tests are driven by byte sequences rather than infinite random streams. This approach provides several benefits:
- Complete reproducibility: the same bytes always produce the same test cases
- Fuzzer integration: byte sequences can come from fuzzers
- Regression testing: you can capture failing bytes and replay them later

```zig
var bytes = [_]u8{ 0x12, 0x34, 0x56, 0x78 };
var prng = FinitePrng.init(&bytes);
var random = prng.random();
// Use random to generate values deterministically
```

When generators need more bytes than are available, you get an `OutOfEntropy` error.

### 2. Context-Based Shrinking

Generated values carry context about how they were created. This enables several capabilities:
- Intelligent shrinking of composed values
- Tracking which bytes generated which values
- Preserving shrinking across `.map()` and `.filter()` transformations

### 3. Comptime Generators

Generators are created at compile time using Zig's type system:
```zig
const intGen = gen(i32, .{ .min = 0, .max = 100 });
const structGen = gen(MyStruct, .{
    .field1 = .{ .min = 0, .max = 10 },
    .field2 = .{},  // Use defaults
});
```

The config shape matches the type structure, and the compiler validates it.

---

## Quick Start

Here is a complete example that tests the property that reversing a list twice returns the original list:

```zig
const std = @import("std");
const zlowcheck = @import("zlowcheck");

test "reverse twice returns original" {
    // 1. Create generator for list of integers
    const list_gen = zlowcheck.gen([]i32, .{
        .min_len = 0,
        .max_len = 50,
        .child_config = .{ .min = -1000, .max = 1000 },
    });

    // 2. Define property (predicate function)
    const reverse_prop = zlowcheck.property(
        []i32,
        list_gen,
        struct {
            fn test_reverse(arr: []i32) bool {
                // Make a copy and reverse twice
                var copy = std.testing.allocator.dupe(i32, arr) catch return false;
                defer std.testing.allocator.free(copy);

                std.mem.reverse(i32, copy);
                std.mem.reverse(i32, copy);

                // Should equal original
                return std.mem.eql(i32, arr, copy);
            }
        }.test_reverse,
    );

    // 3. Run assertion
    const result = try zlowcheck.assert(
        reverse_prop,
        .{ .runs = 100, .verbose = false },
        std.testing.allocator,
    );

    // 4. On success, result is null
    try std.testing.expectEqual(null, result);

    // On failure, result contains:
    // - counterexample (the failing value)
    // - failure_bytes (for regression testing)
    // - num_shrinks (how many shrink steps taken)
}
```

---

## Key APIs

### Main Functions

`gen(T, config)` creates a generator for type T.
- Location: `src/generator.zig:1718`
- Supported types: integers, floats, bools, arrays, slices, structs, enums, unions, optionals
- The config shape mirrors the type structure

`property(T, generator, predicate)` defines a testable property.
- Location: `src/property.zig`
- Returns `Property(T, GeneratorType)`
- The predicate is a function with signature `fn(T) bool` that returns true if the property holds

`assert(property, config, allocator)` runs a property test.
- Location: `src/assert.zig:24`
- Config: `AssertConfig{ .runs = u32, .verbose = bool, .bytes = ?[]u8 }`
- Returns `?PropertyResult`: null on success, or a result struct on failure

### Generator Combinators

`tuple(generators)` combines multiple generators.
- Location: `src/generator.zig:99`
- Returns a tuple type with all generated values
- Example: `tuple(.{ intGen, boolGen, floatGen })`

`oneOf(generators, weights)` chooses between alternatives.
- Location: `src/generator.zig`
- The weights array is optional and allows weighted selection
- Example: `oneOf(.{ gen1, gen2 }, &[_]u32{ 70, 30 })`

### Generator Methods

`.map(NewType, mapFn, unmapFn)` transforms generated values.
- `mapFn`: `fn(T) NewType` performs the forward transformation
- `unmapFn`: `fn(NewType) ?T` performs the reverse transformation for shrinking (optional but recommended)

`.filter(predicateFn)` constrains generated values.
- `predicateFn`: `fn(T) bool` returns true to keep the value
- Warning: overly restrictive filters can cause `OutOfEntropy` errors

### Property Methods

`.beforeEach(context, hookFn)` runs setup before each test run.
`.afterEach(context, hookFn)` runs cleanup after each test run.

---

## Additional Resources

Source code locations:
- Main API: `src/zlowcheck.zig`
- Generator implementation: `src/generator.zig`
- Property implementation: `src/property.zig`
- Examples: `src/generator_test.zig`, `src/property_test.zig`

For stateful or model-based testing, see the `zlowcheck-stateful` skill.

For fuzzer integration, see `src/fuzz_stateful.zig` for examples.
