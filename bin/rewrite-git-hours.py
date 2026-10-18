#!/usr/bin/env python3
"""
Rewrite git history keeping the day but changing hour to 6pm-1am.
Usage: python rewrite-git-hours.py [--dry-run] [branch]
"""

import argparse
import random
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

CALLBACK_SCRIPT = """
import random
from datetime import datetime, timedelta, timezone

# Use author date as the source of truth; apply the same new time to both.
date_bytes = getattr(commit, 'author_date')
if not date_bytes:
    continue
date_str = date_bytes.decode('ascii')
parts = date_str.split()
if len(parts) != 2:
    continue
ts = int(parts[0])
tz_str = parts[1]
tz = timezone.fromisoformat(f'+00:00{tz_str}' if tz_str[0] == '+' else f'-00:00{tz_str[1:]}')
dt = datetime.fromtimestamp(ts, tz=tz)
new_hour = random.randint(18, 25)
if new_hour >= 24:
    dt = dt + timedelta(days=1)
    new_hour -= 24
new_dt = dt.replace(hour=new_hour, minute=random.randint(0, 59), second=random.randint(0, 59))
new_bytes = f'{int(new_dt.timestamp())} {tz_str}'.encode('ascii')
for attr in ('author_date', 'committer_date'):
    setattr(commit, attr, new_bytes)
"""


def parse_args():
    parser = argparse.ArgumentParser(
        description="Rewrite git history keeping day but changing hour to 6pm-1am",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python rewrite-git-hours.py           # Rewrite HEAD
  python rewrite-git-hours.py main      # Rewrite main branch
  python rewrite-git-hours.py --dry-run # Preview new commit times
        """,
    )
    parser.add_argument(
        "branch", nargs="?", default="HEAD", help="Git ref to rewrite (default: HEAD)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview new commit times without modifying history",
    )
    return parser.parse_args()


def check_git_repo():
    try:
        subprocess.run(
            ["git", "rev-parse", "--git-dir"], capture_output=True, check=True
        )
        return True
    except subprocess.CalledProcessError:
        return False


def get_git_filter_repo():
    cmd = shutil.which("git-filter-repo")
    if cmd:
        try:
            subprocess.run([cmd, "--version"], capture_output=True, check=True)
            return cmd
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
    return None


def preview_new_times(branch):
    """Show what commit times would become after the rewrite."""
    result = subprocess.run(
        [
            "git",
            "log",
            "--date=format:%Y-%m-%d %H:%M:%S %z",
            "--format=%h %ad %s",
            branch,
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    print("=== DRY RUN ===")
    print("Current → projected (day preserved, hour 6pm–1am):")
    print()
    for line in result.stdout.strip().splitlines():
        short_hash, rest = line.split(maxsplit=1)
        date_tokens = rest.split()[:3]
        date_str = " ".join(date_tokens)
        message = " ".join(rest.split()[3:])
        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S %z")
        except ValueError:
            print(line)
            continue
        new_hour = random.randint(18, 25)
        if new_hour >= 24:
            dt = dt + timedelta(days=1)
            new_hour -= 24
        new_dt = dt.replace(
            hour=new_hour, minute=random.randint(0, 59), second=random.randint(0, 59)
        )
        print(
            f"{short_hash}  {dt.strftime('%Y-%m-%d %H:%M:%S %z')} → {new_dt.strftime('%Y-%m-%d %H:%M:%S %z')}  {message}"
        )


def main():
    args = parse_args()

    if not check_git_repo():
        print("Error: Not in a git repository", file=sys.stderr)
        return 1

    filter_repo = get_git_filter_repo()
    if not filter_repo:
        print(
            "Error: git-filter-repo not found. Install with: pip install git-filter-repo",
            file=sys.stderr,
        )
        return 1

    if args.dry_run:
        preview_new_times(args.branch)
        return 0

    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write(CALLBACK_SCRIPT)
        callback_file = f.name

    try:
        print(f"Rewriting git history for {args.branch}...")
        print("New commit times will be between 6pm and 1am (preserving day)")
        print()
        result = subprocess.run(
            [
                filter_repo,
                "--force",
                "--commit-callback",
                callback_file,
                "--refs",
                args.branch,
            ]
        )
        if result.returncode != 0:
            print(
                f"Error: git-filter-repo failed with exit code {result.returncode}",
                file=sys.stderr,
            )
            return result.returncode
        print()
        print("Done. Verify with:")
        print(
            "  git log --oneline --date=format:'%Y-%m-%d %H:%M:%S %z' --format='%h %ad %s'"
        )
    finally:
        Path(callback_file).unlink(missing_ok=True)

    return 0


if __name__ == "__main__":
    sys.exit(main())