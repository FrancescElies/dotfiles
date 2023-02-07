#!/usr/bin/env python3
"""Locate Ghidra installation and analyzeHeadless script."""
import os
import sys


def find_headless(base_path):
    for root, dirs, files in os.walk(base_path, onerror=lambda e: None):
        for f in files:
            if f.startswith("analyzeHeadless"):
                candidate = os.path.join(root, f)
                if not os.path.isfile(candidate):
                    continue
                if os.name == "nt":
                    ext = os.path.splitext(candidate)[1].lower()
                    if ext in (".bat", ".cmd", ".sh", ".ps1", ""):
                        return candidate
                elif os.access(candidate, os.X_OK):
                    return candidate
    return None


def main():
    search_paths = [
        "/opt/homebrew/Caskroom/ghidra",
        "/usr/local/Caskroom/ghidra",
        "/opt/ghidra",
        "/usr/local/ghidra",
        os.path.expanduser("~/ghidra"),
        os.path.expanduser("~/Applications/ghidra"),
        "/Applications/ghidra",
        "/usr/share/ghidra",
        "/usr/local/share/ghidra",
        os.environ.get("ProgramFiles", "") + "\\Ghidra",
        os.environ.get("ProgramFiles(x86)", "") + "\\Ghidra",
        os.environ.get("LOCALAPPDATA", "") + "\\Ghidra",
        os.path.expanduser("~\\ghidra"),
        os.path.expanduser("~\\Desktop\\ghidra"),
        os.path.expanduser("~\\Downloads\\ghidra"),
        "C:\\ghidra",
        "D:\\ghidra",
        "C:\\tools\\ghidra",
        "D:\\tools\\ghidra",
    ]

    ghidra_home = os.environ.get("GHIDRA_HOME")
    if ghidra_home:
        support_dir = os.path.join(ghidra_home, "support")
        if os.path.isdir(support_dir):
            found = find_headless(support_dir)
            if found:
                print(found)
                return

    for base_path in search_paths:
        if os.path.isdir(base_path):
            found = find_headless(base_path)
            if found:
                print(found)
                return

    for base in [
        "/opt",
        "/usr/local",
        "/Applications",
        os.path.expanduser("~"),
        "C:\\",
        "D:\\",
        "E:\\",
        "F:\\",
    ]:
        if os.path.isdir(base):
            found = find_headless(base)
            if found:
                print(found)
                return

    print("ERROR: Could not find Ghidra's analyzeHeadless script.", file=sys.stderr)
    print("Please set GHIDRA_HOME environment variable or install Ghidra.", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
