# Writing Idiomatic Zig

> Sources: Marcin Matklad, 2024-03-21; Luis Llamas, 2026-10-05; Nathan Craddock, 2026-10-05; J. Kingston, 2026-10-05; Zig Software Foundation, 2026-10-05
> Raw: [defer-patterns](../../raw/zig/defer-patterns.md); [error-handling-patterns](../../raw/zig/error-handling-patterns.md); [naming-conventions](../../raw/zig/naming-conventions.md); [memory-and-allocators](../../raw/zig/memory-and-allocators.md); [testing-benchmarking-profiling](../../raw/zig/testing-benchmarking-profiling.md); [zig-test-reference](../../raw/zig/zig-test-reference.md)
> Updated: 2026-10-05

## Overview

The conventions that make Zig code read like Zig: how names are chosen, how errors flow, what `defer` is actually for beyond RAII, how allocators are threaded through a program, and how to test and benchmark without lying to yourself. Distilled from the official test documentation, three practitioner guides, and TigerBeetle's published style rules as reported by them.

The through-line: **make ownership and lifetime visible in the text**. Every pattern here exists to push a decision that other languages hide into the reader's head.

## Naming

The official rules, quoted from the style guide:

> If `x` is a type then `x` should be `TitleCase`, unless it is a `struct` with 0 fields and is never meant to be instantiated, in which case it is considered to be a "namespace" and uses `snake_case`.
>
> If `x` is callable, and `x`'s return type is `type`, then `x` should be `TitleCase`.
>
> If `x` is otherwise callable, then `x` should be `camelCase`.
>
> Otherwise, `x` should be `snake_case`.

The consequence people miss: **the naming convention is determined by the type of the thing**. `struct`, `union`, `enum`, and `error` types are `TitleCase`; error names are always `TitleCase` regardless of context.

Source files are the exception that proves the rule. `@import()` returns the public declarations of another file wrapped in a struct, source files are implicitly structs, and those structs have zero fields — so they are namespaces, and namespaces are `snake_case`.

The other exception is the generic constructor. If a function returns a type, it is `TitleCase`:

```zig
fn Point(comptime T: type) type {
    return struct { x: T, y: T };
}

const IntPoint = Point(i32);
const FloatPoint = Point(f64);
```

This is the largest deviation from other systems languages and it is deliberate — seeing `TitleCase` tells you immediately that the call returns a type. Constants that store types are `TitleCase` too.

Nothing enforces this. Neither the compiler nor `zig fmt` checks names. The style guide also grants explicit permission to deviate: if an established convention exists, such as `ENOENT`, follow it.

## Errors: four tools, one decision each

The compiler will not let you consume an error union's value without handling the error. The handling you choose is a statement about intent:

| Tool | Syntax | Intent |
|------|--------|--------|
| Propagate | `try f()` | "If it fails, return the error" |
| Default | `f() catch 0` | "If it fails, use 0" |
| Branch | `if (f()) \|v\| else \|err\|` | "If it goes well, do A; if it goes wrong, do B" |
| Assert impossible | `f() catch unreachable` | "Failing here breaks a precondition" |

`try` is a prefix operator, not a block — it is shorthand for `catch |err| return err`. That is what keeps error-heavy code flat instead of nested.

`catch unreachable` needs the mode caveat: in Debug and ReleaseSafe it panics, but ReleaseFast and ReleaseSmall don't necessarily retain that check, so it degrades to undefined behavior rather than a loud failure. Reserve it for genuine broken preconditions.

`if` with capture is the same shape as unwrapping an optional, which is the point — it's Zig's one way of handling uncertain results.

## `defer` is not just RAII

Marcin Matklad's caveat is worth internalizing before the patterns: he does not like `defer` as a replacement for RAII, because humans are not good at not forgetting defers, especially when optional ownership transfer is in play. His read is that Zig naturally pushes you away from per-object ownership and toward batching — many domain objects sharing one pool of resources — because batching is what makes the defer bookkeeping tractable.

