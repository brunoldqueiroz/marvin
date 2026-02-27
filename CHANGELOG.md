# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-02-27

### Added

- `hooks/_lib.sh`: `log_metric()` — shared JSONL writer with rotation (keep 500
  when >1000 lines), replaces inline rotation in subagent-quality-gate.sh
- `hooks/session-context.sh`: `session_start` metric event (session, model,
  source, permission_mode)
- `hooks/session-end.sh` — new SessionEnd hook, logs `session_end` event with
  reason; pairs with session_start for duration tracking
- `hooks/tool-failure.sh` — new PostToolUseFailure hook, logs `tool_failure`
  event with tool, error, is_interrupt
- `hooks/block-secrets.sh` — PreToolUse hook that blocks Bash commands matching
  secret exposure patterns (.env, credentials, .pem, API keys, tokens)
- `settings.json`: registered SessionEnd and PostToolUseFailure hook entries

### Changed

- `hooks/tool-usage-log.sh`: rewritten from per-session plain text to JSONL via
  `log_metric`; adds file_path (Write/Edit/Read), command preview (Bash),
  tool_use_id for correlation
- `hooks/mcp-error-monitor.sh`: switched from plain-text `tool-errors.log` to
  `log_metric` with `mcp_error` event
- `hooks/subagent-quality-gate.sh`: added `cwd` field, replaced inline
  printf+rotation with `log_metric`
- Brain: added Epistemic Discipline section (say "I don't know", read before
  claiming, question assumptions)
- Brain: added two rules — MUST question assumptions, MUST NOT invent facts
- Brain: rewritten Identity (IT assistant → AI assistant, active voice)
- Brain: expanded Identity section to describe Marvin as a general-purpose IT
  assistant (software dev, data engineering, AI engineering, data analysis,
  research, studies)
- Brain: removed redundant Standards section (duplicated Rule #4)

### Removed

- `/status` skill
- Per-session `tool-logs/<session>.log` files (replaced by unified metrics.jsonl)
- Plain-text `tool-errors.log` (replaced by `mcp_error` events in metrics.jsonl)

## [0.2.0] - 2026-02-26

### Added

- MCP error monitor hook (`mcp-error-monitor.sh`) — PostToolUse hook that
  detects HTTP 4xx/5xx, connection errors, and auth failures on MCP tools;
  logs to `.claude/dev/tool-errors.log` and surfaces via exit 2 (hard gate)
- Brain: reasoning cycle, synthesis, and failure recovery
- `/status` skill — haiku-powered read-only status report (git state, session
  history, agent metrics). First user-invocable skill.
- Development standard (`docs/development-standard.md`) and specs v0.2.0,
  v0.3.0
- Tool usage log hook (`tool-usage-log.sh`) — PostToolUse hook for tracking
  tool invocations

### Changed

- Brain: added delegation token constraint (PREFER under 500 tokens) to
  Handoff Protocol, reducing context waste on agent prompts
- Brain: added Verify section with quick-check commands for hooks, settings,
  and agent/skill frontmatter
- Brain: added MUST/MUST NOT rules at top per development standard §3.1
- Compaction hook: removed hardcoded identity from `compact-reinject.sh`,
  deferring to CLAUDE.md as single source of truth (~30 tokens saved per
  compaction recovery)
- Researcher agent v2: compact tool routing table, decompose step, confidence
  output, KB write discipline, maxTurns 30→20
- Hooks: standardized all hooks to use `_lib.sh` for JSON parsing

### Fixed

- Context7 tool names: `mcp__upstash-context7-mcp__*` →
  `mcp__context7__*` in settings.json allow list and researcher AGENT.md

## [0.1.0] - 2026-02-22

### Added

- Brain (`.claude/CLAUDE.md`) — Think → Route → Delegate → Evaluate → Recover
  cycle with topology-based routing, structured handoff protocol (objective,
  key files, constraints, output format), pre-delegation reasoning checklist,
  post-delegation synthesis, and failure recovery ladder
- Researcher agent — research specialist with proactive routing, Context7,
  Exa, and Qdrant KB access
- Session lifecycle hooks: startup context injection (model, source, git state,
  previous session), session persistence, compaction resilience (pre-compact
  save + post-compact recovery)
- Agent quality gate hook with metrics logging to `.claude/dev/metrics.jsonl`
  (agent_id, transcript path, permission mode, output length, artifact detection)
- Session log (`.claude/dev/session-log.md`) with model, permission mode,
  user prompts, tools used, files modified, git commits, and agent usage
- MCP server configuration for Context7, Exa, and Qdrant
- Permission and hook configuration in `.claude/settings.json`
