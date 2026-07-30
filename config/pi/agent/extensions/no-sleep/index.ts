import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import type { ChildProcess } from "node:child_process";

const MACOS = process.platform === "darwin";
const WINDOWS = process.platform === "win32";

type Scope = "agent" | "session";
type Level = "info" | "warning" | "error";

// Lazily loaded on Windows only, so a missing/broken native module
// never breaks extension load on macOS or any other platform.
type Kernel32 = {
  SetThreadExecutionState: (flags: number) => number;
};
let kernel32: Kernel32 | undefined;
let kernel32LoadFailed = false;

async function getKernel32(): Promise<Kernel32 | undefined> {
  if (!WINDOWS || kernel32LoadFailed) {
    return kernel32;
  }
  if (kernel32) {
    return kernel32;
  }
  try {
    const koffiModule = await import("koffi");
    const koffi = (koffiModule as any).default ?? koffiModule;
    const lib = koffi.load("kernel32.dll");
    kernel32 = {
      SetThreadExecutionState: lib.func("uint32 SetThreadExecutionState(uint32 flags)"),
    };
    return kernel32;
  } catch (error) {
    kernel32LoadFailed = true;
    lastError = error instanceof Error ? error.message : String(error);
    return undefined;
  }
}

let sleepPrevention: ChildProcess | undefined;
let enabled = readBooleanEnv("PI_NO_SLEEP", true);
let scope: Scope = readScopeEnv();
let agentActive = false;
let lastError: string | undefined;
let sleepPreventionActive = false;

function readBooleanEnv(name: string, defaultValue: boolean): boolean {
  const value = process.env[name];
  if (value === undefined || value === "") {
    return defaultValue;
  }
  return !/^(0|false|no|off)$/i.test(value);
}

function readScopeEnv(): Scope {
  return /^session$/i.test(process.env.PI_NO_SLEEP_SCOPE ?? "") ? "session" : "agent";
}

function macosSleepArgs(): string[] {
  const args = ["-i", "-s"];
  if (readBooleanEnv("PI_NO_SLEEP_DISPLAY", false)) {
    args.push("-d");
  }
  args.push("-w", String(process.pid));
  return args;
}

function notify(ctx: ExtensionContext | undefined, message: string, level: Level = "info"): void {
  if (ctx?.hasUI) {
    ctx.ui.notify(message, level);
  }
}

async function start(ctx?: ExtensionContext): Promise<void> {
  if (!enabled || sleepPrevention || sleepPreventionActive) {
    return;
  }

  if (MACOS) {
    const cmd = { command: "caffeinate", args: macosSleepArgs() };
    lastError = undefined;
    const child = spawn(cmd.command, cmd.args, { stdio: "ignore" });
    child.unref();
    sleepPrevention = child;

    child.once("error", (error) => {
      if (sleepPrevention !== child) {
        return;
      }
      sleepPrevention = undefined;
      lastError = error.message;
      notify(ctx, `No Sleep: failed to start sleep prevention: ${error.message}`, "error");
    });

    child.once("exit", (code, signal) => {
      if (sleepPrevention !== child) {
        return;
      }
      sleepPrevention = undefined;

      if (code && code !== 0) {
        lastError = `sleep prevention exited with code ${code}`;
        notify(ctx, `No Sleep: sleep prevention stopped unexpectedly (${lastError}).`, "warning");
      } else if (signal) {
        lastError = `sleep prevention exited after signal ${signal}`;
        notify(ctx, `No Sleep: sleep prevention stopped unexpectedly (${lastError}).`, "warning");
      }
    });
  } else if (WINDOWS) {
    const lib = await getKernel32();
    if (!lib) {
      notify(ctx, `No Sleep: failed to start sleep prevention: ${lastError ?? "koffi unavailable"}`, "error");
      return;
    }

    let flags = 0x80000001; // ES_CONTINUOUS | ES_SYSTEM_REQUIRED
    if (readBooleanEnv("PI_NO_SLEEP_DISPLAY", false)) {
      flags |= 0x00000002; // ES_DISPLAY_REQUIRED
    }

    lastError = undefined;
    const result = lib.SetThreadExecutionState(flags);
    if (result === 0) {
      lastError = "failed to start sleep prevention";
      notify(ctx, `No Sleep: failed to start sleep prevention: ${lastError}`, "error");
    } else {
      sleepPreventionActive = true;
      notify(ctx, "No Sleep: active", "info");
    }
  }
}

