# Tasks — Cognitive Memory System

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.

## Phase 1 — Foundation (C1)

- [x] **T-01: Create memory rules file** — Define when and how Marvin logs
  memories: triggers for decision logging, error extraction, and knowledge
  map updates. This is the behavioral contract that all other tasks reference.
  - Files: `.claude/rules/memory.md` (create)
  - Agent: implementer
  - Depends on: none

- [x] **T-02: Create memory-manager skill** — Skill with Qdrant store/retrieve
  patterns, schema documentation (collection `marvin-memory`, payload fields:
  type, project, domain, timestamp, confidence, session_id, files_affected,
  outcome), record templates for each memory type, and integration instructions.
  Must NOT contain Agent tool usage or delegation instructions (knowledge-only).
  - Files: `.claude/skills/memory-manager/SKILL.md` (create)
  - Agent: implementer
  - Depends on: T-01

- [x] **T-03: Review Phase 1** — Verify memory rules and skill follow project
  conventions (`rules/skills.md`, `rules/agents.md`). Check skill description
  is under 1024 chars. Verify no Agent/delegation instructions in skill body.
  - Files: `.claude/rules/memory.md`, `.claude/skills/memory-manager/SKILL.md`
  - Agent: reviewer
  - Depends on: T-01, T-02

## Phase 2 — Core Memory (C2 + C3, parallel)

### Decision Log (C2)

- [x] **T-04: Add decision record template to memory-manager** — Extend the
  skill with the decision record template (Context, Decision, Alternatives,
  Rationale, Domain, Project) and prompt patterns for: (a) post-decision
  storage via `qdrant-store`, (b) pre-decision retrieval via `qdrant-find`.
  - Files: `.claude/skills/memory-manager/SKILL.md` (edit)
  - Agent: implementer
  - Depends on: T-03

- [x] **T-05: Add decision logging triggers to memory rules** — Extend
  `memory.md` with: "After architectural decisions affecting 2+ files, log
  to memory" and "Before choosing an approach for non-trivial changes, query
  memory for similar past decisions."
  - Files: `.claude/rules/memory.md` (edit)
  - Agent: implementer
  - Depends on: T-03

### Error Patterns (C3)

- [x] **T-06: Add error pattern template to memory-manager** — Extend the
  skill with error pattern template (Trigger, Symptom, Root Cause, Correct
  Approach, Domain, Confidence) and the 3-level extraction heuristic:
  micro (per-session correction), meso (per-task reflection), macro (periodic
  `/reflect` pass). Include confidence escalation logic (similarity > 0.85
  → increment, not duplicate; 2 occurrences = pattern, 3+ = strong).
  - Files: `.claude/skills/memory-manager/SKILL.md` (edit)
  - Agent: implementer
  - Depends on: T-03

- [x] **T-07: Add error extraction triggers to memory rules** — Extend
  `memory.md` with: "When user corrects output, extract error class and store
  as anti-pattern" and "Before acting on a task, query error patterns relevant
  to the task's domain."
  - Files: `.claude/rules/memory.md` (edit)
  - Agent: implementer
  - Depends on: T-03

- [x] **T-08: Review Phase 2** — Verify decision log and error pattern
  templates are consistent with schema from T-02. Check that retrieval
  patterns use correct Qdrant MCP tool names. Verify triggers in memory rules
  are specific (not vague). Check no duplication between templates.
  - Files: `.claude/skills/memory-manager/SKILL.md`, `.claude/rules/memory.md`
  - Agent: reviewer
  - Depends on: T-04, T-05, T-06, T-07

## Phase 3 — Structured Deliberation (C4)

- [x] **T-09: Create deliberation skill** — New skill implementing the 7-step
  deliberation process: FRAME → GENERATE → ATTACK → COST CHECK → PREMORTEM →
  DECIDE → LOG. Include: (a) when to use heuristics (3+ files, new dependency,
  public API, confidence < 0.70), (b) when NOT to use (docs fixes, renames,
  single file behind feature flag), (c) output format as structured
  deliberation record, (d) integration with decision log via memory-manager
  store pattern. Skill must be user-invocable (add to SKILL.md frontmatter).
  - Files: `.claude/skills/deliberation/SKILL.md` (create)
  - Agent: implementer
  - Depends on: T-08

- [x] **T-10: Review deliberation skill** — Verify 7-step process is complete.
  Check heuristics are concrete (not vague). Verify output format matches
  decision record schema. Verify skill is self-contained (no circular
  references to memory-manager skill). Check description under 1024 chars.
  - Files: `.claude/skills/deliberation/SKILL.md`
  - Agent: reviewer
  - Depends on: T-09

## Phase 4 — Project Knowledge Map (C5)

- [x] **T-11: Create knowledge map** — Seed `.claude/memory/knowledge-map.md`
  with current project structure: modules (skills, agents, specs, templates),
  key dependencies (Qdrant, Context7, Exa MCPs), architectural invariants
  (CLAUDE.md > Skills > Agents hierarchy, SDD pipeline), and active
  conventions. Format: human-editable markdown with sections for Modules,
  Key Dependencies, Architectural Invariants, Active Conventions, Error
  Patterns.
  - Files: `.claude/memory/knowledge-map.md` (create)
  - Agent: implementer
  - Depends on: T-08

