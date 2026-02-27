# Specification: Marvin v0.3.0 — Ralph Loop + Dev Container

## Context

Two capabilities inform this spec:

1. **Dev Container** — Docker-based development environment that sandboxes Claude
   Code, enabling `--dangerously-skip-permissions` safely. The Anthropic reference
   implementation (`.devcontainer/` in `anthropics/claude-code`) combines iptables
   firewall, non-root user, and workspace mount isolation.

2. **Ralph Loop** — Self-iterating agent pattern (Geoffrey Huntley, 2025) where a
   bash loop feeds the same prompt to Claude Code until a verifiable completion
   condition is met. State persists in files and git, not in the context window.
   Each iteration starts with clean context — operating in the "smart zone."

### Why together

Neither is useful alone for Marvin:

- **Dev Container without Ralph Loop** = sandbox with no autonomy. Marvin already
  runs interactively; a container alone just adds setup friction.
- **Ralph Loop without Dev Container** = autonomy without safety. Running
  `--dangerously-skip-permissions` on bare metal risks host damage from prompt
  injection or runaway commands.

Together they form the **autonomous execution layer**: the container bounds the
blast radius while the loop drives continuous progress.

### Guiding principle

> Dev Container for **where** the agent runs (isolation).
> Ralph Loop for **how** the agent persists (iteration).
> Existing hooks for **what** the agent must not violate (enforcement).

---

## 1. Dev Container

### 1.1 File structure

```
.devcontainer/
├── devcontainer.json      # Container definition
├── Dockerfile             # Image with Claude Code + Marvin deps
└── init-firewall.sh       # iptables default-deny allowlist
```

### 1.2 devcontainer.json

```jsonc
{
  "name": "Marvin Sandbox",
  "build": {
    "dockerfile": "Dockerfile",
    "args": {
      "TZ": "${localEnv:TZ:America/Sao_Paulo}",
      "CLAUDE_CODE_VERSION": "latest"
    }
  },

  // NET_ADMIN required for iptables inside container
  "runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW"
  ],

  // Non-root user — Claude Code runs unprivileged
  "remoteUser": "node",

  // Persistent volumes: Claude config + bash history survive rebuilds
  "mounts": [
    "source=marvin-claude-config-${devcontainerId},target=/home/node/.claude,type=volume",
    "source=marvin-bash-history-${devcontainerId},target=/commandhistory,type=volume"
  ],

  // Only /workspace is accessible — host filesystem untouched
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
  "workspaceFolder": "/workspace",

  "containerEnv": {
    "DEVCONTAINER": "true",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude",
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "MARVIN_ENABLED": "1"
  },

  // Firewall runs on every start, IDE waits for it
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh",
  "waitFor": "postStartCommand",

  // Copy .envrc secrets into container on creation
  "initializeCommand": "echo 'Ensure .env exists with API keys before opening in container'",

  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "eamodio.gitlens"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh"
      }
    }
  }
}
```

**Design decisions:**

| Decision | Rationale |
|----------|-----------|
| `NET_ADMIN` + `NET_RAW` | Required for iptables. No `privileged` — least privilege |
| `remoteUser: node` | Claude Code is Node-based; non-root limits blast radius |
| Named volumes for `~/.claude` | Auth tokens + session state survive container rebuilds |
| `waitFor: postStartCommand` | IDE blocks until firewall is active — no window of exposure |
| No Docker-in-Docker | Marvin doesn't run containers; avoids attack surface |

### 1.3 Dockerfile

```dockerfile
FROM node:20-slim

ARG TZ=America/Sao_Paulo
ARG CLAUDE_CODE_VERSION=latest

ENV TZ=${TZ}
ENV DEBIAN_FRONTEND=noninteractive

# System deps: firewall + dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables ipset iproute2 dnsutils \
    git git-lfs gh curl jq fzf zsh vim-tiny sudo \
    python3 python3-pip python3-venv \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Claude Code (global install)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# uv (Python package manager — used by Marvin's MCP servers)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && ln -s /root/.local/bin/uv /usr/local/bin/uv \
  && ln -s /root/.local/bin/uvx /usr/local/bin/uvx

# Firewall script
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# Non-root user setup: node user can ONLY sudo the firewall script
RUN echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall \
  && chmod 0440 /etc/sudoers.d/firewall

# Command history persistence
RUN mkdir -p /commandhistory \
  && touch /commandhistory/.zsh_history \
  && chown -R node:node /commandhistory
ENV HISTFILE=/commandhistory/.zsh_history

USER node
WORKDIR /workspace
```

