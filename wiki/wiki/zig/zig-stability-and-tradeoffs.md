# Zig Stability and Trade-offs

> Sources: Ali Fereidani, 2026-10-05; Hacker News commenters, 2026-10-05
> Raw: [zig-tradeoffs-critique](../../raw/zig/zig-tradeoffs-critique.md); [zig-moving-target-hn-thread](../../raw/zig/zig-moving-target-hn-thread.md)
> Updated: 2026-10-05

## Overview

A single-source argument against Zig's trajectory, recorded here because the wiki's other Zig articles describe the language without ever pricing in the migration tax. The thesis: Zig is a technically excellent language whose stability posture, safety claims, documentation, and governance choices are not paying for that excellence, and the projects that prove Zig *can* work (TigerBeetle, Ghostty, `zig cc`) are the exception rather than the rule.

This is one author's position, not a settled consensus. Counter-evidence sits alongside each claim below rather than in a rebuttal section, because both sides are load-bearing for anyone choosing Zig today.

## The stability question

Zig's git history starts in 2015 and it went public in 2016. Ten years later the version number still starts with zero, there is no stability promise, and no date is named. The comparison the author draws: Go went public in November 2009 and drew its compatibility line with Go 1 in March 2012; Rust went public in 2010 and shipped 1.0 in 2015. Both made an early promise that code written today keeps working, and both grew ecosystems on that single sentence.

> People keep asking the same two questions, is Zig stable and is Zig ready for production, and ten years in I think the honest answer to both is no.

