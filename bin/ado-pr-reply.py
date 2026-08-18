#!/usr/bin/env python3
"""Reply to Azure DevOps PR comments from your editor.

Config comes from env: ADO_ORG (or ADO_ORGANIZATION), ADO_PROJECT, ADO_TOKEN,
ADO_REPO (or REPO).

Usage:
    python ado_pr_reply.py <pr_id>
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import requests

API = "7.1"


def base_url(org, project, repo, pr):
    return (
        f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/"
        f"{repo}/pullRequests/{pr}"
    )


def auth_kwargs(token):
    """requests kwargs: PAT basic auth."""
    return {"auth": ("", token)}  # ADO PAT = basic auth with empty user


def get_threads(org, project, repo, pr, token):
    r = requests.get(
        f"{base_url(org, project, repo, pr)}/threads",
        params={"api-version": API},
        **auth_kwargs(token),
    )
    r.raise_for_status()
    return r.json()["value"]


def post_reply(org, project, repo, pr, token, thread_id, parent_id, content):
    r = requests.post(
        f"{base_url(org, project, repo, pr)}/threads/{thread_id}/comments",
        params={"api-version": API},
        **auth_kwargs(token),
        json={"parentCommentId": parent_id, "content": content, "commentType": 1},
    )
    r.raise_for_status()
    return r.json()


# ADO thread status enum values (case-insensitive input -> API camelCase)
STATUSES = {
    s.lower(): s
    for s in ("active", "fixed", "wontFix", "closed", "byDesign", "pending")
}


def set_status(org, project, repo, pr, token, thread_id, status):
    r = requests.patch(
        f"{base_url(org, project, repo, pr)}/threads/{thread_id}",
        params={"api-version": API},
        **auth_kwargs(token),
        json={"status": status},
    )
    r.raise_for_status()
    return r.json()


def real_comments(thread):
    """Human text comments only (skip system/codeChange, skip deleted)."""
    out = []
    for c in thread.get("comments", []):
        if c.get("commentType") not in (None, "text"):
            continue
        if c.get("isDeleted"):
            continue
        if not (c.get("content") or "").strip():
            continue
        out.append(c)
    return out


def render(threads):
    """Build the markdown scratch buffer. Returns (text, replyable_threads)."""
    lines = [
        "# PR review replies",
        "",
        "Write your reply between the [REPLY n] / [/REPLY] markers.",
        "Leave a block empty to skip that thread. Save & quit when done.",
        "Change a [STATUS ...] line to resolve a thread "
        "(active|fixed|wontfix|closed|bydesign|pending).",
        "",
    ]
    replyable = []
    for t in threads:
        comments = real_comments(t)
        if not comments:
            continue
        replyable.append(t)
        ctx = t.get("threadContext") or {}
        loc = ""
        if ctx.get("filePath"):
            line = (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get(
                "line"
            )
            loc = f"  ({ctx['filePath']}" + (f":{line}" if line else "") + ")"
        lines.append("=" * 70)
        lines.append(f"## Thread {t['id']} | status={t.get('status', '?')}{loc}")
        lines.append("=" * 70)
        for c in comments:
            who = (c.get("author") or {}).get("displayName", "?")
            when = (c.get("publishedDate") or "")[:10]
            body = c["content"].strip().replace("\n", "\n    ")
            lines.append(f"\n  {who} [{when}]:")
            lines.append(f"    {body}")
        lines.append("\n--- your reply below (leave blank to skip) ---")
        lines.append(f"[REPLY {t['id']}]")
        lines.append("")
        lines.append("[/REPLY]")
        lines.append(f"[STATUS {t['id']} {t.get('status', 'active')}]")
        lines.append("")
    return "\n".join(lines), replyable


REPLY_RE = re.compile(r"\[REPLY (\d+)\]\n(.*?)\n\[/REPLY\]", re.DOTALL)
STATUS_RE = re.compile(r"\[STATUS (\d+) (\w+)\]")


def parse_replies(text):
    """Return {thread_id: reply_text} for non-empty reply blocks."""
    out = {}
    for m in REPLY_RE.finditer(text):
        body = m.group(2).strip()
        if body:
            out[int(m.group(1))] = body
    return out


def parse_statuses(text, original):
    """Return {thread_id: apiStatus} for status lines that changed.

    `original` maps thread_id -> current status; unknown values are ignored.
    """
    out = {}
    for m in STATUS_RE.finditer(text):
        tid, raw = int(m.group(1)), m.group(2).lower()
        api = STATUSES.get(raw)
        if api and api.lower() != (original.get(tid) or "").lower():
            out[tid] = api
    return out


def edit(text):
    editor = os.environ.get("EDITOR", "nvim")
    path = Path("ADO-PR_REPLY.md")
    path.write_text(text)
    subprocess.call([editor, path])
    return path.read_text(), path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pr", nargs="?", type=int, help="pull request id")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return _self_test()

    if args.pr is None:
        ap.error("the following argument is required: pr")
    token = os.environ.get("ADO_TOKEN")
    if not token:
        r = subprocess.run(
            "az account get-access-token", shell=True, capture_output=True
        )
        r.check_returncode()
        token = json.loads(r.stdout)["accessToken"]

    org = os.environ.get("ADO_ORG") or os.environ.get("ADO_ORGANIZATION")
    project = os.environ.get("ADO_PROJECT")
    repo = os.environ.get("ADO_REPO") or os.environ.get("REPO")
    pr = args.pr
    if not (org and project and repo):
        sys.exit(
            f"Missing env config: ADO_ORG={org} ADO_PROJECT={project} "
            f"ADO_REPO/REPO={repo}"
        )

    threads = get_threads(org, project, repo, pr, token)
    text, replyable = render(threads)
    if not replyable:
        print("No human comment threads found on this PR.")
        return
    print(f"Found {len(replyable)} comment thread(s). Opening editor...")

    edited, path = edit(text)
    replies = parse_replies(edited)
    original = {t["id"]: t.get("status", "active") for t in replyable}
    status_changes = parse_statuses(edited, original)
    if not replies and not status_changes:
        print(f"No replies or status changes written. Draft kept at {path}")
        return

    by_id = {t["id"]: t for t in replyable}
    if replies:
        print("\n=== Replies to post ===")
        for tid, body in replies.items():
            preview = body.replace("\n", " ")
            print(f"  Thread {tid}: {preview[:80]}")
    if status_changes:
        print("\n=== Thread status changes ===")
        for tid, st in status_changes.items():
            print(f"  Thread {tid}: {original.get(tid)} -> {st}")
    print(f"\nDraft saved at {path}")

    n = len(replies) + len(status_changes)
    if input(f"\nApply {n} change(s) to PR {pr}? [y/N] ").strip().lower() != "y":
        print("Aborted. Draft kept.")
        return

    for tid, body in replies.items():
        parent = real_comments(by_id[tid])[-1]["id"]
        post_reply(org, project, repo, pr, token, tid, parent, body)
        print(f"  posted -> thread {tid}")
    for tid, st in status_changes.items():
        set_status(org, project, repo, pr, token, tid, st)
        print(f"  status  -> thread {tid} = {st}")
    print("Done.")


def _self_test():
    txt = (
        "[REPLY 1]\nhello there\n[/REPLY]\n"
        "[REPLY 2]\n\n[/REPLY]\n"
        "[REPLY 3]\nline a\nline b\n[/REPLY]\n"
    )
    r = parse_replies(txt)
    assert r == {1: "hello there", 3: "line a\nline b"}, r
    # rendered buffer must round-trip through both parsers
    sample = [
        {
            "id": 7,
            "status": "active",
            "comments": [
                {
                    "commentType": "text",
                    "content": "please fix",
                    "author": {"displayName": "A"},
                    "publishedDate": "2024-01-01T00:00:00Z",
                }
            ],
        }
    ]
    body, replyable = render(sample)
    assert len(replyable) == 1
    edited = body.replace("[REPLY 7]\n\n[/REPLY]", "[REPLY 7]\nok\n[/REPLY]").replace(
        "[STATUS 7 active]", "[STATUS 7 fixed]"
    )
    assert parse_replies(edited) == {7: "ok"}
    assert parse_statuses(edited, {7: "active"}) == {7: "fixed"}
    assert parse_statuses(body, {7: "active"}) == {}  # unchanged -> no-op
    print("self-test ok")


if __name__ == "__main__":
    main()
