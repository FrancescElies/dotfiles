- Beast mode: https://gist.github.com/burkeholland/88af0249c4b6aff3820bf37898c8bacf
-  https://www.copilotcraft.dev/
- Anvil: A chat mode for GitHub Copilot CLI
- omo.dev: oh-my-openagent
- pi.dev:  a minimal terminal coding harness

 ### Pi model picking strategy

 - Default driver in pi: `gpt-5.4` or `claude-sonnet-4.6`, quality/cost balance for an agent loop
 - Codex-style autonomous coding (*long agent runs, lots of tool calls*): `gpt-5.3-codex`
 - Architecture, a gnarly bug, security audits: `claude-opus-4.8` (each request costs ~10x )
 - Cycle list for `Ctrl+P` suggestion:

Other:
 - Fast cheap mode (*lots of small edits, tight loops*): `claude-haiku-4.5` or `gpt-5.4-mini`
 - Free tier: `gpt-4.1` and `gpt-5-mini` (for autocomplete-style and casual chat)


# Pi Shortcuts

## Model switching

| Key            | Action                                                             |
| ---            | ---                                                                |
| `Ctrl+P`       | Cycle to next model (sonnet → gpt-5.4 → haiku → opus)              |
| `Shift+Ctrl+P` | Cycle backwards                                                    |
| `Ctrl+L`       | Open full model selector                                           |
| `Shift+Tab`    | Cycle thinking level (off → minimal → low → medium → high → xhigh) |
| `Ctrl+T`       | Collapse / expand thinking blocks                                  |

## Input editing

| Key           | Action                                                   |
| ---           | ---                                                      |
| `Enter`       | Submit                                                   |
| `Shift+Enter` | New line (multiline prompt)                              |
| `Alt+Enter`   | Queue a follow-up message (sends after current response) |
| `Alt+Up`      | Restore queued messages back to editor                   |

## Control

| Key      | Action                         |
| ---      | ---                            |
| `Escape` | Cancel / abort running request |
| `Ctrl+C` | Clear editor                   |
| `Ctrl+D` | Exit (when editor is empty)    |

## Sessions

| Key       | Action                            |
| ---       | ---                               |
| `/new`    | New session                       |
| `/fork`   | Fork current session (branch off) |
| `/resume` | Pick a past session to resume     |
| `/tree`   | Open session tree navigator       |

## Output navigation

| Key                           | Action                        |
| ---                           | ---                           |
| `Ctrl+O`                      | Collapse / expand tool output |
| `Ctrl+V` (`Alt+V` on Windows) | Paste image from clipboard    |

## Tips (this setup)

- **Haiku for throw-away questions** — one `Ctrl+P` press away, ask, cycle back.
- **Opus for hard problems** — 2× `Ctrl+P`; don't leave it as default or it burns quota on every session.
- **Long prompts** → `Ctrl+G` opens `$EDITOR` (`set $EDITOR=nvim` or `code --wait` in shell profile).
- **Thinking level** → `Shift+Tab` before submitting; `medium` is default, bump to `high`/`xhigh` for architecture or gnarly bugs.

#### copy pasta

# Sentences

        Act like a senior engineer reviewing this. Be strict and practical.
        If you are unsure, say so explicitly instead of guessing.
        Do not assume missing information. Only use what is given.
        Be extremely concise. No filler. Only the important parts.
        Go deep on the critical parts, skip basics.
        Use bullet points and highlight key insights.
        Give me actionable steps, not just explanation.

        Read AGENT_CONTEXT.md before doing anything else

        Summarize the current state, open tasks, decisions mad, and next steps into SESSION_HANDOFF.md

        Read SESSION_HANDOFF.md and continue where we left off
