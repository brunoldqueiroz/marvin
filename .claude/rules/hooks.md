---
paths:
  - ".claude/hooks/**/*.sh"
---

# Hook Authoring Rules

## Naming Convention

Files MUST follow the pattern `{event}-{action}.sh` where `{event}` maps to
the Claude Code hook event:

| Event | Prefix | Example |
|-------|--------|---------|
| SessionStart | `session-start-` | `session-start-context.sh` |
| SessionEnd | `session-end-` | `session-end-log.sh` |
| PreCompact | `pre-compact-` | `pre-compact-save.sh` |
| PreToolUse | `pre-tool-use-` | `pre-tool-use-block-secrets.sh` |
| PostToolUse | `post-tool-use-` | `post-tool-use-log.sh` |
| PostToolUseFailure | `post-tool-failure-` | `post-tool-failure-log.sh` |
| Stop | `stop-` | `stop-persist.sh` |
| SubagentStart | `subagent-start-` | `subagent-start-log.sh` |
| SubagentStop | `subagent-stop-` | `subagent-stop-gate.sh` |
| UserPromptSubmit | `user-prompt-` | `user-prompt-log.sh` |
| Notification | `notification-` | `notification-log.sh` |

## File Structure

Every hook MUST follow this skeleton:

```bash
#!/bin/bash
# <hook-name>.sh — <one-line description>
# Hook: <PreToolUse|PostToolUse|...> (matcher: <tool-name|"">)
# Exit 2 = block the action

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
```

## Exit Codes

- `exit 0` — allow / pass (default behavior)
- `exit 2` — block with user-facing error message on stderr
- Other codes — fail-open (logged but does not block)
- MUST NOT use `exit 1` for gates — that signals tool failure, not a block.

## _lib.sh Utilities

- MUST use `json_val '.path.to.field'` for JSON extraction — never raw
  jq calls (breaks on systems without jq).
- MUST use `log_metric '{...}'` for JSONL metrics — handles rotation.

## Safety Patterns

- MUST wrap metrics logging in `{ ... } 2>/dev/null` — a metrics failure
  must never crash the hook or block the user.
- MUST sanitize strings before embedding in JSON — escape newlines,
  quotes, and backslashes (see `_lib.sh` patterns).
- MUST source `_lib.sh` via `"$(dirname "$0")/_lib.sh"` — never use
  relative paths like `../_lib.sh` or `source _lib.sh`.

## Hook Roles

Each hook has exactly **one** responsibility:

| Role | Suffix | Purpose | Exit code |
|------|--------|---------|-----------|
| context | `-context` | Inject `additionalContext` into the session | 0 |
| gate | `-gate`, `-block-*` | Validate and block on failure | 0 or 2 |
| log | `-log` | Write a metric line via `log_metric` | 0 |
| persist | `-persist`, `-save` | Write state to disk for future sessions | 0 |
| reinject | `-reinject` | Re-inject saved state after compaction | 0 |
| monitor | `-monitor` | Detect anomalies and log (never blocks) | 0 |

MUST NOT mix roles in a single hook. If an event needs both a gate and
a log, register two hooks — gate first so it can block before logging.

## Session Logs

Session persistence uses raw text files in `.claude/dev/session_logs/`:

- `stop-persist.sh` writes `{timestamp}.log` on session stop
- `session-start-context.sh` reads the latest `.log` on session start
- Rotation: keep last 10 files, older ones are deleted automatically
- MUST NOT use structured formats (Markdown, JSON) for session logs

## Current Hook Inventory

| Event | Hook | Role |
|-------|------|------|
| SessionStart (startup) | `session-start-context.sh` | context |
| SessionStart (startup) | `session-start-log.sh` | log |
| SessionStart (compact) | `session-start-reinject.sh` | reinject |
| SessionEnd | `session-end-log.sh` | log |
| PreCompact | `pre-compact-save.sh` | persist |
| PreToolUse (Bash) | `pre-tool-use-block-secrets.sh` | gate |
| PostToolUse | `post-tool-use-log.sh` | log |
| PostToolUse (mcp__) | `post-tool-use-mcp-monitor.sh` | monitor |
| PostToolUseFailure | `post-tool-failure-log.sh` | log |
| Stop | `stop-persist.sh` | persist |
| SubagentStart | `subagent-start-log.sh` | log |
| SubagentStop | `subagent-stop-gate.sh` | gate |
| SubagentStop | `subagent-stop-log.sh` | log |
| UserPromptSubmit | `user-prompt-log.sh` | log |
| Notification | `notification-log.sh` | log |

## Lifecycle

1. Start new hooks as **warning** (`exit 0` + logged message)
2. Promote to **hard gate** (`exit 2`) only after validating accuracy
   via metrics (confirm low false-positive rate)
