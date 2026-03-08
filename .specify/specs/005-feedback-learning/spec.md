# Spec — Feedback Learning System

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin has the building blocks for learning from mistakes — error pattern
storage in Qdrant (spec 002), micro/meso/macro extraction levels in memory
rules, and confidence escalation in the memory-manager skill. However, three
critical gaps remain:

1. **No `/reflect` skill** — The macro-level extraction ("run `/reflect` to
   consolidate recurring patterns") is referenced in memory rules and
   memory-manager but doesn't exist. There is no way to periodically audit
   stored patterns, prune stale records, identify contradictions, or
   consolidate weak signals into strong patterns.

2. **No rework tracking** — When a user corrects output or a reviewer rejects
   work, there is no systematic capture of *which task types and domains*
   generate the most corrections. Without this, Marvin can't learn where to
   slow down and deliberate more vs. where to go fast.

3. **No adaptive calibration** — Deliberation and self-consistency have fixed
   activation thresholds. They don't adapt based on Marvin's actual track
   record in a domain. A domain where Marvin consistently makes mistakes
   should trigger more deliberation automatically, while domains with a clean
   track record should allow faster execution.

This is the final improvement from the initial cognitive evolution roadmap
(section 6: Learning from Feedback). It is the only improvement that
**compounds over time** — all other improvements (specs 002-004) help equally
on day 1 and day 100, but systematic feedback learning gets better with use.

## Desired Outcome

After implementation:

1. A `/reflect` skill exists that audits Qdrant records for a project,
   identifies stale/contradictory/weak patterns, and consolidates them. It
   produces a structured reflection report and updates records in place.
2. Error patterns stored in Qdrant include a `task_type` metadata field
   (e.g., "implementation", "architecture", "testing") and a `correction_count`
   field that tracks how many times this class of error has been observed.
3. Memory rules include guidance for adaptive thresholds: domains/task types
   with high error density should bias toward deliberation and self-consistency.
4. The memory-manager skill references `/reflect` with concrete guidance on
   when and how to trigger it.
5. Over multiple sessions, Marvin's error rate in frequently-corrected domains
   decreases measurably (tracked via correction counts in Qdrant).

## Requirements

### Functional

1. **FR-01: `/reflect` skill** — Create a new user-invocable skill that:
   (a) queries all records in `marvin-kb` for the current project,
   (b) groups them by type and domain,
   (c) identifies stale records (outcome contradicted by recent evidence),
   (d) identifies weak patterns (confidence < 0.65 with no recent confirmation),
   (e) identifies duplicate/near-duplicate records (similarity > 0.85),
   (f) consolidates recurring weak patterns into strong signals (3+ occurrences
   → confidence 0.80+),
   (g) produces a structured reflection report,
   (h) optionally prunes or updates records with user approval.

2. **FR-02: Rework metadata fields** — Extend the error-pattern record schema
   with: `task_type` (implementation | architecture | testing | review |
   planning), `correction_count` (integer, starts at 1, incremented on
   re-occurrence), and `last_corrected` (ISO timestamp of most recent
   occurrence).

3. **FR-03: Domain error density query** — The memory-manager skill should
   support querying error density for a domain: "how many error patterns exist
   for domain X with confidence > 0.65?" This informs adaptive calibration.

4. **FR-04: Adaptive calibration rules** — Update memory rules to include
   calibration guidance: when a domain has 3+ high-confidence error patterns,
   bias toward loading deliberation and/or self-consistency skills for tasks
   in that domain. When a domain has 0-1 error patterns, allow fast execution
   without forced deliberation.

5. **FR-05: Reflection triggers** — Document when `/reflect` should be run:
   (a) explicitly by user command,
   (b) after completing a multi-task spec implementation (5+ tasks),
   (c) when session memory density is high (10+ records stored in one session).
   These are advisory, not forced.

6. **FR-06: Reflection report format** — The reflection report should include:
   (a) record counts by type and domain,
   (b) stale records identified (with reason),
   (c) weak patterns identified (with suggestion: prune or boost),
   (d) near-duplicates identified (with merge suggestion),
   (e) consolidated patterns (weak → strong),
   (f) domain error density summary (for calibration review),
   (g) recommended actions (prune, merge, boost, no-action).

7. **FR-07: Update memory-manager with reflect integration** — Add concrete
   guidance in memory-manager for: (a) when to suggest `/reflect` to the user,
   (b) how reflection results feed back into error pattern confidence, and
   (c) how to update `correction_count` and `last_corrected` on re-occurrence.

### Non-Functional

1. **NFR-01: Token cost control** — `/reflect` queries Qdrant multiple times.
   Keep total queries under 10 per reflection session. Batch by type/domain
   rather than individual record queries.
2. **NFR-02: Non-blocking** — Reflection is advisory. If Qdrant is unavailable,
   report gracefully and skip. Never block primary task work for reflection.
3. **NFR-03: Backward compatibility** — Existing error-pattern records without
   the new metadata fields remain valid. New fields are optional for old records,
   required for new ones.
4. **NFR-04: Skill count awareness** — Adding `/reflect` brings skill count
   to 20. Update scaling.md accordingly. Verify no confusability with
   memory-manager (reflect audits/consolidates; memory-manager stores/retrieves).

## Scope

### In Scope

- `/reflect` skill creation (user-invocable, advisory category)
- Error-pattern metadata extension (task_type, correction_count, last_corrected)
- Memory rules update with adaptive calibration guidance
- Memory-manager update with reflect integration
- Scaling.md count update
- Knowledge-map update

### Out of Scope

- Automatic reflection (user must invoke or approve)
- Dashboard or visualization of error patterns
- Cross-project error pattern analysis
- Changes to deliberation or self-consistency skills (calibration is advisory
  in memory rules, not enforced in those skills)
- Automated testing of reflection quality

## Constraints

- Must follow skill authoring rules (7 mandatory sections for advisory skill)
- New skill description must have "Do NOT use for" cross-references
- Must update symmetric cross-references in memory-manager
- Qdrant record schema changes must be backward-compatible
- CLAUDE.md must not exceed 200 lines
- Skill count stays at or below 20 after addition

## Open Questions

- Should reflection results be stored as their own Qdrant record type
  (e.g., `reflection`)? Recommendation: no — reflection consolidates existing
  records rather than creating new type. The report is ephemeral.
- Should `correction_count` be stored in Qdrant metadata or in a separate
  tracking file? Recommendation: Qdrant metadata — keeps everything in one
  place and queryable.

## References

- `.specify/specs/002-cognitive-memory/initial-analysis.md` — section 6
  (Learning from Feedback)
- `.claude/rules/memory.md` — existing extraction levels and `/reflect` reference
- `.claude/skills/memory-manager/SKILL.md` — existing skill to be updated
- `.claude/rules/scaling.md` — skill count tracking
