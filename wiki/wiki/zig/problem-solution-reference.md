# Zig Problem → Solution Reference

> Sources: Zig Software Foundation, 2026-10-05
> Raw: [learn-index](../../raw/zig/learn-index.md); [overview](../../raw/zig/overview.md); [why-zig](../../raw/zig/why-zig.md); [getting-started](../../raw/zig/getting-started.md); [build-system](../../raw/zig/build-system.md); [samples](../../raw/zig/samples.md); [tools](../../raw/zig/tools.md)
> Updated: 2026-10-05

## Overview

A lookup table of recurring Zig problems — the ones a C, C++, Rust, or D programmer actually hits — paired with the language or toolchain feature that answers them. Compiled from the official `ziglang.org/learn/` guides, which are feature tours rather than tutorials: every claim here is traceable to one of the seven raw pages linked above.

Two problems drive most of Zig's design: **code that lies about what it runs**, and **code that allocates behind your back**. Nearly everything else below follows from those.

## Toolchain setup

**Problem: I don't know whether to install a tagged release or a development build.**
Tagged releases are the practical choice for projects with dependencies; development builds are for people contributing to Zig itself. Installs are self-contained archives, so multiple versions coexist, and you put them wherever and add that directory to `PATH`.

> **Status: Disputed**
> A critique of Zig's stability posture argues the opposite: "Every breaking release turns into paid hours spent repairing code that already worked, and no manager signs up for that when Rust and Go deliver the same class of software without the tax." See [Zig Stability and Trade-offs](zig-stability-and-tradeoffs.md#the-stability-question).

**Problem: My editor only highlights Zig syntax.**
Use `zigtools/zls` instead of a syntax-highlighting extension. The `tools` page's argument: consider a language server over a syntax-highlighting extension for a richer development experience. Highlighters exist for VS Code, Visual Studio, Sublime, Vim, Emacs, Kate, and the JetBrains family; the LSP is the one worth installing.

**Problem: I want a project skeleton that already builds.**
`zig init` scaffolds the whole thing:

```
info: created build.zig
info: created build.zig.zon
info: created src/main.zig
info: created src/root.zig
info: see `zig build --help` for a menu of options
```

`zig build run` then compiles and runs, and `zig build test` runs the tests. The overview notes the same scaffold drives an older-style `build.zig` where `zig build run` prints `All your codebase are belong to us.`

**Problem: I want to see the whole toolchain surface at once.**
`zig build --help` prints every step, project option, system-integration option, and general option — including `--summary`, `--watch`, `--webui`, `--fuzz`, `--time-report`, and the per-scope `--seed`.

## Language design

**Problem: I can't tell what code is actually running.**
Zig's rule: if it doesn't look like it's jumping away to call a function, it isn't. No operator overloading, no `@property`-style field access that calls a function, no exceptions. So this provably calls `foo()` then `bar()` and nothing else, without knowing any types:

```zig
var a = b + c.d;
foo();
bar();
```

The contrast cases are named explicitly: D's `@property` functions make `c.d` potentially a call; operator overloading in C++, D, and Rust makes `+` potentially a call; throw/catch in C++, D, and Go makes `foo()` potentially skip `bar()`. Zig also has no preprocessor and no macros, and its entire syntax is a [580-line PEG grammar file](https://ziglang.org/documentation/master/#Grammar).

**Problem: My code allocates without telling me.**
There is no `new`, and no language feature reaches a heap allocator — the array concatenation operator exists but only works at compile time. Every stdlib API that allocates takes an `Allocator` parameter. The stated payoff: if you never initialize a heap allocator, you can be confident your program will not heap allocate.

What other languages do that Zig doesn't, per the docs: Go's `defer` allocates function-local stack memory (and can OOM inside a loop); C++ coroutines allocate heap memory to call a coroutine; a Go call can allocate because goroutine stacks get resized; the main Rust stdlib APIs panic on OOM and the allocator-accepting variants are "an afterthought."

