# docs

https://pi.dev/docs/latest/

    npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Other configs

> [!NOTE]
> Many bits are shamelessly stolen from

- https://github.com/narumiruna/pi-extensions
- https://github.com/tomsej/pi-ext
- https://github.com/mitsuhiko/agent-stuff
- https://github.com/badlogic/pi-skills
- https://github.com/tmustier/pi-extensions/tree/main/pi-ralph-wiggum
- https://github.com/amosblomqvist/pi-config

# Packages

## Pi Web Access
Web search, content extraction, and video understanding for Pi agent.
OpenAI/Codex search, zero-config Exa search, Brave, Parallel, TinyFish, Tavily,
SERPdive, AnySearch, self-hosted SearXNG, optional browser-cookie Gemini Web, or
bring your own API keys.

    pi install git:github.com/nicobailon/pi-web-access

## code search

Semantic search

    uv tool install semble
    semble install
    uv tool upgrade semble   # upgrade
    uv cache clean semble    # for MCP users (restart your MCP client after)

Graph search

    uv tool install graphifyy
    graphify install --platform pi

## subagents
    pi install git:github.com/HazAT/pi-interactive-subagents
