#!/usr/bin/env python3
"""Reply to Azure DevOps or GitHub PR comments from your editor.

Config comes from env:
  ADO: ADO_ORG (or ADO_ORGANIZATION), ADO_PROJECT, ADO_REPO (or REPO), ADO_TOKEN
  GitHub: GH_OWNER, GH_REPO, GH_TOKEN
  Auto-detect based on config present, or use --platform flag.

Usage:
    python pr-reply.py --platform github <owner>/<repo> <pr_id>
    python pr-reply.py --platform ado <pr_id>
"""

import argparse
import base64
import json
import os
import re
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

API_ADO = "7.1"
API_GH = "2022-11-28"  # GraphQL would be better, but REST is simpler


# ============================================================================
# GitHub API helpers
# ============================================================================


def gh_request(method, url, token, data=None):
    """Make GitHub API request using urllib.

    Args:
        method: HTTP method (GET, POST, etc.)
        url: Full URL
        token: GitHub token
        data: Dict to JSON-encode as body

    Returns:
        Parsed JSON response
    """
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.2022-11-28+json",
        "User-Agent": "ado-pr-reply",
    }

    body = None
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        raise RuntimeError(f"GitHub API {e.code}: {error_body}") from e


def gh_get_review_comments(owner, repo, pr, token):
    """Get all inline review comments on a PR (code review comments)."""
    url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr}/comments"
    return gh_request("GET", url, token)


def gh_post_reply(owner, repo, pr, comment_id, token, body):
    """Reply to a review comment by creating a new comment with in_reply_to_id."""
    url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr}/comments"
    data = {"in_reply_to_id": comment_id, "body": body}
    return gh_request("POST", url, token, data=data)


# ============================================================================
# Azure DevOps API helpers
# ============================================================================


def ado_request(method, url, token, data=None):
    """Make ADO API request using urllib.

    Args:
        method: HTTP method (GET, POST, PATCH, etc.)
        url: Full URL with query params
        token: ADO PAT token
        data: Dict to JSON-encode as body

    Returns:
        Parsed JSON response
    """
    headers = {}

    # ADO PAT uses basic auth with empty username
    auth_str = base64.b64encode(f":{token}".encode()).decode()
    headers["Authorization"] = f"Basic {auth_str}"

    body = None
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        raise RuntimeError(f"ADO API {e.code}: {error_body}") from e


def ado_base_url(org, project, repo, pr):
    return (
        f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/"
        f"{repo}/pullRequests/{pr}"
    )


def ado_get_threads(org, project, repo, pr, token):
    url = f"{ado_base_url(org, project, repo, pr)}/threads?api-version={API_ADO}"
    return ado_request("GET", url, token)["value"]


def ado_post_reply(org, project, repo, pr, token, thread_id, parent_id, content):
    url = f"{ado_base_url(org, project, repo, pr)}/threads/{thread_id}/comments?api-version={API_ADO}"
    data = {"parentCommentId": parent_id, "content": content, "commentType": 1}
    return ado_request("POST", url, token, data=data)


def ado_set_status(org, project, repo, pr, token, thread_id, status):
    url = f"{ado_base_url(org, project, repo, pr)}/threads/{thread_id}?api-version={API_ADO}"
    data = {"status": status}
    return ado_request("PATCH", url, token, data=data)


# ============================================================================
# ADO-specific (status tracking, thread rendering)
# ============================================================================


STATUSES = {
    s.lower(): s
    for s in ("active", "fixed", "wontFix", "closed", "byDesign", "pending")
}


def ado_real_comments(thread):
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


def render_ado(threads):
    """Build markdown scratch buffer for ADO threads."""
    lines = [
        "# PR review replies (Azure DevOps)",
        "",
        "Write your reply between the [REPLY n] / [/REPLY] markers.",
        "Leave a block empty to skip that thread. Save & quit when done.",
        "Change a [STATUS ...] line to resolve a thread "
        "(active|fixed|wontfix|closed|bydesign|pending).",
        "",
    ]
    replyable = []
    for t in threads:
        comments = ado_real_comments(t)
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


