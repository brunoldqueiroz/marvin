# Tasks — Self-Consistency & Verification

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.

## Phase 1 — Core Skill (C1)

- [x] **T-01: Create self-consistency skill** — Create the full skill file
  with all 7 mandatory sections: Tool Selection, Core Principles (7-10 rules
  covering candidate generation, rubric scoring, confidence derivation,
  activation/skip heuristics, transparency, Qdrant logging), Best Practices
  (10 items including stance prompts, default rubric with weights, domain
  rubric overrides, simultaneous scoring, winner selection, close-call
  handling, pre-task query, result logging template, integration patterns),
  Anti-Patterns (10 items), Examples (3 scenarios), Troubleshooting (3-4
  entries), Review Checklist (10 items). User-invocable as `/verify`.
  Description must be under 1024 chars. Body must be under 500 lines.
  Frontmatter: `metadata.category: workflow`, tools list must include
  Read, Glob, Grep, Agent, mcp__qdrant__qdrant-store, mcp__qdrant__qdrant-find.
  - Files: `.claude/skills/self-consistency/SKILL.md` (create)
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Review core skill** — Verify all 7 sections present and in
  order per `rules/skills.md`. Check description under 1024 chars, body under
  500 lines. Verify rubric weights sum to 1.0. Verify confidence derivation
  thresholds are consistent (HIGH >20%, MED 10-20%, LOW <10%). Check no
  circular references to deliberation or memory-manager. Verify activation
  and skip heuristics are concrete, not vague. Verify examples use realistic
  marvin project context.
  - Files: `.claude/skills/self-consistency/SKILL.md`
  - Agent: reviewer
  - Depends on: T-01

## Phase 2 — Integration (C2 + C3 + C4 + C5, parallel)

- [x] **T-03: Update memory rules** — Add `evaluation` to the valid types
  list in `rules/memory.md`. Add a "Self-Consistency Triggers" section with:
  "Before complex code generation or architectural decisions with MED/LOW
  confidence, consider self-consistency" and "After self-consistency
  evaluation, log result to Qdrant with type `evaluation`."
  - Files: `.claude/rules/memory.md` (edit)
  - Agent: implementer
  - Depends on: T-02

- [x] **T-04: Update sibling skill cross-references** — Edit deliberation
  skill description to add "candidate scoring (self-consistency)" to its
  "Do NOT use for" clause. Edit memory-manager skill description to add
  "candidate comparison (self-consistency)" to its "Do NOT use for" clause.
  Add a brief note in deliberation's GENERATE step (Best Practices section)
  mentioning optional self-consistency integration for scoring alternatives.
  - Files: `.claude/skills/deliberation/SKILL.md` (edit),
    `.claude/skills/memory-manager/SKILL.md` (edit)
  - Agent: implementer
  - Depends on: T-02

- [x] **T-05: Update CLAUDE.md** — Add `verify/compare → self-consistency`
  to the Skill Loading keyword map. Add a bullet to the Cognitive Memory
  section: "For comparing alternatives: load the `self-consistency` skill".
  Verify total line count stays under 200.
  - Files: `.claude/CLAUDE.md` (edit)
  - Agent: implementer
  - Depends on: T-02

- [x] **T-06: Update scaling and knowledge map** — Update scaling.md: change
  skill count from 18 to 19, add `self-consistency` to the Cognitive category
  row in the taxonomy table. Update knowledge-map.md: add self-consistency
  entry to the Skills list, update skill count from 18 to 19, update the
  Modules line if needed.
  - Files: `.claude/rules/scaling.md` (edit),
    `.claude/memory/knowledge-map.md` (edit)
  - Agent: implementer
  - Depends on: T-02

## Phase 3 — Review

