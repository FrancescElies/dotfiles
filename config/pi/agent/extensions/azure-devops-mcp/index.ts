/**
 * Pi extension: Azure DevOps MCP bridge
 *
 * Spawns the @azure-devops/mcp stdio server and registers all its tools
 * into pi so the LLM can call them directly.
 *
 * Config (env vars):
 *   ADO_ORG   - Azure DevOps organisation name (required)
 *   ADO_DOMAINS - Space-separated domain list, e.g. "work-items repos" (optional, default: all)
 *
 * Auth: the first tool call opens a browser for Microsoft login, or set
 *   AZURE_DEVOPS_EXT_PAT to use a Personal Access Token instead.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { Type } from "typebox";

export default async function (pi: ExtensionAPI) {
  const org = process.env.ADO_ORG;
  if (!org) {
    console.warn("[azure-devops-mcp] ADO_ORG env var not set — extension disabled.");
    return;
  }

  const domains = process.env.ADO_DOMAINS?.split(/\s+/).filter(Boolean) ?? [];

  const args = ["-y", "@azure-devops/mcp", org];
  if (domains.length > 0) {
    args.push("-d", ...domains);
  }

  const transport = new StdioClientTransport({
    command: "npx",
    args,
    env: { ...process.env } as Record<string, string>,
  });

  const client = new Client({ name: "pi-ado-bridge", version: "1.0.0" });

  try {
    await client.connect(transport);
  } catch (err) {
    console.error("[azure-devops-mcp] Failed to connect to MCP server:", err);
    return;
  }

  let tools: Awaited<ReturnType<typeof client.listTools>>["tools"];
  try {
    ({ tools } = await client.listTools());
  } catch (err) {
    console.error("[azure-devops-mcp] Failed to list tools:", err);
    return;
  }

  for (const tool of tools) {
    // Build a TypeBox schema from the MCP JSON Schema input schema.
    // MCP tools use standard JSON Schema objects; pass through as-is when
    // TypeBox would reject it, falling back to a passthrough object schema.
    let schema: ReturnType<typeof Type.Object>;
    try {
      const props = (tool.inputSchema as any)?.properties ?? {};
      const required: string[] = (tool.inputSchema as any)?.required ?? [];
      const tbProps: Record<string, ReturnType<typeof Type.String>> = {};
      for (const [key, val] of Object.entries(props)) {
        const v = val as any;
        // Map common JSON Schema types to TypeBox
        if (v.type === "string" || !v.type) {
          tbProps[key] = Type.Optional(Type.String({ description: v.description }));
        } else if (v.type === "number" || v.type === "integer") {
          tbProps[key] = Type.Optional(Type.Number({ description: v.description })) as any;
        } else if (v.type === "boolean") {
          tbProps[key] = Type.Optional(Type.Boolean({ description: v.description })) as any;
        } else {
          tbProps[key] = Type.Optional(Type.Any({ description: v.description })) as any;
        }
      }
      // Mark required fields (remove Optional wrapper)
      for (const key of required) {
        if (tbProps[key]) {
          const v = (props as any)[key] as any;
          if (v.type === "string" || !v.type) {
            tbProps[key] = Type.String({ description: v.description });
          } else if (v.type === "number" || v.type === "integer") {
            tbProps[key] = Type.Number({ description: v.description }) as any;
          } else if (v.type === "boolean") {
            tbProps[key] = Type.Boolean({ description: v.description }) as any;
          } else {
            tbProps[key] = Type.Any({ description: v.description }) as any;
          }
        }
      }
      schema = Type.Object(tbProps);
    } catch {
      schema = Type.Object({});
    }

    const toolName = tool.name;
    const toolDesc = tool.description ?? toolName;

    pi.registerTool({
      name: toolName,
      label: toolName,
      description: toolDesc,
      parameters: schema,
      async execute(_id, params) {
        const result = await client.callTool({
          name: toolName,
          arguments: params as Record<string, unknown>,
        });

        const text = (result.content as any[])
          .map((c: any) => {
            if (c.type === "text") return c.text as string;
            return JSON.stringify(c);
          })
          .join("\n");

        return {
          content: [{ type: "text", text }],
          details: {},
        };
      },
    });
  }

  console.log(`[azure-devops-mcp] Registered ${tools.length} ADO tools for org "${org}".`);
}
