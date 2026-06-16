"""
Generate compile_commands.json on Windows.

Windows replacement for `bear -- make` whe you don't have a Make/CMake
build for the C sources.

We invoke clang directly on every .c file with `-fsyntax-only -MJ <fragment>.json`,
which makes clang itself emit a compile_commands fragment per file.
Then concatenate them into a single compile_commands.json.

Flags here MUST stay in sync with the `.clangd` file at the repo root.

"""

import argparse
import json
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)

REPO_ROOT = Path(__file__).resolve().parents[1]
C_CODE_DIR = REPO_ROOT / "TODO" 


 # │ Target       │ MSVC             │ clang / gcc            │
 # │ ------       │ ----             │ -----------            │
 # │ x86-64       │ _M_X64, _M_AMD64 │ __x86_64__, __amd64__  │
 # │ x86 (32-bit) │ _M_IX86          │ __i386__               │
 # │ ARM64        │ _M_ARM64         │ __aarch64__, __arm64__ │
 # │ ARM (32-bit) │ _M_ARM           │ __arm__                │
MAIN_PLATFORM_DEF_SET =  {"_M_X64", "__x86_64__"}
MAIN_PLATFORM_DEF = [f"-D{x}=1" for x in ["_M_X64", "__x86_64__"]]


COMMON_FLAGS_NO_PLAT = [
    "-xc",
    "-std=c11",
    "-fsyntax-only",
    "-ferror-limit=0",
    "-Wno-everything",  # we only want the JSON, not the diagnostics
] 
COMMON_FLAGS = COMMON_FLAGS_NO_PLAT + MAIN_PLATFORM_DEF

# per-directory #define switch, mirroring what your
# real per-target build system would do, so that clangd/IDE tooling sees the
# correct active code in each platform's sources. 
#
# `-U` removes the macro whether it was defined by:
#  - an earlier -D on the same command line
#  - the compiler itself (built-in macros like _M_X64, __x86_64__)
#  - a system/config header pulled in via -include
PLATFORM_OVERRIDES: dict[str, list[str]] = {
    # path-substring : extra flags
    "platform_specific_subidr": ["-DPLAT_FLAG=1", f"-U{MAIN_PLATFORM_DEF}"],
}

EXCLUDE_PARTS = {"__pycache__", "target", ".venv"}


def find_include_dirs(repo_dir: Path) -> list[str]:
    """Every directory that contains a header, as repo relative
    posix paths. Includes don't have to be kept in sync by hand."""
    dirs: set[str] = set()
    for h in C_CODE_DIR.rglob("*.h"):
        rel = h.relative_to(repo_dir).as_posix()
        if any(part in rel for part in EXCLUDE_PARTS):
            continue
        dirs.add(h.parent.relative_to(repo_dir).as_posix())
    return sorted(dirs)


def find_sources(repo_dir: Path) -> list[Path]:
    out: list[Path] = []
    for p in C_CODE_DIR.rglob("*.c"):
        rel = p.relative_to(repo_dir).as_posix()
        if any(part in rel for part in EXCLUDE_PARTS):
            continue
        out.append(p)
    return sorted(out)


def flags_for(src: Path, include_dirs: list[str]) -> list[str]:
    flags = list(COMMON_FLAGS_NO_PLAT)
    flags.extend(f"-I{x}" for x in include_dirs)
    for needle, extra in PLATFORM_OVERRIDES.items():
        if needle in src.parts:
            flags.extend(extra)
            break
    return flags


def main():
    ap = argparse.ArgumentParser()
    _ = ap.add_argument(
        "--verbose", "-v", action="store_true", help="show clang stderr for each file"
    )
    _ = ap.add_argument(
        "--clang",
        default=shutil.which("clang") or "clang",
        help="path to clang executable",
    )
    _ = ap.add_argument(
        "--repo-dir",
        type=Path,
        default=os.getcwd(),
        help="repor dir",
    )
    args = ap.parse_args()

    repo_dir: Path = args.repo_dir
    sources = find_sources(repo_dir)
    if not sources:
        logging.info(f"No .c files found under {repo_dir}")
        return 1

    include_dirs = find_include_dirs(repo_dir)

    logging.info(f"clang   : {args.clang}")
    logging.info(f"repo    : {args.repo_dir}")
    logging.info(f"sources : {len(sources)} .c files under {repo_dir}")
    logging.info(f"includes: {include_dirs}")

    fragments: list[dict[str, Any]] = []
    failed = 0
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        for i, src in enumerate(sources, 1):
            frag = td_path / f"{i}.json"
            cmd = [args.clang, *flags_for(src, include_dirs), f"-MJ{frag}", str(src)]
            r = subprocess.run(cmd, capture_output=True, text=True, cwd=repo_dir)
            if not frag.exists():
                failed += 1
                if args.verbose:
                    logging.info(
                        f"  [skip] {src.relative_to(repo_dir)}: clang produced no fragment",
                    )
                    logging.error(r.stderr)
                continue
            if r.returncode != 0 and args.verbose:
                logging.warning(f"  {src.relative_to(repo_dir)} compiled with errors")
                logging.error(r.stderr)
            # `-MJ` writes one JSON object per invocation, followed by a comma.
            text = frag.read_text().strip().rstrip(",")
            # Some clang versions wrap multiple entries; be defensive:
            for obj in _split_objects(text):
                fragments.append(obj)
            if i % 25 == 0 or i == len(sources):
                logging.info(f"  ... processed {i}/{len(sources)}")

    out_path = repo_dir / "compile_commands.json"
    _ = out_path.write_text(json.dumps(fragments, indent=2))
    logging.info(f"wrote {out_path}  ({len(fragments)} entries, {failed} skipped)")


def _split_objects(text: str) -> list[dict[str, Any]]:
    """Parse JSON objects produced by `clang -MJ`."""
    text = text.strip()
    if not text:
        return []
    if text.startswith("["):
        return json.loads(text)
    # Could be `{...},{...}` -- wrap into an array.
    return json.loads("[" + text + "]")


if __name__ == "__main__":
    main()
