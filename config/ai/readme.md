- Beast mode: https://gist.github.com/burkeholland/88af0249c4b6aff3820bf37898c8bacf
-  https://www.copilotcraft.dev/
- Anvil: A chat mode for GitHub Copilot CLI
- omo.dev: oh-my-openagent
- pi.dev:  a minimal terminal coding harness

## Useful copilot cli commands

### 🧠 Modes (Shift+Tab to cycle)
| Mode               | What it does                                                   |
| ------             | -------------                                                  |
| **Plan mode**      | Copilot asks questions, builds a plan *before* coding          |
| **Autopilot mode** | Fully autonomous — runs end-to-end without asking for approval |

### 💻 Code & Review
| Command   | Description                                                  |
| --------- | -------------                                                |
| `/diff`   | Review all changes in your session with syntax highlighting  |
| `/review` | AI code review of staged/unstaged changes before committing  |
| `/pr`     | Operate on pull requests for the current branch              |
| `Esc×2`   | **Undo/rewind** — reverts file changes to any prior snapshot |

### 🤖 Agents & Delegation
| Command      | Description                                                          |
| ---------    | -------------                                                        |
| `& <prompt>` | Delegate to the **cloud agent** — frees your terminal while it works |
| `/delegate`  | Send the session to GitHub; Copilot creates a PR                     |
| `/resume`    | Switch between local and remote sessions                             |
| `/fleet`     | Parallel subagent execution for big tasks                            |
| `/agent`     | Browse & select specialized agents                                   |

### 🔧 Customization & Extensions
| Command                      | Description                                                                           |
| ---------                    | -------------                                                                         |
| `/mcp`                       | Add/manage MCP servers (connect any tool)                                             |
| `/plugin install owner/repo` | Install a plugin directly from a GitHub repo, e.g. `/plugin install obra/superpowers` |
| `/skills`                    | Manage markdown-based skill files                                                     |
| `/model`                     | Switch AI model mid-session (Claude, GPT, Gemini)                                     |
| `/init`                      | Initialize Copilot instructions for the repo                                          |

### 📋 Session Management
| Command       | Description                                         |
| ---------     | -------------                                       |
| `/compact`    | Compress history to free up context window          |
| `/rewind`     | Undo last turn and revert file changes              |
| `/share`      | Export session to markdown, HTML, or GitHub Gist    |
| `/chronicle`  | Browse past session history and insights            |
| `/context`    | See token usage in the context window               |
| `/statusline` | configure statusline items (branch, efforts, quota) |

### 🔍 Research & Planning
| Command        | Description                                 |
| ---------      | -------------                               |
| `/research`    | Deep research using GitHub search + web     |
| `/plan`        | Create an implementation plan before coding |
| `@ <file>`     | Mention a file to include it in context     |
| `# <issue/PR>` | Reference GitHub issues or PRs directly     |

### ⚡ Power Tips
- **`! <shell cmd>`** — run shell commands inline without leaving the chat
- **`Ctrl+T`** — toggle reasoning display (see Copilot's thinking)
- **`Ctrl+X → B`** — move current task to background
- **`/every 5m run tests`** — schedule a recurring prompt/check

Files:
- .github/copilot-instructions.md: stable project knowledge
- SESSION_HANDOFF.md: what happened today
- TODO.md: next actions

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
