# Zig: A Good Language Drowning in Bad Decisions

> Source: https://fereidani.com/zig-a-good-language-drowning-in-bad-decisions
> Collected: 2026-10-05
> Published: Unknown

# Zig: A Good Language Drowning in Bad Decisions

> _Disclaimer: I am not a professional Zig developer. I am a language enthusiast who switches stacks when better technology arrives. I started with C and VB6 in 2005, added PHP for web work in 2006, then moved to Node.js. I followed Go from its introduction in 2009 and had moved everything to it by 2013. I started testing Rust in 2015 and made it my main language by 2018, once its async story matured. Zig has been in that same holding pattern ever since: I write toy programs with it and use it as a C compiler. Read this as the view of a pragmatic evaluator, not a Zig insider, from someone who pays for his tool choices with his own working hours._

_Updated in July 2026 with the Bun rewrite and other events that happened after the first version of this post._

I have long held that if LLVM was the defining achievement of compiler design in the 2000s and 2010s, Zig is its equivalent in the 2020s. One toolchain that compiles Zig, C, and C++ from any platform to any platform, out of the box, is something neither GCC nor Clang ever gave us. As a compiler enthusiast, I was sold.

Writing this is not easy for me. I believe Zig is failing, and the language itself is the best part of the project. Every hole I can find was drilled from the inside.

## The D language already walked this road

D arrived as a modern successor to C++, with smart design and a passionate early community. Then it spent its credibility on years of instability: the Phobos and Tango standard library split, the D1 to D2 break, the long wait for stable footing, no serious corporate backer. The community lost faith one contributor at a time.

D never died. You can still write D today and some people love it. It settled into a small permanent niche, and "niche" was the polite word its early believers had to accept. Zig, I fear, is writing the same story.

## Delayed 1.0 and waning momentum

Zig's git history starts in 2015, and Andrew Kelley introduced it publicly in 2016. Ten years later the version number still starts with zero, there is no stability promise, and the team does not name a date. To be fair, they never promised one, so you cannot accuse Zig of missing a deadline it refused to set. Refusing to set one has its own price.

Go went public in November 2009 and drew its compatibility line with Go 1 in March 2012, less than three years later. Rust went public in 2010 and shipped 1.0 in 2015. Both said, early, that code you write today will keep working, and both grew their ecosystems on that one sentence.

Zig asks the opposite. It asks every user to keep every program current with a language that redesigns itself twice a year.

People keep asking the same two questions, is Zig stable and is Zig ready for production, and ten years in I think the honest answer to both is no. Courage has nothing to do with it. Every breaking release turns into paid hours spent repairing code that already worked, and no manager signs up for that when Rust and Go deliver the same class of software without the tax.

Honesty requires the counterexamples. TigerBeetle runs Zig in a production financial database. Ghostty, one of the most anticipated terminal releases in years, shipped its 1.0 in Zig in December 2024. Uber thought `zig cc` was worth a $184,800 support contract in 2023, to keep its Go cross-builds working. Zig is not dead and it is not dying, and surveys still rank it among the most admired languages.

What a decade of 0.x has done instead is filter. The users who stay are the rare teams that can absorb a breaking release every six months. The ordinary engineer who wants to ship something reads the upgrade notes, closes the tab, and the ecosystem that engineer would have added never appears.

## Lack of a stable standard library

