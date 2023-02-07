#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys


def list_sessions(query: str = "") -> None:
    try:
        out = subprocess.check_output(["zellij", "list-sessions"], text=True)
    except FileNotFoundError:
        print("zellij not found in PATH", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError:
        print("No zellij server found", file=sys.stderr)
        sys.exit(1)

    sessions = [line for line in out.splitlines() if line.strip()]
    if query:
        q = query.lower()
        sessions = [s for s in sessions if q in s.lower()]

    if not sessions:
        print("No sessions found")
        return

    for s in sessions:
        print(f"  - {s}")


def main() -> None:
    parser = argparse.ArgumentParser(description="List zellij sessions")
    parser.add_argument("-q", "--query", default="", help="filter session names")
    args = parser.parse_args()
    list_sessions(args.query)


if __name__ == "__main__":
    main()
