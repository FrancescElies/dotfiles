#!/usr/bin/env python3
"""Edit an Azure DevOps work item from your editor.

Config comes from env: ADO_ORG (or ADO_ORGANIZATION), ADO_PROJECT, ADO_TOKEN
(PAT) or ADO_BEARER (AAD token).

Usage:
    python ado_workitem_edit.py <work_item_id>
"""

import argparse
import html
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import requests

API = "7.2-preview.3"  # work item get/update: Markdown field support
COMMENTS_API = "7.2-preview.4"  # comments get: Markdown + format field
DESC_FIELD = "System.Description"
AC_FIELD = "Microsoft.VSTS.Common.AcceptanceCriteria"
HISTORY_FIELD = "System.History"  # discussion comment field (patch appends one)


def wi_url(org, project, wid):
    return f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{wid}"


def auth_kwargs(token):
    bearer = os.environ.get("ADO_BEARER")
    if bearer:
        return {"headers": {"Authorization": f"Bearer {bearer}"}}
    return {"auth": ("", token)}  # ADO PAT = basic auth with empty user


def get_workitem(org, project, wid, token):
    r = requests.get(
        wi_url(org, project, wid),
        params={"api-version": API, "$expand": "fields"},
        **auth_kwargs(token),
    )
    r.raise_for_status()
    return r.json()


def get_comments(org, project, wid, token):
    r = requests.get(
        f"{wi_url(org, project, wid)}/comments",
        params={"api-version": COMMENTS_API},
        **auth_kwargs(token),
    )
    r.raise_for_status()
    # API returns newest-first; show oldest-first for reading
    return sorted(r.json().get("comments", []), key=lambda c: c.get("createdDate", ""))


def post_comment(org, project, wid, token, text):
    """Add a discussion reply rendered as Markdown.

    ADO's dedicated comments API (POST .../comments) has no way to set the
    comment format, so a raw-Markdown body renders literally. Adding the reply
    to the System.History field instead lets us pair it with a
    /multilineFieldsFormat/System.History = "markdown" op (same mechanism used
    for the Description/Acceptance Criteria fields); each such patch appends one
    discussion comment.
    """
    return patch_fields(org, project, wid, token, {HISTORY_FIELD: text})


def patch_fields(org, project, wid, token, fields):
    """fields: {fieldRefName: markdownValue} -> json-patch update.

    Each value is written as Markdown by pairing the field op with a matching
    /multilineFieldsFormat/<field> op, so ADO stores and renders it as Markdown
    instead of HTML.
    """
    ops = []
    for k, v in fields.items():
        ops.append({"op": "add", "path": f"/fields/{k}", "value": v})
        ops.append(
            {"op": "add", "path": f"/multilineFieldsFormat/{k}", "value": "markdown"}
        )
    kw = auth_kwargs(token)
    headers = dict(kw.pop("headers", {}))
    headers["Content-Type"] = "application/json-patch+json"
    r = requests.patch(
        wi_url(org, project, wid),
        params={"api-version": API},
        json=ops,
        headers=headers,
        **kw,
    )
    r.raise_for_status()
    return r.json()


