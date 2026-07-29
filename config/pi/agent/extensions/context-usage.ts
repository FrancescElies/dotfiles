import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ponytail: char-based estimate scaled to real usage tokens so percentages are
// accurate even though per-category tokens are approximate. Real total comes
// from ctx.getContextUsage() (last assistant usage). Falls back to ~4 chars/token
// before the first response.

const fmt = (n: number): string => (n >= 1000 ? `${(n / 1000).toFixed(1)}k` : `${Math.round(n)}`);

function bar(pct: number, w = 20): string {
  const f = Math.max(0, Math.min(w, Math.round((pct / 100) * w)));
  return "█".repeat(f) + "░".repeat(w - f);
}

function categorize(messages: any[]): Record<string, number> {
  const cats: Record<string, number> = {
    "system-prompt": 0,
    "user": 0,
    "assistant": 0,
    "thinking": 0,
    "tool-call": 0,
    "tool-result": 0,
    "image": 0,
  };
  for (const m of messages) {
    const role: string = m.role ?? "";
    const content = m.content;
    if (typeof content === "string") {
      cats[role === "user" ? "user" : role === "system" ? "system-prompt" : "assistant"] += content.length;
      continue;
    }
    if (!Array.isArray(content)) continue;
    for (const b of content) {
      switch (b?.type) {
        case "text":
          cats[role === "user" ? "user" : role === "system" ? "system-prompt" : "assistant"] += (b.text ?? "").length;
          break;
        case "thinking":
          cats["thinking"] += (b.text ?? "").length;
          break;
        case "toolCall":
          cats["tool-call"] += (b.name ?? "").length + JSON.stringify(b.arguments ?? {}).length;
          break;
        case "toolResult":
          if (Array.isArray(b.content)) {
            for (const c of b.content) {
              if (c?.type === "text") cats["tool-result"] += (c.text ?? "").length;
              else if (c?.type === "image") cats["image"] += 850;
            }
          }
          break;
        case "image":
          cats["image"] += 850;
          break;
      }
    }
  }
  return cats;
}

export default function (pi: ExtensionAPI) {
  function report(ctx: any): string[] {
    const usage = ctx.getContextUsage();
    const total: number = usage?.tokens ?? 0;
    const window: number = ctx.model?.contextWindow ?? 0;
    const sysPrompt: string = ctx.getSystemPrompt() ?? "";
    const msgs: any[] = ctx.sessionManager.getBranch() ?? [];
    const cats = categorize(msgs);
    cats["system-prompt"] += sysPrompt.length;
    const totalChars = Object.values(cats).reduce((a, b) => a + b, 0) || 1;
    const scale = total > 0 ? total / totalChars : 0.25;
    const pct = window > 0 ? (total / window) * 100 : 0;

    const lines: string[] = [];
    lines.push(`Context  ${fmt(total)} / ${fmt(window)} tokens  (${pct.toFixed(1)}%)`);
    lines.push(bar(pct, 40));
    lines.push("");
    lines.push("Breakdown (estimated, scaled to real usage):");
    const entries = Object.entries(cats)
      .filter(([, v]) => v > 0)
      .sort((a, b) => b[1] - a[1]);
    for (const [name, chars] of entries) {
      const toks = Math.round(chars * scale);
      const p = total > 0 ? (toks / total) * 100 : 0;
      lines.push(`  ${name.padEnd(14)} ${fmt(toks).padStart(7)}  ${p.toFixed(1).padStart(5)}%  ${bar(p, 16)}`);
    }
    if (total === 0) lines.push("", "(Send a message to get real token counts.)");
    lines.push("", "esc/enter/q to close");
    return lines;
  }

  function updateStatus(ctx: any) {
    if (!ctx.hasUI) return;
    const usage = ctx.getContextUsage();
    const total: number = usage?.tokens ?? 0;
    const window: number = ctx.model?.contextWindow ?? 0;
    if (window > 0) {
      const p = (total / window) * 100;
      const color = p > 80 ? "error" : p > 50 ? "warning" : "success";
      ctx.ui.setStatus("context-usage", ctx.ui.theme.fg(color, `ctx ${fmt(total)}/${fmt(window)} ${p.toFixed(0)}%`));
    } else {
      ctx.ui.setStatus("context-usage", undefined);
    }
  }

  pi.on("turn_end", async (_e, ctx) => updateStatus(ctx));
  pi.on("session_start", async (_e, ctx) => updateStatus(ctx));
  pi.on("model_select", async (_e, ctx) => updateStatus(ctx));
  pi.on("session_shutdown", async (_e, ctx) => {
    if (ctx.hasUI) ctx.ui.setStatus("context-usage", undefined);
  });

  pi.registerCommand("context", {
    description: "Show context usage and breakdown by category",
    handler: async (_args, ctx) => {
      const lines = report(ctx);
      if (ctx.mode !== "tui") {
        for (const l of lines) console.log(l);
        return;
      }
      await ctx.ui.custom<void>((_tui, _theme, _kb, done) => ({
        render: (w: number) => lines.map((l) => (l.length > w ? l.slice(0, w) : l)),
        invalidate: () => {},
        handleInput: (data: string) => {
          if (data === "\x1b" || data === "\r" || data === "q") done();
        },
      }));
    },
  });
}