**Problem: I want to catch memory bugs.**
Note the boundary: Zig's safe build modes check bounds and integer overflow — whether a pointer lands inside its object — not whether the object is still alive. No release mode prevents use-after-free or double-free; in production the debug allocator is not running either. See [Zig Stability and Trade-offs](zig-stability-and-tradeoffs.md#where-the-safety-story-stops).

Three allocators cover most cases: a debug allocator that stays correct in the face of use-after-free and double-free and prints stack traces of leaks, an arena allocator that frees everything at once, and special-purpose allocators for a specific workload. In practice you wire `std.heap.DebugAllocator(.{}){}` up and assert on `deinit()`:

```zig
var debug_allocator = std.heap.DebugAllocator(.{}){};
defer std.debug.assert(debug_allocator.deinit() == .ok);
const gpa = debug_allocator.allocator();
```

Forgetting a `free` produces a leak report with a full stack trace, then a panic from the deferred assertion. In tests, `std.testing.allocator` does the same job per-test.

**Problem: I can't use this on bare metal / in a kernel.**
The standard library is entirely optional and each API is only compiled in if you use it. Linking libc or not linking libc are equally supported. Because allocators are parameters, `std.ArrayList` and `std.AutoHashMap` work on freestanding targets. Stack traces and error return traces work on all Tier 1 targets, some Tier 2, and even freestanding.

**Problem: Null pointers keep crashing me.**
Unadorned Zig pointers cannot be null — `@ptrFromInt(0x0)` into a `*i32` is a compile error (`pointer type '*i32' does not allow address zero`). Prefix any type with `?` to make it optional instead. Three ways to unwrap:

```zig
const ptr = malloc(1234) orelse return null;   // default value
if (optional_foo) |foo| { ... }               // if
while (it.next()) |item| { ... }              // while / for
```

**Problem: Errors get silently dropped.**
Errors are values and may not be ignored — dropping one is a compile error, not a warning. Three idioms: `catch` to recover, `try` as shorthand for `catch |err| return err`, and `switch` on the error value, which the compiler enforces is exhaustive (`switch must handle all possibilities`, listing each unhandled error). `catch unreachable` asserts success; in unsafe build modes that's undefined behavior, so it belongs only where success is guaranteed.

A `try` failure prints an **Error Return Trace**, not a stack trace — the code did not unwind the stack to produce it.

**Problem: Cleanup code gets lost in the middle of a function.**
`defer` handles normal exits, `errdefer` only the error path:

```zig
const device = try allocator.create(Device);
errdefer allocator.destroy(device);
device.name = try std.fmt.allocPrint(allocator, "Device(id={d})", id);
errdefer allocator.free(device.name);
if (id == 0) return error.ReservedDeviceId;
```

**Problem: Integer overflow is undefined behavior in C and I can't see where it happens.**
Compile-time overflow is always an error regardless of build mode. Runtime overflow in safety-checked builds panics with a stack trace. For a known hot spot, opt out explicitly with `@setRuntimeSafety(false)` — at which point the same code is genuinely undefined behavior, marked as such in the example's own comment.

There are four build modes (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall) and safety can be mixed and matched down to scope granularity.

**Problem: I need a generic container.**
There is no generic syntax. A generic type is a function that returns a `type`:

```zig
fn List(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
    };
}
```

Types are first-class values known at compile time, so `const T1 = u8;` is a real binding.

**Problem: I need reflection or compile-time code generation.**
`@typeInfo` walks a type's fields; pair it with `inline for` over `info.field_types` and `info.field_names`. Functions and blocks can run at compile time with `comptime`, and combining that with assertions catches mistakes at build time — the fibonacci example allocates `[fibonacci(6)]i32` and the deliberately false `assert(array.len == 12345)` fails as a compile error with `note: called at comptime here`.

