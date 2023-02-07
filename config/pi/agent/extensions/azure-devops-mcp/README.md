# Pi Extension: Azure DevOps MCP

Bridges the [Azure DevOps MCP server](https://github.com/microsoft/azure-devops-mcp) into pi by spawning it as a stdio child process and registering all its tools so the LLM can call them directly.

## Files

```
~/.pi/agent/extensions/azure-devops-mcp/
├── index.ts        # extension entry point
├── package.json    # declares @modelcontextprotocol/sdk dependency
└── node_modules/   # installed via npm install
```

## Setup

```bash
export ADO_ORG=myorg
pi
```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ADO_ORG` | ✅ | Azure DevOps organisation name (e.g. `contoso`) |
| `ADO_DOMAINS` | ❌ | Space-separated domain list to limit loaded tools (e.g. `"work-items repositories"`). Defaults to all 90 tools. |
| `AZURE_DEVOPS_EXT_PAT` | ❌ | Personal Access Token. If unset, first tool call opens browser for Microsoft login. |

## Auth

Two options:
- **Interactive (default):** first ADO tool call opens a browser for Microsoft OAuth login.
- **PAT:** set `AZURE_DEVOPS_EXT_PAT=<token>` to skip the browser.

## Available Domains

Use `ADO_DOMAINS` with any combination of:
`advanced-security`, `pipelines`, `core`, `repositories`, `search`, `test-plans`, `wiki`, `work`, `work-items`

## Example Prompts

```
List my ADO projects
List work items in current iteration for project Contoso
List ADO builds for Contoso
List repos for project Contoso
List test plans for Contoso
```

## Reload

If pi is already running when you set `ADO_ORG`, use `/reload` to pick up the extension.