With that in mind, four uses that have nothing to do with freeing memory:

**Assert postconditions.** `defer` gives you contract programming almost for free:

```zig
{
  assert(!grid.free_set.opened);
  defer assert(grid.free_set.opened);
  // Code to open the free set
}
```

**Statically forbid errors below a point.** `errdefer comptime unreachable` — `errdefer` arms on the error path, `unreachable` crashes in ReleaseSafe, and `comptime` makes the compiler reject the runtime code entirely. The three together close the door on failure; the stdlib's hash map `grow` uses it: the function as a whole can fail, and after the allocation succeeds, `errdefer comptime unreachable` asserts that "from this point on, failure is impossible".

**Attach context to an error at the point it originates.** Error traces give you a code and a trace, which is plenty for an operator and not enough for an end user. Since an application can often get away with not propagating, log at the source:

```zig
const port = port: {
  errdefer |err| log.err("failed to read the port number: {}", .{err});
  var buf: [fmt.count("{}\n", .{maxInt(u16)})]u8 = undefined;
  const len = try process.stdout.?.readAll(&buf);
  break :port try fmt.parseInt(u16, buf[0 .. len -| 1], 10);
};
```

**Post-increment.** `defer self.count += 1` before a `return` gives you the increment-on-every-exit-path behavior without an `i++` operator.

## Allocator discipline

`std.mem.Allocator` is a vtable with four operations — `alloc(T, count)`, `free(slice)`, `create(T)`, `destroy(pointer)` — plus `alignedAlloc` when you need specific alignment. All of them return error unions with `error.OutOfMemory` as the primary failure mode.

One C-ism goes away: `alloc(T, 0)` returns a usable empty slice and freeing it is a no-op, so no defensive length checks are needed.

**Pass the allocator first**, ordered from most general to most specific. Name it for what it implies about ownership — `gpa` for a general-purpose allocator you must clean up individually, `arena` for a bulk-cleanup context. The name is documentation.

**Pick by use case:**

| Allocator | Characteristics | Best for | Trade-off |
|-----------|-----------------|----------|-----------|
| `std.testing.allocator` | Fails tests on leaks, stack traces | Tests | dev-only |
| `GeneralPurposeAllocator` | Thread-safe, catches double-free/use-after-free, never reuses addresses | Development | Safety over performance |
| `ArenaAllocator` | Bulk deallocation, `free` is a no-op | Request-scoped work, parsers, temp data | Holds everything until `deinit()` |
| `FixedBufferAllocator` | Pre-allocated buffer, often on the stack, no syscalls | Known max size, perf-critical | Fixed capacity |
| `c_allocator` | Wraps malloc/free | Release builds, C interop | No safety features |
| `page_allocator` | Direct OS page mapping (4KB min) | Large buffers, isolation | High overhead for small allocations |

Since 0.16, `std.process.Init` hands you a pre-initialized GPA as `init.gpa`, so application code can skip the manual setup. The explicit patterns below still matter in libraries, tests, and tools that don't take a `process.Init`.

**Document ownership in one of three shapes**, and say which one in a doc comment:

- *Caller-owns* — you allocate, the function only uses it.
- *Callee-returns-owned* — the function allocates, the caller must free with the same allocator.
- *Init/deinit pair* — the dominant pattern for structs; `defer` the `deinit()`.

For long-lived structs, storing the allocator as a field costs struct size but removes the need to pass it to `deinit()`. For hot paths, TigerBeetle's out-pointer style — `init()` taking `self: *Resource` and filling it in place — avoids intermediate copies and keeps pointers stable.

**Put the cleanup next to the acquisition.** Immediately after the allocating line, not at the end of the function:

```zig
const data = try allocator.alloc(u8, 100);
defer allocator.free(data);

const file = try std.fs.cwd().openFile("data.txt", .{});
defer file.close();
```

TigerBeetle's style guide goes further and recommends grouping allocations with their defers using blank lines, so leaks are visible during review rather than at runtime.

For multi-step init where a later step can fail, cascade `errdefer`, one per acquired resource, in acquisition order.

