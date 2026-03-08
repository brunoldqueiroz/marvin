# Tasks — TDD Guidance in Pipeline

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

### Phase 1 — Core Changes (C1 + C2, parallel)

- [x] **T-01: Add TDD heuristic and test-first task pattern to sdd-tasks** —
  Edit `.claude/skills/sdd-tasks/SKILL.md`:
  (a) Add step 4c "TDD assessment" after step 4b (dependency validation).
  For each implementer task, check if it matches the TDD heuristic: complex
  logic (algorithms, state machines, parsers, validators), behavioral
  contracts (public APIs, interface implementations), bug fixes (regression
  tests first), or data transformations (ETL, pipeline steps). Tasks that
  don't match (config, docs, rules, skill metadata) skip TDD.
  (b) For matching tasks, generate the 3-task `[TEST-FIRST]` pattern:
  write test (tester) → implement (implementer) → verify (tester), linked
  by dependencies.
  (c) Add a constraint: `[TEST-FIRST]` is advisory — recommendations are
  shown during the confirmation step so the user can accept or remove them.
  (d) Bump version to 1.2.0.
  Must stay under 500 lines total. Must preserve all existing sections.
  - Files: `.claude/skills/sdd-tasks/SKILL.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Add test-first dispatch note to specs.md** — Edit
  `.claude/rules/specs.md`. In the Task Execution section, after the
  "Parallel dispatch" paragraph (around line 66), add 3-4 lines noting
  that `[TEST-FIRST]` annotated tasks use a tester → implementer → tester
  sequence, handled naturally by task dependencies (no new execution logic).
  Keep total file under 170 lines.
  - Files: `.claude/rules/specs.md`
  - Agent: implementer
  - Depends on: none

### Phase 2 — Review

- [x] **T-03: Review core changes** — Verify: (a) sdd-tasks SKILL.md has
  all required sections, body under 500 lines; (b) TDD heuristic criteria
  are clearly defined with specific task types; (c) `[TEST-FIRST]` 3-task
  pattern is correctly described with dependency structure; (d) advisory
  nature is explicit (user can remove annotations); (e) specs.md test-first
  dispatch note is concise and consistent with sdd-tasks; (f) specs.md
  under 170 lines; (g) no breaking changes to existing task patterns.
  - Files: `.claude/skills/sdd-tasks/SKILL.md`, `.claude/rules/specs.md`
  - Agent: reviewer
  - Depends on: T-01, T-02

### Phase 3 — Integration

- [x] **T-04: Update knowledge-map** — Update `.claude/memory/knowledge-map.md`:
  (a) update sdd-tasks entry in Skills section to mention TDD heuristic;
  (b) update specs list to include 010; (c) add spec 010 to Recent Decisions.
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-03

### Phase 4 — Validation + Final Review

- [x] **T-05: Scenario walkthrough** — Walk through a scenario where
  sdd-tasks generates tasks for a plan with mixed task types: (a) an
  implementer task for complex parsing logic (should trigger `[TEST-FIRST]`),
  (b) an implementer task for updating a config file (should NOT trigger),
  (c) a reviewer task (should NOT trigger — TDD only applies to implementer
  tasks). Verify: correct annotation, correct dependency structure (test →
  implement → verify), and that non-matching tasks are unchanged.
  - Files: `.claude/skills/sdd-tasks/SKILL.md` (read-only)
  - Agent: tester
  - Depends on: T-04

- [x] **T-06: Final review** — Review all modified files. Verify all FR/NFR
  requirements. Check cross-file consistency.
  - Files: all modified files
  - Agent: reviewer
  - Depends on: T-05

## Execution Phases

| Phase | Tasks | Parallel? | Notes |
|-------|-------|-----------|-------|
| 1 | T-01, T-02 | Yes | Different files |
| 2 | T-03 | No | Review gate |
| 3 | T-04 | No | Integration |
| 4 | T-05, T-06 | No | Sequential (test then review) |

## Task Dependency Graph

```
T-01 ──┐
       ├──→ T-03 ──→ T-04 ──→ T-05 ──→ T-06
T-02 ──┘
```

## Acceptance Criteria

- [x] TDD heuristic defined with specific criteria (complex logic, APIs, bug fixes, data transformations)
- [x] `[TEST-FIRST]` 3-task pattern generates correct dependency structure
- [x] Advisory nature preserved (user can remove annotations at confirmation)
- [x] Non-TDD tasks unchanged (zero overhead for non-matching tasks)
- [x] specs.md test-first dispatch note is concise and consistent
- [x] sdd-tasks SKILL.md under 500 lines
- [x] specs.md under 170 lines
- [x] Backward compatible (existing task patterns work unchanged)
- [x] Knowledge-map reflects all changes
- [x] Code reviewed (T-03 + T-06)
