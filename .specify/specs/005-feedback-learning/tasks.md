# Tasks — Feedback Learning System

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.

## Phase 1 — Core Changes (C1 + C2 + C3 + C4, parallel)

- [x] **T-01: Create `/reflect` skill** — Create new advisory skill at
  `.claude/skills/reflect/SKILL.md`. User-invocable. Must have all 7 mandatory
  sections (Tool Selection, Core Principles, Best Practices, Anti-Patterns,
  Examples, Troubleshooting, Review Checklist). Tools: `mcp__qdrant__qdrant-find`,
  `mcp__qdrant__qdrant-store`, `Read`, `Glob`, `AskUserQuestion`. Description
  must include "Do NOT use for" cross-refs to memory-manager (store/retrieve)
  and deliberation (structured decisions). Implements FR-01 (audit workflow with
  8 steps: query → group → stale → weak → duplicates → consolidate → report →
  prune with approval), FR-05 (reflection triggers: explicit, post-spec 5+ tasks,
  high density 10+ records), FR-06 (report format with 7 sections). Keep queries
  under 10 per session (NFR-01). Graceful degradation if Qdrant unavailable
  (NFR-02). Body < 500 lines, description < 1024 chars.
  - Files: `.claude/skills/reflect/SKILL.md` (create)
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Update memory-manager with rework fields and reflect integration**
  — Edit memory-manager SKILL.md to add: (a) rework metadata fields in error
  pattern template (`task_type`: implementation | architecture | testing |
  review | planning; `correction_count`: integer starting at 1; `last_corrected`:
  ISO timestamp) — FR-02. (b) New best practice for error density queries
  ("query error patterns for domain X with confidence > 0.65") — FR-03.
  (c) Reflect integration guidance: when to suggest `/reflect` (post-spec,
  high density, explicit), how reflection feeds back into confidence, how to
  update `correction_count` and `last_corrected` on re-occurrence — FR-07.
  (d) Update "Do NOT use for" with symmetric cross-reference to reflect skill
  (periodic audit/consolidation). (e) Note backward compatibility: existing
  records without new fields remain valid (NFR-03). Body < 500 lines.
  - Files: `.claude/skills/memory-manager/SKILL.md` (edit)
  - Agent: implementer
  - Depends on: none

- [x] **T-03: Update memory rules with adaptive calibration** — Edit
  `.claude/rules/memory.md` to add: (a) New "Adaptive Calibration" section
  between Self-Consistency Triggers and General Rules — FR-04. Concrete
  thresholds: 3+ high-confidence (>0.65) error patterns in a domain → bias
  toward deliberation/self-consistency; 0-1 patterns → allow fast execution.
  (b) New "Reflection Triggers" section — FR-05. Three advisory triggers:
  explicit user command, after completing spec with 5+ tasks, when 10+ records
  stored in one session. (c) Keep rules concise — bullet lists, not paragraphs.
  - Files: `.claude/rules/memory.md` (edit)
  - Agent: implementer
  - Depends on: none

- [x] **T-04: Update CLAUDE.md with reflect skill mapping** — Edit
  `.claude/CLAUDE.md` to add: (a) `reflect/audit → reflect` in Skill Loading
  keyword mapping list. (b) New bullet in Cognitive Memory section:
  "**Periodically**: run `/reflect` to consolidate patterns and prune stale
  records". (c) Verify total stays under 200 lines.
  - Files: `.claude/CLAUDE.md` (edit)
  - Agent: implementer
  - Depends on: none

## Phase 2 — Review Core Changes

- [x] **T-05: Review core changes** — Review all four files from Phase 1.
  Check: (a) reflect SKILL.md has all 7 mandatory sections, description < 1024
  chars, body < 500 lines, triggers are specific not generic, "Do NOT use for"
  names memory-manager and deliberation. (b) memory-manager has rework fields
  in error pattern template, error density query best practice, reflect
  integration guidance, symmetric "Do NOT use for" naming reflect. (c) memory.md
  has Adaptive Calibration with concrete thresholds (3+ patterns), Reflection
  Triggers with 3 conditions. (d) CLAUDE.md under 200 lines with reflect
  mapping. (e) Backward compatibility: existing records without new fields
  described as valid.
  - Files: `.claude/skills/reflect/SKILL.md`,
    `.claude/skills/memory-manager/SKILL.md`,
    `.claude/rules/memory.md`,
    `.claude/CLAUDE.md`
  - Agent: reviewer
  - Depends on: T-01, T-02, T-03, T-04

