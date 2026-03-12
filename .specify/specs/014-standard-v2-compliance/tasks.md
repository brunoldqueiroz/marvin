# Tasks — Standard v2.0 Compliance

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

### Phase 1 — Quick Wins

- [x] **T-01: Remove Edit from read-only agents** — Remove `Edit` from
  `tools:` field in reviewer, researcher, and security AGENT.md. Add comment
  `# Write retained for .artifacts/ output only` on the tools line of each.
  - Files: `.claude/agents/reviewer/AGENT.md`, `.claude/agents/researcher/AGENT.md`, `.claude/agents/security/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-02: Fix MCP monitor exit code and add async to PostToolUse hooks** —
  Change `exit 2` → `exit 0` in `post-tool-use-mcp-monitor.sh` (PostToolUse
  cannot block). Update the comment header to remove "hard gate" language.
  Add `"async": true` to both PostToolUse hook entries in `settings.json`.
  - Files: `.claude/hooks/post-tool-use-mcp-monitor.sh`, `.claude/settings.json`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-03: Update skill categories to v2.0 enum** — Change
  `self-consistency` to `category: orchestration`, `memory-manager` to
  `category: knowledge`, `reflect` to `category: workflow` in their
  respective SKILL.md metadata sections.
  - Files: `.claude/skills/self-consistency/SKILL.md`, `.claude/skills/memory-manager/SKILL.md`, `.claude/skills/reflect/SKILL.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

### Phase 2 — CLAUDE.md Refactor

- [x] **T-04: Trim CLAUDE.md to ≤100 lines with attention engineering** —
  Remove duplicated Handoff Protocol body (~15 lines), Cognitive Memory
  bullets (~10 lines), Skill Loading table (~8 lines), and Verify shell
  commands (~3 lines). Replace each with single-line `@path` pointers. Add
  `<!-- budget: <100 lines; last pruned: 2026-03-12 -->` after the heading.
  Add `## Critical Reminders` at bottom echoing top 3-5 MUST/MUST NOT rules.
  Final line count MUST be ≤ 100.
  - Files: `.claude/CLAUDE.md`
  - Agent: implementer
  - Depends on: T-01
  - Wave: 2

### Phase 3 — Rules & Skills Alignment

- [x] **T-05: Add claude-progress.txt and 4-category enum to rules** —
  In `specs.md` "Re-evaluation loop" section, add instruction: after marking
  tasks `[x]`, append `{task-id}: {one-line status}` to
  `{spec-dir}/claude-progress.txt`. In `skills.md`, update
  `metadata.category` line from `advisory or workflow` to all 4 values
  (`advisory`, `workflow`, `knowledge`, `orchestration`) with one-line safety
  semantics for each.
  - Files: `.claude/rules/specs.md`, `.claude/rules/skills.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-06: Add tools field to SDD skill frontmatter** — Read each SDD
  skill body to determine which tools it actually uses, then add the
  `tools:` frontmatter field. Read the skill bodies first to determine the
  correct tool list for each.
  - Files: `.claude/skills/sdd-constitution/SKILL.md`, `.claude/skills/sdd-specify/SKILL.md`, `.claude/skills/sdd-plan/SKILL.md`, `.claude/skills/sdd-tasks/SKILL.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

### Phase 4 — Hook Refinements & Agent Polish

- [x] **T-07: Fix MCP monitor server name extraction** — Change
  `cut -d'_' -f3` to `awk -F'__' '{print $2}'` on line 28 of
  `post-tool-use-mcp-monitor.sh`. The MCP tool naming convention uses double
  underscore (`mcp__server__tool`), not single.
  - Files: `.claude/hooks/post-tool-use-mcp-monitor.sh`
  - Agent: implementer
  - Depends on: T-02
  - Wave: 2

