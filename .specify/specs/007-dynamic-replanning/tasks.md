# Tasks — Dynamic Replanning

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

- [x] **T-01: Add plan checkpoint to Task Execution in specs.md** — Extend
  the re-evaluation loop in the Task Execution subsection of
  `.claude/rules/specs.md`. Insert a "Plan checkpoint" paragraph between the
  existing "Re-evaluation loop" and "Blocked task handling" paragraphs. The
  checkpoint defines: (1) Three signal checks — failure signal (any task in
  batch marked `[-]` or returned SIGNAL:BLOCKED), contradiction signal
  (reviewer requested structural changes, implementer modified unlisted files,
  implementer used alternative approach), coherence signal (next-batch tasks
  reference renamed/deleted files or assume changed approach). (2) Silent-pass
  rule — if all signals pass, continue without output. (3) Deviation report
  format — structured block with batch ID, signal type, evidence, affected
  tasks, and three options (continue/adjust/abort) presented via
  AskUserQuestion. (4) Plan adjustment flow — if user chooses adjust, propose
  specific edits to plan.md and tasks.md, apply only after user approval, then
  restart phase derivation from the updated tasks.md. Keep the addition under
  20 lines. Total specs.md must stay under 170 lines.
  - Files: `.claude/rules/specs.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Review checkpoint implementation** — Verify: (a) the checkpoint
  integrates naturally into the re-evaluation loop without contradicting
  spec 006's execution rules; (b) the three signals have concrete, actionable
  indicators (not vague); (c) the silent-pass rule ensures zero overhead on
  happy path; (d) the deviation report format includes all elements from
  FR-05; (e) the plan adjustment flow is suggest-only (FR-06); (f) specs.md
  total length is under 170 lines; (g) no breaking changes to existing
  execution flow.
  - Files: `.claude/rules/specs.md`
  - Agent: reviewer
  - Depends on: T-01

- [x] **T-03: Update knowledge-map** — Update `.claude/memory/knowledge-map.md`
  to reflect: (a) specs.md now includes plan checkpoints with deviation
  detection in the Task Execution section; (b) add spec 007 to Recent
  Decisions.
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-02

- [x] **T-04: Scenario walkthrough validation** — Walk through a hypothetical
  mid-execution deviation scenario: Phase 1 completes (T-01 through T-03),
  but T-02's reviewer requested a structural change that affects T-04's
  assumptions. Verify: (a) the contradiction signal fires correctly; (b) the
  deviation report format is complete; (c) the plan adjustment flow would
  produce coherent updated tasks; (d) after adjustment, phase derivation
  restarts correctly.
  - Files: `.claude/rules/specs.md` (read-only)
  - Agent: tester
  - Depends on: T-03

- [x] **T-05: Final review** — Review all modified files for cross-file
  consistency. Verify all spec requirements (FR-01 through FR-07, NFR-01
  through NFR-04) are addressed.
  - Files: `.claude/rules/specs.md`, `.claude/memory/knowledge-map.md`
  - Agent: reviewer
  - Depends on: T-04

## Execution Phases

| Phase | Tasks | Parallel? | Notes |
|-------|-------|-----------|-------|
| 1 | T-01 | No | Single implementer task |
| 2 | T-02 | No | Review gate |
| 3 | T-03 | No | Integration |
| 4 | T-04 | No | Validation |
| 5 | T-05 | No | Final review |

## Task Dependency Graph

```
T-01 ──→ T-02 ──→ T-03 ──→ T-04 ──→ T-05
```

## Acceptance Criteria

- [x] specs.md Task Execution includes plan checkpoint with 3 signal checks
- [x] Silent-pass rule ensures zero overhead on happy path
- [x] Deviation report format matches FR-05
- [x] Plan adjustment is suggest-only (user approves before edits)
- [x] specs.md total length under 170 lines
- [x] Knowledge-map reflects all changes
- [x] Code reviewed (T-02 + T-05)
