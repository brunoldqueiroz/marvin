# Spec — Intra-Session Adaptation

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin's adaptive calibration (spec 005, memory.md) works **between sessions**
— on session start, query Qdrant for error patterns in a domain and adjust
deliberation thresholds accordingly. But within a single session, there is no
mechanism to adjust behavior based on accumulating evidence.

If Marvin makes 2 errors in Python implementation tasks within one session,
the third Python task is approached with the same default confidence. The user
corrects output twice, but the agent doesn't recognize the pattern in real
time. It only learns *next session* when Qdrant is queried and the stored
error patterns influence calibration.

This creates two problems:

1. **Repeated mistakes within a session**: the same class of error can recur
   3-4 times before the session ends and the learning is persisted. Each
   correction costs the user time and tokens.

2. **No proportional response**: a domain where Marvin just failed twice
   should trigger more caution (deliberation, self-consistency) on the next
   task in that domain. Instead, the agent proceeds at full speed.

The gap is a **session-scoped confidence tracker** that degrades in real time
as corrections accumulate, and triggers behavioral adjustments within the
same session — without waiting for cross-session Qdrant persistence.

## Desired Outcome

After implementation:

1. Memory rules include a "Session Confidence" section that defines an
   ephemeral, domain-specific confidence tracker.
2. The tracker starts at a neutral state on session start and degrades when:
   - The user corrects output (any domain)
   - A reviewer agent rejects work
   - A task produces output that requires backtracking
3. Confidence is tracked per domain (e.g., `python`, `architecture`,
   `terraform`) so errors in one domain don't affect unrelated domains.
4. When session confidence in a domain drops below a threshold:
   - The agent loads `deliberation` and/or `self-consistency` skills before
     acting on the next task in that domain
   - The agent explicitly notes the confidence degradation in its output
5. The tracker is ephemeral — it resets on session start, is never persisted
   to Qdrant, and adds zero overhead when no corrections occur.
6. The tracker complements (not replaces) the existing cross-session Adaptive
   Calibration — both can trigger independently.

## Requirements

### Functional

1. **FR-01: Session Confidence section in memory.md** — Add a new section
   to `.claude/rules/memory.md` that defines the session confidence tracker.
   The section specifies: tracker initialization, degradation triggers,
   domain scoping, behavioral thresholds, and relationship to cross-session
   calibration.

2. **FR-02: Tracker initialization** — On session start, all domains begin
   at confidence level NEUTRAL. No special initialization action is needed —
   the absence of degradation signals means NEUTRAL.

3. **FR-03: Degradation triggers** — Confidence in a domain degrades when:
   (a) The user corrects output related to that domain (micro-level extraction
   from spec 005).
   (b) A reviewer agent requests changes to work in that domain.
   (c) A task in that domain produces output requiring backtracking.
   Each trigger degrades confidence by one level.

4. **FR-04: Confidence levels** — Three levels per domain:
   - **NEUTRAL** (default): no corrections in this domain this session. Execute
     normally.
   - **CAUTIOUS** (1 correction): query Qdrant for error patterns in this
     domain before the next task. Note elevated caution in output.
   - **DELIBERATE** (2+ corrections): load `deliberation` or
     `self-consistency` skill before the next task in this domain. Explicitly
     tell the user: "Session confidence in {domain} is low — deliberating
     before proceeding."

5. **FR-05: Domain scoping** — Track confidence per domain using the same
   domain tags used in Qdrant metadata (e.g., `python`, `architecture`,
   `testing`, `terraform`, `data-engineering`). If a correction doesn't map
   to a specific domain, apply it to a `general` domain that affects all
   subsequent non-trivial tasks.

6. **FR-06: Relationship to cross-session calibration** — Session confidence
   and Adaptive Calibration are independent but additive:
   - If Adaptive Calibration already flags a domain as high-error (3+ patterns
     in Qdrant), session confidence starts at CAUTIOUS instead of NEUTRAL.
   - If session confidence degrades to DELIBERATE in a clean domain (0 Qdrant
     patterns), deliberation is still triggered — session evidence overrides
     cross-session absence.

7. **FR-07: Zero overhead on happy path** — When no corrections occur in a
   session, the tracker adds no output, no queries, and no skill loading.
   It is invisible until the first correction.

### Non-Functional

1. **NFR-01: Ephemeral** — The tracker is never persisted to Qdrant or files.
   It exists only in the agent's session context. At session end, the
   micro/meso extraction from spec 005 handles persistence of error patterns
   to Qdrant.

2. **NFR-02: No new files or skills** — The tracker logic lives entirely
   within `.claude/rules/memory.md`. No new skills, rules files, or
   templates.

3. **NFR-03: Backward compatible** — Sessions without corrections behave
   identically to the current system. The tracker is purely additive.

4. **NFR-04: Lightweight** — The tracker is a mental model for the agent,
   not a data structure. The agent tracks "how many corrections have I
   received in domain X this session?" and adjusts accordingly. No counters,
   no state files.

## Scope

### In Scope

- Session Confidence section in memory.md
- Three confidence levels (NEUTRAL, CAUTIOUS, DELIBERATE)
- Degradation triggers (user correction, reviewer rejection, backtracking)
- Domain-scoped tracking
- Integration with existing Adaptive Calibration
- Knowledge-map update

### Out of Scope

- Persisting session confidence to Qdrant (ephemeral by design)
- Confidence *improvement* within a session (only degrades, never recovers)
- New skills or rules files
- Changes to deliberation or self-consistency skills
- Automatic error pattern extraction (already covered by spec 005)
- UI or visual display of confidence levels

## Constraints

- memory.md should remain under 120 lines total after this addition
- The new section must integrate naturally with the existing Adaptive
  Calibration section (they are complementary, not competing)
- Domain tags must match existing Qdrant metadata convention

## Open Questions

- Should confidence ever recover within a session (e.g., 3 consecutive
  successes after 2 corrections)? Recommendation: no — keep it simple. The
  session is short enough that degradation should persist. Recovery happens
  naturally on the next session start.

## References

- `.claude/rules/memory.md` — existing Adaptive Calibration section (lines
  64–77)
- `.specify/specs/005-feedback-learning/spec.md` — micro/meso/macro
  extraction levels
- `.claude/skills/deliberation/SKILL.md` — skill loaded at DELIBERATE level
- `.claude/skills/self-consistency/SKILL.md` — skill loaded at DELIBERATE
  level
