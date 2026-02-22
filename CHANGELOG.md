# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-22

### Added

- Brain (`.claude/CLAUDE.md`) — topology-based routing and structured handoff
  protocol with 4 essential components (objective, key files, constraints,
  output format)
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