async function stop(ctx?: ExtensionContext): Promise<void> {
  const child = sleepPrevention;
  sleepPrevention = undefined;

  if (child) {
    if (child.exitCode === null && !child.killed) {
      child.kill("SIGTERM");
      const timer = setTimeout(() => {
        if (child.exitCode === null) {
          child.kill("SIGKILL");
        }
      }, 1000);
      timer.unref?.();
    }
  }

  if (WINDOWS && sleepPreventionActive) {
    // Reset execution state back to normal (ES_CONTINUOUS only).
    const lib = await getKernel32();
    lib?.SetThreadExecutionState(0x80000000);
    sleepPreventionActive = false;
  }
}

async function reconcile(ctx?: ExtensionContext): Promise<void> {
  if (!enabled) {
    await stop(ctx);
    return;
  }

  if (scope === "session" || agentActive) {
    await start(ctx);
  } else {
    await stop(ctx);
  }
}

function describeState(): string {
  if (!MACOS && !WINDOWS) {
    return "No Sleep is inactive: sleep prevention is only supported on macOS and Windows.";
  }

  const active = MACOS ? Boolean(sleepPrevention) : sleepPreventionActive;
  const state = active
    ? MACOS
      ? `active (pid ${sleepPrevention?.pid ?? "unknown"})`
      : "active"
    : "idle";
  const display = readBooleanEnv("PI_NO_SLEEP_DISPLAY", false) ? "yes" : "no";
  return [
    `No Sleep is ${enabled ? "enabled" : "disabled"}.`,
    `scope: ${scope}`,
    `state: ${state}`,
    `keeps display awake: ${display}`,
    lastError ? `last error: ${lastError}` : undefined,
  ]
    .filter(Boolean)
    .join("\n");
}

export default function noSleepExtension(pi: ExtensionAPI) {
  const cleanupOnProcessExit = () => {
    // Best-effort synchronous cleanup on process exit; the async
    // Windows reset can't reliably complete here, so at minimum
    // terminate the macOS caffeinate child.
    const child = sleepPrevention;
    sleepPrevention = undefined;
    if (child && child.exitCode === null && !child.killed) {
      child.kill("SIGTERM");
    }
  };
  process.once("exit", cleanupOnProcessExit);

  pi.on("session_start", async (_event, ctx) => {
    agentActive = false;
    await reconcile(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => {
    agentActive = true;
    await reconcile(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    agentActive = false;
    await reconcile(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    agentActive = false;
    await stop(ctx);
    process.off("exit", cleanupOnProcessExit);
  });

  pi.registerCommand("no-sleep", {
    description: "Show or change sleep-prevention status",
    handler: async (args, ctx) => {
      const command = args.trim().toLowerCase();

      if (command === "on" || command === "enable") {
        enabled = true;
        await reconcile(ctx);
      } else if (command === "off" || command === "disable") {
        enabled = false;
        await reconcile(ctx);
      } else if (command === "toggle") {
        enabled = !enabled;
        await reconcile(ctx);
      } else if (command === "agent") {
        scope = "agent";
        await reconcile(ctx);
      } else if (command === "session") {
        scope = "session";
        await reconcile(ctx);
      } else if (command && command !== "status") {
        notify(ctx, "Usage: /no-sleep [status|on|off|toggle|agent|session]", "warning");
        return;
      }

      notify(ctx, describeState(), lastError ? "warning" : "info");
    },
  });
}