**Arenas scale better than per-object cleanup.** Reset between requests rather than freeing individually:

```zig
var arena = std.heap.ArenaAllocator.init(da.allocator());
defer arena.deinit();

while (i < 3) : (i += 1) {
    defer _ = arena.reset(.{ .retain_with_limit = 4096 });
    const response = try handleRequest(arena.allocator(), i, "data");
    // No individual frees needed
}
```

Ghostty parses its terminal configuration in an arena, ZLS does the same for argument processing, and Lightpanda recycles per-request arenas through a mutex-protected free list.

### Four allocator mistakes

1. **Early return without a defer.** `if (cond) return error.Failed;` right after an allocation leaks. The `defer` goes on the line after the allocation, not at the bottom.
2. **Freeing with a different allocator.** Allocate through `arena.allocator()`, free through `gpa` and you corrupt the arena. Store the allocator in a local and use it consistently; for arenas, rely on `deinit()`.
3. **Use-after-free.** Detect it with `GeneralPurposeAllocator` in development — it never reuses addresses, so a stale pointer is visibly stale rather than silently pointing at new data.
4. **Returning a pointer to stack memory.** If data must outlive the function, allocate it.

TigerBeetle removes the entire class by allocating all memory at startup and doing no dynamic allocation during operation.

## Testing

`zig test` compiles the file, discovers every `test` block, and runs them. Each test's implicit return type is the error union `anyerror!void` and cannot be changed; when a source file isn't built with `zig test`, the test declarations are omitted from the build entirely. Tests are top-level declarations, so they're order-independent and can live in a separate file from the code. Tests in imported modules are picked up automatically unless the import is guarded by `if (!builtin.is_test)`.

Naming a test with an identifier makes it a doctest — it documents the declaration and appears in generated docs. The runner prints `decltest` for those.

Skipping: `--test-filter [text]` includes only tests whose name contains the text (unnamed tests always run), or return `error.SkipZigTest` programmatically.

Assertions from `std.testing`: `expect` (returns an error when false), `expectEqual(expected, actual)` (casts actual to expected's type), `expectError(expected, union)`.

**The leak behavior is the important part.** Use `std.testing.allocator` and a missing `deinit()` produces a stack trace and this at the end:

```
All 1 tests passed.
1 errors were logged.
1 tests leaked memory.
error: the following test command failed with exit code 1
```

The test itself passes; the *command* fails. Don't let a green test line hide a red exit code.

`@import("builtin").is_test` tells code it's in a test build, so test-only paths compile out of real builds.

Test error paths, not just happy paths — `expectError` with each error your function can actually return, and `FailingAllocator` to exercise allocation-failure branches. Test the contract, not the implementation: asserting on `list.capacity` breaks on refactor, asserting on `items.len` and `items[0]` survives.

## Benchmarking and profiling

Benchmarking is manual instrumentation, and the failure modes are all self-deception:

- **Dead code elimination.** Without `std.mem.doNotOptimizeAway(&result)` the compiler can delete the whole loop.
- **One sample.** Context switches and cache state make a single measurement noise. Take a batch and report min/max/mean.
- **Debug mode.** Results are 10-100x slower than release; benchmark with `-O ReleaseFast`.
- **No warm-up.** The first iterations run on cold caches and a throttled CPU. Warm up, then measure.
- **Stripped binaries.** `perf record` on a stripped binary shows addresses and no function names. Build with `-Dstrip=false` and `-Doptimize=ReleaseFast`, then profile with perf on Linux, Instruments on macOS, or Callgrind/Massif under Valgrind.

Test output goes to standard error, not standard out — which is what keeps it from colliding with the build runner's protocol.

## See Also

- [Zig Problem → Solution Reference](problem-solution-reference.md) — the feature-level tour: why the language is shaped this way, C interop, cross-compilation, build-system idioms.
- [Zig Stability and Trade-offs](zig-stability-and-tradeoffs.md) — whether these patterns are worth the migration cost, and where Zig's safety story stops.