# ============================================================================
# GitHub-specific (review comment rendering)
# ============================================================================


def render_gh(comments):
    """Build markdown scratch buffer for GitHub review comments."""
    lines = [
        "# PR review replies (GitHub)",
        "",
        "Write your reply between the [REPLY n] / [/REPLY] markers.",
        "Leave a block empty to skip that comment. Save & quit when done.",
        "",
    ]
    replyable = []
    for c in comments:
        if not (c.get("body") or "").strip():
            continue
        replyable.append(c)
        loc = ""
        if c.get("path"):
            line = c.get("line")
            loc = f"  ({c['path']}" + (f":{line}" if line else "") + ")"
        lines.append("=" * 70)
        lines.append(f"## Comment {c['id']}{loc}")
        lines.append("=" * 70)
        who = (c.get("user") or {}).get("login", "?")
        when = (c.get("created_at") or "")[:10]
        body = c["body"].strip().replace("\n", "\n    ")
        lines.append(f"\n  {who} [{when}]:")
        lines.append(f"    {body}")
        lines.append("\n--- your reply below (leave blank to skip) ---")
        lines.append(f"[REPLY {c['id']}]")
        lines.append("")
        lines.append("[/REPLY]")
        lines.append("")
    return "\n".join(lines), replyable


# ============================================================================
# Parsing (shared between platforms)
# ============================================================================


REPLY_RE = re.compile(r"\[REPLY (\d+)\]\n(.*?)\n\[/REPLY\]", re.DOTALL)
STATUS_RE = re.compile(r"\[STATUS (\d+) (\w+)\]")


def parse_replies(text):
    """Return {id: reply_text} for non-empty reply blocks."""
    out = {}
    for m in REPLY_RE.finditer(text):
        body = m.group(2).strip()
        if body:
            out[int(m.group(1))] = body
    return out


def parse_statuses(text, original):
    """Return {thread_id: apiStatus} for status lines that changed (ADO only)."""
    out = {}
    for m in STATUS_RE.finditer(text):
        tid, raw = int(m.group(1)), m.group(2).lower()
        api = STATUSES.get(raw)
        if api and api.lower() != (original.get(tid) or "").lower():
            out[tid] = api
    return out


def edit(text):
    editor = os.environ.get("EDITOR", "nvim")
    path = Path("PR-REPLY.md")
    path.write_text(text)
    subprocess.call([editor, path])
    return path.read_text(), path


# ============================================================================
# Platform detection & main
# ============================================================================


