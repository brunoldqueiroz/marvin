---
name: status
description: >
  Show Marvin project status. Use when: the user asks for status, health check,
  session history, or "what did we do last session".
user-invocable: true
allowed-tools: Read, Bash(git *)
model: haiku
---

## Status Report

Read and summarize:
1. `git status` + `git log --oneline -10`
2. `.claude/dev/session-log.md` — last 3 sessions
3. `.claude/dev/metrics.jsonl` — agent usage stats (last 20 entries)

Present as a concise status report.
