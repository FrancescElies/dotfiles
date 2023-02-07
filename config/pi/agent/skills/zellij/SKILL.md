---
name: zellij
description: "Remote control zellij sessions for interactive CLIs (python, gdb, etc.) by sending keystrokes and scraping pane output."
disable-model-invocation: true
license: Vibecoded
---

# zellij Skill

Use zellij as a programmable terminal multiplexer for interactive work. Works on Linux and macOS with stock zellij; avoid custom config by using background sessions.

## Quickstart (background session)

```bash
SESSION=zellij-python                          # slug-like names; avoid spaces
zellij attach "$SESSION" -b                    # create detached background session
zellij --session "$SESSION" action new-pane -- python3 -q   # run command, returns terminal_<id>
zellij --session "$SESSION" action dump-screen -p terminal_0 # watch output
zellij kill-session "$SESSION"                 # clean up
```

After starting a session ALWAYS tell the user how to monitor the session by giving them a command to copy paste:

```
To monitor this session yourself:
  zellij attach "$SESSION"

Or to capture the output once:
  zellij --session "$SESSION" action dump-screen -p terminal_0
```

This must ALWAYS be printed right after a session was started and once again at the end of the tool loop. But the earlier you send it, the happier the user will be.

## Session creation

- Agents create background sessions with `zellij attach <name> -b`. The session starts with one default shell pane (`terminal_0`) and a set of plugin panes.
- Keep names short (e.g., `zellij-py`, `zellij-gdb`).
- Inspect: `zellij list-sessions`, `zellij --session <name> action list-panes`.

## Targeting panes and naming

- Use `zellij --session <name> action <subcommand>` to target a specific session from anywhere.
- Pane IDs are per-session: `terminal_0`, `terminal_1`, `plugin_0`, etc. Always pass `-p <pane_id>` to actions that touch a pane.
- `list-panes -a -c -s -t` shows all panes with command/state info.
- Avoid relying on focus; always specify `-p`.

## Finding sessions

- List all sessions: `zellij list-sessions`.
- Filter by name: `./scripts/find-sessions.py -q partial-name`.

## Sending input safely

- Send text: `zellij --session "$SESSION" action write-chars -p terminal_0 -- "your text"`
- Send control keys: `zellij --session "$SESSION" action send-keys Enter`, `Ctrl c`, `Ctrl d`, `Escape`, etc.
- Prefer `write-chars` for arbitrary text; `send-keys` only for named keys.
- To run a command in a new pane: `zellij --session "$SESSION" action new-pane -- <command>` (returns `terminal_<id>`).

## Watching output

- Capture pane content: `zellij --session "$SESSION" action dump-screen -p terminal_0`.
- For continuous monitoring, poll with the helper script (below) instead of `zellij subscribe` (which is real-time but harder to script against for simple waiting).
- You can also temporarily attach to observe: `zellij attach "$SESSION"`; detach with `Ctrl + o` then `q` (or your configured detach key).

## Spawning Processes

Some special rules for processes:

- when asked to debug, use lldb by default
- when starting a python interactive shell, always set the `PYTHON_BASIC_REPL=1` environment variable. This is very important as the non-basic console interferes with your send-keys.

## Synchronizing / waiting for prompts

- Use timed polling to avoid races with interactive tools. Example: wait for a Python prompt before sending code:
  ```bash
  ./scripts/wait-for-text.py -t "$SESSION":terminal_0 -p '^>>>' -T 15
  ```
- For long-running commands, poll for completion text before proceeding.

## Interactive tool recipes

- **Python REPL**: `zellij ... action new-pane -- env PYTHON_BASIC_REPL=1 python3 -q`; wait for `^>>>`; send code with `write-chars`; interrupt with `Ctrl c`.
- **gdb**: `zellij ... action new-pane -- gdb --quiet ./a.out`; disable paging `write-chars -p terminal_1 "set pagination off"` + `send-keys Enter`; break with `Ctrl c`; issue `bt`, `info locals`, etc.; exit via `quit` then confirm `y`.
- **Other TTY apps** (ipdb, psql, mysql, node, bash): same pattern—start the program, poll for its prompt, then send literal text and Enter.

## Cleanup

- Kill a session when done: `zellij kill-session "$SESSION"`.
- Kill all sessions: `zellij kill-all-sessions`.
- Remove an exited session from the list: `zellij delete-session "$SESSION"`.

## Helper: wait-for-text.py

`./scripts/wait-for-text.py` polls a pane for a regex (or fixed string) with a timeout.

```bash
./scripts/wait-for-text.py -t session:terminal_0 -p 'pattern' [-F] [-T 20] [-i 0.5]
```

- `-t`/`--target` pane target in `session:pane_id` format (required)
- `-p`/`--pattern` regex to match (required); add `-F` for fixed string
- `-T` timeout seconds (integer, default: 15)
- `-i` poll interval seconds (default: 0.5)
- Exits 0 on first match, 1 on timeout. On failure prints the last captured text to stderr to aid debugging.
