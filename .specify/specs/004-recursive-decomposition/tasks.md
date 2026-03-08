# Tasks — Recursive Decomposition

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.

## Phase 1 — Core Changes (C1 + C2 + C3 + C4, parallel)

- [x] **T-01: Update sdd-plan skill with complexity detection and sub-spec
  suggestion** — Add complexity heuristics (5+ files, 2+ arch decisions, new
  tech, unresearched) to the planning workflow. When a component triggers 2+
  heuristics, present a sub-spec suggestion to the user with component name,
  triggered heuristics, and proposed sub-spec scope. Add Mermaid dependency
  graph generation step (graph TD with subgraphs for sub-specs, distinct
  marker for spike-first). Add depth limit check (max 2 levels — if already
  at grandchild, escalate to user as top-level spec). Keep body under 500
  lines, description under 1024 chars. Preserve all 7 mandatory sections.
  - Files: `.claude/skills/sdd-plan/SKILL.md` (edit)
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Update specs.md rules with sub-spec and spike patterns** — Add
  three new sections: (1) "Sub-Specs" — directory structure
  `.specify/specs/{parent-id}-{slug}/{sub-id}-{sub-slug}/spec.md`, lifecycle
  rules (full SDD cycle independently), depth limit (max 2 levels), result
  integration (parent task marked complete when sub-spec done). (2) "Spike-First
  Pattern" — when to use (new tech, uncertain feasibility, performance-critical),
  time-box (15 min agent time), findings file format
  (`spike-{component}.md` in spec dir), worktree isolation, plan update if
  spike invalidates approach. (3) Update directory tree to show nested sub-specs
  and spike files. Keep total file under ~120 lines.
  - Files: `.claude/rules/specs.md` (edit)
  - Agent: implementer
  - Depends on: none

- [x] **T-03: Update plan template with Dependency Graph and Sub-Specs
  sections** — Add a "Dependency Graph" section with a Mermaid `graph TD`
  placeholder showing component nodes, dependency edges, and subgraph syntax
  for sub-specs. Add a "Sub-Specs" section with a status table
  (ID | Name | Status: pending/in-progress/complete). Keep existing sections
  intact. Note both sections are optional (omit if no sub-specs/simple plan).
  - Files: `.specify/templates/plan.md` (edit)
  - Agent: implementer
  - Depends on: none

- [x] **T-04: Update sdd-tasks skill with sub-spec task type** — Add a
  workflow step for handling plans with sub-specs: emit a "sub-spec" task type
  that represents the full SDD lifecycle (specify → plan → tasks → implement →
  review). Sub-spec tasks block downstream parent tasks. Document the sub-spec
  task format in the constraints section. Keep body under 500 lines, description
  under 1024 chars. Preserve all existing sections.
  - Files: `.claude/skills/sdd-tasks/SKILL.md` (edit)
  - Agent: implementer
  - Depends on: none

## Phase 2 — Review Core Changes

- [x] **T-05: Review core changes** — Verify all four files modified in Phase
  1. Check: (a) sdd-plan SKILL.md has all 7 mandatory sections, description
  < 1024 chars, body < 500 lines, complexity heuristics are concrete not vague,
  sub-spec suggestion workflow is clear, Mermaid generation step is present,
  depth limit documented. (b) specs.md is internally consistent — directory
  tree matches rules, sub-spec and spike sections are complete. (c) plan
  template has valid Mermaid placeholder syntax, Sub-Specs table is clear.
  (d) sdd-tasks SKILL.md has all 7 mandatory sections, description < 1024
  chars, body < 500 lines, sub-spec task type is documented. (e) No breaking
  changes — existing specs still valid.
  - Files: `.claude/skills/sdd-plan/SKILL.md`,
    `.claude/rules/specs.md`,
    `.specify/templates/plan.md`,
    `.claude/skills/sdd-tasks/SKILL.md`
  - Agent: reviewer
  - Depends on: T-01, T-02, T-03, T-04

## Phase 3 — Integration (C5)

