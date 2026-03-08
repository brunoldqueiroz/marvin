# Tasks — Intra-Session Adaptation

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

- [x] **T-01: Add Session Confidence section to memory.md** — Add a new
  section to `.claude/rules/memory.md` after the existing "Adaptive
  Calibration" section (line 77). The section defines: (1) Three confidence
  levels — NEUTRAL (default, no corrections), CAUTIOUS (1 correction in
  domain: query Qdrant patterns, note caution), DELIBERATE (2+ corrections:
  load deliberation/self-consistency, tell user). (2) Degradation triggers —
  user corrects output (domain inferred from task context), reviewer requests
  changes, task requires backtracking. Each trigger degrades by one level.
  (3) Domain scoping — track per domain using Qdrant domain tags (python,
  architecture, testing, terraform, data-engineering, general). Corrections
  without a clear domain map to `general`. (4) Cross-session integration —
  if Adaptive Calibration flags domain as high-error (3+ Qdrant patterns),
  session starts at CAUTIOUS instead of NEUTRAL. (5) Zero overhead — when no
  corrections occur, tracker is invisible. (6) Example: "User corrects a
  Python typing error → python domain degrades to CAUTIOUS. User corrects
  another Python output → python domain degrades to DELIBERATE. Next Python
  task: load deliberation skill before acting." Keep addition under 25 lines.
  Total memory.md must stay under 120 lines.
  - Files: `.claude/rules/memory.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Review session confidence implementation** — Verify: (a) the
  section integrates naturally after Adaptive Calibration without contradictions;
  (b) three levels are clearly defined with concrete triggers; (c) domain
  scoping uses existing Qdrant domain tags; (d) cross-session integration is
  explicit (high-error domains start at CAUTIOUS); (e) zero-overhead happy
  path (FR-07); (f) memory.md total under 120 lines; (g) no breaking changes
  to existing calibration rules.
  - Files: `.claude/rules/memory.md`
  - Agent: reviewer
  - Depends on: T-01

- [x] **T-03: Update knowledge-map** — Update `.claude/memory/knowledge-map.md`:
  (a) update memory.md entry in Rules section to mention session confidence
  tracking; (b) update specs list to include 008; (c) add spec 008 to Recent
  Decisions.
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-02

- [x] **T-04: Scenario walkthrough** — Walk through a scenario: session starts,
  user asks for a Python refactor, Marvin produces output, user corrects a
  typing error (→ python CAUTIOUS), user asks for another Python task, Marvin
  queries Qdrant patterns and notes caution, user corrects output again
  (→ python DELIBERATE), next Python task triggers deliberation skill loading.
  Verify all transitions are covered by the rules. Also verify that a
  concurrent Terraform task remains at NEUTRAL throughout.
  - Files: `.claude/rules/memory.md` (read-only)
  - Agent: tester
  - Depends on: T-03

- [x] **T-05: Final review** — Review all modified files. Verify FR-01 through
  FR-07 and NFR-01 through NFR-04 are addressed. Check cross-file consistency.
  - Files: `.claude/rules/memory.md`, `.claude/memory/knowledge-map.md`
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

- [x] memory.md contains Session Confidence section with 3 levels
- [x] Degradation triggers are concrete (user correction, reviewer rejection, backtracking)
- [x] Domain-scoped tracking using Qdrant domain tags
- [x] Cross-session integration (high-error domains start at CAUTIOUS)
- [x] Zero overhead when no corrections occur
- [x] memory.md total under 120 lines
- [x] Knowledge-map reflects all changes
- [x] Code reviewed (T-02 + T-05)
