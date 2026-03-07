# Plan — Self-Consistency & Verification

> Implementation strategy derived from the spec. Reviewable checkpoint before
> writing code.

## Approach

Create a new `self-consistency` workflow skill that generates 3 candidate
solutions in parallel, scores them against a weighted rubric, and selects the
winner with an explicit confidence level. The skill integrates optionally with
the existing deliberation skill (at the GENERATE step) and with the
implementer agent workflow (wrapping code generation). All evaluations are
logged to Qdrant (`marvin-kb`, type: `evaluation`) for cross-session learning.

The implementation follows the same pattern as spec 002: skill file as the
primary artifact, rules file updates for triggers, and lightweight integration
touches to CLAUDE.md, scaling.md, knowledge-map.md, and cross-references in
sibling skills.

## Components

### C1: Self-Consistency Skill

- **What**: New workflow skill implementing the full self-consistency process:
  candidate generation with stance prompts, rubric definition (default +
  domain overrides), simultaneous scoring, winner selection with confidence
  derivation, and result logging to Qdrant. User-invocable as `/verify`.
  Must include all 7 mandatory sections per `rules/skills.md`.
- **Files**: `.claude/skills/self-consistency/SKILL.md` (create)
- **Dependencies**: none (standalone skill, no circular refs)

### C2: Memory Rules Update

- **What**: Add `evaluation` as a valid memory type in `rules/memory.md`.
  Add self-consistency triggers: "Before complex code generation or
  architectural decisions with MED/LOW confidence, consider self-consistency"
  and "After self-consistency evaluation, log result to Qdrant."
- **Files**: `.claude/rules/memory.md` (edit)
- **Dependencies**: C1 (need to know the exact metadata schema)

### C3: Sibling Skill Cross-References

- **What**: Update deliberation and memory-manager skill descriptions to
  reference self-consistency in their "Do NOT use for" clauses (symmetric
  cross-refs per scaling.md checklist). Add a note in deliberation's GENERATE
  step about optional self-consistency integration.
- **Files**: `.claude/skills/deliberation/SKILL.md` (edit description),
  `.claude/skills/memory-manager/SKILL.md` (edit description)
- **Dependencies**: C1 (need final skill name and trigger phrases)

### C4: CLAUDE.md Integration

- **What**: Add `verify/self-consistency → self-consistency` to the Skill
  Loading keyword map. Add a bullet to the Cognitive Memory section:
  "For comparing alternatives: load the `self-consistency` skill".
  Must keep CLAUDE.md under 200 lines.
- **Files**: `.claude/CLAUDE.md` (edit)
- **Dependencies**: C1

### C5: Scaling & Knowledge Map

- **What**: Update scaling.md skill count from 18 to 19, add
  self-consistency to the Cognitive category in the taxonomy table. Update
  knowledge-map.md with the new skill entry and skill count.
- **Files**: `.claude/rules/scaling.md` (edit),
  `.claude/memory/knowledge-map.md` (edit)
- **Dependencies**: C1

### C6: E2E Validation

- **What**: Validate the full self-consistency workflow:
  (a) Generate 3 candidates for a sample architectural question, score via
  rubric, verify winner selection and confidence derivation.
  (b) Store evaluation record in Qdrant, retrieve it, verify metadata.
  (c) Verify skill description is under 1024 chars, body under 500 lines.
  (d) Verify no circular dependencies with deliberation or memory-manager.
- **Files**: `.claude/skills/self-consistency/SKILL.md` (read-only),
  Qdrant operations
- **Dependencies**: C1, C2, C3, C4, C5

## Execution Order

1. **Phase 1 — Core Skill (C1)**: Create the self-consistency skill. This is
   the foundation; all other components reference it.
2. **Phase 2 — Integration (C2 + C3 + C4 + C5, parallel)**: Once the skill
   exists, all integration updates are independent of each other and can run
   in parallel. C2 edits memory rules, C3 edits sibling skills, C4 edits
   CLAUDE.md, C5 edits scaling/knowledge-map.
3. **Phase 3 — Review**: Reviewer agent validates all changes for consistency,
   convention adherence, and no regressions.
4. **Phase 4 — E2E Validation (C6)**: Tester agent runs the full workflow
   end-to-end.
5. **Phase 5 — Final Review**: Final reviewer pass on the complete diff.

## Delegation Strategy

| Phase | Agent | Parallel? |
|-------|-------|-----------|
| C1 | implementer | — |
| C2 | implementer | yes (with C3, C4, C5) |
| C3 | implementer | yes (with C2, C4, C5) |
| C4 | implementer | yes (with C2, C3, C5) |
| C5 | implementer | yes (with C2, C3, C4) |
| Review | reviewer | — |
| C6 | tester | — |
| Final | reviewer | — |

Note: C2-C5 each edit different files, so parallel execution is safe without
worktree isolation.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Skill body exceeds 500-line budget | Medium | Rubric registry + examples are verbose. Use concise tables for rubrics. Move detailed rubric definitions into numbered subsections, not nested code blocks. Target ~350 lines to leave margin. |
| Description exceeds 1024 chars | Medium | Draft description first, measure, iterate. Self-consistency has many trigger phrases — prioritize the top 5. |
| Confusability with deliberation skill | High | Clear "Do NOT" clauses in both directions. Deliberation = structured decision process (7 steps). Self-consistency = multi-candidate generation + scoring. Different triggers, different output. |
| Token cost concerns (3x generation) | Medium | Strict activation heuristics: only ~15% of tasks. Skip heuristics explicit. User can always bypass with "just do it". |
| CLAUDE.md line count creep | Low | Adding 2 lines max. Current is 105 lines — well under 200. |

## Testing Strategy

- **Unit**: Verify rubric weight calculations produce correct rankings for
  known inputs (manual walkthrough in the skill examples section).
- **Integration**: Store an evaluation record in Qdrant, retrieve it by
  semantic similarity, verify all metadata fields are present and correct.
- **Manual verification**: Invoke `/verify` on a sample question. Confirm
  3 candidates are generated, scored, and a winner is selected with the
  correct confidence level.

## Alternatives Considered

| Alternative | Why rejected |
|-------------|-------------|
| Pairwise comparison instead of rubric scoring | O(n²) comparisons for n candidates. With N=3, that's 3 comparisons vs 1 simultaneous scoring pass. Rubric is more efficient and produces numeric scores for confidence derivation. |
| Embedding self-consistency into the deliberation skill | Violates NFR-04 (no circular dependencies). Deliberation is about the decision process (7 steps); self-consistency is about candidate generation and evaluation. Separate concerns, separate skills. |
| LLM-as-judge (single judge prompt) | Susceptible to position bias (Zheng et al. 2023). Rubric scoring with explicit criteria is more auditable and reproducible. |
| Adaptive N (2-5 based on stakes) | Added complexity for marginal gain. Research shows 1→3 is the big jump; 3→5 is diminishing returns. Fixed N=3 is simpler and sufficient. |
