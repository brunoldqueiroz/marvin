# Marvin

<p align="center">
  <a href="https://github.com/brunoldqueiroz/marvin/releases"><img src="https://img.shields.io/badge/version-0.27.0-blue" alt="version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="license"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude%20Code-powered-blueviolet" alt="Claude Code"></a>
</p>

A Claude Code orchestration layer that adds session memory, agent delegation,
and observability through hooks, specialist agents, and structured reasoning.

## Install

```shell
curl -fsSL https://raw.githubusercontent.com/brunoldqueiroz/marvin/main/install.sh | bash
```



## MCP Servers

Marvin uses three MCP servers (configured in `.mcp.json`):
**Context7** (docs), **Exa** (search), **Qdrant** (knowledge base).

Create a `.env` file with your API keys:

```bash
CONTEXT7_API_KEY=...
EXA_API_KEY=...
QDRANT_URL=...
QDRANT_API_KEY=...
```

## How It Works

Marvin operates on an **Orient → Think → Work → Persist** cycle:

1. **Orient** — Hooks inject git context and previous session summary on start
2. **Think** — Reason about the task, route to the right topology, plan if uncertain
3. **Work** — Delegate with structured handoffs, evaluate output, recover from failures
4. **Persist** — Write session log for continuity across sessions

