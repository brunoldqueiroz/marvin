# Marvin

A Claude Code orchestration layer that thinks before acting, plans before
executing, and delegates to specialist agents.

Marvin adds session memory, agent delegation, and observability to Claude Code
through hooks, a structured brain, and specialist agents.

## What's Included (v0.1.0)

- **Brain** — Topology-based routing (trivial/focused/multi-domain/architectural)
  and structured handoff protocol for agent delegation
- **Researcher agent** — Proactive research specialist with Context7, Exa,
  and Qdrant KB access
- **5 hooks** — Session context (model, source, git state), persistence,
  compaction resilience, agent quality gate with metrics
- **3 MCP servers** — Context7 (docs), Exa (search), Qdrant (knowledge base)

## Setup

```bash
# Clone the repository
git clone <repo-url> && cd marvin

# Create .env with your API keys (or .envrc for direnv)
# Required:
#   CONTEXT7_API_KEY  — Context7 MCP access
#   EXA_API_KEY       — Exa search access
#   QDRANT_URL        — Qdrant Cloud endpoint
#   QDRANT_API_KEY    — Qdrant Cloud access

# Run Claude Code from the project directory
claude
```

## Project Structure

```
.claude/
  CLAUDE.md                      # Brain — routing + handoff protocol
  settings.json                  # Hooks + permissions
  agents/researcher/AGENT.md     # Research specialist
  hooks/
    _lib.sh                      # Shared utilities (json_val)
    session-context.sh           # SessionStart: model, source, git, previous session
    compact-reinject.sh          # SessionStart(compact): recover after compaction
    pre-compact-save.sh          # PreCompact: snapshot before compaction
    session-persist.sh           # Stop: transcript → session log (model, mode, tools)
    subagent-quality-gate.sh     # SubagentStop: validate + metrics (agent_id, transcript)
.mcp.json                        # MCP server configuration
```

## How It Works

Marvin operates on an **Orient → Work → Persist** cycle:

1. **Orient** — On session start, hooks inject session metadata (model, source),
   git context, and the previous session summary
2. **Work** — The brain chooses a topology for the task: handle directly if no
   specialist covers it, or delegate with a structured handoff (objective, key
   files, constraints, output format)
3. **Persist** — On session end, hooks parse the transcript and write a structured
   summary (model, permission mode, prompts, tools, files, commits) for the next
   session

## Observability

Two files in `.claude/dev/` (gitignored) provide session-level telemetry:

- **`session-log.md`** — Per-session summaries: user prompts, tools used, files
  modified, git commits, agent usage, model, and permission mode
- **`metrics.jsonl`** — Per-agent-invocation metrics: agent_id, status,
  output length, artifact detection, transcript path, permission mode