- [x] **T-12: Add knowledge map update triggers to memory rules** — Extend
  `memory.md` with: "After implementing a feature that adds modules, changes
  dependencies, or establishes new conventions → update knowledge-map.md"
  and "On session start, consult knowledge-map.md for project orientation."
  - Files: `.claude/rules/memory.md` (edit)
  - Agent: implementer
  - Depends on: T-11

- [x] **T-13: Review Phase 4** — Verify knowledge map accurately reflects
  current project. Check that update triggers are actionable. Verify the map
  is human-readable and doesn't duplicate CLAUDE.md content.
  - Files: `.claude/memory/knowledge-map.md`, `.claude/rules/memory.md`
  - Agent: reviewer
  - Depends on: T-11, T-12

## Phase 5 — Integration (C6)

- [x] **T-14: Update CLAUDE.md with memory section** — Add a "Cognitive Memory"
  section to CLAUDE.md that references `.claude/rules/memory.md` for detailed
  rules. Add knowledge map reference to the Session Orientation section.
  Keep additions minimal — CLAUDE.md should stay under 200 lines.
  - Files: `.claude/CLAUDE.md` (edit)
  - Agent: implementer
  - Depends on: T-13

- [x] **T-15: E2E validation — decision log** — Store a test decision via
  `qdrant-store` using the memory-manager schema. Retrieve it via
  `qdrant-find` with a semantically similar query. Verify correct record is
  returned with expected metadata.
  - Files: none (Qdrant operations only)
  - Agent: tester
  - Depends on: T-14

- [x] **T-16: E2E validation — error patterns** — Store a test error pattern.
  Query with a task description that should trigger retrieval. Verify the
  anti-pattern is surfaced. Test confidence escalation: store a second similar
  pattern and verify deduplication behavior.
  - Files: none (Qdrant operations only)
  - Agent: tester
  - Depends on: T-14

- [x] **T-17: E2E validation — deliberation** — Invoke the deliberation skill
  on a sample architectural question (e.g., "Should we add a caching layer to
  the memory-manager?"). Verify all 7 steps complete. Verify the result is
  stored as a decision record in Qdrant.
  - Files: `.claude/skills/deliberation/SKILL.md` (read-only)
  - Agent: tester
  - Depends on: T-14

- [x] **T-18: E2E validation — knowledge map** — Verify the knowledge map
  is accurate and complete. Simulate a session start and confirm the map
  provides useful orientation context.
  - Files: `.claude/memory/knowledge-map.md` (read-only)
  - Agent: tester
  - Depends on: T-14

- [x] **T-19: Final review** — Review the complete diff of all files created
  and modified across all phases. Verify consistency, no duplication, and
  adherence to project conventions. Check total CLAUDE.md line count stays
  under 200.
  - Files: all created/modified files
  - Agent: reviewer
  - Depends on: T-15, T-16, T-17, T-18

## Task Dependency Graph

```
T-01 ──→ T-02 ──→ T-03 ──┬──→ T-04 ──→ T-08
                          ├──→ T-05 ──→ T-08
                          ├──→ T-06 ──→ T-08
                          └──→ T-07 ──→ T-08
                                         │
                          T-08 ──┬──→ T-09 ──→ T-10
                                 └──→ T-11 ──→ T-12 ──→ T-13
                                                          │
                                 T-10 + T-13 ──→ T-14
                                                   │
                                    T-14 ──┬──→ T-15
                                           ├──→ T-16  ──→ T-19
                                           ├──→ T-17
                                           └──→ T-18
```

## Parallelization Opportunities

- **T-04 ∥ T-05 ∥ T-06 ∥ T-07**: All depend only on T-03. Can run 4
  implementer agents in parallel (worktree isolation recommended since
  T-04/T-06 both edit the same skill file).
- **T-09 ∥ T-11**: Deliberation skill and knowledge map are independent.
  Can run in parallel after T-08.
- **T-15 ∥ T-16 ∥ T-17 ∥ T-18**: All E2E validations are independent.
  Can run 4 tester agents in parallel.

## Acceptance Criteria

- [x] All 19 tasks completed
- [x] Memory-manager skill created with store/retrieve patterns for all 4 types
- [x] Deliberation skill created with 7-step process and trigger heuristics
- [x] Knowledge map seeded with accurate project structure
- [x] CLAUDE.md updated with memory section (under 200 lines total)
- [x] E2E: decision stored and retrieved via Qdrant
- [x] E2E: error pattern stored and retrieved via Qdrant
- [x] E2E: deliberation process completes and logs to Qdrant
- [x] E2E: knowledge map provides useful session orientation
- [x] Code reviewed (reviewer agent on each phase + final review)
- [x] No circular dependencies between skills
- [x] All skill descriptions under 1024 characters
