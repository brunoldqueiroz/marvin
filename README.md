# Marvin

[![version](https://img.shields.io/badge/version-0.10.0-blue)](https://github.com/brunoldqueiroz/marvin/releases)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-powered-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)

A Claude Code orchestration layer that thinks before acting, plans before
executing, and delegates to specialist agents.

Marvin adds session memory, agent delegation, and observability to Claude Code
through hooks, a structured brain, and specialist agents.

## What's Included (v0.10.0)

- **Brain** — Think → Route → Delegate → Evaluate → Recover cycle with
  topology-based routing, structured handoff protocol, and failure recovery
- **Ralph Loop** — Autonomous implementation workflow: `/prd` → `/ralph` →
  `ralph.sh` spawns fresh Claude Code sessions until all stories pass
- **Researcher agent** — Proactive research specialist with Context7, Exa,
  and Qdrant KB access
- **12 skills** — 10 expert advisors + `/prd` (PRD generator) + `/ralph`
  (PRD-to-JSON converter)
- **Observability hooks** — Session context, tool usage, agent quality gate,
  metrics logging to JSONL
- **3 MCP servers** — Context7 (docs), Exa (search), Qdrant (knowledge base)
- **CLI** — `marvin init`, `marvin agents`, `marvin skills`, `marvin metrics`
- **Devcontainer** — Ready-to-use dev environment with Python 3.13, Node 22,
  uv, and Claude Code

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

## Ralph Loop (Autonomous Implementation)

The Ralph Loop is an autonomous implementation workflow inspired by
[snarktank/ralph](https://github.com/snarktank/ralph). It iteratively spawns
fresh Claude Code sessions to implement user stories until all acceptance
criteria pass.

### How it works

```
/prd → tasks/prd-feature.md (markdown PRD)
/ralph → prd.json (JSON task list, passes: false)
./scripts/ralph.sh [max_iterations]
  └─ Iteration N: claude -p <prompt>
     └─ Reads prd.json → implements 1 story → tests → commits → updates prd.json
     └─ Exits (fresh context on next iteration)
  └─ All stories pass → exit 0
```

### Step 1: Create a PRD

```bash
# Inside Claude Code, run:
/prd
```

The skill asks clarifying questions and generates a structured PRD at
`tasks/prd-{feature}.md` with user stories and testable acceptance criteria.

### Step 2: Convert to JSON

```bash
/ralph
```

Converts the markdown PRD to `prd.json` — the task tracking file the loop uses.
Each story starts with `passes: false`.

### Step 3: Run the loop in the devcontainer

The loop uses `--dangerously-skip-permissions`, which gives Claude Code full
system access. **Always run it inside the devcontainer** to isolate execution
from your host machine.

```bash
# 1. Open the project in the devcontainer (VS Code or GitHub Codespaces)
# 2. Inside the container, run:
./scripts/ralph.sh        # default: 10 iterations
./scripts/ralph.sh 20     # custom max iterations
```

**Why the devcontainer matters:** The `.claude/` directory is part of the
project workspace, so Claude Code automatically loads it on every session.
This means each `ralph.sh` iteration spawns Claude Code **as Marvin** — with
the brain (`CLAUDE.md`), all skills (`/prd`, `/ralph`, expert advisors),
hooks (quality gate, metrics, secrets blocking), and settings. The agent
inside the loop isn't a bare Claude Code — it's Marvin with full
orchestration capabilities.

The devcontainer provides:

| Component | How it gets there |
|-----------|-------------------|
| Python 3.13 + uv | Dockerfile base image |
| Node 22 + Claude Code | Devcontainer feature + `postCreateCommand` |
| Marvin CLI (`marvin`) | `uv sync` installs the project on PATH |
| Marvin config (`.claude/`) | Workspace mount — part of the repo |
| API keys | Forwarded from host via `remoteEnv` |
| Executable hooks | `postCreateCommand` runs `chmod +x` |

Each iteration spawns a fresh Claude Code session that:
1. Loads `.claude/CLAUDE.md` (Marvin brain), skills, hooks, and settings
2. Reads `prd.json` and `progress.txt`
3. Picks the highest-priority incomplete story
4. Implements it, runs quality checks, commits if passing
5. Updates `prd.json` (`passes: true`) and appends to `progress.txt`
6. Signals `<promise>COMPLETE</promise>` when all stories pass

### Runtime files (gitignored)

| File | Purpose |
|------|---------|
| `prd.json` | Active task state — stories with `passes` flags |
| `progress.txt` | Append-only learnings log across iterations |
| `.last-branch` | Branch change detection for archival |
| `archive/` | Archived runs from previous features |

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
scripts/
  ralph.sh                         # Ralph Loop orchestration script
tasks/                             # PRD storage (prd-*.md files)
prd.json.example                   # Reference PRD JSON schema
.devcontainer/
  devcontainer.json                # Dev environment configuration
  Dockerfile                       # Python 3.13 + git + jq + uv
.claude/
  CLAUDE.md                        # Brain — reasoning, routing, handoff, recovery
  settings.json                    # Hooks + permissions
  agents/researcher/AGENT.md       # Research specialist
  skills/
    prd/SKILL.md                   # /prd — PRD generator (workflow)
    ralph/SKILL.md                 # /ralph — PRD to JSON converter (workflow)
    */SKILL.md                     # 10 expert advisory skills
  hooks/
    _lib.sh                        # Shared utilities (log_metric, json_val)
    session-context.sh             # SessionStart: model, source, git, previous session
    session-end.sh                 # SessionEnd: log session_end event
    compact-reinject.sh            # SessionStart(compact): recover after compaction
    pre-compact-save.sh            # PreCompact: snapshot before compaction
    session-persist.sh             # Stop: transcript → session log
    subagent-quality-gate.sh       # SubagentStop: validate + metrics
    tool-usage-log.sh              # PostToolUse: tool invocation tracking
    tool-failure.sh                # PostToolUseFailure: failure tracking
    mcp-error-monitor.sh           # PostToolUse: MCP error detection
    block-secrets.sh               # PreToolUse: block secret exposure
  dev/                             # Gitignored — metrics.jsonl, session-log.md
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
4. **Persist** — On session end, hooks parse the transcript and write a structured
   summary (model, permission mode, prompts, tools, files, commits) for the next
   session

## Observability

Two files in `.claude/dev/` (gitignored) provide session-level telemetry:

- **`session-log.md`** — Per-session summaries: user prompts, tools used, files
  modified, git commits, agent usage, model, and permission mode
- **`metrics.jsonl`** — Unified event stream: session_start, session_end,
  tool_use, tool_failure, subagent_stop

Use `marvin metrics` to analyze the JSONL data from the command line.