- [x] **T-08: Consolidate failure patterns into _lib.sh** — Add a shared
  `AGENT_FAILURE_PATTERNS` variable to `_lib.sh` containing the 6-pattern
  superset: `I could not`, `I cannot`, `I'm unable`, `failed to`,
  `error occurred`, `no results found`. Update both `subagent-stop-gate.sh`
  and `subagent-stop-log.sh` to source and use this shared variable in
  their grep commands.
  - Files: `.claude/hooks/_lib.sh`, `.claude/hooks/subagent-stop-gate.sh`, `.claude/hooks/subagent-stop-log.sh`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-09: Agent description trims, model diversity, and deviation docs** —
  Trim all 5 agent descriptions to ~140 chars preserving "Does NOT:" clause.
  Change tester `model: sonnet` → `model: haiku` with comment explaining
  reasoning. Add inline comments for `implementer.maxTurns: 25` and
  `researcher.memory: project`.
  - Files: `.claude/agents/implementer/AGENT.md`, `.claude/agents/reviewer/AGENT.md`, `.claude/agents/researcher/AGENT.md`, `.claude/agents/security/AGENT.md`, `.claude/agents/tester/AGENT.md`
  - Agent: implementer
  - Depends on: T-01
  - Wave: 2

### Verification

- [x] **T-10: Review all changes** — Stage-1 Markdown review of all modified
  files. Verify: no Edit in read-only agents, correct categories, CLAUDE.md
  ≤100 lines with bottom section, settings.json valid JSON, hook scripts
  pass `bash -n`, descriptions ≤140 chars, tester model is haiku.
  - Files: all files modified by T-01 through T-09
  - Agent: reviewer
  - Depends on: T-04, T-05, T-06, T-07, T-08, T-09
  - Wave: 3

- [x] **T-11: Run verification suite** — Execute the plan's testing strategy:
  `bash -n .claude/hooks/*.sh`, JSON validation on settings.json,
  `wc -l .claude/CLAUDE.md` ≤ 100, grep checks for Edit removal, async
  flags, exit codes, categories, model change, progress instruction.
  - Files: all files modified by T-01 through T-09
  - Agent: tester
  - Depends on: T-10
  - Wave: 4

## Execution Phases

| Wave | Tasks | Parallel? | Notes |
|------|-------|-----------|-------|
| 1 | T-01, T-02, T-03, T-05, T-06, T-08 | Yes | No shared files between tasks |
| 2 | T-04, T-07, T-09 | Yes | T-04 and T-09 share no files; T-07 shares file with T-02 (done) |
| 3 | T-10 | No | Review all changes |
| 4 | T-11 | No | Automated verification |

## Task Dependency Graph

```
T-01 ──────┬──→ T-04 (CLAUDE.md) ──────────┐
           └──→ T-09 (agent polish) ────────┤
T-02 ──────────→ T-07 (MCP extraction) ─────┤
T-03 ───────────────────────────────────────→├──→ T-10 (review) ──→ T-11 (verify)
T-05 ───────────────────────────────────────→│
T-06 ───────────────────────────────────────→│
T-08 ───────────────────────────────────────→┘
```

## Acceptance Criteria

- [ ] `grep -c ', Edit' .claude/agents/{reviewer,researcher,security}/AGENT.md` returns 0 for all three
- [ ] `grep -c 'exit 2' .claude/hooks/post-tool-use-mcp-monitor.sh` returns 0
- [ ] `grep -c '"async": true' .claude/settings.json` returns ≥ 2
- [ ] `grep 'category:' .claude/skills/{self-consistency,memory-manager,reflect}/SKILL.md` shows orchestration, knowledge, workflow respectively
- [ ] `wc -l .claude/CLAUDE.md` returns ≤ 100
- [ ] `grep '<!-- budget' .claude/CLAUDE.md` returns 1 match
- [ ] `grep 'Critical Reminders' .claude/CLAUDE.md` returns 1 match
- [ ] `grep 'claude-progress.txt' .claude/rules/specs.md` returns ≥ 1
- [ ] `grep -E 'knowledge|orchestration' .claude/rules/skills.md` returns matches for both
- [ ] All 4 SDD skills have `tools:` in frontmatter
- [ ] `grep 'model: haiku' .claude/agents/tester/AGENT.md` returns 1
- [ ] All 5 agent descriptions are ≤ 140 chars
- [ ] `bash -n .claude/hooks/*.sh` passes with no errors
- [ ] `python3 -c "import json; json.load(open('.claude/settings.json'))"` exits 0
- [ ] `grep 'AGENT_FAILURE_PATTERNS' .claude/hooks/_lib.sh` returns 1
