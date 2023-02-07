 ### Warnings (compile-time, all builds)

 ```makefile
   # Core
   -Wall -Wextra -Werror -Wpedantic

   # Integer / type safety
   -Wsign-conversion        # the main one from this discussion
   -Wconversion             # any value-changing implicit conversion
   -Wfloat-conversion       # implicit float→int or double→float
   -Wdouble-promotion       # float silently promoted to double in expression
   -Wfloat-equal            # comparing floats with == (almost always a bug)

   # Memory / pointers
   -Wnull-dereference        # GCC: potential null deref paths
   -Wcast-align              # cast increases alignment requirement → UB on ARM
   -Wcast-qual               # cast drops const/volatile qualifier
   -Wstrict-aliasing=3       # with -fstrict-aliasing, catches type-pun UB

   # Control flow / logic
   -Wshadow                  # local variable shadows outer scope
   -Wundef                   # undefined macro used in #if (reads as 0, silently)
   -Wlogical-op              # GCC: suspicious && / || (e.g. same condition both sides)
   -Wduplicated-cond         # GCC: same condition in if/else if chain
   -Wduplicated-branches     # GCC: identical then/else bodies

   # Format strings
   -Wformat=2                # stricter than -Wformat, checks %n etc.
   -Wformat-overflow=2       # potential overflow writing into fixed buffer
   -Wformat-truncation=2     # snprintf may truncate

   # C-specific
   -Wstrict-prototypes       # function declared without parameter types
   -Wmissing-prototypes      # global function has no prior declaration
   -Wmissing-declarations    # same but broader
   -Wvla                     # variable-length arrays (banned in MISRA/safety)

   # Stack
   -Wstack-usage=512         # warn if a stack frame exceeds N bytes (tune per target)
 ```

 ────────────────────────────────────────────────────────────────────────────────

 ### Sanitizers (dev/test builds only — too slow for production)

 ```makefile
   # Your list, which is good — a few additions:
`   -fsanitize=address`                    # heap/stack buffer over/underflow, use-after-free
   -fsanitize=undefined                  # signed overflow, misaligned access, null deref, ...
   -fsanitize=float-divide-by-zero       # not in -fsanitize=undefined by default
   -fsanitize=unsigned-integer-overflow  # not UB but still usually a bug
   -fsanitize=implicit-conversion        # Clang only: catches the silent promotions discussed
   -fsanitize=local-bounds               # Clang only: tighter than ASan for local arrays
   -fsanitize=nullability                # Clang only: enforces _Nonnull annotations

   # Also worth adding:
   -fsanitize=leak           # leak sanitizer (Linux; often bundled with ASan)
   -fsanitize=memory         # Clang only: uninitialized reads — catches a whole class ASan misses
                             # NOTE: cannot be combined with ASan, run separately

   # Companion flags for better sanitizer output:
   -fno-omit-frame-pointer   # readable stack traces
   -fno-optimize-sibling-calls
   -g                        # debug info
 ```

 │ ⚠ -fsanitize=thread (data race detection) is also valuable but mutually exclusive with ASan — needs a separate build.

 ────────────────────────────────────────────────────────────────────────────────

 ### Hardening (production/release builds)

`-fstack-protector-strong`  : stack canaries on vulnerable functions
`-D_FORTIFY_SOURCE=2`       : runtime checks on memcpy/strcpy/sprintf etc.
`-fno-common`               : disallow tentative global definitions (catches ODR bugs)
`-fstrict-aliasing`         : enables compiler to assume no aliasing → also enables -Wstrict-aliasing

 ────────────────────────────────────────────────────────────────────────────────

 ### Static analysis (beyond flags)

 These flags alone won't catch everything. Complement with:

 ┌──────────────────────────────┬─────────────────────────────────────────────────────────────┐
 │ Tool                         │ What it adds                                                │
 ├──────────────────────────────┼─────────────────────────────────────────────────────────────┤
 │ -fanalyzer (GCC 10+)         │ Inter-procedural static analysis, null/use-after-free paths │
 ├──────────────────────────────┼─────────────────────────────────────────────────────────────┤
 │ clang --analyze / scan-build │ Clang static analyzer                                       │
 ├──────────────────────────────┼─────────────────────────────────────────────────────────────┤
 │ cppcheck                     │ Standalone, good for embedded C, low false-positive rate    │
 ├──────────────────────────────┼─────────────────────────────────────────────────────────────┤
 │ clang-tidy                   │ Lint + style + bugprone checks, configurable                │
 └──────────────────────────────┴─────────────────────────────────────────────────────────────┘
