#!/usr/bin/env python3
"""
Simple prompts use @path/file to add file contents

    uv pip install mlx-lm requests
    mlx_lm.server --port 8080 --model mlx-community/Qwen3-8B-4bit
"""

import argparse
import json
import re
from pathlib import Path

import requests


def expand_file_refs(text: str) -> str:
    pattern = r"@([^\s@]+)"  # @ followed by non-whitespace, non-@ chars

    def replacer(match):
        path = match.group(1)
        try:
            text= Path(path).read_text()
            return text
        except (FileNotFoundError, IsADirectoryError, PermissionError):
            # leave the original token untouched if it's not a real file
            return match.group(0)

    return re.sub(pattern, replacer, text)


def main():
    parser = argparse.ArgumentParser(description="Simple local ai requests")
    parser.add_argument("prompt", help="Just write something")
    parser.add_argument(
        "-o", "--outfile", default="ai-response.md", help="Output Markdown file"
    )
    args = parser.parse_args()

    print(args.prompt)
    prompt = expand_file_refs(args.prompt)
    print(prompt)
    outfile = args.outfile

    with (
        requests.post(
            "http://localhost:8080/v1/chat/completions",
            json={
                "model": "mlx-community/Qwen3-8B-4bit",
                "messages": [{"role": "user", "content": prompt}],
                "stream": True,
            },
            stream=True,
        ) as r,
        open(outfile, "w", encoding="utf-8") as out,
    ):
        for line in r.iter_lines():
            if line and line.startswith(b"data: ") and line != b"data: [DONE]":
                chunk = json.loads(line[6:])
                delta = chunk["choices"][0]["delta"].get("content", "")
                print(delta, end="", flush=True)
                out.write(delta)


if __name__ == "__main__":
    main()
