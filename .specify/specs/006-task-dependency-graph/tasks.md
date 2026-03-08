# Tasks — Task Dependency Graph

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.

## Tasks

### Phase 1 — Core Changes (C1 + C2 + C3, parallel)

- [x] **T-01: Add dependency-aware Task Execution section to specs.md** —
  Extend the "Implementation Rule" section in `.claude/rules/specs.md` with a
  "Task Execution" subsection that defines: (1) DAG parsing algorithm — read
  all tasks, extract `Depends on:` fields, build dependency map; (2) phase
  derivation — Phase 1 = tasks with `Depends on: none`, Phase N = tasks whose
  deps are all in prior phases; (3) parallel dispatch — launch ready tasks in
  parallel via Agent calls (max 4 per batch, no same-file conflicts); (4)
  re-evaluation loop — after each batch completes, mark tasks `[x]` in
  tasks.md, derive next batch of ready tasks; (5) blocked task handling — if
  a dependency failed or was skipped, report the blockage and ask user to
  skip (`[-]`), retry, or abort; (6) deadlock detection — if no tasks are
  ready but uncompleted tasks remain, report deadlock; (7) graceful fallback —
  if parsing fails, fall back to sequential top-to-bottom execution with
  warning. Keep the new section under 50 lines. Preserve all existing sections.
  - Files: `.claude/rules/specs.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Add dependency validation step to sdd-tasks skill** — Insert a
  new step 4b ("Validate dependency graph") in the sdd-tasks SKILL.md workflow
  between "Generate tasks" (step 4) and "Add acceptance criteria" (step 5).
  The validation step checks: (a) cycle detection — for each task, walk the
  dependency chain; if any task ID is visited twice, report a cycle error with
  the chain; (b) missing reference — if `Depends on: T-XX` references a task
  ID that doesn't exist, report error; (c) self-reference — if a task depends
  on itself, report error; (d) isolated task — if a task has no dependencies
  AND nothing depends on it, emit an info-level note (not blocking). Add a
  constraint: "MUST validate the dependency graph before writing — errors
  block writing, info-level notes are reported but don't block." Keep body
  under 500 lines, description under 1024 chars.
  - Files: `.claude/skills/sdd-tasks/SKILL.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-03: Enhance tasks template with execution phases section** — Update
  `.specify/templates/tasks.md` to add: (1) task ID format comment — each task
  uses `T-XX` prefix (e.g., T-01, T-02); (2) an "Execution Phases" section
  after the Tasks section showing derived phases as a table (Phase | Tasks |
  Parallel?); (3) document the three task markers: `[ ]` = pending, `[x]` =
  completed, `[-]` = skipped; (4) keep the `Depends on:` field in each task
  (already exists) and add a note that omitting it implies `Depends on: none`.
  - Files: `.specify/templates/tasks.md`
  - Agent: implementer
  - Depends on: none

### Phase 2 — Review Core Changes

- [x] **T-04: Review core changes** — Verify all three files modified in
  Phase 1. Check: (a) specs.md Task Execution section is internally consistent
  with the existing Implementation Rule — no contradictions; (b) the DAG
  parsing algorithm is explicit enough for an agent to follow step-by-step;
  (c) sdd-tasks validation step fits naturally in the workflow and doesn't
  break existing constraints; (d) tasks template execution phases section is
  consistent with specs.md phase derivation algorithm; (e) no breaking changes
  to existing specs 001–005 (backward compatibility); (f) specs.md total
  length is reasonable (< 160 lines).
  - Files: `.claude/rules/specs.md`, `.claude/skills/sdd-tasks/SKILL.md`,
    `.specify/templates/tasks.md`
  - Agent: reviewer
  - Depends on: T-01, T-02, T-03

### Phase 3 — Integration

- [x] **T-05: Update knowledge-map** — Update `.claude/memory/knowledge-map.md`
  to reflect: (a) specs.md now includes dependency-aware task execution rules
  (update the specs.md entry in Rules section); (b) sdd-tasks validates
  dependency graphs (update the sdd-tasks entry in Skills section); (c) tasks
  template includes execution phases section (update templates line in Modules
  section); (d) add spec 006 to Recent Decisions. Verify scaling.md skill
  count is unchanged (no new skill added).
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-04

### Phase 4 — Validation

- [x] **T-06: Walkthrough validation with spec 004 tasks** — Read spec 004's
  `tasks.md` and walk through the new execution rules from specs.md. Verify:
  (a) the DAG parsing algorithm correctly identifies T-01 through T-04 as
  Phase 1 (all `Depends on: none`); (b) T-05 is correctly placed in Phase 2
  (depends on T-01–T-04); (c) T-06 in Phase 3 (depends on T-05); (d) T-07,
  T-08, T-09 are Phase 4 (parallel, depend on T-06); (e) T-10 is Phase 5
  (depends on T-07–T-09). Verify parallel dispatch constraints: T-01–T-04
  touch different files so parallelization is valid; T-07–T-09 are read-only
  tester tasks so parallelization is valid.
  - Files: `.specify/specs/004-recursive-decomposition/tasks.md`,
    `.claude/rules/specs.md` (read-only)
  - Agent: tester
  - Depends on: T-05

- [x] **T-07: Backward compatibility check** — Verify existing tasks.md files
  for specs 001–003 work with the new execution rules. Specifically: (a) tasks
  without `Depends on:` field are treated as `Depends on: none`; (b) tasks.md
  files without an "Execution Phases" section can still be executed (sequential
  fallback); (c) the `[-]` marker doesn't break any existing patterns.
  - Files: `.specify/specs/001-skill-architecture-improvements/tasks.md`,
    `.specify/specs/002-cognitive-memory/tasks.md`,
    `.specify/specs/003-self-consistency/tasks.md`,
    `.claude/rules/specs.md` (read-only)
  - Agent: tester
  - Depends on: T-05

### Phase 5 — Final Review

- [x] **T-08: Final review** — Review the complete diff of all files modified.
  Verify cross-file consistency: specs.md rules, sdd-tasks validation,
  template format, and knowledge-map all align. Check all spec requirements
  (FR-01 through FR-06, NFR-01 through NFR-04) are addressed. Verify no
  regressions.
  - Files: all modified files
  - Agent: reviewer
  - Depends on: T-06, T-07

## Execution Phases

| Phase | Tasks | Parallel? | Notes |
|-------|-------|-----------|-------|
| 1 | T-01, T-02, T-03 | Yes | Different files, no conflicts |
| 2 | T-04 | No | Review gate — needs all Phase 1 outputs |
| 3 | T-05 | No | Integration — needs review approval |
| 4 | T-06, T-07 | Yes | Independent validation targets |
| 5 | T-08 | No | Final review gate |

## Task Dependency Graph

```
T-01 ──┐
T-02 ──┼──→ T-04 ──→ T-05 ──┬──→ T-06 ──┐
T-03 ──┘                     └──→ T-07 ──┼──→ T-08
```

## Acceptance Criteria

- [x] specs.md contains a "Task Execution" section with DAG-aware algorithm
- [x] Task execution supports parallel dispatch (max 4 agents per batch)
- [x] Blocked task handling includes user decision point (skip/retry/abort)
- [x] sdd-tasks validates dependency graphs (cycles, missing refs, self-refs)
- [x] Tasks template includes "Execution Phases" section
- [x] `[-]` skipped marker is documented
- [x] Backward compatible with existing specs 001–005
- [x] Knowledge-map reflects all changes
- [x] Code reviewed (reviewer on Phase 2 + final review)
