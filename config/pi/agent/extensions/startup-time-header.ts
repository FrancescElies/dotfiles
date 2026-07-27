/**
 * Startup Time Header Extension
 *
 * Shows the session startup time above the editor without touching the
 * built-in header. Uses ctx.ui.setWidget() so the pi logo and keybinding
 * hints in the built-in header are preserved (extending, not replacing).
 *
 * The widget auto-clears when the first agent run starts.
 *
 * Inspired by ~/src/oss/pi/packages/coding-agent/examples/extensions/custom-header.ts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const moduleLoadTime = Date.now();

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const elapsedMs = Date.now() - moduleLoadTime;
    const elapsedStr =
      elapsedMs >= 1000
        ? `${(elapsedMs / 1000).toFixed(2)}s`
        : `${elapsedMs}ms`;

    // Show startup time as a widget (above the editor) — built-in header stays intact
    ctx.ui.setWidget("startup-time", (_tui, theme) => ({
      render(_width: number): string[] {
        return [theme.fg("dim", `  Started up in ${elapsedStr}`)];
      },
      invalidate() {},
    }));
  });

  // Auto-clear the widget once the user fires their first prompt
  pi.on("agent_start", async (_event, ctx) => {
    ctx.ui.setWidget("startup-time", undefined);
  });

  // Also expose a manual clear command
  pi.registerCommand("reset-startup-time", {
    description: "Clear the startup time widget",
    handler: async (_args, ctx) => {
      ctx.ui.setWidget("startup-time", undefined);
      ctx.ui.notify("Startup time widget cleared", "info");
    },
  });
}