- [x] **T-07: Review integration changes** — Verify memory rules include
  `evaluation` type and triggers are specific. Verify sibling skill
  cross-references are symmetric (self-consistency excludes deliberation AND
  deliberation excludes self-consistency). Verify CLAUDE.md is under 200
  lines. Verify scaling.md count is 19. Verify knowledge-map.md is accurate.
  Check no duplication across files.
  - Files: `.claude/rules/memory.md`, `.claude/skills/deliberation/SKILL.md`,
    `.claude/skills/memory-manager/SKILL.md`, `.claude/CLAUDE.md`,
    `.claude/rules/scaling.md`, `.claude/memory/knowledge-map.md`
  - Agent: reviewer
  - Depends on: T-03, T-04, T-05, T-06

## Phase 4 — E2E Validation (C6)

- [x] **T-08: E2E — rubric scoring walkthrough** — Manually walk through
  the skill's example scenario to verify: 3 candidates are described with
  distinct stances, rubric scoring produces correct weighted totals, winner
  selection follows the highest score, confidence level matches the margin
  threshold. Verify the output format includes a comparison table.
  - Files: `.claude/skills/self-consistency/SKILL.md` (read-only)
  - Agent: tester
  - Depends on: T-07

- [x] **T-09: E2E — Qdrant evaluation record** — Store a test evaluation
  record in Qdrant with type `evaluation` and full metadata (candidates,
  rubric, scores, winner, confidence, domain, project, timestamp). Retrieve
  it via `qdrant-find` with a semantically similar query. Verify the correct
  record is returned with expected metadata fields.
  - Files: none (Qdrant operations only)
  - Agent: tester
  - Depends on: T-07

- [x] **T-10: E2E — skill constraints** — Verify: (a) skill description is
  under 1024 characters, (b) skill body is under 500 lines, (c) no circular
  imports or dependencies with deliberation or memory-manager, (d) all tool
  names in the frontmatter are valid.
  - Files: `.claude/skills/self-consistency/SKILL.md` (read-only)
  - Agent: tester
  - Depends on: T-07

## Phase 5 — Final Review

- [x] **T-11: Final review** — Review the complete diff of all files created
  and modified. Verify consistency across all artifacts: skill, rules,
  CLAUDE.md, scaling, knowledge-map, sibling cross-references. Check no
  regressions in existing skills. Verify all spec requirements (FR-01 through
  FR-12, NFR-01 through NFR-05) are addressed.
  - Files: all created/modified files
  - Agent: reviewer
  - Depends on: T-08, T-09, T-10

## Task Dependency Graph

```
T-01 ──→ T-02 ──┬──→ T-03 ──→ T-07
                 ├──→ T-04 ──→ T-07
                 ├──→ T-05 ──→ T-07
                 └──→ T-06 ──→ T-07
                                 │
                      T-07 ──┬──→ T-08
                             ├──→ T-09  ──→ T-11
                             └──→ T-10
```

## Parallelization Opportunities

- **T-03 ∥ T-04 ∥ T-05 ∥ T-06**: All depend only on T-02. Can run 4
  implementer agents in parallel (each edits different files — no conflicts).
- **T-08 ∥ T-09 ∥ T-10**: All E2E validations are independent. Can run 3
  tester agents in parallel.

## Acceptance Criteria

- [x] All 11 tasks completed
- [x]Self-consistency skill created with all 7 mandatory sections
- [x]Default rubric defined with 4 weighted criteria summing to 1.0
- [x]Domain rubric overrides included (security, performance, data engineering)
- [x]Activation and skip heuristics are concrete and specific
- [x]Confidence scoring derives from score distribution margins
- [x]`evaluation` type added to memory rules
- [x]Sibling skill cross-references are symmetric
- [x]CLAUDE.md updated with skill mapping (under 200 lines total)
- [x]Scaling count is 19, taxonomy includes self-consistency
- [x]Knowledge map updated with new skill
- [x]E2E: evaluation record stored and retrieved via Qdrant
- [x]E2E: rubric scoring produces correct rankings
- [x]E2E: skill description under 1024 chars, body under 500 lines
- [x]Code reviewed (reviewer on each phase + final review)
- [x]No circular dependencies between skills
