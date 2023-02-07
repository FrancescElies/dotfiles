#!/usr/bin/env python3
import argparse
import re
import subprocess
import sys
import time


def dump_screen(session: str, pane_id: str) -> str:
    out = subprocess.check_output(
        ["zellij", "--session", session, "action", "dump-screen", "-p", pane_id],
        text=True,
        stderr=subprocess.STDOUT,
    )
    return out


def wait_for_text(target: str, pattern: str, fixed: bool, timeout: int, interval: float) -> int:
    if ":" not in target:
        print("target must be in session:pane_id format (e.g. my-session:terminal_0)", file=sys.stderr)
        return 1

    session, pane_id = target.split(":", 1)
    if not session or not pane_id:
        print("target must be in session:pane_id format (e.g. my-session:terminal_0)", file=sys.stderr)
        return 1

    flags = 0 if fixed else re.MULTILINE
    regex = re.compile(pattern, flags)

    deadline = time.time() + timeout
    last_text = ""
    while True:
        try:
            last_text = dump_screen(session, pane_id)
        except FileNotFoundError:
            print("zellij not found in PATH", file=sys.stderr)
            return 1
        except subprocess.CalledProcessError:
            last_text = ""

        if regex.search(last_text):
            return 0

        if time.time() >= deadline:
            print(f"Timed out after {timeout}s waiting for pattern: {pattern}", file=sys.stderr)
            print(f"Last captured text from {target}:", file=sys.stderr)
            sys.stderr.write(last_text)
            return 1

        time.sleep(interval)


def main() -> None:
    parser = argparse.ArgumentParser(description="Poll a zellij pane for text")
    parser.add_argument("-t", "--target", required=True, help="session:pane_id")
    parser.add_argument("-p", "--pattern", required=True, help="regex pattern")
    parser.add_argument("-F", "--fixed", action="store_true", help="fixed string match")
    parser.add_argument("-T", "--timeout", type=int, default=15, help="timeout seconds")
    parser.add_argument("-i", "--interval", type=float, default=0.5, help="poll interval seconds")
    args = parser.parse_args()
    sys.exit(wait_for_text(args.target, args.pattern, args.fixed, args.timeout, args.interval))


if __name__ == "__main__":
    main()
