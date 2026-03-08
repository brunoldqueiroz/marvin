# Spec — Multidimensional Confidence

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

The deliberation skill assigns a single scalar confidence score (HIGH/MED/LOW,
mapped to 0.0–1.0) to every decision. This collapses multiple dimensions of
uncertainty into one number, losing information that would guide targeted
follow-up.

Example: when deciding whether to add Redis caching, feasibility might be HIGH
(the team knows Redis well) but maintenance cost confidence might be LOW (cache
invalidation is complex). A single MED confidence hides this — the agent would
re-run the full deliberation instead of researching cache invalidation costs
specifically.

The problem is not that scalar confidence is wrong — it's that it's
**insufficient for actionable follow-up**. When confidence is MED or LOW, the
agent doesn't know *which dimension* to investigate further. It either
re-deliberates everything (wasteful) or escalates to the user without
specificity (unhelpful).

Self-consistency already provides per-criterion rubric scores (correctness,
simplicity, maintainability, performance). The gap is in deliberation, where
the DECIDE step produces a single number without dimensional breakdown.

## Desired Outcome

After implementation:

1. The deliberation skill's DECIDE step (step 6) reports confidence across
   3–4 dimensions alongside the overall scalar score.
2. Each dimension has its own HIGH/MED/LOW rating with a brief justification.
3. The overall confidence remains a weighted aggregate for backward
   compatibility — existing Qdrant records, session confidence, and adaptive
   calibration all continue to work with the scalar value.
4. When overall confidence is MED or LOW, the dimension breakdown identifies
   which specific dimension(s) drove it down, enabling targeted follow-up
   (e.g., "cost confidence is LOW — research maintenance burden before
   proceeding").
5. The decision record template in the deliberation skill includes per-
   dimension scores alongside the overall score.
6. The Qdrant metadata schema supports optional dimension scores without
   breaking existing records (backward compatible).

## Requirements

### Functional

1. **FR-01: Confidence dimensions** — Define 3 standard dimensions for
   deliberation confidence:
   - **Feasibility**: can this be built with available tools, skills, and time?
   - **Cost**: what is the implementation + maintenance burden relative to
     the benefit?
   - **Risk**: what is the probability and impact of the pre-mortem failure
     mode?

   These dimensions map naturally to deliberation's 7-step process:
   feasibility from GENERATE/ATTACK, cost from COST CHECK, risk from PREMORTEM.

2. **FR-02: Dimensional scoring in DECIDE step** — Update the DECIDE step
   (step 6) in the deliberation skill to include per-dimension confidence:
   ```
   6. DECIDE — State the chosen approach. Assign confidence:
      Overall: MED (0.72)
      - Feasibility: HIGH (0.90) — well-understood technology
      - Cost: LOW (0.45) — cache invalidation complexity unknown
      - Risk: MED (0.70) — pre-mortem failure mode has partial mitigation
   ```
   The overall score is a weighted aggregate: feasibility 0.40, cost 0.30,
   risk 0.30.

3. **FR-03: Updated decision record template** — Extend the decision record
   template in the deliberation skill to include dimensional scores:
   ```
   Confidence: [HIGH|MED|LOW] ([score])
     Feasibility: [HIGH|MED|LOW] ([score]) — [justification]
     Cost: [HIGH|MED|LOW] ([score]) — [justification]
     Risk: [HIGH|MED|LOW] ([score]) — [justification]
   ```

4. **FR-04: Targeted follow-up guidance** — Add guidance to the deliberation
   skill: when overall confidence is MED or LOW, identify the lowest-scoring
   dimension and suggest a targeted action:
   - Feasibility LOW → spike or prototype before committing
   - Cost LOW → research implementation effort and maintenance burden
   - Risk LOW → revisit pre-mortem, add mitigations, or consider alternatives

5. **FR-05: Backward-compatible Qdrant metadata** — When storing deliberation
   records in Qdrant, include optional `confidence_dimensions` in metadata:
   `{feasibility: 0.90, cost: 0.45, risk: 0.70}`. Existing records without
   this field remain valid. Queries filter by overall `confidence` as before.

6. **FR-06: Confidence calibration update** — Update the confidence calibration
   section in the deliberation skill to reference dimensions:
   - HIGH overall: all dimensions ≥ 0.70
   - MED overall: at least one dimension < 0.70, none < 0.40
   - LOW overall: any dimension < 0.40

### Non-Functional

1. **NFR-01: Backward compatible** — The overall scalar confidence remains
   the primary value. All existing integrations (session confidence, adaptive
   calibration, Qdrant queries) continue to use it unchanged.

2. **NFR-02: No new files or skills** — Changes are contained within the
   deliberation skill SKILL.md and optionally the memory.md Qdrant metadata
   documentation.

3. **NFR-03: Skill body budget** — The deliberation SKILL.md must remain
   under 500 lines after changes.

4. **NFR-04: Dimensional scoring is additive** — If the agent cannot assess
   a dimension (insufficient information), it may omit that dimension and
   note why. The overall score can still be computed from available dimensions.

## Scope

### In Scope

- 3 confidence dimensions (feasibility, cost, risk) in deliberation skill
- Updated DECIDE step with dimensional scoring
- Updated decision record template
- Targeted follow-up guidance for MED/LOW dimensions
- Updated confidence calibration section
- Qdrant metadata extension (optional `confidence_dimensions`)
- Knowledge-map update

### Out of Scope

- Changes to self-consistency skill (its rubric scores already provide
  per-criterion data)
- Changes to memory.md adaptive calibration (continues using scalar)
- Changes to session confidence (continues using scalar)
- New confidence dimensions beyond 3 (keep it simple)
- Migration of existing Qdrant records (backward compatible)
- Weighted aggregate configuration (fixed weights: 0.40/0.30/0.30)

## Constraints

- Deliberation SKILL.md must stay under 500 lines
- Deliberation skill description must stay under 1024 chars
- The 7-step process is unchanged — dimensions are an output of DECIDE,
  not new steps
- Existing examples in the skill should be updated to show dimensional
  confidence

## Open Questions

- Should the dimension weights (0.40/0.30/0.30) be domain-specific?
  Recommendation: no — fixed weights keep it simple. Domain-specific rubric
  overrides are already handled by self-consistency. Deliberation dimensions
  should be universal.

## References

- `.claude/skills/deliberation/SKILL.md` — current confidence scoring
  (lines 57–58, 95–103, 165, 173–178)
- `.claude/skills/self-consistency/SKILL.md` — per-criterion rubric scoring
  (already dimensional)
- `.claude/rules/memory.md` — Qdrant metadata schema (line 84–85)