Zig's formatted printing is implemented this way, entirely in the stdlib. The contrast: in C, printf compile errors are hard-coded into the compiler; in Rust, the `format!` macro is hard-coded into the compiler.

**Problem: My binary is too big.**
`zig build-exe hello.zig -O ReleaseSmall -fstrip -fsingle-threaded` yields a 9.8 KiB static x86_64-linux executable (`wc -c` reports `9944`, `ldd` reports `not a dynamic executable`). The Windows build of the same program is 4096 bytes.

**Problem: My build is slow and I want to see why.**
All Zig code lives in one compilation unit optimized together. Beyond that, Zig is faster than C by way of deliberately chosen illegal behavior — both signed and unsigned integers have illegal behavior on overflow, which enables optimizations unavailable in C — plus a first-class SIMD vector type, hash maps and array lists in the stdlib instead of linked lists, and advanced CPU features on by default unless cross-compiling.

## C interop and portability

**Problem: I have a C library and don't want to write bindings.**
`@cImport` + `@cInclude` imports types, variables, functions, and simple macros directly, and translates inline C functions into Zig. The libsoundio sine-wave example uses it with zero bindings and is described as significantly simpler than the equivalent C while having more safety protections. The docs' summary: *Zig is better at using C libraries than C is at using C libraries.*

**Problem: Other languages need to call my library.**
`export` in front of functions, variables, and types makes them part of the C ABI API. `zig build-lib` makes a static library, `zig build-lib -dynamic` a shared one. The build system route is `b.addSharedLibrary(...)` plus `exe.linkLibrary(lib)` and `exe.linkSystemLibrary("c")`.

**Problem: I want Zig to build my project's C too.**
`zig build-exe hello.c -lc` compiles and links it. `--verbose-cc` shows the exact `zig cc` command line. Re-running it finishes instantly (`real 0m0.027s`) because Zig parses the `.d` file and caches build artifacts.