> **Status: Disputed**
> The official getting-started guide frames tagged releases as the practical choice for projects with dependencies — "In general, tagged releases are more practical for projects that have dependencies and benefit from stability" (Zig Software Foundation, via [raw/zig/getting-started.md](../../raw/zig/getting-started.md)). The position here is that a pre-1.0 toolchain that redesigns itself roughly twice a year makes that advice unusable in practice, because upgrading means repair work: "Every breaking release turns into paid hours spent repairing code that already worked, and no manager signs up for that when Rust and Go deliver the same class of software without the tax." See [Zig Problem → Solution Reference](problem-solution-reference.md#toolchain-setup).

The author's own read of what a decade of 0.x produces is not death but filtering: the users who stay are teams that can absorb a breaking release every six months, and the ordinary engineer who wants to ship something reads the upgrade notes and closes the tab.

## The counterexamples are real

The same article names them, because a critique that hides them is propaganda:

- **TigerBeetle** runs Zig in a production financial database.
- **Ghostty** shipped its 1.0 in Zig in December 2024.
- **Uber** judged `zig cc` worth a $184,800 support contract in 2023, to keep its Go cross-builds working.
- Surveys still rank Zig among the most admired languages.

The pattern worth noticing: the part of Zig that behaves like a finished product is `zig cc`, and that is the part companies actually deploy — to build C. The author's conclusion is that the set of projects where Zig's advantages outweigh a stable ecosystem keeps shrinking, and that teams needing small binaries mostly tune Rust with `build-std` rather than adopt a pre-1.0 toolchain.

## Standard library churn is the concrete cost

Zig 0.15, released in August 2025, deprecated every reader and writer in the standard library and replaced them with a new design. The release notes named the event Writergate and described their own release as rocking the boat "with tidal waves of breaking API changes." The same release removed the `usingnamespace` keyword and the `async` and `await` keywords. Networking was rebuilt on the new I/O interface in 0.16.

> Whatever you learn about `std` this year is a draft.

There is a second-order effect the wiki's own raw material shows. This repository's own Zig pages currently mix APIs from several versions — the overview's examples use `std.fs.cwd()` while the build-system guide's examples use `Io.Dir.cwd()` with a `std.process.Init` parameter — which is exactly the failure mode the churn produces. A user following two official pages on the same day can end up with mutually incompatible code.

An independent thread makes the same point from a developer's seat. Asked to produce a simple TCP echo server in Zig, an assistant produced code that failed to compile twice in a row against different versions:

```
zig build-exe main.zig main.zig:30:21: error: no field named 'io' in struct 'process.Init.Minimal'
```

and against 0.15.2:

```
zig.lang.org isn't in the allowed domains...
/opt/homebrew/Cellar/zig/0.15.2/lib/zig/std/Io/Writer.zig:1200:9: error: ambiguous format string; specify {f} to call format method, or {any} to skip it
```

The author's read of that: weak documentation used to cost a language its beginners, and now it also costs the AI tooling story those beginners expect, because the assistant learned Zig from the same thin corpus smeared across incompatible versions of `std`.

## Where the safety story stops

This is the part most worth internalizing before writing Zig:

> Zig sells itself as safer than C, and it is, when the checks are on. That claim has a precise boundary and the marketing never draws it. Zig's safe build modes check bounds, integer overflow, and similar mistakes, which is to say whether a pointer lands inside its object. They do not check whether the object is still alive.

> No release mode of the Zig compiler prevents use-after-free or double-free. The debug allocator can catch some of these in test runs. In production, nothing does.

Two counterweights, both from the article and both honest:

- TigerBeetle proves the other direction — with static allocation, heavy assertions, and what the author calls NASA-grade discipline, a team can write solid Zig.
- C had those teams too. "A guarantee that only holds for teams with TigerBeetle's discipline describes the team, not the language."

## Bun: the showcase that left

Bun was the flagship: a JavaScript runtime with 22 million monthly downloads and over half a million lines of Zig, written by a team with every reason to make Zig look good. That team patched the Zig compiler to run Address Sanitizer on every commit and shipped safety-checked builds on Windows.

Their rewrite announcement still lists a "heap-use-after-free crash in `node:zlib`", use-after-free crashes in `node:http2` where a hashmap rehash invalidated live stream pointers, and a double-free in the CSS parser. Every one belongs to the class the safe modes do not cover — and the class a borrow checker rejects before the program exists.

Jarred Sumner writes "I don't blame Zig for that," because Bun sits between JavaScriptCore's garbage collector on one side and manual memory on the other, an unusually hard combination.

Then the corporate decision: Anthropic acquired Bun in December 2025, and in July 2026 Jarred Sumner published *Rewriting Bun in Rust*. His reasons were "the quiet kind": the bugfix list "felt bad", he was "tired of going to sleep worrying about crashes in Bun", and the lifetimes at the border between the GC and Zig's manual memory could not be made safe at the speed his team ships.

He thanks Zig warmly, notes that until recently language choice "was a one-way decision" for a project like Bun, and says he rewrote it in eleven days with AI doing the mechanical work and the test suite holding the line.

> Every argument in this article meets in that story.

## Smaller claims worth knowing

- **Windows is built on `ntdll.dll`**, the layer below the documented Win32 API. The engineering rationale is coherent — skipping the Windows SDK and the MSVC runtime is how Zig cross-compiles to Windows from any machine with nothing installed — but Microsoft's compatibility promise lives at the Win32 layer and not below it. Go ran the same experiment on macOS and the BSDs, retreated to calling through the platform's C libraries, and Zig chose the exposed position anyway.
- **Feature churn follows a cycle**: ship a major feature, leave it broken for years, then remove it. The author names async as the case that cost the most trust.
- **Documentation is auto-generated, thin on examples, and often out of step with the compiler you are running.** The community's standing advice to newcomers is to read the standard library source. The source is readable; "read the source" is a filter, not an onboarding plan.
- **The D parallel.** D arrived as a modern successor to C++, spent its credibility on the Phobos/Tango split and the D1-to-D2 break, and settled into "a small permanent niche." The author's worry is that Zig is writing the same story.

## What the author actually recommends

Not abandonment. The repairs are named as unglamorous: a dated, honest path to 1.0; a compatibility promise even a modest one; answering critics instead of fighting them; an AI policy that regulates contributions instead of banning the mention of a tool.

> Zig does not need to become a different project. It needs to stop drilling holes in itself.

## Practical read for a new project

If this article is right about even half of it, the mitigation is the one its own evidence points at — minimize dependencies, pin a version, and treat `std` as a draft. The parts of Zig that survive regardless are comptime (the most elegant metaprogramming idea of its generation, by this account), C interop, small binaries, and allocation you can see.

## See Also

- [Zig Problem → Solution Reference](problem-solution-reference.md) — the feature tour; its setup section carries the other side of the stability dispute.
- [Writing Idiomatic Zig](writing-idiomatic-zig.md) — the patterns that survive regardless of which way the stability question resolves.