**What's included and why:**

| Package | Why |
|---------|-----|
| `iptables`, `ipset`, `iproute2`, `dnsutils` | Network firewall |
| `python3`, `python3-venv` | Marvin hooks use Python fallback; `uvx` needs Python |
| `uv` / `uvx` | Runs MCP servers (Qdrant uses `uvx mcp-server-qdrant`) |
| `gh` | GitHub CLI — used by permissions allowlist |
| `jq` | Hooks use jq for JSON parsing |
| `git`, `git-lfs` | State persistence layer for Ralph Loop |

**What's NOT included:**

| Package | Why not |
|---------|---------|
| Docker-in-Docker | Marvin doesn't need containers inside containers |
| Node.js feature | Already in base image `node:20-slim` |
| Any IDE | VS Code connects remotely; no need to install inside |

### 1.4 init-firewall.sh

```bash
#!/bin/bash
# init-firewall.sh — Default-deny iptables allowlist for Marvin sandbox
# Runs as root via scoped sudoers on every container start.
set -euo pipefail

echo "[firewall] Configuring network allowlist..."

# Flush existing rules
iptables -F OUTPUT 2>/dev/null || true
ipset destroy allowed-ips 2>/dev/null || true

# Create IP set for allowed destinations
ipset create allowed-ips hash:net

# --- Allowed domains ---

# Anthropic API (Claude Code)
for ip in $(dig +short api.anthropic.com 2>/dev/null); do
  ipset add allowed-ips "$ip" 2>/dev/null || true
done

# npm registry (package installs)
for ip in $(dig +short registry.npmjs.org 2>/dev/null); do
  ipset add allowed-ips "$ip" 2>/dev/null || true
done

# PyPI (uv/pip installs)
for ip in $(dig +short pypi.org files.pythonhosted.org 2>/dev/null); do
  ipset add allowed-ips "$ip" 2>/dev/null || true
done

# GitHub (git operations + gh CLI)
if command -v curl &>/dev/null; then
  GITHUB_IPS=$(curl -s https://api.github.com/meta 2>/dev/null \
    | jq -r '.git[],.api[],.web[]' 2>/dev/null || true)
  for cidr in $GITHUB_IPS; do
    ipset add allowed-ips "$cidr" 2>/dev/null || true
  done
fi

# Exa API (MCP search)
for ip in $(dig +short mcp.exa.ai 2>/dev/null); do
  ipset add allowed-ips "$ip" 2>/dev/null || true
done

# Context7 API (MCP docs)
for ip in $(dig +short mcp.context7.com 2>/dev/null); do
  ipset add allowed-ips "$ip" 2>/dev/null || true
done

# Qdrant Cloud (MCP knowledge base)
QDRANT_HOST=$(echo "${QDRANT_URL:-}" | sed 's|https\?://||' | sed 's|/.*||')
if [ -n "$QDRANT_HOST" ]; then
  for ip in $(dig +short "$QDRANT_HOST" 2>/dev/null); do
    ipset add allowed-ips "$ip" 2>/dev/null || true
  done
fi

# VS Code Remote + extensions marketplace
for domain in \
  update.code.visualstudio.com \
  marketplace.visualstudio.com \
  vscode.blob.core.windows.net \
  dc.services.visualstudio.com; do
  for ip in $(dig +short "$domain" 2>/dev/null); do
    ipset add allowed-ips "$ip" 2>/dev/null || true
  done
done

# --- Apply rules ---

# Allow DNS (required for domain resolution)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow loopback (MCP servers run locally)
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections (responses to allowed requests)
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow connections to allowed IPs
iptables -A OUTPUT -m set --match-set allowed-ips dst -j ACCEPT

# Drop everything else
iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable

# --- Verify ---
echo "[firewall] Testing..."

# Should fail
if curl -sf --max-time 3 https://example.com >/dev/null 2>&1; then
  echo "[firewall] WARNING: example.com is reachable — firewall may be misconfigured"
else
  echo "[firewall] OK: example.com blocked"
fi

# Should succeed
if curl -sf --max-time 5 https://api.github.com >/dev/null 2>&1; then
  echo "[firewall] OK: api.github.com reachable"
else
  echo "[firewall] WARNING: api.github.com unreachable — check DNS/network"
fi

echo "[firewall] Done."
```

