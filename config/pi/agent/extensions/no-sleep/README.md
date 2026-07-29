# pi-sleep-prevention

A Pi extension to prevent the system from sleeping while the agent is running.

## Features

- Prevents system sleep on macOS using `caffeinate`
- Prevents system sleep on Windows using `node-ffi-napi` to call `SetThreadExecutionState` directly
- No external dependencies beyond `node-ffi-napi`
- Configurable to keep display awake
- Agent-scoped or session-scoped sleep prevention

## Installation

This extension is typically installed as part of your Pi dotfiles. Ensure `node-ffi-napi` is installed:

```bash
npm install node-ffi-napi
```

## Usage

Once installed, the extension is automatically loaded by Pi.

### Commands

- `/no-sleep status` - Show current status
- `/no-sleep on` - Enable sleep prevention
- `/no-sleep off` - Disable sleep prevention
- `/no-sleep toggle` - Toggle sleep prevention
- `/no-sleep agent` - Set scope to agent (default)
- `/no-sleep session` - Set scope to session

### Environment Variables

- `PI_NO_SLEEP` - Set to `false` to disable (default: `true`)
- `PI_NO_SLEEP_DISPLAY` - Set to `true` to keep display awake (default: `false`)
- `PI_NO_SLEEP_SCOPE` - Set to `session` for session-scoped, otherwise agent-scoped

## How It Works

### macOS

Uses the `caffeinate` command to create an assertion that prevents sleep.

### Windows

Uses `node-ffi-napi` to call the Windows `SetThreadExecutionState` API directly from Node.js, avoiding PowerShell entirely.

## License

MIT