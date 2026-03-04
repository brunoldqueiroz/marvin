# Marvin

[![version](https://img.shields.io/badge/version-0.14.0-blue)](https://github.com/brunoldqueiroz/marvin/releases)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-powered-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)

A Claude Code orchestration layer that thinks before acting, plans before
executing, and delegates to specialist agents.

Marvin adds session memory, agent delegation, and observability to Claude Code
through hooks, a structured brain, and specialist agents.

## What's Included (v0.14.0)

- **Brain** — Think → Route → Delegate → Evaluate → Recover cycle with
  topology-based routing, structured handoff protocol, and failure recovery
- **Researcher agent** — Proactive research specialist with Context7, Exa,
  and Qdrant KB access
- **10 skills** — Expert advisors: python, dbt, spark, airflow, aws, docker,
  docs, git, snowflake, terraform
- **Observability hooks** — Session context, tool usage, agent quality gate,
  metrics logging to JSONL
- **3 MCP servers** — Context7 (docs), Exa (search), Qdrant (knowledge base)
- **CLI** — `marvin init`, `marvin agents`, `marvin skills`, `marvin metrics`

## Install

```bash
uv tool install git+https://github.com/brunoldqueiroz/marvin
```

Or with pipx:

```bash
pipx install git+https://github.com/brunoldqueiroz/marvin
```

Or via the one-line installer (tries uv, falls back to pipx):

```bash
curl -fsSL https://raw.githubusercontent.com/brunoldqueiroz/marvin/main/install.sh | bash
```

### Prerequisites

- `python3 >= 3.10`
- `uv` or `pipx`

### Upgrading

```bash
uv tool upgrade marvin-cli
# or
pipx upgrade marvin-cli
```

## CLI Usage

```bash
# Initialize Marvin in your project (uses bundled data, no network)
marvin init

# Initialize in a specific directory
marvin init /path/to/project

# Download latest from GitHub main branch
marvin init --latest

# Download a specific version
marvin init --ref v0.4.0

# Overwrite existing .claude/ without prompting
marvin init --force

# List available agents and skills
marvin agents
marvin skills

# View metrics insights for current project
marvin metrics
marvin metrics --json          # JSON output for scripting

# Version and help
marvin --version
marvin --help
```

## MCP Servers

Marvin uses three MCP servers (configured in `.mcp.json`):

- **Context7** — Up-to-date library documentation
- **Exa** — Web search and research
- **Qdrant** — Persistent knowledge base

Create a `.env` file with your API keys:

```bash
CONTEXT7_API_KEY=...
EXA_API_KEY=...
QDRANT_URL=...
QDRANT_API_KEY=...
```

## Project Structure

```
cli/
  __init__.py                      # Package marker
  marvin.py                        # CLI entry point (click + loguru)
install.sh                         # One-line installer (uv/pipx)
.claude/
  CLAUDE.md                        # Brain — reasoning, routing, handoff, recovery
  settings.json                    # Hooks + permissions
  agents/researcher/AGENT.md       # Research specialist
  skills/
    */SKILL.md                     # 10 expert advisory skills
  hooks/
    _lib.sh                        # Shared utilities (log_metric, json_val)
    session-start-context.sh       # SessionStart: inject git + previous session context
    session-start-log.sh           # SessionStart: log session_start metric
    session-start-reinject.sh      # SessionStart(compact): recover after compaction
    session-end-log.sh             # SessionEnd: log session_end metric
    pre-compact-save.sh            # PreCompact: snapshot before compaction
    pre-tool-use-block-secrets.sh  # PreToolUse: block secret exposure
    post-tool-use-log.sh           # PostToolUse: tool invocation tracking
    post-tool-use-mcp-monitor.sh   # PostToolUse: MCP error detection
    post-tool-failure-log.sh       # PostToolUseFailure: failure tracking
    stop-persist.sh                # Stop: persist raw session log
    subagent-start-log.sh          # SubagentStart: spawn tracking
    subagent-stop-gate.sh          # SubagentStop: quality gate
    subagent-stop-log.sh           # SubagentStop: log subagent metrics
    user-prompt-log.sh             # UserPromptSubmit: prompt tracking
    notification-log.sh            # Notification: idle/permission tracking
  dev/                             # Gitignored — metrics.jsonl, session_logs/
.mcp.json                          # MCP server configuration
```

## How It Works

Marvin operates on an **Orient → Think → Work → Persist** cycle:

1. **Orient** — On session start, hooks inject session metadata (model, source),
   git context, and the previous session summary
2. **Think** — The brain reasons about the task: can I handle it directly? What
   subtasks? Parallel or sequential? Plan mode for uncertain approaches
3. **Work** — Route to the right topology, delegate with structured handoffs,
   evaluate output against acceptance criteria, recover from failures
4. **Persist** — On session stop, a hook writes a raw text log (git state,
   commits, uncommitted changes) to `session_logs/` for the next session

## Observability

Two locations in `.claude/dev/` (gitignored) provide session-level telemetry:

- **`session_logs/`** — Raw text logs per session (git state, commits,
  uncommitted changes). Last 10 kept, older rotated automatically
- **`metrics.jsonl`** — Unified event stream: session_start, session_end,
  tool_use, tool_failure, subagent_start, subagent_stop, user_prompt,
  notification

Use `marvin metrics` to analyze the JSONL data from the command line.
