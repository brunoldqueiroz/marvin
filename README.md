# Marvin

[![version](https://img.shields.io/badge/version-0.11.1-blue)](https://github.com/brunoldqueiroz/marvin/releases)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-powered-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)

A Claude Code orchestration layer that thinks before acting, plans before
executing, and delegates to specialist agents.

Marvin adds session memory, agent delegation, and observability to Claude Code
through hooks, a structured brain, and specialist agents.

## What's Included (v0.11.1)

- **Brain** — Think → Route → Delegate → Evaluate → Recover cycle with
  topology-based routing, structured handoff protocol, and failure recovery
- **Ralph Loop** — Autonomous implementation workflow: `/prd` → `/ralph` →
  `ralph.sh` spawns fresh Claude Code sessions until all stories pass, with
  post-implementation verification and automatic run archival
- **SDD Light** — Structured acceptance criteria (`scenario/when/then/verify`),
  project-wide constitution constraints (`must/must_not/prefer`), and
  `/spec-check` readiness validation before autonomous execution
- **Researcher agent** — Proactive research specialist with Context7, Exa,
  and Qdrant KB access
- **13 skills** — 10 expert advisors + `/prd` (PRD generator) + `/ralph`
  (PRD-to-JSON converter) + `/spec-check` (PRD readiness validator)
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
/prd → tasks/prd-feature.md (markdown PRD with structured criteria + constitution)
/spec-check → validates prd.json readiness (score 0–11, READY/REVIEW/BLOCK)
/ralph → prd.json (JSON task list, passes: false)
./scripts/ralph.sh [max_iterations]
  └─ Iteration N: claude -p <prompt> (constitution injected if present)
     └─ Reads prd.json → implements 1 story → tests → commits → updates prd.json
     └─ Exits (fresh context on next iteration)
  └─ All stories pass → verify each criteria.verify command → archive run → exit 0
```

### Step 1: Create a PRD

```bash
# Inside Claude Code, run:
/prd
```

The skill asks clarifying questions (including architectural constraints) and
generates a structured PRD at `tasks/prd-{feature}.md` with user stories,
structured acceptance criteria (`scenario/when/then/verify`), and an optional
constitution (`must/must_not/prefer`).

### Step 2: Convert to JSON

```bash
/ralph
```

Converts the markdown PRD to `prd.json` — the task tracking file the loop uses.
Each story starts with `passes: false`. Structured criteria and constitution are
preserved. Flat string criteria from older PRDs are auto-converted.

### Step 2.5: Validate readiness (optional)

```bash
/spec-check
```

Runs 6 quality checks on `prd.json` (criteria count, verify coverage, dependency
order, story size, quality gates, constitution presence) and scores 0–11. A score
of 9+ means READY to run the loop.

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
7. Post-completion: ralph.sh runs each `verify` command to confirm, reverts
   `passes` on failure, and archives the run to `archive/{feature}-{date}/`

### Runtime files (gitignored)

| File | Purpose |
|------|---------|
| `prd.json` | Active task state — stories with `passes` flags |
| `progress.txt` | Append-only learnings log across iterations |
| `.last-branch` | Branch change detection for archival |
| `.verified-stories` | Tracks which stories passed post-verification |
| `archive/` | Archived runs (prd.json + progress.txt per feature) |

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
    spec-check/SKILL.md            # /spec-check — PRD readiness validator (workflow)
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