**Problem: I need to cross-compile, or I need libc on the target.**
`-target` builds for any supported target regardless of host — no separate cross toolchain. `zig targets` lists the libc targets. Because Zig ships libc sources and compiles them on demand, `-lc` for those targets depends on no system files: the same static-link trick that glibc refuses (it can't build statically) works via `-target x86_64-linux-musl`, and Zig builds musl from source and caches it.

The scaling argument, from the overview: Zig's libc headers total 130 MiB uncompressed versus 8 MiB for musl + Linux headers and 3.1 MiB for glibc on x86_64, yet Zig ships 97 libcs where naive bundling would be 776 MiB. Header processing plus manual curation keeps binary tarballs at roughly 50 MiB, against 132 MiB for the Windows binary build of clang 8.0.0 itself.

**Problem: My open-source project's contributors can't build it.**
Zig's build system and package manager replace autotools, cmake, make, scons, or ninja, and work even when the codebase is entirely C or C++. The cited example: porting ffmpeg to the Zig build system makes it compilable for any supported target using only a 50 MiB download of Zig. The stated pattern — dependencies come from the Zig package manager rather than the user's system package manager, so the first build attempt succeeds regardless of the user's platform.

## Build system

**Problem: My build command line is unwieldy, or the build has many steps.**
`zig build-exe`, `zig build-lib`, `zig build-obj`, and `zig test` are often enough. Bust out to `build.zig` when the command line gets long, when you build many things, want concurrency and caching, need configuration options, need target-dependent behavior, have dependencies, want to drop cmake/make/shell/python, want to publish a package, or want a standardized way for IDEs to understand the build.

The model: a DAG of steps that run independently and concurrently. The default root step is **install**, which copies artifacts to a prefix. The maintainer decides *what* is installed; the user decides *where* via `--prefix` / `-p`. Hardcoding output paths breaks caching, concurrency, composability, and annoys the user.

Two generated directories: `.zig-cache` (deletable at any time with no consequences, never checked in) and `zig-out` (the installation prefix).

**Problem: I want users to configure my build.**
`b.option` exposes anything; `b.standardTargetOptions` and `b.standardOptimizeOption` give the conventional `-Dtarget=` and `-Doptimize=`. These show up auto-generated in the help menu under "Project-Specific Options", so users can discover them without reading the source.

**Problem: I want build-time values visible to my Zig code.**
Use the Options step — `b.addOptions()` plus `exe.root_module.addOptions("config", options)` — and `@import("config")` in the source. The data is comptime-known, so build flags can gate code at compile time: `config.have_libfoo` selects whether `foo_bar()` is called, and a version check that fails becomes `@compileError("too old")`.

**Problem: My unit tests compile but never run.**
Tests split into a Compile step and a Run step, and without `addRunArtifact` establishing the dependency edge the tests are not executed.

**Problem: I want to run tests on several targets, but the host can't execute them.**
Loop over `std.Target.Query` values, call `b.addTest` + `b.addRunArtifact` per target, and set `run_unit_tests.skip_foreign_checks = true` so foreign-architecture targets compile without failing the run.

**Problem: My test output is jumbled or my tests print to stdout.**
The build runner and test runner communicate over stdin and stdout to run suites concurrently and report failures meaningfully. Printing to stdout in a unit test interferes with that channel.

**Problem: I need a system library.**
`exe.root_module.linkSystemLibrary("z", .{})` with `.link_libc = true`. The docs draw a distinction: for upstream maintainers, getting the library through the Zig build system is the preferred path because everyone gets reproducible results and cross-compilation works; for distro packaging (Debian, Homebrew, Nix) linking system libraries is mandatory, so build scripts must detect the mode and configure accordingly. Users can add search paths with `--search-prefix`.

**Problem: I need to generate source files as part of the build.**
Preferred over shelling out to a system tool, because system dependencies make the project harder for others to build. Build a Zig tool with `b.addExecutable`, run it with `b.addRunArtifact`, capture its output with `tool_step.addOutputFileArg("person.zig")`, and hand it to the app with `exe.root_module.addAnonymousImport("person", .{ .root_source_file = output })`. The graph shows the dependency explicitly — `compile exe hello` depends on `run exe generate_struct (person.zig)`.

For files sharing a parent directory, the **WriteFiles** step generates into `.zig-cache` and exposes each file as a `std.Build.LazyPath`.

**Problem: I want to ship release binaries for many targets.**
Loop over target queries, build each executable, and use `b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .{ .custom = try t.zigTriple(b.allocator) } } })` so each lands in its own subdirectory — aarch64-macos, aarch64-linux, x86_64-linux-gnu, x86_64-linux-musl, x86_64-windows.

## Known costs

**Problem: Zig has no macros and I miss my metaprogramming.**
Accepted trade: Zig is still expressive enough without them, because comptime + reflection cover the same ground in the stdlib. The counterweight is that things C and Rust hard-code in the compiler live in Zig's stdlib instead.

**Problem: The stdlib APIs in the official guides don't always match the compiler in the same page.**
The build-system guide's own unit-testing example fails to compile against the compiler it documents: `struct 'array_list.Aligned(i32,null)' has no member named 'init'`, against `std.ArrayList(i32).init(std.testing.allocator)`. Expect churn; the pages are `master` docs for nightly builds.

**Problem: The project is young.**
Official line: Zig doesn't yet have the capacity to produce extensive documentation and learning materials for everything, so join one of the existing communities, check zig.guide and the Ziglings exercises, and note that nightly builds should use `master` docs while tagged releases have versioned docs.

## See Also

- [Writing Idiomatic Zig](writing-idiomatic-zig.md) — naming, error flow, `defer` beyond RAII, allocator discipline, and testing/benchmarking rules.
- [Zig Stability and Trade-offs](zig-stability-and-tradeoffs.md) — what the migration tax and the safety boundary cost.