- [x] **T-06: Update knowledge-map** — Update `.claude/memory/knowledge-map.md`
  to reflect: (a) specs.md now includes sub-spec and spike-first patterns,
  (b) plan template includes Dependency Graph and Sub-Specs sections,
  (c) SDD pipeline supports recursive decomposition. Update the `.specify/`
  modules line if needed. Add a Recent Decisions entry for spec 004.
  - Files: `.claude/memory/knowledge-map.md` (edit)
  - Agent: implementer
  - Depends on: T-05

## Phase 4 — E2E Validation (C6)

- [x] **T-07: E2E — skill constraints check** — Verify: (a) sdd-plan SKILL.md
  description < 1024 chars, body < 500 lines, (b) sdd-tasks SKILL.md
  description < 1024 chars, body < 500 lines, (c) all tool names in both
  frontmatters are valid, (d) specs.md total length is reasonable (< 150
  lines).
  - Files: `.claude/skills/sdd-plan/SKILL.md`,
    `.claude/skills/sdd-tasks/SKILL.md`,
    `.claude/rules/specs.md` (read-only)
  - Agent: tester
  - Depends on: T-06

- [x] **T-08: E2E — complexity heuristics walkthrough** — Walk through a
  hypothetical complex component (e.g., "implement data pipeline module" that
  touches 7 files, requires 3 architectural decisions, introduces a new
  library) and verify: (a) the heuristics in sdd-plan correctly flag it as
  complex (3/4 triggers), (b) the sub-spec suggestion format is clear,
  (c) the Mermaid graph example in the template is valid syntax, (d) the
  spike-first criteria in specs.md match spec FR-06.
  - Files: `.claude/skills/sdd-plan/SKILL.md`,
    `.specify/templates/plan.md`,
    `.claude/rules/specs.md` (read-only)
  - Agent: tester
  - Depends on: T-06

- [x] **T-09: E2E — backward compatibility check** — Verify existing specs
  (001, 002, 003) directory structure is still valid under updated specs.md
  rules. Confirm: (a) plans without sub-specs or dependency graphs are still
  valid, (b) tasks without sub-spec task type are still valid, (c) no
  mandatory fields were added that break existing artifacts.
  - Files: `.specify/specs/001-skill-architecture-improvements/`,
    `.specify/specs/002-cognitive-memory/`,
    `.specify/specs/003-self-consistency/`,
    `.claude/rules/specs.md` (read-only)
  - Agent: tester
  - Depends on: T-06

## Phase 5 — Final Review

- [x] **T-10: Final review** — Review the complete diff of all files modified.
  Verify consistency across all artifacts: sdd-plan skill, sdd-tasks skill,
  specs.md rules, plan template, knowledge-map. Check no regressions in
  existing functionality. Verify all spec requirements (FR-01 through FR-10,
  NFR-01 through NFR-05) are addressed.
  - Files: all modified files
  - Agent: reviewer
  - Depends on: T-07, T-08, T-09

## Task Dependency Graph

```
T-01 ──┐
T-02 ──┤
T-03 ──┼──→ T-05 ──→ T-06 ──┬──→ T-07
T-04 ──┘                     ├──→ T-08  ──→ T-10
                              └──→ T-09
```

## Parallelization Opportunities

- **T-01 || T-02 || T-03 || T-04**: All modify different files with no
  dependencies. Can run 4 implementer agents in parallel.
- **T-07 || T-08 || T-09**: All E2E validations are independent. Can run 3
  tester agents in parallel.

## Acceptance Criteria

- [x] All 10 tasks completed
- [x] sdd-plan skill includes complexity heuristics (4 criteria, threshold 2+)
- [x] sdd-plan skill includes sub-spec suggestion workflow with user approval
- [x] sdd-plan skill includes Mermaid dependency graph generation
- [x] sdd-plan skill includes depth limit check (max 2 levels)
- [x] specs.md documents sub-spec directory structure and lifecycle
- [x] specs.md documents spike-first pattern with time-box and findings format
- [x] Plan template includes Dependency Graph section with Mermaid placeholder
- [x] Plan template includes Sub-Specs section with status table
- [x] sdd-tasks skill includes sub-spec task type that blocks downstream tasks
- [x] Existing specs (001, 002, 003) remain valid under updated rules
- [x] Knowledge-map reflects all changes
- [x] All skill files: description < 1024 chars, body < 500 lines
- [x] Code reviewed (reviewer on Phase 2 + final review)
