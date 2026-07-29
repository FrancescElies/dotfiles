/**
 * Prevent the system from sleeping while pi's agent is running.
 *
 * macOS: uses caffeinate(8). Windows: uses PowerShell with
 * SetThreadExecutionState via kernel32.dll P/Invoke.
 * No footer/status UI is rendered, and no chat notifications are
 * emitted for routine sleep-prevention state changes.
 * Error/warning notifications are still surfaced.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import type { ChildProcess } from "node:child_process";

const MACOS = process.platform === "darwin";
const WINDOWS = process.platform === "win32";

type Scope = "agent" | "session";
type Level = "info" | "warning" | "error";

let sleepPrevention: ChildProcess | undefined;
let enabled = readBooleanEnv("PI_NO_SLEEP", true);
let scope: Scope = readScopeEnv();
let agentActive = false;
let lastError: string | undefined;

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

	// By default, allow the display to sleep. Set PI_NO_SLEEP_DISPLAY=1 to keep
	// the screen awake too.
	if (readBooleanEnv("PI_NO_SLEEP_DISPLAY", false)) {
		args.push("-d");
	}

	// Tie the assertion to the pi process so a hard crash won't leave the
	// sleep-prevention process running forever.
	args.push("-w", String(process.pid));
	return args;
}

function windowsSleepArgs(): string[] {
	// ES_CONTINUOUS | ES_SYSTEM_REQUIRED = 0x80000001
	// Add ES_DISPLAY_REQUIRED (0x00000002) when PI_NO_SLEEP_DISPLAY is set
	// to keep the display awake too.
	let flags = 0x80000001;
	if (readBooleanEnv("PI_NO_SLEEP_DISPLAY", false)) {
		flags |= 0x00000002;
	}

	const psCommand = [
		"Add-Type -TypeDefinition @'",
		"using System;",
		"using System.Runtime.InteropServices;",
		"public class Power {",
		"  [DllImport(\"kernel32.dll\", CharSet = CharSet.Auto, SetLastError = true)]",
		"  public static extern uint SetThreadExecutionState(uint esFlags);",
		"}",
		"'@",
		`while ($true) { [Power]::SetThreadExecutionState(${flags}); Start-Sleep -Seconds 30 }`,
	].join(" ");

	return ["-NoProfile", "-Command", psCommand];
}

function sleepPreventionCommand(): { command: string; args: string[] } | null {
	if (MACOS) {
		return { command: "caffeinate", args: macosSleepArgs() };
	}
	if (WINDOWS) {
		return { command: "powershell.exe", args: windowsSleepArgs() };
	}
	return null;
}

function notify(ctx: ExtensionContext | undefined, message: string, level: Level = "info"): void {
	if (ctx?.hasUI) {
		ctx.ui.notify(message, level);
	}
}

function start(ctx?: ExtensionContext): void {
	if (!enabled || sleepPrevention) {
		return;
	}

	const cmd = sleepPreventionCommand();
	if (!cmd) {
		return;
	}

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
}

function stop(ctx?: ExtensionContext): void {
	const child = sleepPrevention;
	sleepPrevention = undefined;

	if (!child) {
		return;
	}

	if (child.exitCode === null && !child.killed) {
		child.kill("SIGTERM");
		const timer = setTimeout(() => {
			if (child.exitCode === null) {
				child.kill("SIGKILL");
			}
		}, 1_000);
		timer.unref?.();
	}
}

function reconcile(ctx?: ExtensionContext): void {
	if (!enabled) {
		stop(ctx);
		return;
	}

	if (scope === "session" || agentActive) {
		start(ctx);
	} else {
		stop(ctx);
	}
}

function describeState(): string {
	if (!MACOS && !WINDOWS) {
		return "No Sleep is inactive: sleep prevention is only supported on macOS and Windows.";
	}

	const state = sleepPrevention ? `active (pid ${sleepPrevention.pid ?? "unknown"})` : "idle";
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
		stop(undefined);
	};
	process.once("exit", cleanupOnProcessExit);

	pi.on("session_start", (_event, ctx) => {
		agentActive = false;
		reconcile(ctx);
	});

	pi.on("agent_start", (_event, ctx) => {
		agentActive = true;
		reconcile(ctx);
	});

	pi.on("agent_end", (_event, ctx) => {
		agentActive = false;
		reconcile(ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		agentActive = false;
		stop(ctx);
		process.off("exit", cleanupOnProcessExit);
	});

	pi.registerCommand("no-sleep", {
		description: "Show or change sleep-prevention status",
		handler: async (args, ctx) => {
			const command = args.trim().toLowerCase();

			if (command === "on" || command === "enable") {
				enabled = true;
				reconcile(ctx);
			} else if (command === "off" || command === "disable") {
				enabled = false;
				reconcile(ctx);
			} else if (command === "toggle") {
				enabled = !enabled;
				reconcile(ctx);
			} else if (command === "agent") {
				scope = "agent";
				reconcile(ctx);
			} else if (command === "session") {
				scope = "session";
				reconcile(ctx);
			} else if (command && command !== "status") {
				notify(ctx, "Usage: /no-sleep [status|on|off|toggle|agent|session]", "warning");
				return;
			}

			notify(ctx, describeState(), lastError ? "warning" : "info");
		},
	});
}
