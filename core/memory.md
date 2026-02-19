# Marvin Memory — Global

## User Preferences


## Architecture Decisions

- [2026-02-15] Skills are orchestration workflows (contain "Delegate to X agent" instructions) — cannot be injected into specialist agents via the `skills` frontmatter field without causing circular delegation. Future work: refactor skills to separate methodology from orchestration, or create agent-injectable snippets.
- [2026-02-15] Multi-agent evolution plan created at research/multi-agent-evolution-2026.md — 10 proposals in 3 phases based on Anthropic's official patterns and Claude Code native capabilities.

## Patterns & Conventions

- [2026-02-15] Agent model strategy: Opus for complex synthesis, Sonnet for domain experts and implementation, Haiku for deterministic tasks (verification, commits, docs).
- [2026-02-15] Agent maxTurns: 15 (git), 20 (verifier, docs), 25 (docker), 30 (most domain experts), 50 (coder).

## Lessons Learned

- [2026-02-15] Subagent researcher/coder types cannot access MCP tools (Exa, Context7) unless permissions are pre-approved — web search must be done from the main session or with explicit permission grants.

