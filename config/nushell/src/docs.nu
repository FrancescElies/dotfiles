# how to bug reports http://sscce.org/
export def "docs bug-reports" [] {
    [
        [name link];
        ["Short, Self Contained, Correct (Compilable), Example" http://sscce.org/]
    ]
}

def download-python-docs [py_version: string] {
    let zipfile = 'python-' + $py_version + '-docs-text.zip'
    if not ($zipfile | path exists) {
      http get $'https://docs.python.org/3/archives/($zipfile)' | save $zipfile
      extract $zipfile
    }

    let zipfile = 'python-' + $py_version + '-docs-html.zip'
    if not ($zipfile | path exists) {
      http get $'https://docs.python.org/3/archives/($zipfile)' | save $zipfile
      extract $zipfile
    }
}

export def 'docs vim' [] {
  if not ("~/src/oss/vim-galore" | path exists) {
    cd ~/src/oss
    git clone https://github.com/mhinz/vim-galore
  }
  cd ~/src/oss/vim-galore
  nvim *.md
}

export def 'docs dsp' [] {
    start https://www.dspguide.com/eightres.htm
}


export def 'docs python' [] {
  let dir = ("~/src/oss/python-docs" | path expand)
  mkdir $dir
  cd $dir
  let py_version = '3.12.0'
  download-python-docs $py_version
  ^broot $dir
}

export def "docs js" [] {
  if not ("~/src/oss/You-Dont-Know-JS" | path exists) {
    cd ~/src/oss
    git clone https://github.com/francescelies/You-Dont-Know-JS
  }
  cd ~/src/oss/You-Dont-Know-JS
  just open
}

# ------------------------------------------------------------------------------
# Rust
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
        [testing-proc-macros  https://ferrous-systems.com/blog/testing-proc-macros]
    ]
}
export def "docs rust" [] {
  rustup doc
  rust links
}

# ------------------------------------------------------------------------------
# Zig
#
# Overview: https://ziglang.org/learn/overview/#wide-range-of-targets-supported
#           https://zig.guide/
#           https://github.com/zighelp/zighelp/

# https://www.youtube.com/watch?v=YXrb-DqsBNU
# You add one dependency but you can remove one cmake e.g.

# gives you hermetic builds, so that you don't have to depend on what's on the system.
# c/c++ drop in dropin replacement compailer
# zig cc
# enables ubasn by default
# -Werror -Wall -Wextra -fsanitize=undefined,address

# cross compilation
# zig cc -o hello hello.c -target x86_64-windows
# zig cc -o hello hello.c -target aarch64-macos
# zig cc -o hello hello.c -target aarch64-macos
# zig cc -o hello hello.c -target aarch-linux-gnu.2.31
# zig cc -o hello hello.c -target aarch-linux-musl  # creates a statib build, doesn't dyn link libc, distro independent

# built-in caching
# example building a c project
# https://github.com/facebook/zstd
# zig build-lib --name zstd -lc ...(ls lib/**/*c | get name)

# zi build system
# zig build --help
# will show user defined flags in the help too


# mixing zig and c
# dumpCurrentStackTrace will show c and zig code
# zig build -Drelease-fast
# objdump -d zig-out/bin/foo -Minterl | vim


# // zig cc main.c -o main.exe -lUser32
# #include <windows.h>
#
# int main() {
#     MessageBoxA(NULL, "Hello from Windows API!", "Zig & C", MB_OK);
#     return 0;
# }

# https://zig.news/kristoff/how-to-release-your-zig-applications-2h90
#
# Zig will produce a build optimized for the current, thus always specify a
# target when doing releases.
# To finetune the selection of instruction sets you can take a look at -Dcpu
#
# In practice here's how you would want to make a release for Arm macOS:
# build-exe is fine for simple projects, but build will use `build.zig` file
# $ zig build-exe myapp.zig -target aarch64-macos
# $ zig build -Dtarget=aarch64-macos
#
# zig targets | nvim
# x86-64-linux // uses musl libc
# x86-64-linux-gnu // uses glibc
# x86-64-windows // uses MingW headers
# x86-64-windows-msvc // uses MSVC headers but they need to be present in your system
# wasm32-freestanding // you will have to use build-obj since wasm modules are not full exes

# go install -ldflags "-s -w" github.com/tristanisham/zvm@latest
# zvm i --zls 0.15.2

export def "zig links" [] {
    [
        [name                 link];
        [zig-guide https://zig.guide/]
        [zig-book https://pedropark99.github.io/zig-book/]
        [zig-lings https://codeberg.org/ziglings/exercises]
        [zig-docs https://ziglang.org/documentation/master/std/]
        [operation-costs-cpucycles  http://ithare.com/infographics-operation-costs-in-cpu-clock-cycles/]
        [handles-better-pointers    https://mjtsai.com/blog/2018/06/27/handles-are-the-better-pointers/]
    ]
}
export def "docs zig" [] {
    let dir = "~/src/oss/zig-docs/"
    if not ($dir | path exists) {
        mkdir $dir
        cd $dir
        httrack https://ziglang.org/documentation/master
    }
    cd $dir
    start indext.html
    zig links
}

