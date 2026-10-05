# Memory & Allocators — Zig: Zero to Hero

> Source: https://jkingston.github.io/zig_guide/04-memory-allocators.html
> Collected: 2026-10-05
> Published: Unknown

# Memory & Allocators — Zig: Zero to Hero

TL;DR for C/C++/Rust developers

*   **No implicit allocations** - all allocations require explicit allocator parameter
*   **Allocator interface:** `allocator.alloc(T, count)`, `allocator.free(slice)`
*   **Choose allocator:** GPA (dev), c\_allocator (prod), Arena (request-scoped), testing.allocator (tests)
*   **Cleanup:** `defer allocator.free(ptr)` immediately after allocation
*   **Error handling:** `errdefer` for multi-step initialization cleanup
*   **Zero-length allocations work** — `alloc(T, 0)` returns a valid empty slice; `free()` on it is a no-op (unlike C's undefined `malloc(0)`)
*   **See [comparison table](#allocator-types-and-selection) below for full allocator guide**
*   **Jump to:** [Allocator Interface](#the-allocator-interface) | [Allocator Types](#allocator-types-and-selection) | [Ownership Patterns](#ownership-and-cleanup-responsibilities)

## Overview

Memory management in Zig is explicit, deterministic, and designed to eliminate an entire class of bugs common in other systems languages. Unlike languages with garbage collection or hidden allocations, Zig requires every memory allocation to specify an allocator explicitly. This philosophy—"no hidden memory allocations"—forces clarity about ownership, lifetime, and resource cleanup throughout the codebase.

This chapter explains the allocator interface, common allocator patterns, ownership semantics, and cleanup idioms that underpin containers, I/O, and concurrency in Zig. Understanding these patterns is essential for writing correct, maintainable systems software.

## Core Concepts

### The Allocator Interface

Zig's `std.mem.Allocator` provides a uniform interface for all memory allocation strategies. This vtable-based design enables compile-time polymorphism—callers can switch allocator implementations without code changes, making it trivial to use an arena for request handling or a debug allocator for leak detection.

The interface defines four primary operations:

*   **`alloc(T, count)`** — Allocates a slice of type `[]T` with `count` elements
*   **`free(slice)`** — Deallocates a previously allocated slice
*   **`create(T)`** — Allocates a single item of type `T`, returning `*T`
*   **`destroy(pointer)`** — Deallocates a single item

All allocation methods return error unions (`![]T` or `!*T`), with `error.OutOfMemory` as the primary failure mode. For performance-critical scenarios, `alignedAlloc()` ensures specific alignment requirements, such as cache-line alignment for buffers.11 [TigerBeetle state\_machine.zig - Aligned allocation](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/src/state_machine.zig#L1051)  Zero-length allocations are valid: `alloc(T, 0)` returns a usable empty slice with `len == 0`, and `free()` on such slices is a safe no-op. This eliminates the need for defensive length checks before allocating or freeing, unlike C where `malloc(0)` has implementation-defined behavior.

`const std = @import("std");  pub fn main() !void {     var da: std.heap.DebugAllocator(.{}) = .{ .backing_allocator = std.heap.smp_allocator };     defer {         const deinit_status = da.deinit();         if (deinit_status == .leak) {             std.debug.print("Memory leak detected!\n", .{});         }     }     const allocator = da.allocator();      // Slice allocation     const numbers = try allocator.alloc(u32, 5);     defer allocator.free(numbers);      // Single item allocation     const single = try allocator.create(u32);     defer allocator.destroy(single);     single.* = 42;      // Aligned allocation (16-byte boundary)     const aligned = try allocator.alignedAlloc(u8, .@"16", 64);     defer allocator.free(aligned); }`

This example demonstrates the core interface with leak detection. The `DebugAllocator` reports leaks at `deinit()`, catching forgotten frees during development.

> **0.16+ note:** In application code, `std.process.Init` provides a pre-initialized GPA via `init.gpa`, eliminating the manual setup shown above. The explicit patterns in this chapter are shown for understanding—they remain valid and are necessary in libraries, tests, and tools that don't use `process.Init`.

### Allocator Types and Selection

Zig's standard library provides specialized allocators for different use cases:

Allocator

Characteristics

Best For

Trade-offs

Production Use

`std.testing.allocator`

Fails tests on leaks, stack traces

Testing

Safety (dev-only)

Required for tests

`GeneralPurposeAllocator`

Thread-safe, detects double-free/use-after-free, never reuses addresses

Development, debugging

Safety > performance

Ghostty, ZLS, Lightpanda (debug)[2](#fn:2)[3](#fn:3)

`ArenaAllocator`

Bulk deallocation, `free()` is no-op

Request-scoped, parsers, temp data

Holds all until `deinit()`

TigerBeetle config, Lightpanda ArenaPool[2](#fn:2)[3](#fn:3)

`FixedBufferAllocator`

Pre-allocated buffer (often stack), no syscalls

Known max size, perf-critical

Fixed capacity

Zig test runner[4](#fn:4)

`c_allocator`

Wraps malloc/free, minimal overhead

Release builds, C interop

No safety features

Production (after testing)

`page_allocator`

Direct OS page mapping (4KB min)

Large buffers, isolation

High overhead for small allocs

Security-critical

### Allocator Propagation

Allocators flow through Zig codebases as explicit parameters. The standard convention places the allocator as the first parameter, ordered from most general to most specific dependencies.55 [TigerBeetle TIGER\_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/docs/TIGER_STYLE.md) 

`fn processData(allocator: std.mem.Allocator, data: []const u8) !Result {     const buffer = try allocator.alloc(u8, data.len * 2);     defer allocator.free(buffer);     // Process data... }`

For long-lived structs, allocators may be stored as fields to simplify cleanup:

`const Parser = struct {     allocator: std.mem.Allocator,     tokens: std.ArrayList(Token),      pub fn init(allocator: std.mem.Allocator) !Parser {         return .{             .allocator = allocator,             .tokens = std.ArrayList(Token).init(allocator),         };     }      pub fn deinit(self: *Parser) void {         self.tokens.deinit();         // Allocator stored for cleanup     } };`

The trade-off: storing the allocator increases struct size but eliminates the need to pass it to `deinit()`. TigerBeetle recommends meaningful allocator parameter names—`gpa` for general-purpose allocators requiring explicit cleanup, `arena` for bulk cleanup contexts—to communicate ownership semantics.[5](#fn:5)

### Ownership Semantics

Ownership in Zig is explicit and documented by convention. Three patterns dominate production codebases:

**Caller-Owns Pattern** — Caller allocates and retains ownership; the function uses but does not free the memory.

``/// Processes data into caller-provided buffer. /// Caller retains ownership of `buffer`. fn processInPlace(buffer: []u8, data: []const u8) void {     @memcpy(buffer[0..data.len], data); }``

**Callee-Returns-Owned Pattern** — Function allocates and returns memory; caller must free it.

`/// Allocates and returns a buffer. Caller owns returned memory /// and must free it with the same allocator. fn allocateResult(allocator: std.mem.Allocator, size: usize) ![]u8 {     return try allocator.alloc(u8, size); }  // Usage const result = try allocateResult(allocator, 100); defer allocator.free(result); // Caller must free`

**Init/Deinit Pairs** — RAII-like pattern where `init()` allocates and `deinit()` releases. This is the dominant pattern for structs managing resources.

`const Resource = struct {     allocator: std.mem.Allocator,     data: []u8,      pub fn init(allocator: std.mem.Allocator, size: usize) !Resource {         return .{             .allocator = allocator,             .data = try allocator.alloc(u8, size),         };     }      pub fn deinit(self: *Resource) void {         self.allocator.free(self.data);     } };  // Usage var resource = try Resource.init(allocator, 1024); defer resource.deinit();`

TigerBeetle also uses an "out-pointer" style for performance-critical code, where `init()` takes `self: *Resource` and modifies it in place, eliminating intermediate copies and ensuring pointer stability.[5](#fn:5)

### Cleanup Idioms

Zig provides `defer` and `errdefer` for deterministic cleanup (see Ch5 for comprehensive coverage). Best practice: pair allocations with cleanup immediately:

`const data = try allocator.alloc(u8, 100); defer allocator.free(data);  // LIFO order: runs at scope exit  const file = try std.fs.cwd().openFile("data.txt", .{}); defer file.close();`

For multi-step initialization where later steps might fail, `errdefer` executes only on error returns:

`fn createResources(allocator: std.mem.Allocator) !Resources {     const buffer1 = try allocator.alloc(u8, 100);     errdefer allocator.free(buffer1);  // Cleanup if subsequent errors occur      const buffer2 = try allocator.alloc(u8, 200);     errdefer allocator.free(buffer2);      return .{ .buf1 = buffer1, .buf2 = buffer2 }; }`

**Memory Management Strategy:**

*   **Arenas** — Request-scoped bulk cleanup (all freed together)
*   **Manual cleanup (defer/errdefer)** — Individual lifetimes or incremental reclamation
*   See TigerBeetle's manifest initialization for cascading errdefer patterns[6](#fn:6)

## Code Examples

### Arena Pattern for Request Handling

`const std = @import("std");  fn handleRequest(allocator: std.mem.Allocator, req_id: u32, data: []const u8) ![]u8 {     _ = data;     var parts: std.ArrayList([]const u8) = .empty;     defer parts.deinit(allocator);      try parts.append(allocator, "Processing request ");     const id_str = try std.fmt.allocPrint(allocator, "{}", .{req_id});     defer allocator.free(id_str);     try parts.append(allocator, id_str);      // Concatenate parts     var total_len: usize = 0;     for (parts.items) |part| total_len += part.len;      const result = try allocator.alloc(u8, total_len);     var offset: usize = 0;     for (parts.items) |part| {         @memcpy(result[offset..][0..part.len], part);         offset += part.len;     }      return result; }  pub fn main() !void {     var da: std.heap.DebugAllocator(.{}) = .{ .backing_allocator = std.heap.smp_allocator };     defer std.debug.assert(da.deinit() == .ok);      var arena = std.heap.ArenaAllocator.init(da.allocator());     defer arena.deinit();      // Process multiple requests     var i: u32 = 0;     while (i < 3) : (i += 1) {         defer _ = arena.reset(.{ .retain_with_limit = 4096 });         const response = try handleRequest(arena.allocator(), i, "data");         std.debug.print("{s}\n", .{response});         // No individual frees needed—arena handles it     } }`

This demonstrates arena reuse with `reset()`, retaining small allocations for performance. Ghostty uses this pattern for configuration parsing, while ZLS uses it for argument processing.22 [Ghostty Config.zig](https://github.com/ghostty-org/ghostty/blob/05b580911577ae86e7a29146fac29fb368eab536/src/config/Config.zig#L17) 33 [ZLS main.zig](https://github.com/zigtools/zls/blob/24f01e406dc211fbab71cfae25f17456962d4435/src/main.zig#L282-288) 

### FixedBufferAllocator for Stack-Based Operations

`const std = @import("std");  fn formatMessage(buffer: []u8, name: []const u8, value: i32) ![]const u8 {     var fba = std.heap.FixedBufferAllocator.init(buffer);     const allocator = fba.allocator();      return try std.fmt.allocPrint(         allocator,         "User: {s}, Score: {}",         .{ name, value }     ); }  pub fn main() !void {     var stack_buffer: [256]u8 = undefined;      const msg1 = try formatMessage(&stack_buffer, "Alice", 100);     std.debug.print("{s}\n", .{msg1});      // Reuse same buffer (overwrites previous content)     const msg2 = try formatMessage(&stack_buffer, "Bob", 200);     std.debug.print("{s}\n", .{msg2}); }`

FixedBufferAllocator eliminates heap allocations entirely, offering predictable performance with no system calls. The Zig test runner uses this pattern for command-line processing.44 [zig.guide - Allocators](https://zig.guide/standard-library/allocators/) 

### Error-Path Cleanup with errdefer

`const std = @import("std");  const Database = struct {     connection: []u8,     buffer: []u8,     cache: []u8,     allocator: std.mem.Allocator,      pub fn init(allocator: std.mem.Allocator, conn_str: []const u8) !Database {         const connection = try allocator.alloc(u8, conn_str.len);         errdefer allocator.free(connection);         @memcpy(connection, conn_str);          const buffer = try allocator.alloc(u8, 1024);         errdefer allocator.free(buffer);          const cache = try allocator.alloc(u8, 2048);         errdefer allocator.free(cache);          if (conn_str.len > 100) {             return error.ConnectionFailed; // Automatic cleanup via errdefer         }          return .{             .connection = connection,             .buffer = buffer,             .cache = cache,             .allocator = allocator,         };     }      pub fn deinit(self: *Database) void {         self.allocator.free(self.cache);         self.allocator.free(self.buffer);         self.allocator.free(self.connection);     } };`

If initialization fails after allocating `connection` and `buffer`, both are automatically freed by their respective `errdefer` statements. TigerBeetle's state machine initialization uses this cascading pattern for complex multi-step setup.77 [TigerBeetle state\_machine.zig](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/src/state_machine.zig#L846-852) 

## Common Pitfalls

### Forgetting to Free Allocations

`// ❌ WRONG: Leak on early return fn leakyFunction(allocator: std.mem.Allocator) !void {     const data = try allocator.alloc(u8, 100);     if (someCondition) return error.Failed; // Leak! }  // ✅ CORRECT: defer ensures cleanup fn fixedFunction(allocator: std.mem.Allocator) !void {     const data = try allocator.alloc(u8, 100);     defer allocator.free(data);     if (someCondition) return error.Failed; // No leak }`

**Prevention:** Place `defer allocator.free(data)` immediately after allocation. TigerBeetle's style guide recommends grouping allocations with their defer statements using newlines to make leaks visible during code review.[5](#fn:5)

### Freeing with the Wrong Allocator

`// ❌ WRONG: Wrong allocator var arena = std.heap.ArenaAllocator.init(gpa.allocator()); const data = try arena.allocator().alloc(u8, 100); gpa.allocator().free(data); // Wrong allocator!  // ✅ CORRECT: Use same allocator var arena = std.heap.ArenaAllocator.init(gpa.allocator()); const allocator = arena.allocator(); const data = try allocator.alloc(u8, 100); // Rely on arena.deinit() or use same allocator`

**Prevention:** Store the allocator in a local variable and use it consistently. For arenas, rely on bulk cleanup via `deinit()`.

### Use-After-Free

`// ❌ WRONG: Use after free var data = try allocator.alloc(u8, 100); allocator.free(data); data[0] = 42; // Use after free!  // ✅ CORRECT: defer delays free until end of scope var data = try allocator.alloc(u8, 100); defer allocator.free(data); data[0] = 42; // Still valid`

**Detection:** Use `GeneralPurposeAllocator` during development—it never reuses memory addresses, helping catch use-after-free bugs.

### Returning Pointers to Stack Memory

`// ❌ WRONG: Dangling pointer fn createData() *u8 {     var data: u8 = 42;     return &data; // Pointer to stack memory! }  // ✅ CORRECT: Heap allocation, caller owns fn createData(allocator: std.mem.Allocator) !*u8 {     const data = try allocator.create(u8);     data.* = 42;     return data; // Caller must destroy() }`

**Prevention:** Use heap allocation for any data outliving the function scope. Document ownership clearly.

## In Practice

Production codebases demonstrate these patterns at scale:

**TigerBeetle** enforces static allocation: all memory must be allocated at startup, with no dynamic allocation during operation.[5](#fn:5) This prevents runtime surprises and forces upfront memory planning, critical for financial database correctness. Their manifest initialization shows cascading errdefer cleanup for complex nested structures.66 [TigerBeetle manifest.zig](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/src/lsm/manifest.zig#L213-216) 

**Ghostty** uses `ArenaAllocator` for terminal configuration parsing, simplifying cleanup for temporary parsing state.[2](#fn:2)

**Bun** implements custom allocators for JavaScript runtime performance, demonstrating zero-sized type optimization for nullable allocators and atomic operations for thread-safe allocation.88 [Bun allocators.zig](https://github.com/oven-sh/bun/blob/e0aae8adc1ca0d84046f973e563387d0a0abeb4e/src/allocators.zig) 

**ZLS** (Zig Language Server) conditionally selects debug vs release allocators based on build configuration, balancing safety and performance.[3](#fn:3)

**Lightpanda** (headless browser, 26k stars) demonstrates a three-tier allocator strategy:99 [Lightpanda main.zig - Dual allocator strategy](https://github.com/lightpanda-io/browser/blob/main/src/main.zig)  `DebugAllocator` with stack traces in debug mode, `c_allocator` in release mode, and a thread-safe `ArenaPool` that recycles per-request arenas via a mutex-protected free list—ideal for server workloads with many short-lived allocations.

These exemplars share common patterns: allocator-first parameter ordering, meaningful allocator names (`gpa`, `arena`), immediate defer placement, and comprehensive errdefer for multi-step initialization.

## Summary

Zig's explicit memory management model eliminates hidden allocations, making ownership and lifetime visible in the code. The uniform `Allocator` interface enables compile-time polymorphism, allowing seamless switching between allocators for different use cases.

Key principles:

*   **Allocators are explicit parameters**—no hidden allocations
*   **Choose allocators by use case**—arena for request scoping, fixed-buffer for bounded performance, GPA for safety
*   **Ownership is documented**—caller-owns, callee-returns-owned, or init/deinit pairs
*   **Cleanup is deterministic**—defer for guaranteed cleanup, errdefer for error paths
*   **Memory is either managed or unmanaged**—unmanaged containers require explicit allocator passing

Understanding these patterns provides the foundation for containers, I/O, and concurrency covered in subsequent chapters.

## References

1.  [Learning Zig - Heap Memory & Allocators](https://www.openmymind.net/learning_zig/heap_memory/)
2.  [Ghostty Config.zig - ArenaAllocator usage](https://github.com/ghostty-org/ghostty/blob/05b580911577ae86e7a29146fac29fb368eab536/src/config/Config.zig#L17)
3.  [ZLS main.zig - Arena for argument parsing](https://github.com/zigtools/zls/blob/24f01e406dc211fbab71cfae25f17456962d4435/src/main.zig#L282-288)
4.  [Zig test runner - FixedBufferAllocator](https://codeberg.org/ziglang/zig/src/branch/master/lib/compiler/test_runner.zig)
5.  [TigerBeetle TIGER\_STYLE.md - Memory conventions](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/docs/TIGER_STYLE.md)
6.  [TigerBeetle manifest.zig - errdefer cleanup](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/src/lsm/manifest.zig#L213-216)
7.  [TigerBeetle state\_machine.zig - Cascading cleanup](https://github.com/tigerbeetle/tigerbeetle/blob/dafb825b1cbb2dc7342ac485707f2c4e0c702523/src/state_machine.zig#L846-852)
8.  [Bun allocators.zig - Custom allocators](https://github.com/oven-sh/bun/blob/e0aae8adc1ca0d84046f973e563387d0a0abeb4e/src/allocators.zig)
9.  [zig.guide - Allocators](https://zig.guide/standard-library/allocators/)
10.  [Leveraging Zig's Allocators](https://www.openmymind.net/Leveraging-Zigs-Allocators/)
11.  [Introduction to Zig - Memory and Allocators](https://pedropark99.github.io/zig-book/Chapters/01-memory.html)
12.  [Defeating Memory Leaks With Zig Allocators](https://tgmatos.github.io/defeating-memory-leaks-with-zig-allocators/)
13.  [Zig 0.14.0 Release Notes](https://ziglang.org/download/0.14.0/release-notes.html)
