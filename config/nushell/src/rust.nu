export def "cargo multi-fix" [] {
  cargo fmt --all
  cargo fix --allow-dirty --allow-staged
  cargo clippy --fix --allow-dirty --allow-staged
}

# rustup override set stable

export def "rust commands" [] {
    [
        [command                   description];
        ["cargo nextest"           "executs tests faster and other goodies"]
        ["cargo outdated"          "shows outdated deps"]
        ["cargo sort"              "sorts cargo.toml deps alphabetically"]
        ["cargo sweep"             "removes built artifacts matching certain properties"]
        ["cargo +nightly udeps"    "finds unused dependencies"]
        ["cargo run"               "executes your only program"]
        ["cargo run --bin foo"     "executes the foo binary"]
        ["cargo build --bins"      "builds all binaries"]
        ["cargo build --timings"   "generates report of build times"]
        ["cargo test"              "runs all tests"]
        ["cargo fix"               "automatically fixes compiler warnings"]
        ["cargo clippy --fix"      "automatically fixes clippy warnings"]
        ["cargo add/remove"        "adds/removes dependencies"]
        ["cargo update"            "updates cargo.lock file entries"]
        ["cargo tree"              "renders the dependency tree"]
        ["cargo tree --duplicates" "shows duplicate dependencies"]
    ]

}
export def "rust libraries" [] {
    [
        [name                  type description];
        [turmoil               testing "async chaos"]
        [shuttle               testing "sync chaos"]
        ["quickcheck/proptest" testing "(hypothesis like): value chaos (fuzzing, figure out inputs with erroneous behaviour)"]
        [cargo-mutants         testing "logic chaos, e.g. switches sign of +/- boundary conditions"]
        [criterion             testing "detect and measure performance improvements "]
        [loom                  testing "interleaves all possible permutation of thread interactions"]
        [kani                  testing "symbolic execution, interprets the code and sees which values to set to execute other branches"]
        [ai-callgrind          bench "runs measurement through valgrind and reports number of instructions executed (dont use time or ops/sec, this depends on external processes)"]
        [tango                 bench "runs the old code and the new one interleaved"]
        ["Open Versus Closed"  bench "https://www.usenix.org/legacy/event/nsdi06/tech/full_papers/schroeder/schroeder.pdf"]
        [proptest              testing "https://github.com/proptest-rs/proptest"]
    ] | sort-by type
}

export def "rust links" [] {
    [
        [name                 link];
        [nextest              https://nexte.st/]
        [comprehensive-rust   https://google.github.io/comprehensive-rust/error-handling/thiserror-and-anyhow.html]
        [rust-cookbook        https://rust-lang-nursery.github.io/rust-cookbook/]
        [rust-by-example      https://doc.rust-lang.org/rust-by-example/]
        [cross-compiling      https://actually.fyi/posts/zig-makes-rust-cross-compilation-just-work/]
        [ytb-logan-smith      https://www.youtube.com/@_noisecode]
        [dystroy              "https://dystroy.org/blog/how-not-to-learn-rust/#mistake-1-not-be-prepared-for-the-first-high-step"]
        [half-hour            https://fasterthanli.me/articles/a-half-hour-to-learn-rust]
        [unsafe-rust-and-zig  https://zackoverflow.dev/writing/unsafe-rust-vs-zig]
        [unsafe-guidelines https://rust-lang.github.io/unsafe-code-guidelines/glossary.html]
        [unsafe-mental-model  https://ia0.github.io/unsafe-mental-model/what-are-types.html]
        [negative-programming https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md]
        [types-table          https://rustcurious.com/elements]
        [associated-types     https://gavinleroy.com/writings/i-heart-assoc-types.html]
    ]
}

export def --wrapped "rust proc-macro expand" [...rest ] { cargo expand ...$rest }
export def --wrapped "rust proc-macro backtrace" [...rest ] { RUSTFLAGS="-Z proc-macro-backtrace" cargo +nightly ...$rest }
