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
