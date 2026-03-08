# Tasks — Multidimensional Confidence

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

### Phase 1 — Core Changes (C1 + C2, parallel)

- [x] **T-01: Update deliberation skill with dimensional confidence** — Edit
  `.claude/skills/deliberation/SKILL.md`:
  (a) In Core Principles, update principle 7 (confidence scoring) to define
  3 dimensions: feasibility (0.40 weight), cost (0.30), risk (0.30). State
  that overall confidence is a weighted aggregate.
  (b) Update DECIDE step (step 6 in Best Practices section 1) to show
  per-dimension format: `Overall: MED (0.72)` followed by indented dimension
  lines with HIGH/MED/LOW, score, and justification.
  (c) Update decision record template (Best Practices section 9) to include
  `Confidence` with indented dimension lines.
  (d) Update confidence calibration (Best Practices section 10) with
  dimension-based thresholds: HIGH overall = all dims ≥ 0.70; MED = at least
  one dim < 0.70, none < 0.40; LOW = any dim < 0.40.
  (e) Add targeted follow-up guidance after calibration: feasibility LOW →
  spike/prototype, cost LOW → research effort/maintenance, risk LOW → revisit
  pre-mortem mitigations.
  (f) Update examples (scenarios 1 and 3) to show dimensional confidence in
  their DECIDE steps. Keep changes minimal — add 2-3 lines per example.
  (g) Bump version to 1.1.0.
  Must stay under 500 lines total. Must preserve all 7 mandatory sections.
  - Files: `.claude/skills/deliberation/SKILL.md`
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Add confidence_dimensions to Qdrant metadata docs** — Edit
  `.claude/rules/memory.md`. In the General Rules section, after the
  `confidence` metadata field (line 85), add a note that deliberation records
  may include an optional `confidence_dimensions` field:
  `{feasibility: 0.0-1.0, cost: 0.0-1.0, risk: 0.0-1.0}`. Existing records
  without this field remain valid. Keep addition to 1-2 lines. Total memory.md
  must stay under 120 lines.
  - Files: `.claude/rules/memory.md`
  - Agent: implementer
  - Depends on: none

### Phase 2 — Review

- [x] **T-03: Review core changes** — Verify: (a) deliberation SKILL.md has
  all 7 mandatory sections, body under 500 lines, description under 1024 chars;
  (b) DECIDE step format includes per-dimension scores; (c) decision record
  template includes dimensions; (d) calibration thresholds are dimension-based;
  (e) targeted follow-up guidance is present; (f) examples show dimensional
  confidence; (g) memory.md addition is concise and backward compatible;
  (h) overall scalar confidence is preserved for backward compatibility.
  - Files: `.claude/skills/deliberation/SKILL.md`, `.claude/rules/memory.md`
  - Agent: reviewer
  - Depends on: T-01, T-02

### Phase 3 — Integration

- [x] **T-04: Update knowledge-map** — Update `.claude/memory/knowledge-map.md`:
  (a) update deliberation entry in Skills section to mention dimensional
  confidence; (b) update specs list to include 009; (c) add spec 009 to
  Recent Decisions.
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-03

### Phase 4 — Validation + Final Review

- [x] **T-05: Scenario walkthrough** — Walk through deliberation scenario 1
  (caching decision) with the updated rules. Verify: (a) dimensional scores
  are produced at DECIDE step; (b) overall score matches weighted aggregate;
  (c) when cost dimension is LOW, the follow-up guidance correctly suggests
  researching maintenance burden; (d) the decision record template is filled
  correctly with dimensions.
  - Files: `.claude/skills/deliberation/SKILL.md` (read-only)
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

- [x] Deliberation DECIDE step includes per-dimension confidence (feasibility, cost, risk)
- [x] Overall confidence is a weighted aggregate (0.40/0.30/0.30)
- [x] Decision record template includes dimensional scores
- [x] Calibration thresholds are dimension-based
- [x] Targeted follow-up guidance for LOW dimensions
- [x] Examples show dimensional confidence
- [x] Qdrant metadata supports optional confidence_dimensions
- [x] Backward compatible (scalar confidence preserved)
- [x] Deliberation SKILL.md under 500 lines
- [x] Knowledge-map reflects all changes
- [x] Code reviewed (T-03 + T-06)