You do not need my word for this one, the release notes say it themselves. Zig 0.15, released in August 2025, deprecated every reader and writer in the standard library and replaced them with a new design. The release notes named the event [Writergate](https://ziglang.org/download/0.15.1/release-notes.html#Writergate) and describe their own release as rocking the boat "with tidal waves of breaking API changes." The same release removed the `usingnamespace` keyword and the `async` and `await` keywords. That is one minor version.

Go made the opposite bet in 2012 and has been collecting ever since. Code from a decade ago still compiles, so a decade of tutorials, answers, and libraries still works. That single promise built more ecosystem than any feature Go ever shipped.

Zig's standard library cannot promise that the way you print to stdout survives the next release. The 0.15 notes include a migration guide for `std.io.getStdOut().writer().print()`. Networking was rebuilt on the new I/O interface in 0.16. Whatever you learn about `std` this year is a draft.

## Unstable feature set: a cycle of addition and removal

Zig has a habit of shipping a major feature, leaving it broken for years, then removing it. Async is where the habit cost the most trust.

### Async saga

The timeline, taken from the project's own releases:

*   2018: Zig adds `async` and `await`. Developers build event loops, libraries, and frameworks on them.
*   October 2022: Zig 0.10 switches to the new self-hosted compiler, which cannot compile async code. A flag keeps the old compiler available for one more release.
*   August 2023: Zig 0.11 deletes the old compiler. Async code no longer builds at all. The keywords stay in the grammar as a promise.
*   August 2025: Zig 0.15 removes the keywords and closes the question. The notes state it plainly: "it is settled that there will not be async/await keywords in the language."
*   2026: Zig 0.16 ships the replacement, a new [`std.Io` interface](https://ziglang.org/download/0.16.0/release-notes.html#IO-as-an-Interface) where functions take an `io` parameter the same way Zig functions already take an allocator.

Read that timeline as a user. If you built on async in its first four years, your code stopped compiling in 2023 and had no supported path forward until 2026. That is three years without an answer to concurrency, in the exact years when async I/O became the entry requirement for server software.

The new design is genuinely interesting: explicit, testable, and honest about the difference between asynchrony and parallelism. It is also brand new, shipping its first version a decade into the language's life, while Rust's async has been stable since 2019.

#### The real cost: developers left with broken code

The redesign itself is not the damage. Languages are allowed to correct course, and the old implementation had real problems. The damage is what the process taught.

People came back to a Zig project after six months away and found that nothing compiled. Not because they wrote bad code, but because the language moved under them. Zig ships no migration tool the way Go ships `go fix`, so you repair your code by hand, release after release.

The community learned the lesson the compiler kept teaching: do not invest too deeply here. A language cannot teach that lesson for ten years and then ask for trust at 1.0.

## The false promise of safety

Zig sells itself as safer than C, and it is, when the checks are on. That claim has a precise boundary and the marketing never draws it. Zig's safe build modes check bounds, integer overflow, and similar mistakes, which is to say whether a pointer lands inside its object. They do not check whether the object is still alive.

No release mode of the Zig compiler prevents use-after-free or double-free. The debug allocator can catch some of these in test runs. In production, nothing does. The bugs that kill C programs, the ones where memory dies while a pointer still points at it, pass straight through every safety setting Zig offers. And the performance-minded users Zig attracts turn the remaining checks off with `ReleaseFast` anyway.

Bun measured what this means at scale. It was Zig's flagship: a JavaScript runtime with 22 million monthly downloads and over half a million lines of Zig, written by a team with every reason to make Zig look good. That team patched the Zig compiler to run Address Sanitizer on every commit and shipped safety-checked builds on Windows.

Their [rewrite announcement](https://bun.com/blog/bun-in-rust) still lists, in its own words, a "heap-use-after-free crash in node:zlib", use-after-free crashes in node:http2 where a hashmap rehash invalidated live stream pointers, and a double-free in the CSS parser. Every one of those belongs to the class the safe modes do not cover, and the class a borrow checker rejects before the program exists.

Two honest notes. Jarred Sumner writes "I don't blame Zig for that", because Bun sits between JavaScriptCore's garbage collector on one side and manual memory on the other, an unusually hard combination that no language designs for. And TigerBeetle proves the other direction: with static allocation, heavy assertions, and NASA-grade discipline, a team can write solid Zig.

Both points are true and neither rescues the promise. A guarantee that only holds for teams with TigerBeetle's discipline describes the team, not the language. C had those teams too.

## Poor documentation and steep learning curve

The standard library documentation is auto-generated, thin on examples, and often out of step with the compiler you are running. The community's standing advice to newcomers is to read the standard library source. The source is readable, to its credit, but "read the source" is a filter, not an onboarding plan.

Comptime, error unions, and allocator passing are new ideas that deserve real teaching material. After ten years the project still leaves that work to blog posts and forum threads.

There is also a modern twist. When documentation is thin, developers ask an AI assistant. The assistant learned Zig from that same thin corpus, smeared across five incompatible versions of `std`, and its Zig answers come out confidently wrong. Weak documentation used to cost a language its beginners. Now it also costs the tooling story those beginners expect.

## Technical idealism over platform stability

On Windows, Zig's standard library talks to the operating system through `ntdll.dll`, the layer underneath the documented Win32 API. The engineering reasons are coherent: skipping the Windows SDK and the MSVC runtime is part of how Zig cross-compiles to Windows from any machine with nothing installed.

The problem is that Microsoft's compatibility promise lives at the Win32 layer and not below it. Native API details have shifted between Windows builds before, and programs that bypass the contract break with them.

Go already ran this experiment and published the result. It made raw system calls on macOS and the BSDs until OS updates kept breaking its binaries, then retreated to calling through the platform's C libraries like everyone else. Zig knows this history and chose the exposed position anyway, because out-of-the-box cross-compilation matters more to the project than the enterprise checklist. That is a real ranking of values, honestly held. It is also one more reason a careful platform team says no.

## Ideological and emotional decisions

Some of Zig's most expensive choices were not technical. The last two years produced enough controversy that parts of the internet now search for it by name, the Zig crashout, and one pattern runs through all of it: when principle and adoption conflict, principle wins, and the cost lands on the community.

Principle is not a flaw. But a pre-1.0 language fighting for relevance cannot keep pretending the cost is zero.

### Leaving GitHub, moving to Codeberg

In November 2025, Zig moved its development from GitHub to Codeberg. The [official announcement](https://web.archive.org/web/20251127021007/https://ziglang.org/news/migrating-from-github-to-codeberg/) gave its reasons: GitHub Actions had become unreliable and neglected, Microsoft's ownership and AI push were objectionable, and Copilot features kept funneling AI-generated submissions into a project that forbids them. Parts of that are true. The CI complaints were concrete and documented, and the scraping of open source code is a real grievance.

The move still traded discoverability away at the worst possible moment. GitHub is where contributors already are. Every new account, unfamiliar workflow, and broken link filters a few more of them out, and a project whose own foundation admits that good pull requests already sit unreviewed should think twice before adding friction at the front door.

It also raises questions nobody answered. How stable is the system they moved to? Does Codeberg solve these infrastructure and political problems long term, or does it just trade one set of bottlenecks for another? And is it fair to ask developers to learn a smaller, less visible platform as the price of contributing to a language?

The announcement's tone deserves its own sentence, because this was official project communication. It says GitHub "sold out to Microsoft", describes GitHub Actions as "created by monkeys", and refers to "the lackeys at Microsoft". Keep that tone in mind, it is not an isolated case.

### Toxic and unprofessional interactions

A healthy open source project welcomes criticism, engages respectfully with its peers, and makes contributors feel valued. By these measures Zig's leadership has fallen short in ways that are hard to overlook.

Ten days after Writergate landed, Andrew Kelley published [An Open Letter to Everyone I've Butted Heads With](https://andrewkelley.me/post/open-letter-everyone-butted-heads.html). Then in July 2026, one day after Bun announced its move to Rust, he published [a response](https://andrewkelley.me/post/my-thoughts-bun-rust-rewrite.html) that calls Bun's codebase the prime example of "How Not To Write Zig Code", says its founder "was already writing slop well before he had access to LLMs", passes along secondhand stories about what kind of manager he is, and reports that the foundation was "ecstatic" to see the language's most famous project go.

Whatever the private frustrations were, he published that the day after losing the language's flagship.

Then, once the post had been read everywhere and the damage was finished, he edited the ending. The new conclusion says the post "has been characterized as a personal attack" and that his framing "didn't work" because he had "unprocessed emotions of resentment, that were obvious to the reader, but not to myself".

Read what that sentence actually does. The insults are still on the page. Nothing was retracted, nobody was apologized to, and the same updated section says he stands by his criticism of Jarred's leadership. What he corrected was the reader's characterization of his post, which means the failure belongs to how it was read rather than to the man who chose the words.

This is the habit, not the exception. Attack in public, wait until the post has done its work, then arrive late with a paragraph that admits a feeling and concedes nothing: no responsibility, no repair, no promise to stop. It is the same move as the open letter below, and by now it is a pattern anyone can time.

The consequences are real. Talented engineers avoid communities with a reputation for hostility, and they weigh culture before they weigh code quality. Nobody files an issue explaining that they left. They just spend their evenings somewhere else, and that quiet loss compounds every other problem in this article.

For me this was the end of the Zig saga. I will not contribute to, endorse, or rely on a language whose leader acts like a toxic ex.

#### The non-apology

The open letter deserves a closer look, because it was the project's one chance to reset.

It opens by insisting it is "not a reaction to recent events or some kind of apology" because "nothing happened". That framing kills any appearance of accountability in the first paragraph. What follows is warm, thoughtful, and specific about nothing: no incident named, no person acknowledged, no behavior committed to change.

It offers to "literally buy you a drink" and promises to "crank up the empathy dial", and in the same breath promises to keep "protecting" Zig "from those who would destroy or corrupt it" and to "fight back" whenever someone talks badly about Zig in public.

An apology has three parts: ownership, specifics, and a change. This letter has high empathy signaling and none of the three. For contributors who had clashed with leadership and hoped for something real, it confirmed their concerns instead of addressing them.

#### Blame culture and the self-validation loop

The same reflex points downward at users. When someone reports a memory bug or a rough edge, the standard community answer is that the programmer lacked discipline. When adoption lags, the answer is that mainstream developers cannot handle a real systems language. Even the code of conduct tells users not to file language proposals and instead to convince a core team member to champion the idea for them.

Each of these is defensible on its own. Together they sketch a project that treats outside input as a threat to manage. A community that reads every user struggle as the user's failure has closed the main channel through which tools improve, and leadership that models the attitude from the top makes the loop self-reinforcing.

### AI ban and resisting inevitable change

Zig banned AI contributions outright. The code of conduct calls it a [Strict No LLM / No AI Policy](https://ziglang.org/code-of-conduct/#strict-no-llm-no-ai-policy), and it deserves quoting, because paraphrase softens it:

> No LLM-generated content, whether it be code or prose. No paraphrasing LLM-generated content. No LLMs for editing, including fixing spelling or grammatical errors. No LLMs for translation. \[...\] No LLMs for finding bugs. No talking about use of chatbot/LLM services.

The strongest version of Zig's position is stronger than most critics admit, so let me make it. Loris Cro of the Zig Software Foundation [lays out the economics](https://kristoff.it/blog/contributor-poker-and-ai/): a new contributor's first pull request usually costs maintainers more effort than it saves, and the investment pays off later, through the person, who learns, stays, and becomes trusted. You bet on the contributor, not the patch. A generated patch breaks that bet, because there may be no person growing behind it.

After the Bun acquisition connected Zig's name to the AI world, the project reports a wave of exactly those drive-by submissions. And Zig is not alone. Gentoo, NetBSD, and QEMU restrict AI contributions too, mostly over copyright worries.

Now read the reach of the text above. It does not ban low-effort patches. It bans a non-native English speaker from using a model to fix their grammar, in a community that says English is not required and that readers should machine-translate posts with whatever tool they like, which in 2026 means an LLM. It bans using a model to find a real bug, no matter who confirms it. It bans talking about the tools at all.

Gentoo has been shipping since 2002 and defends settled ground, so it can afford a purity rule. A pre-1.0 language needs its next ten thousand contributors, and it has posted a sign on the door saying that the way most of them now work, and the way most of them will first explore Zig, is unwelcome.

The deeper cost is a feedback loop. Coding models learn from public code. Rust, Go, Python, and TypeScript have huge public corpora, so assistants are good at them, so more code gets written and published, so the next model is better again. Zig's corpus is small, its API surface changes twice a year, and its policy pushes AI-assisted work out of sight. Every year this loop runs, the gap widens between writing Rust with an assistant that knows it and writing Zig against one that guesses.

Companies are not sentimental about this. They measure delivery speed, they have already standardized on the assistants, and a language hostile to those tools does not read as principled to them. It reads as slow.

Of all the problems in this article, I believe this one is the decision that ends the story, and the Bun rewrite is why. Until now, half a million lines in your language meant the user was locked in, and the cost of leaving protected you. Bun's Zig codebase was 535,496 lines without comments, the kind of number that used to mean a rewrite would cost a small team a year. It took eleven days to go from the first file to the whole test suite passing on every platform, using roughly fifty automated Claude Code workflows with that test suite as the referee.

That protection is gone. A language now keeps its flagship projects only by being worth staying for, and Zig picked this exact decade to make its ecosystem smaller, its contributor funnel narrower, and its tooling story worse.

## Shrinking contributor base and bus factor risk

Zig's contributor base was never large, and the people who carry it are few. The foundation's own writing admits that incoming pull requests exceed the energy available to review them, and that good ones have waited long enough for their authors to walk away. Some longtime contributors have drifted off over the past two years, a few naming the churn or the management style on the way out, others just going quiet.

The knowledge that remains sits with a handful of people. If one of them stops, whole areas of the compiler stop with them. For a project whose hardest promises are still ahead of it, that is a fragile position.

The foundation pays contributors where it can, which is the right move. But money keeps people fed, it does not make them feel heard. Culture does that, and culture is set at the top.

## Lack of corporate backing

Rust had Mozilla, then Google, Amazon, and Microsoft. Go has Google's payroll. Swift has Apple's. Every language that reached the mainstream in the last fifteen years walked in with at least one corporation behind it. Zig walks in with donations.

The Zig Software Foundation has kept real development funded for years on community money, a large Uber support contract that has since dropped off the books, and sponsors that included Bun at sixty thousand dollars a year, a donation leadership expected to lose the moment Bun was sold and shrugged off in public when it happened. The budget is real, and it is a rounding error next to what Zig's competitors spend on compilers, documentation teams, and developer relations.

That gap compounds every other problem in this article.

## Rust being a better stable alternative

Zig positioned itself as the pragmatic alternative to C and the simpler alternative to Rust. Meanwhile Rust reached the Linux kernel, Android, and Windows, with the largest companies in the industry behind it, a stable compiler since 2015, and stable async since 2019.

It is worth stating plainly: for nearly every project where Zig is a candidate, Rust is the better choice today. Not theoretically, not in some future state. Now. Elegance has little to do with it. Rust made the boring institutional investments Zig kept deferring: a stability promise, a package registry, real documentation, governance.

Zig's real advantages survive. Comptime is the most elegant metaprogramming idea of its generation. C interop is smoother. Binaries are smaller, and allocation is explicit and visible in a way Rust never matches.

But the set of projects where those advantages outweigh a stable ecosystem keeps shrinking. Teams that need small binaries mostly tune Rust with `build-std` rather than adopt a pre-1.0 toolchain. The one part of Zig that behaves like a finished product, `zig cc`, is the part companies deploy, and they deploy it to build C.

### Bun's move to Rust

Bun was the showcase, proof that a small team could ride Zig to 22 million monthly downloads. In December 2025, Anthropic acquired it. In July 2026, Jarred Sumner published [Rewriting Bun in Rust](https://bun.com/blog/bun-in-rust), and his reasons are the quiet kind that decide real arguments: the bugfix list "felt bad", he was "tired of going to sleep worrying about crashes in Bun", and the lifetimes at the border between JavaScript's garbage collector and Zig's manual memory could not be made safe at the speed his team ships.

He thanks Zig warmly and blames it for nothing. He also notes that until recently, language choice "was a one-way decision" for a project like Bun. Then he rewrote it anyway, in eleven days, with an AI doing the mechanical work and the test suite holding the line.

Every argument in this article meets in that story. A safety model that could not stop use-after-free in the language's flagship. A corporate backer that chose Rust the moment it owned the code. AI tooling, banned from Zig's own community, turning a competitor's ecosystem advantage into an eleven-day migration. And a leadership that answered the loss by celebrating it in public and insulting the person who left.

## Conclusion

Zig is a language of real brilliance. Comptime is a landmark idea. The toolchain made cross-compilation ordinary for the first time in compiler history. The people who built it have more talent than most projects ever attract, and nothing in this post argues otherwise.

None of that makes the trajectory less troubling. Brilliant ideas are necessary and not sufficient. Execution matters, stability matters, culture matters, ecosystem investment matters. On most of these, Zig chose the principled path over the pragmatic one, and the bill has come due.

There is still time, because there is always time. D is still alive too, and that sentence should worry Zig's leadership more than any criticism here. The repairs are not mysterious. A dated, honest path to 1.0. A compatibility promise, even a modest one. Answering critics instead of fighting them. An AI policy that regulates contributions instead of banning the mention of a tool.

Zig does not need to become a different project. It needs to stop drilling holes in itself.

I hope Zig's leaders read criticism like this not as an attack but as a statement of what the language could still be. The foundation is extraordinary. What gets built on it is still their choice, and the comments are open, so I would be glad to be argued out of this one.
