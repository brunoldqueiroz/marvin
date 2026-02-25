# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Brain: added delegation token constraint (PREFER under 500 tokens) to
  Handoff Protocol, reducing context waste on agent prompts
- Brain: added Verify section with quick-check commands for hooks, settings,
  and agent/skill frontmatter
- Compaction hook: removed hardcoded identity from `compact-reinject.sh`,
  deferring to CLAUDE.md as single source of truth (~30 tokens saved per
  compaction recovery)

### Added

- `/status` skill — haiku-powered read-only status report (git state, session
  history, agent metrics). First user-invocable skill.

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