def detect_platform():
    """Auto-detect platform based on env vars."""
    if os.environ.get("ADO_ORG") or os.environ.get("ADO_ORGANIZATION"):
        return "ado"
    if os.environ.get("GH_OWNER"):
        return "github"
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--platform", choices=["ado", "github"], help="Force platform")
    ap.add_argument("--self-test", action="store_true", help="Run self-tests")
    ap.add_argument(
        "pr_args",
        nargs="*",
        help="pr_id for ADO, or owner/repo and pr_id for GitHub (if not in env)",
    )
    args = ap.parse_args()

    if args.self_test:
        return _self_test()

    # Detect or get platform
    platform = args.platform or detect_platform()
    if not platform:
        ap.error(
            "Cannot detect platform. Set ADO_ORG (for ADO) or GH_OWNER (for GitHub), "
            "or use --platform flag."
        )

    # --- ADO Platform ---
    if platform == "ado":
        if len(args.pr_args) != 1:
            ap.error("ADO mode: requires pr_id")
        pr = int(args.pr_args[0])

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
        if not (org and project and repo):
            ap.error(
                f"Missing ADO config: ADO_ORG={org} ADO_PROJECT={project} "
                f"ADO_REPO/REPO={repo}"
            )

        threads = ado_get_threads(org, project, repo, pr, token)
        text, replyable = render_ado(threads)
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
            parent = ado_real_comments(by_id[tid])[-1]["id"]
            ado_post_reply(org, project, repo, pr, token, tid, parent, body)
            print(f"  posted -> thread {tid}")
        for tid, st in status_changes.items():
            ado_set_status(org, project, repo, pr, token, tid, st)
            print(f"  status  -> thread {tid} = {st}")
        print("Done.")

    # --- GitHub Platform ---
    else:  # platform == "github"
        if len(args.pr_args) == 2:
            owner_repo, pr = args.pr_args[0], int(args.pr_args[1])
            if "/" not in owner_repo:
                ap.error("GitHub mode: use owner/repo pr_id format")
            owner, repo = owner_repo.split("/", 1)
        elif len(args.pr_args) == 1:
            owner = os.environ.get("GH_OWNER")
            repo = os.environ.get("GH_REPO")
            pr = int(args.pr_args[0])
            if not (owner and repo):
                ap.error(
                    f"Missing GitHub config: GH_OWNER={owner} GH_REPO={repo} "
                    f"(or pass owner/repo pr_id)"
                )
        else:
            ap.error("GitHub mode: requires pr_id, or owner/repo pr_id")

        token = os.environ.get("GH_TOKEN")
        if not token:
            r = subprocess.run("gh auth token", shell=True, capture_output=True)
            if r.returncode == 0:
                token = r.stdout.decode().strip()
            else:
                ap.error("GH_TOKEN not set and gh auth token failed")

        comments = gh_get_review_comments(owner, repo, pr, token)
        text, replyable = render_gh(comments)
        if not replyable:
            print("No review comments found on this PR.")
            return
        print(f"Found {len(replyable)} comment(s). Opening editor...")

        edited, path = edit(text)
        replies = parse_replies(edited)
        if not replies:
            print(f"No replies written. Draft kept at {path}")
            return

        by_id = {c["id"]: c for c in replyable}
        print("\n=== Replies to post ===")
        for cid, body in replies.items():
            preview = body.replace("\n", " ")
            print(f"  Comment {cid}: {preview[:80]}")
        print(f"\nDraft saved at {path}")

        if (
            input(f"\nApply {len(replies)} reply(ies) to PR {pr}? [y/N] ")
            .strip()
            .lower()
            != "y"
        ):
            print("Aborted. Draft kept.")
            return

        for cid, body in replies.items():
            gh_post_reply(owner, repo, pr, cid, token, body)
            print(f"  posted -> comment {cid}")
        print("Done.")


def _self_test():
    # Test reply parsing
    txt = (
        "[REPLY 1]\nhello there\n[/REPLY]\n"
        "[REPLY 2]\n\n[/REPLY]\n"
        "[REPLY 3]\nline a\nline b\n[/REPLY]\n"
    )
    r = parse_replies(txt)
    assert r == {1: "hello there", 3: "line a\nline b"}, r

    # Test ADO rendering round-trip
    sample_ado = [
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
    body, replyable = render_ado(sample_ado)
    assert len(replyable) == 1
    edited = body.replace("[REPLY 7]\n\n[/REPLY]", "[REPLY 7]\nok\n[/REPLY]").replace(
        "[STATUS 7 active]", "[STATUS 7 fixed]"
    )
    assert parse_replies(edited) == {7: "ok"}
    assert parse_statuses(edited, {7: "active"}) == {7: "fixed"}
    assert parse_statuses(body, {7: "active"}) == {}

    # Test GitHub rendering round-trip (review comments)
    sample_gh = [
        {
            "id": 42,
            "path": "main.py",
            "line": 10,
            "body": "looks good",
            "user": {"login": "alice"},
            "created_at": "2024-01-01T00:00:00Z",
        }
    ]
    body_gh, replyable_gh = render_gh(sample_gh)
    assert len(replyable_gh) == 1
    edited_gh = body_gh.replace(
        "[REPLY 42]\n\n[/REPLY]", "[REPLY 42]\nthanks!\n[/REPLY]"
    )
    assert parse_replies(edited_gh) == {42: "thanks!"}

    print("self-test ok")


if __name__ == "__main__":
    main()