## Phase 3 — Integration (C5)

- [x] **T-06: Update scaling.md and knowledge-map** — Edit scaling.md: skill
  count 19→20, add `reflect` to Cognitive category row. Edit knowledge-map.md:
  add reflect skill entry, update memory-related descriptions to mention
  adaptive calibration and rework tracking, add Recent Decisions entry for
  spec 005.
  - Files: `.claude/rules/scaling.md` (edit),
    `.claude/memory/knowledge-map.md` (edit)
  - Agent: implementer
  - Depends on: T-05

## Phase 4 — E2E Validation (C6)

- [x] **T-07: E2E — skill constraints and cross-references** — Verify:
  (a) reflect SKILL.md description < 1024 chars, body < 500 lines, all tool
  names valid. (b) memory-manager SKILL.md body < 500 lines. (c) scaling.md
  count = 20, reflect in Cognitive row. (d) CLAUDE.md < 200 lines. (e) Symmetric
  "Do NOT use for": reflect mentions memory-manager, memory-manager mentions
  reflect. (f) No confusability: reflect triggers are distinct from
  memory-manager triggers.
  - Files: `.claude/skills/reflect/SKILL.md`,
    `.claude/skills/memory-manager/SKILL.md`,
    `.claude/rules/scaling.md`,
    `.claude/CLAUDE.md` (read-only)
  - Agent: tester
  - Depends on: T-06

- [x] **T-08: E2E — reflection workflow walkthrough** — Walk through a
  hypothetical reflection session: (a) query records for project "marvin",
  (b) find 12 records: 5 decisions, 4 error-patterns, 2 knowledge, 1 evaluation,
  (c) identify 1 stale decision (outcome contradicted), 2 weak patterns
  (confidence 0.5, no recent confirmation), 1 near-duplicate pair (similarity
  0.90), (d) verify the report format covers all 7 sections from FR-06,
  (e) verify prune/update requires user approval, (f) verify query count stays
  under 10 (NFR-01).
  - Files: `.claude/skills/reflect/SKILL.md`,
    `.claude/rules/memory.md` (read-only)
  - Agent: tester
  - Depends on: T-06

- [x] **T-09: E2E — backward compatibility and calibration** — Verify:
  (a) memory-manager error pattern template marks `task_type`, `correction_count`,
  `last_corrected` as optional for existing records. (b) Adaptive calibration
  thresholds in memory.md match spec FR-04 (3+ patterns → deliberate, 0-1 →
  fast). (c) Reflection triggers in memory.md match spec FR-05 (3 conditions).
  (d) Existing memory rules sections are unchanged (Decision Logging, Error
  Pattern, Knowledge Map, Self-Consistency triggers all intact).
  - Files: `.claude/skills/memory-manager/SKILL.md`,
    `.claude/rules/memory.md` (read-only)
  - Agent: tester
  - Depends on: T-06

## Phase 5 — Final Review

- [x] **T-10: Final review** — Review complete diff of all modified files.
  Verify consistency across: reflect skill, memory-manager, memory rules,
  CLAUDE.md, scaling.md, knowledge-map. Check all spec requirements addressed
  (FR-01 through FR-07, NFR-01 through NFR-04). Verify no regressions in
  existing memory system functionality.
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

- **T-01 || T-02 || T-03 || T-04**: All modify different files. 4 implementers
  in parallel.
- **T-07 || T-08 || T-09**: All E2E validations are independent. 3 testers
  in parallel.

## Acceptance Criteria

- [x] All 10 tasks completed
- [x] `/reflect` skill exists with all 7 mandatory sections
- [x] `/reflect` skill has "Do NOT use for" cross-refs to memory-manager and deliberation
- [x] memory-manager has symmetric "Do NOT use for" cross-ref to reflect
- [x] Error pattern template includes `task_type`, `correction_count`, `last_corrected`
- [x] Existing records without new fields described as backward-compatible
- [x] Error density query pattern documented in memory-manager
- [x] Adaptive calibration in memory rules (3+ patterns → deliberate, 0-1 → fast)
- [x] Reflection triggers documented (explicit, post-spec 5+, density 10+)
- [x] Reflection report format covers 7 sections per FR-06
- [x] CLAUDE.md under 200 lines with reflect mapping
- [x] scaling.md count = 20, reflect in Cognitive category
- [x] Knowledge-map updated with spec 005 changes
- [x] Code reviewed (reviewer on Phase 2 + final review)