**Marvin-specific additions vs Anthropic reference:**

| Domain | Why |
|--------|-----|
| `mcp.exa.ai` | Exa MCP server (research agent's primary tool) |
| `mcp.context7.com` | Context7 MCP server (library docs) |
| `$QDRANT_HOST` (dynamic) | Qdrant Cloud (knowledge base) |
| `pypi.org` + `files.pythonhosted.org` | `uvx` needs PyPI to download MCP servers |

---

## 2. Ralph Loop

### 2.1 Architecture decision: bash loop, not Stop hook

The Anthropic `ralph-wiggum` plugin uses a Stop hook to re-inject the prompt
within the same session. This causes context accumulation — by iteration 3-4,
the model operates in degraded space.

Marvin already suffers from context decay (ETH Zurich research cited in
spec-v0.2.0: CLAUDE.md compliance drops to <20% after 10+ messages). Adding
intra-session loop iterations would compound this.

**Decision: external bash loop** — each iteration gets a fresh Claude Code
session with clean context. The loop script lives outside Claude's control.

### 2.2 File structure

```
scripts/
├── ralph.sh               # The loop driver
└── ralph-prompt.md.tmpl   # Prompt template (user creates per-task)
.ralph/                     # Runtime state (gitignored)
├── progress.md             # Append-only log of learnings across iterations
├── iteration.log           # Current iteration number + timestamps
└── tasks.md                # Task list with completion status
```

### 2.3 ralph.sh — the loop driver

```bash
#!/bin/bash
# ralph.sh — Ralph Loop driver for Marvin
# Usage: ./scripts/ralph.sh <prompt-file> [--max-iterations N] [--dry-run]
set -euo pipefail

# --- Defaults ---
PROMPT_FILE="${1:?Usage: ralph.sh <prompt-file> [--max-iterations N]}"
MAX_ITERATIONS=20
DRY_RUN=false
COMPLETION_MARKER="<marvin:complete/>"
RALPH_DIR=".ralph"

# --- Parse flags ---
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# --- Validate ---
if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: prompt file '$PROMPT_FILE' not found" >&2
  exit 1
fi

# --- Initialize state ---
mkdir -p "$RALPH_DIR"

if [ ! -f "$RALPH_DIR/progress.md" ]; then
  cat > "$RALPH_DIR/progress.md" << 'EOF'
# Progress Log

Append-only log of learnings, patterns, and decisions across iterations.
Each iteration should add what it learned, what it changed, and what remains.

---
EOF
fi

if [ ! -f "$RALPH_DIR/iteration.log" ]; then
  echo "0" > "$RALPH_DIR/iteration.log"
fi

# --- Loop ---
ITERATION=$(cat "$RALPH_DIR/iteration.log")

while [ "$ITERATION" -lt "$MAX_ITERATIONS" ]; do
  ITERATION=$((ITERATION + 1))
  echo "$ITERATION" > "$RALPH_DIR/iteration.log"

  echo ""
  echo "═══════════════════════════════════════════════"
  echo "  RALPH ITERATION $ITERATION / $MAX_ITERATIONS"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "═══════════════════════════════════════════════"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] Would run: claude -p < $PROMPT_FILE"
    sleep 1
    continue
  fi

  # Build the prompt with current state context
  PROMPT="$(cat "$PROMPT_FILE")"

  # Inject iteration metadata
  PROMPT="$PROMPT

---
## Ralph Loop Context (auto-injected)
- Iteration: $ITERATION / $MAX_ITERATIONS
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Progress log: .ralph/progress.md (READ THIS FIRST)
- Task list: .ralph/tasks.md (if it exists)

### Instructions for this iteration:
1. Read .ralph/progress.md to understand what previous iterations accomplished
2. Read .ralph/tasks.md to find the next incomplete task
3. Implement ONE task (or continue an incomplete one)
4. Update .ralph/progress.md with what you learned and changed
5. Mark the task complete in .ralph/tasks.md
6. Commit your changes with a descriptive message
7. If ALL tasks are complete, output exactly: $COMPLETION_MARKER
8. If you cannot make progress, document the blocker in .ralph/progress.md
"

  # Run Claude Code — fresh session, skip permissions (inside container)
  OUTPUT=$(echo "$PROMPT" | claude \
    --dangerously-skip-permissions \
    --output-format text \
    -p 2>&1) || true

  # Log output summary
  echo "$OUTPUT" | tail -20

  # Check for completion
  if echo "$OUTPUT" | grep -qF "$COMPLETION_MARKER"; then
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  COMPLETE after $ITERATION iterations"
    echo "═══════════════════════════════════════════════"
    exit 0
  fi

  # Check for stuck detection (same git hash as previous iteration)
  CURRENT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "none")
  if [ -f "$RALPH_DIR/.last-hash" ]; then
    LAST_HASH=$(cat "$RALPH_DIR/.last-hash")
    if [ "$CURRENT_HASH" = "$LAST_HASH" ]; then
      echo "[ralph] WARNING: No git changes in this iteration (possible stuck loop)"
    fi
  fi
  echo "$CURRENT_HASH" > "$RALPH_DIR/.last-hash"

  # Brief pause between iterations (rate limiting courtesy)
  sleep 2
done

echo ""
echo "═══════════════════════════════════════════════"
echo "  MAX ITERATIONS ($MAX_ITERATIONS) reached"
echo "  Check .ralph/progress.md for current state"
echo "═══════════════════════════════════════════════"
exit 1
```

### 2.4 Prompt template

```markdown
# ralph-prompt.md.tmpl — Template for Ralph Loop prompts

You are Marvin, working inside an automated Ralph Loop.
Your full instructions are in .claude/CLAUDE.md — read it.

## Task

<!-- Replace with your specific task description -->
Implement [FEATURE/REFACTOR/MIGRATION] as described in [SPEC_FILE].

## Completion Criteria

<!-- Machine-verifiable conditions. Examples: -->
- [ ] All tests pass: `pytest -q`
- [ ] No lint errors: `ruff check .`
- [ ] Type check clean: `mypy .`
- [ ] All items in .ralph/tasks.md marked complete

## Constraints

- MUST commit after each completed task
- MUST update .ralph/progress.md with learnings
- MUST NOT modify files outside the scope of the current task
- PREFER small, focused commits over large multi-file changes
- If stuck for more than 5 minutes on one task, document the blocker
  and move to the next task

## When ALL tasks are complete

Output exactly: <marvin:complete/>
```

### 2.5 State model

The Ralph Loop uses three state files, all in `.ralph/` (gitignored by default,
but optionally committable for shared tasks):

| File | Purpose | Written by |
|------|---------|------------|
| `progress.md` | Append-only log of learnings per iteration | Claude (each iteration) |
| `tasks.md` | Checklist with `- [x]` / `- [ ]` status | User (initial), Claude (updates) |
| `iteration.log` | Current iteration number | `ralph.sh` (loop driver) |
| `.last-hash` | Git hash of previous iteration (stuck detection) | `ralph.sh` |

**Why `.ralph/` and not `.artifacts/`?** `.artifacts/` is Marvin's agent handoff
directory (cleaned between workflows). Ralph state must persist across iterations
— it's the loop's memory. Different lifecycle, different directory.

### 2.6 Integration with existing hooks

The Ralph Loop runs Claude Code sessions. Each session triggers Marvin's existing
hooks. Here's how they interact:

| Hook | Ralph Loop behavior | Changes needed |
|------|-------------------|----------------|
| `session-context.sh` (SessionStart) | Fires each iteration — injects git context and last session | **None** — works as-is. Each iteration benefits from git context |
| `compact-reinject.sh` (SessionStart:compact) | Unlikely to fire — each iteration starts fresh | **None** |
| `pre-compact-save.sh` (PreCompact) | Unlikely to fire — fresh context per iteration | **None** |
| `session-persist.sh` (Stop) | Fires each iteration — writes to session-log.md | **Add**: detect `RALPH_ITERATION` env var, tag entries with iteration number |
| `subagent-quality-gate.sh` (SubagentStop) | Fires for any subagent delegations within an iteration | **None** |

**Only one hook needs modification**: `session-persist.sh` should detect Ralph
Loop context and annotate session log entries:

```bash
# In session-persist.sh — after building ENTRY header
if [ -n "${RALPH_ITERATION:-}" ]; then
  ENTRY="## Session: $TIMESTAMP (branch: $BRANCH) [ralph:$RALPH_ITERATION]
"
fi
```

The `ralph.sh` script exports `RALPH_ITERATION` before each `claude` invocation:

```bash
export RALPH_ITERATION="$ITERATION"
```

---

## 3. Safety Mechanisms

### 3.1 Defense in depth

```
Layer 1: Dev Container        — filesystem + process isolation
Layer 2: iptables firewall    — network exfiltration prevention
Layer 3: Non-root user        — privilege limitation
Layer 4: Max iterations       — runaway loop prevention
Layer 5: Stuck detection      — no-progress detection per iteration
Layer 6: Existing hooks       — quality gate + metrics on subagents
Layer 7: Permission deny list — settings.json blocks destructive commands
```

### 3.2 What the container prevents

| Threat | Mitigation |
|--------|------------|
| Prompt injection → data exfiltration | Firewall blocks all non-allowlisted hosts |
| Runaway `rm -rf` | Only `/workspace` mounted; host untouched |
| Credential theft | Only explicitly-passed env vars available |
| Crypto mining / abuse | Network restricted; no outbound to arbitrary hosts |
| Infinite loop cost | `--max-iterations` cap on ralph.sh |

### 3.3 What the container does NOT prevent

| Threat | Why | Mitigation |
|--------|-----|------------|
| Kernel exploit → container escape | Shared kernel with host | Accept risk for personal dev; use microVM for higher assurance |
| Bad code committed to repo | Agent has git access by design | Code review before merging Ralph Loop output |
| API cost overrun | Claude API calls are allowed | `--max-iterations` + monitoring `.ralph/iteration.log` |
| Corrupted project state | Agent can write to /workspace | Git history as rollback mechanism; branch per Ralph run |

### 3.4 Operational safety protocol

1. **Always run Ralph Loop on a branch**, never on `main`:
   ```bash
   git checkout -b ralph/feature-name
   ./scripts/ralph.sh prompts/feature-name.md --max-iterations 15
   ```
2. **Start with `--max-iterations 3`** to validate the prompt before going AFK
3. **Review `.ralph/progress.md`** after each run before merging
4. **Use `--dry-run`** to verify the prompt injection without running Claude

---

## 4. .gitignore additions

```gitignore
# Ralph Loop runtime state
.ralph/
```

**Note**: `.ralph/` is gitignored by default. For shared tasks where multiple
developers iterate on the same Ralph Loop, commit `.ralph/tasks.md` and
`.ralph/progress.md` explicitly with `git add -f`.

---

## 5. Change Summary

### Files to create

| File | Purpose |
|------|---------|
| `.devcontainer/devcontainer.json` | Container definition |
| `.devcontainer/Dockerfile` | Image with Claude Code + Marvin deps |
| `.devcontainer/init-firewall.sh` | iptables default-deny allowlist |
| `scripts/ralph.sh` | Ralph Loop driver |
| `scripts/ralph-prompt.md.tmpl` | Prompt template |

### Files to modify

| File | Change |
|------|--------|
| `.claude/hooks/session-persist.sh` | Detect `RALPH_ITERATION` env var, tag log entries |
| `.gitignore` | Add `.ralph/` |

### Files NOT to create

| File | Reason |
|------|--------|
| Stop hook for Ralph | Bash loop is superior — clean context each iteration |
| `ralph-wiggum` plugin | External loop avoids context accumulation |
| `.ralph/` committed state | Runtime state; gitignored by default |
| Docker Compose | Single container; no orchestration needed |
| `Makefile` / task runner | `ralph.sh` is self-contained; KISS |

### Files NOT to modify

| File | Reason |
|------|--------|
| `CLAUDE.md` | No new instructions needed — Ralph Loop is external to Claude |
| `settings.json` | No new hooks or permissions needed |
| `AGENT.md` (researcher) | Subagents work unchanged inside Ralph iterations |
| `.mcp.json` | MCP servers work unchanged inside container |

---

## 6. Implementation Order

```
Phase 1: Dev Container (can be used immediately, independent of Ralph Loop)
  1. Create .devcontainer/Dockerfile
  2. Create .devcontainer/init-firewall.sh
  3. Create .devcontainer/devcontainer.json
  4. Test: open in VS Code Dev Container, verify firewall, verify claude runs

Phase 2: Ralph Loop (requires Dev Container for safe --dangerously-skip-permissions)
  5. Create scripts/ralph.sh
  6. Create scripts/ralph-prompt.md.tmpl
  7. Modify .claude/hooks/session-persist.sh (Ralph iteration tagging)
  8. Add .ralph/ to .gitignore
  9. Test: run ralph.sh with --dry-run, then --max-iterations 3 on a trivial task

Phase 3: Validation
  10. Run a real task end-to-end inside container with Ralph Loop
  11. Verify session-log.md entries are tagged with [ralph:N]
  12. Verify firewall blocks unauthorized domains
  13. Verify stuck detection works (loop that makes no git changes)
```

---

## 7. Future Considerations (NOT in this spec)

| Idea | When to revisit |
|------|-----------------|
| GitHub Codespaces support | When collaborators need cloud-hosted Marvin |
| Cost tracking per Ralph run | When API spend exceeds $50/month |
| `/ralph` skill (user-invocable) | After 3+ manual Ralph runs prove the pattern |
| `prd.json` structured task format | When `tasks.md` checklist proves insufficient |
| gVisor / Firecracker | When running untrusted code from external PRs |
| Multi-agent Ralph (parallel loops) | When single-agent throughput bottlenecks |

---

## 8. Sources

- [anthropics/claude-code .devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) — Official Anthropic reference sandbox
- [everything is a ralph loop — Geoffrey Huntley](https://ghuntley.com/loop/) — Canonical Ralph Loop blog post
- [snarktank/ralph](https://github.com/snarktank/ralph) — Reference implementation (11.2k stars)
- [Why the Anthropic Ralph plugin sucks](https://www.aihero.dev/why-the-anthropic-ralph-plugin-sucks) — Context accumulation critique
- [How to Safely Run AI Agents Inside a DevContainer](https://codewithandrea.com/articles/run-ai-agents-inside-devcontainer/) — Practical setup guide
- [Docker Sandboxes](https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/) — MicroVM alternative for higher assurance
- [From ReAct to Ralph Loop — Alibaba Cloud](https://www.alibabacloud.com/blog/from-react-to-ralph-loop-a-continuous-iteration-paradigm-for-ai-agents_602799) — Technical comparison with ReAct
- [11 Tips for Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) — Best practices
- [ETH Zurich 2026, arXiv:2509.14744](https://arxiv.org/abs/2509.14744) — Instruction file efficacy research
- Marvin spec-v0.2.0 — Prior research on hooks, skills, and context decay

### README/CHANGELOG version

- v0.3.0: "Add Dev Container sandbox and Ralph Loop for autonomous execution"
