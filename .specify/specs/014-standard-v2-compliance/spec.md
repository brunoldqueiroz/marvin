# Spec — Standard v2.0 Compliance

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

The development standard was updated from v1.2 to v2.0 (March 2026), adding
new guidelines for hooks (12 lifecycle events, async, HTTP type), context
engineering (§3.9), agent tool tiers, skill categories, and anti-patterns. A
full project review against v2.0 revealed **5 HIGH, 8 MEDIUM, and 6 LOW**
findings across CLAUDE.md, agents, skills, hooks, and rules. The project's
configuration artifacts are out of sync with its own standard.

**Who is affected:** Every Claude Code session — CLAUDE.md is injected into
every conversation; agent/skill/hook configurations govern all delegated work.

## Desired Outcome

All `.claude/` configuration artifacts pass a review against development
standard v2.0 with zero FAIL and zero VIOLATION findings. Specifically:

- CLAUDE.md ≤ 100 lines with U-shaped attention and HTML comments
- No `Edit` tool in read-only/research-tier agents
- All skills have correct `category` values (4-value enum)
- PostToolUse observability hooks are `async: true`
- `claude-progress.txt` instruction added to specs.md
- Agent model diversity introduced (not all sonnet)
- Hook bugs fixed (exit code, server name extraction, failure patterns)

## Requirements

### Functional

1. **FR-01**: Remove `Edit` from `tools:` in reviewer, researcher, and
   security AGENT.md files.
2. **FR-02**: Fix `exit 2` → `exit 0` in `post-tool-use-mcp-monitor.sh`.
3. **FR-03**: Add `"async": true` to both PostToolUse hook entries in
   `settings.json`.
4. **FR-04**: Update `category` in 3 skills: `self-consistency` →
   `orchestration`, `memory-manager` → `knowledge`, `reflect` → `workflow`.
5. **FR-05**: Trim CLAUDE.md to ≤ 100 lines by removing duplicated content
   from Handoff Protocol (~15 lines), Cognitive Memory (~10 lines), Skill
   Loading table (~8 lines), and Verify shell commands (~3 lines). Replace
   with single-line `@path` pointers.
6. **FR-06**: Add `<!-- budget: <100 lines; last pruned: 2026-03-12 -->` HTML
   comment below the `# MARVIN` heading.
7. **FR-07**: Add a `## Critical Reminders` section at the bottom of CLAUDE.md
   echoing the top 3-5 MUST/MUST NOT rules (U-shaped attention).
8. **FR-08**: Add `claude-progress.txt` instruction to `specs.md` in the
   "Re-evaluation loop" section: after marking tasks `[x]`, append task ID +
   one-line status to `{spec-dir}/claude-progress.txt`.
9. **FR-09**: Update `.claude/rules/skills.md` to list all 4 valid category
   values (`advisory`, `workflow`, `knowledge`, `orchestration`) with safety
   semantics for each.
10. **FR-10**: Add `tools:` frontmatter field to 4 SDD skills
    (`sdd-constitution`, `sdd-specify`, `sdd-plan`, `sdd-tasks`) listing the
    tools they actually use.
11. **FR-11**: Change `model: sonnet` → `model: haiku` in
    `agents/tester/AGENT.md`. Add inline comment documenting the reasoning
    (classification tasks, pass/fail judgment, diversity from implementer).
12. **FR-12**: Fix server name extraction in `post-tool-use-mcp-monitor.sh`:
    change `cut -d'_' -f3` to `awk -F'__' '{print $2}'`.
13. **FR-13**: Consolidate `AGENT_FAILURE_PATTERNS` from
    `subagent-stop-gate.sh` (4 patterns) and `subagent-stop-log.sh`
    (6 patterns) into `_lib.sh` as a shared variable. Both scripts source
    the same superset.
14. **FR-14**: Trim all 5 agent descriptions to ~140 chars max, preserving
    the "Does NOT:" clause.
15. **FR-15**: Add inline comments documenting intentional deviations:
    `implementer.maxTurns: 25` (multi-cycle fix-rerun) and
    `researcher.memory: project` (project-scoped findings).

### Non-Functional

1. **NFR-01**: All changes are Markdown, JSON, or shell — no Python code
   modified. Review phase uses Stage-1 only (no deep code review).
2. **NFR-02**: Zero behavioral regression — agent capabilities remain
   identical except tester model change (haiku) and Edit removal from 3
   agents.
3. **NFR-03**: All hook scripts pass `bash -n` syntax check after changes.
4. **NFR-04**: `settings.json` remains valid JSON after changes.

## Scope

### In Scope

- `.claude/CLAUDE.md` — trim, restructure, add HTML comment + bottom section
- `.claude/agents/*/AGENT.md` — tool tier fixes, description trims, model
  change, inline comments
- `.claude/skills/*/SKILL.md` — category corrections, tools field additions
  (4 SDD skills)
- `.claude/settings.json` — async flag on PostToolUse hooks
- `.claude/hooks/post-tool-use-mcp-monitor.sh` — exit code + extraction fix
- `.claude/hooks/subagent-stop-gate.sh` and `subagent-stop-log.sh` — pattern
  consolidation into `_lib.sh`
- `.claude/rules/skills.md` — 4-category update
- `.claude/rules/specs.md` — claude-progress.txt instruction

### Out of Scope

- Changing `docs/development-standard.md` — already at v2.0
- Adding hooks for `PermissionRequest` or `Setup` events (LOW priority, no
  clear use case yet)
- Verifying `PostToolUseFailure` event name validity (requires external doc
  lookup, tracked separately)
- Rubric changes (§3.5 two-tier evaluation) — separate spec if needed
- MCP monitor hook refactor beyond the extraction fix
- Compaction threshold configuration (Claude Code default is acceptable)

## Constraints

- MUST NOT change agent behavior beyond the explicit model change (FR-11)
  and Edit removal (FR-01).
- MUST preserve all existing hook functionality — fixes are targeted, not
  rewrites.
- MUST NOT introduce new files — all changes are edits to existing files
  (except `claude-progress.txt` which is a runtime artifact, not a config
  file).
- PREFER mechanical, verifiable changes over subjective rewrites.

## Open Questions

None — all findings are concrete and actionable from the completed review.

## References

- `docs/development-standard.md` — v2.0 (the standard being enforced)
- Review findings from this session (5 parallel reviewer agents, March 2026)
- arXiv:2602.03794 — diversity scaling; justification for FR-11 model change
- arXiv:2601.16649 — LUMINA error compounding; justification for FR-08
