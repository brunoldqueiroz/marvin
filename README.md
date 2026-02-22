# Marvin

Data Engineering & AI Assistant — a Claude Code orchestration layer.

Marvin adds session memory, agent delegation, and observability to Claude Code
through hooks, a structured brain, and specialist agents.

## What's Included (v0.1.0)

- **Brain** — Generalist orchestrator that routes tasks and delegates to specialists
- **Researcher agent** — Deep research with Context7, Exa, and Qdrant KB
- **5 hooks** — Session context, persistence, compaction resilience, agent quality gate
- **3 MCP servers** — Context7 (docs), Exa (search), Qdrant (knowledge base)

## Setup

```bash
# Clone the repository
git clone <repo-url> && cd marvin

# Create .env with your API keys
cp .env.example .env  # then edit with your keys

# Required environment variables:
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
  CLAUDE.md                      # Brain — orchestrator instructions
  settings.json                  # Hooks + permissions
  agents/researcher/AGENT.md     # Research specialist
  hooks/
    _lib.sh                      # Shared utilities (json_val)
    session-context.sh           # SessionStart: git + previous session
    compact-reinject.sh          # SessionStart(compact): recover after compaction
    pre-compact-save.sh          # PreCompact: snapshot before compaction
    session-persist.sh           # Stop: transcript → session log
    subagent-quality-gate.sh     # SubagentStop: validate + metrics
.mcp.json                        # MCP server configuration
```

## How It Works

Marvin operates on an **Orient → Work → Persist** cycle:

1. **Orient** — On session start, hooks inject git context and the previous
   session summary so Claude knows where it left off
2. **Work** — The brain routes tasks: research goes to the researcher agent,
   everything else is handled directly
3. **Persist** — On session end, hooks parse the transcript and write a
   structured summary for the next session
