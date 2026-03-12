# Tasks — Agent Hardening

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

- [x] **T-01: Add Red Lines and stop rule to implementer agent** — Add `## Red Lines` section with 5-7 implementer-specific anti-rationalization entries and uniform 3-attempt stop rule. Replace existing "5 fix-rerun cycles" with 3.
  - Files: `.claude/agents/implementer/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-02: Add Red Lines and stop rule to reviewer agent** — Add `## Red Lines` section with 5-7 reviewer-specific anti-rationalization entries (soft-passing, not reading full files, missing security concerns) and 3-attempt stop rule.
  - Files: `.claude/agents/reviewer/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-03: Add Red Lines and stop rule to tester agent** — Add `## Red Lines` section with 5-7 tester-specific anti-rationalization entries (claiming tests pass without running, ignoring flaky tests). Add explicit stop-and-report language to existing 3-cycle limit.
  - Files: `.claude/agents/tester/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-04: Add Red Lines and stop rule to researcher agent** — Add `## Red Lines` section with 5-7 researcher-specific anti-rationalization entries (single-source conclusions, guessing without searching, not checking Qdrant KB first) and 3-attempt stop rule.
  - Files: `.claude/agents/researcher/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-05: Add Red Lines and stop rule to security agent** — Add `## Red Lines` section with 5-7 security-specific anti-rationalization entries (clean audit without running scanners, downgrading severity, not checking CVE databases) and 3-attempt stop rule.
  - Files: `.claude/agents/security/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-06: Add wave computation to sdd-tasks skill** — Add wave assignment logic after dependency graph validation (step 4b). Compute `Wave: N` for each task using topological sort of the dependency DAG. Annotate each task with the wave field. Update Execution Phases table to use wave numbers.
  - Files: `.claude/skills/sdd-tasks/SKILL.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-07: Add Wave field to tasks template** — Add `Wave:` field to the task entry format. Update the Execution Phases table to reference waves instead of generic phases.
  - Files: `.specify/templates/tasks.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-08: Add per-task commit convention** — Add commit convention instruction (`feat({spec-id}-T-{task-id}): <description>`) to implementer AGENT.md and document the convention in specs.md Task Execution section.
  - Files: `.claude/agents/implementer/AGENT.md`, `.claude/rules/specs.md`
  - Agent: implementer
  - Depends on: T-01
  - Wave: 2

- [x] **T-09: Review all modified files for spec compliance** — Verify Red Lines are agent-specific (not generic), stop rule language is uniform across all 5 agents, wave logic is consistent with existing step 4b, template includes Wave field, commit convention is clear. Check NFR-04 (≤25 lines added per agent).
  - Files: `.claude/agents/implementer/AGENT.md`, `.claude/agents/reviewer/AGENT.md`, `.claude/agents/tester/AGENT.md`, `.claude/agents/researcher/AGENT.md`, `.claude/agents/security/AGENT.md`, `.claude/skills/sdd-tasks/SKILL.md`, `.specify/templates/tasks.md`, `.claude/rules/specs.md`
  - Agent: reviewer
  - Depends on: T-01, T-02, T-03, T-04, T-05, T-06, T-07, T-08
  - Wave: 3

- [x] **T-10: Update knowledge map** — Update `.claude/memory/knowledge-map.md` to reflect: agents now include Red Lines sections, sdd-tasks computes wave annotations, per-task commit convention added.
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-09
  - Wave: 4

## Execution Phases

| Wave | Tasks | Parallel? | Notes |
|------|-------|-----------|-------|
| 1 | T-01, T-02, T-03, T-04, T-05, T-06, T-07 | Yes | No shared files — all independent |
| 2 | T-08 | No | Modifies implementer AGENT.md after T-01 + specs.md |
| 3 | T-09 | No | Review pass — reads all modified files |
| 4 | T-10 | No | Knowledge map summary after review |

## Task Dependency Graph

```
T-01 ──┬──→ T-08 ──┐
T-02 ──┤            ├──→ T-09 ──→ T-10
T-03 ──┤            │
T-04 ──┤            │
T-05 ──┼────────────┘
T-06 ──┤
T-07 ──┘
```

## Acceptance Criteria

- [ ] All 5 AGENT.md files contain a `## Red Lines` section with ≥5 agent-specific entries (FR-01, FR-02)
- [ ] All 5 agents include uniform 3-attempt stop rule language (FR-03)
- [ ] Implementer's "5 fix-rerun cycles" replaced with 3 (FR-04)
- [ ] sdd-tasks SKILL.md computes `Wave: N` via topological sort (FR-05)
- [ ] tasks.md template includes `Wave:` field and wave-based execution phases (FR-06)
- [ ] Implementer AGENT.md documents commit convention `feat({spec-id}-T-{task-id}): ...` (FR-07)
- [ ] specs.md Task Execution section documents commit convention (FR-08)
- [ ] No Red Lines table exceeds 10 entries (NFR-01)
- [ ] Wave computation skips gracefully on cycle detection (NFR-02)
- [ ] No AGENT.md gains more than 25 lines (NFR-04)
- [ ] Reviewer confirms Red Lines are role-specific, not generic copy-paste
- [ ] Knowledge map reflects all changes