# --- legacy HTML -> text (for content not yet stored as Markdown) ----------
def html_to_text(s):
    if not s:
        return ""
    s = re.sub(r"(?i)<br\s*/?>", "\n", s)
    s = re.sub(r"(?i)</(p|div|h[1-6])>", "\n\n", s)
    s = re.sub(r"(?i)<li[^>]*>", "- ", s)
    s = re.sub(r"(?i)</li>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)  # strip remaining tags
    s = html.unescape(s)
    s = re.sub(r"\n{3,}", "\n\n", s)  # collapse blank runs
    return s.strip()


def field_markdown(wi, field):
    """Return a work item field's content as editable Markdown text.

    New/edited fields are stored as Markdown and shown verbatim; legacy fields
    still stored as HTML are converted to plain text for editing.
    """
    value = (wi.get("fields") or {}).get(field, "")
    fmt = (wi.get("multilineFieldsFormat") or {}).get(field, "html")
    return value if fmt == "markdown" else html_to_text(value)


def comment_markdown(c):
    """Return a comment body as Markdown text, converting legacy HTML."""
    text = c.get("text", "")
    fmt = c.get("format", "html")
    return text if fmt == "markdown" else html_to_text(text)


# --- scratch buffer --------------------------------------------------------
DESC_START, DESC_END = "<!-- DESCRIPTION -->", "<!-- /DESCRIPTION -->"
AC_START, AC_END = "<!-- ACCEPTANCE-CRITERIA -->", "<!-- /ACCEPTANCE-CRITERIA -->"


def render(wi, comments, wid):
    fields = wi.get("fields") or {}
    title = fields.get("System.Title", "")
    state = fields.get("System.State", "?")
    wtype = fields.get("System.WorkItemType", "?")
    desc = field_markdown(wi, DESC_FIELD)
    ac = field_markdown(wi, AC_FIELD)
    lines = [
        f"# Work item {wid}: {title}",
        f"<!-- {wtype} | {state} -->",
        "",
        "Edit the text inside the DESCRIPTION / ACCEPTANCE-CRITERIA marker",
        "pairs to update those fields. Write a new discussion reply between",
        "the [REPLY] / [/REPLY] markers (leave blank to skip). Save & quit.",
        "",
        "## Description",
        DESC_START,
        desc,
        DESC_END,
        "",
        "## Acceptance Criteria",
        AC_START,
        ac,
        AC_END,
        "",
        "## Discussion (read-only)",
    ]
    if comments:
        for c in comments:
            who = (c.get("createdBy") or {}).get("displayName", "?")
            when = (c.get("createdDate") or "")[:10]
            body = comment_markdown(c).replace("\n", "\n    ")
            lines.append(f"\n  {who} [{when}]:")
            lines.append(f"    {body}")
    else:
        lines.append("\n  (no comments yet)")
    lines += [
        "",
        "--- new reply below (leave blank to skip) ---",
        "[REPLY]",
        "",
        "[/REPLY]",
        "",
    ]
    return "\n".join(lines)


SECTION_RE = {
    "desc": re.compile(
        re.escape(DESC_START) + r"\n(.*?)\n" + re.escape(DESC_END), re.DOTALL
    ),
    "ac": re.compile(re.escape(AC_START) + r"\n(.*?)\n" + re.escape(AC_END), re.DOTALL),
}
REPLY_RE = re.compile(r"\[REPLY\]\n(.*?)\n\[/REPLY\]", re.DOTALL)


def parse(text):
    """Return (desc_text, ac_text, reply_text); any may be None if missing."""
    d = SECTION_RE["desc"].search(text)
    a = SECTION_RE["ac"].search(text)
    r = REPLY_RE.search(text)
    return (
        d.group(1).strip() if d else None,
        a.group(1).strip() if a else None,
        (r.group(1).strip() if r else "") or None,
    )


def edit(text):
    editor = os.environ.get("EDITOR", "nvim")
    path = Path("ADO-WORK-ITEM-EDIT.md")
    path.write_text(text)
    subprocess.call([editor, path])
    return path.read_text(), path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("wid", nargs="?", type=int, help="work item id")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return _self_test()
    if args.wid is None:
        ap.error("the following argument is required: wid")

    token = os.environ.get("ADO_TOKEN")
    if not token:
        r = subprocess.run(
            "az account get-access-token", shell=True, capture_output=True
        )
        r.check_returncode()
        token = json.loads(r.stdout)["accessToken"]
    org = os.environ.get("ADO_ORG") or os.environ.get("ADO_ORGANIZATION")
    project = os.environ.get("ADO_PROJECT")
    if not (org and project):
        sys.exit(f"Missing env config: ADO_ORG={org} ADO_PROJECT={project}")
    wid = args.wid

    wi = get_workitem(org, project, wid, token)
    comments = get_comments(org, project, wid, token)
    orig_desc = field_markdown(wi, DESC_FIELD)
    orig_ac = field_markdown(wi, AC_FIELD)

    print(f"Opening work item {wid} in editor...")
    edited, path = edit(render(wi, comments, wid))
    new_desc, new_ac, reply = parse(edited)

    field_updates = {}
    if new_desc is not None and new_desc != orig_desc:
        field_updates[DESC_FIELD] = new_desc
    if new_ac is not None and new_ac != orig_ac:
        field_updates[AC_FIELD] = new_ac

    if not field_updates and not reply:
        print(f"No changes. Draft kept at {path}")
        return

    print(f"\nDraft saved at {path}")
    if DESC_FIELD in field_updates:
        print("  * Description changed")
    if AC_FIELD in field_updates:
        print("  * Acceptance Criteria changed")
    if reply:
        print(f"  * New reply: {reply.replace(chr(10), ' ')[:80]}")

    n = len(field_updates) + (1 if reply else 0)
    if (
        input(f"\nApply {n} change(s) to work item {wid}? [y/N] ").strip().lower()
        != "y"
    ):
        print("Aborted. Draft kept.")
        return

    if field_updates:
        patch_fields(org, project, wid, token, field_updates)
        print("  updated fields")
    if reply:
        post_comment(org, project, wid, token, reply)
        print("  posted reply")
    print("Done.")


def _self_test():
    assert html_to_text("<div>a<br>b</div><div>c</div>") == "a\nb\n\nc"
    assert html_to_text("<ul><li>x</li><li>y</li></ul>") == "- x\n- y"
    assert html_to_text("a &amp; b &lt;c&gt;") == "a & b <c>"
    # Markdown fields/comments are shown verbatim; legacy HTML is converted.
    md_wi = {
        "fields": {DESC_FIELD: "# H\n\n- **a**"},
        "multilineFieldsFormat": {DESC_FIELD: "markdown"},
    }
    assert field_markdown(md_wi, DESC_FIELD) == "# H\n\n- **a**"
    assert field_markdown({"fields": {DESC_FIELD: "<div>hi</div>"}}, DESC_FIELD) == "hi"
    assert comment_markdown({"text": "**hi**", "format": "markdown"}) == "**hi**"
    assert comment_markdown({"text": "<div>hi</div>", "format": "html"}) == "hi"
    # round-trip through render + parse (Markdown preserved verbatim)
    wi = {
        "fields": {
            "System.Title": "T",
            "System.State": "Active",
            "System.WorkItemType": "User Story",
            DESC_FIELD: "old **desc**",
            AC_FIELD: "ac1",
        },
        "multilineFieldsFormat": {DESC_FIELD: "markdown", AC_FIELD: "markdown"},
    }
    buf = render(
        wi,
        [
            {
                "text": "hi",
                "format": "markdown",
                "createdBy": {"displayName": "A"},
                "createdDate": "2024-01-01T00:00:00Z",
            }
        ],
        42,
    )
    d, a, r = parse(buf)
    assert d == "old **desc**", repr(d)
    assert a == "ac1", repr(a)
    assert r is None, repr(r)
    edited = buf.replace("old **desc**", "new **desc**").replace(
        "[REPLY]\n\n[/REPLY]", "[REPLY]\nmy reply\n[/REPLY]"
    )
    d2, a2, r2 = parse(edited)
    assert d2 == "new **desc**" and a2 == "ac1" and r2 == "my reply", (d2, a2, r2)
    print("self-test ok")


if __name__ == "__main__":
    main()
