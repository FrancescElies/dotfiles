#!/usr/bin/env python3
"""
Extract currently open Firefox tabs (from the session store) into a Markdown
file of links.

Requires: pip install lz4
    Firefox's sessionstore files use the "mozLz4" format

Usage:
    python firefox-tabs-to-md.py [path/to/recovery.jsonlz4] [-o tabs.md]

If no path is given, the script tries to auto-detect your default Firefox
profile's recovery.jsonlz4
"""

import argparse
import glob
import json
import os
import sys
from pathlib import Path

try:
    import lz4.block
except ImportError:
    sys.exit("Missing dependency. Install it with:\n    pip install lz4")


def find_default_session_file():
    if sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", "")) / "Mozilla/Firefox/Profiles"
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Firefox/Profiles"
    else:
        base = Path.home() / ".mozilla/firefox"

    pattern = os.path.join(base, "*", "sessionstore-backups", "recovery.jsonlz4")
    candidates = list(glob.glob(pattern))

    if not candidates:
        sys.exit(
            "Couldn't auto-find recovery.jsonlz4. Pass the path manually, e.g.\n"
            f"  python {os.path.basename(__file__)} /path/to/recovery.jsonlz4"
        )
    return candidates[0]


def load_mozlz4(path):
    with open(path, "rb") as f:
        data = f.read()

    magic = b"mozLz40\0"
    if not data.startswith(magic):
        sys.exit("File doesn't look like a mozLz4 session file (bad magic header).")

    payload = data[len(magic) :]
    decompressed = lz4.block.decompress(payload)
    return json.loads(decompressed)


def extract_tabs(session_json):
    """Yield (title, url) for every tab in every window."""
    for window in session_json.get("windows", []):
        for tab in window.get("tabs", []):
            entries = tab.get("entries", [])
            if not entries:
                continue
            # The active entry reflects what's currently shown in the tab.
            idx = tab.get("index", len(entries)) - 1
            idx = max(0, min(idx, len(entries) - 1))
            entry = entries[idx]
            title = entry.get("title") or entry.get("url", "Untitled")
            url = entry.get("url", "")
            if url:
                yield title, url


def main():
    parser = argparse.ArgumentParser(
        description="Export open Firefox tabs to a Markdown link list."
    )
    parser.add_argument(
        "session_file",
        nargs="?",
        help="Path to recovery.jsonlz4 (auto-detected if omitted)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="tabs.md",
        help="Output Markdown file (default: tabs.md)",
    )
    args = parser.parse_args()

    path = args.session_file or find_default_session_file()
    session_json = load_mozlz4(path)
    tabs = list(extract_tabs(session_json))

    if not tabs:
        sys.exit("No tabs found in session file.")

    with open(args.output, "w", encoding="utf-8") as out:
        out.write("# Open Firefox Tabs\n\n")
        for title, url in tabs:
            safe_title = title.replace("[", "(").replace("]", ")")
            out.write(f"- [{safe_title}]({url})\n")

    print(f"Wrote {len(tabs)} tabs to {args.output}")


if __name__ == "__main__":
    main()
