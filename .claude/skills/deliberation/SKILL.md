---
name: deliberation
user-invocable: true
description: >
  Structured deliberation for high-stakes decisions. Load when facing
  irreversible choices, multi-file architectural changes, or when confidence
  is below 0.70. Use when: introducing new dependencies, changing public APIs,
  designing module structure, or choosing between competing approaches.
  Triggers: "deliberate", "think carefully", "evaluate options", "pre-mortem",
  "devil's advocate", "should we", "trade-offs", "weigh alternatives".
  Do NOT use for: simple refactors (python-expert), documentation changes
  (docs-expert), memory storage (memory-manager), candidate scoring
  (self-consistency), or one-file fixes.
tools:
  - Read
  - Write
  - Glob
  - Grep
metadata:
  author: bruno
  version: 2.0.0
  category: workflow
---

# Deliberation

Structured "System 2" slow-thinking workflow for high-stakes decisions.
Produces a decision record stored in `.claude/memory/deliberations/` for
cross-session continuity.

## Tool Selection

| Need | Tool |
|------|------|
| Read existing code/config | Read, Glob, Grep |
| Query past decisions | Grep + Read in `memory/decisions/` and `memory/deliberations/` |
| Store deliberation result | Write to `memory/deliberations/{date}-{slug}.md` |

## Core Principles

1. **The 7-step DELIBERATION process is the core workflow** — FRAME, GENERATE,
   ATTACK, COST CHECK, PREMORTEM, DECIDE, LOG. All 7 steps are mandatory.
2. **Deliberation is proportional to stakes** — never invoke this process for
   trivial, reversible, or low-cost decisions. Use Bezos Type 1/Type 2
   framing to classify: only Type 1 (irreversible) decisions warrant full deliberation.
3. **Devil's advocate must challenge the premise, not just the details** — the
   objection must ask "should we do this at all?", not just "could this break?".
   No sycophancy — the leading option must be genuinely challenged.
4. **Cost check is mandatory** — "what does building this actually cost?" must
   cover time, token/compute cost, implementation complexity, and ongoing
   maintenance burden. Skipping cost is the most common deliberation failure.
5. **Pre-mortem uses Klein's technique** — project 6 months forward and assume
   the decision failed. Identify the specific, concrete failure mode. Vague
   pre-mortems ("it might not work out") do not count.
6. **Every deliberation produces a decision record** — stored in
   `memory/deliberations/{date}-{slug}.md`. No undocumented decisions.
7. **Confidence scoring is explicit** — Confidence is a single scalar score
   (0.0–1.0) with a label: HIGH (≥0.70), MED (0.40–0.69), LOW (<0.40).
   Confidence below 0.60 after deliberation means reframe the question.
8. **Query past decisions before generating alternatives** — don't re-derive
   what has already been decided. Grep `memory/decisions/` and
   `memory/deliberations/` first; generate only if no match.
9. **Two alternatives minimum** — if only one approach comes to mind,
   the frame is too narrow. Consider "do nothing" as a valid option.

## Best Practices

### 1. The 7-Step Deliberation Process

```
1. FRAME      — State the decision in one sentence. Subject + verb + constraint.
                Bad: "caching". Good: "Should we add Redis caching to the
                memory query path to reduce retrieval latency?"

2. GENERATE   — List 2–3 viable approaches. Each must be genuinely viable —
                no strawmen. Include "do nothing" when appropriate.
                Optional: invoke /verify to generate and score candidates
                with rubric-based evaluation instead of manual listing.

3. ATTACK     — For each approach, write the devil's advocate objection.
                Rules: (a) challenge the premise, not just details;
                (b) no sycophancy — the leading option gets the hardest attack;
                (c) if you can't find a real objection, you haven't looked hard enough.

4. COST CHECK — For each approach: "What does building this actually cost?"
                Cover all four dimensions:
                  - Time: hours of implementation + integration
                  - Complexity: added abstractions, dependencies, failure modes
                  - Tokens/compute: if AI-assisted, what's the generation cost
                  - Maintenance: ongoing support burden, upgrade surface

5. PREMORTEM  — For the leading approach only (Klein's technique):
                "It is 6 months later. This decision failed. What specifically
                went wrong?" Name at least one concrete failure mode. If you
                can't name one, the approach is underspecified.

6. DECIDE     — State the chosen approach. Assign confidence:
                  [HIGH|MED|LOW] ([score])
                  Include a clear next action.

7. LOG        — Store as a decision record in memory/deliberations/.
                Use the deliberation record template.
                Include: all alternatives, all objections, rationale, confidence.
```

### 2. When to Deliberate

Deliberate when the decision is:
- **Irreversible** (schema change, public API surface, persistent storage format)
- **Broad** (3+ files affected, new module, dependency introduction)
- **Uncertain** (confidence < 0.70 before starting)
- **Outside primary expertise** (unfamiliar technology, novel pattern)

### 3. When NOT to Deliberate

Skip deliberation for:
- Documentation fixes, variable renames, log messages, test fixtures
- Single-file changes with low reversal cost
- Features behind a feature flag (reversible by definition)
- Decisions already logged in `memory/deliberations/` with HIGH confidence

### 4. Output Format

The deliberation record must be fully visible — all 7 steps shown in output.
Do not summarize the process; write each step with its content. This is the
reasoning trace that future sessions will retrieve.

### 5. Bezos Type 1 / Type 2 Framework

Before deliberating, classify the decision:
- **Type 1 (irreversible)**: public API, database schema, module naming, core abstractions → full deliberation
- **Type 2 (reversible)**: implementation detail, internal helper, config flag → skip deliberation

### 6. Time-Box

Deliberation must complete within 5 minutes. If analysis exceeds the
time-box, the frame is too broad — split into sub-decisions and deliberate
each.

### 7. Reframing Low Confidence

If consensus remains below 0.60 after completing all 7 steps, do not
force a decision. Instead, reframe the question at a higher level of
abstraction or escalate to the user for input. Forced low-confidence
decisions are worse than acknowledged uncertainty.

### 8. Pre-Decision Query Pattern

Before generating alternatives, Grep memory:
```
Grep memory/deliberations/ for "[topic]"
Grep memory/decisions/ for "[topic]"
```
If a HIGH-confidence match is found, skip deliberation and apply the
existing decision. Log a note that the prior decision was reused.

### 9. Decision Record Template

```yaml
---
type: deliberation
domain: [domain tag]
project: [project name]
confidence: [0.0–1.0]
priority: P1
created: [ISO date]
updated: [ISO date]
tags: [relevant, tags]
files_affected: [list or "TBD"]
---

Context: [situation that prompted the decision]
Decision: [chosen approach]
Alternatives: [rejected options with objections]
Rationale: [why the winner beats the alternatives]
Pre-mortem failure mode: [what could go wrong]
Confidence: [HIGH|MED|LOW] ([score])

**Why:** [core reasoning]
**How to apply:** [when to reference this deliberation]
```

### 10. Confidence Calibration

- **HIGH** (≥ 0.70): objections addressed, pre-mortem failure mode has a known mitigation.
- **MED** (0.40–0.69): objections partially addressed or pre-mortem reveals residual risk.
- **LOW** (< 0.40): return to GENERATE or escalate to the user.

## Anti-Patterns

1. **Over-deliberating trivial decisions** — analysis paralysis. Variable
   names, test helper signatures, and log messages do not need FRAME→LOG.
   Use Type 1/Type 2 classification before starting.
2. **Skipping the cost check** — the most common failure. Without explicit
   cost assessment, the "simpler" option often hides hidden maintenance debt.
3. **Sycophantic devil's advocate** — writing an objection that subtly
   reinforces the leading option ("the main risk is execution, but that's
   manageable"). The objection must be genuinely threatening.
4. **Challenging details instead of premises** — "this approach might be
   slow" is a detail. "We may not need this feature at all" is a premise.
   Devil's advocate must go to the premise first.
5. **Deliberating Type 2 decisions** — reversible decisions behind feature
   flags, internal helpers, or easily-changed config do not warrant the
   full 7-step process. Use quick judgment and move on.
6. **Strawman alternatives** — generating one obviously-worse option as the
   "alternative" to make the leading choice look inevitable. Alternatives
   must be genuine contenders that someone reasonable would choose.
7. **Skipping the pre-mortem** — the pre-mortem is the step that catches
   the failure mode everyone is motivated to ignore. It cannot be skipped
   for the winning option.
8. **Not logging the deliberation** — losing the reasoning is the same as
   never doing the deliberation. Future sessions will re-derive the same
   decision without the benefit of the rejected alternatives.
9. **Forcing consensus at LOW confidence** — picking the "least bad" option
   when confidence is below 0.60 produces decisions that look committed but
   are actually guesses. Reframe or escalate instead.
10. **Deliberating without querying past decisions first** — the decision may
    already exist in `memory/deliberations/` with full rationale. Always
    Grep before generating.

## Examples

### Scenario 1: "Should we add a caching layer to the memory system?"

User asks about adding Redis caching for memory query results.

Actions:
1. Grep `memory/deliberations/` and `memory/decisions/` for "caching memory" — no match.
2. FRAME: "Should we add a Redis caching layer to reduce retrieval latency?"
3. GENERATE: (A) Add Redis cache, (B) In-process LRU cache, (C) Do nothing.
4. ATTACK: (A) "Wrong tool — caches exact keys, not semantic similarity."
   (B) "Per-session only; cross-session is the entire point." (C) "Current
   latency is acceptable; premature optimization."
5. COST CHECK: (A) ~4h + Redis infra + cache invalidation. (B) ~2h + memory
   footprint. (C) 0h.
6. PREMORTEM (leading: do nothing): "6 months later: query latency became
   bottleneck as memory grew. Mitigation: monitor query times; revisit if P95 > 500ms."
7. DECIDE: Do nothing (C). HIGH (0.86).
8. LOG: Write to `memory/deliberations/2026-03-15-memory-caching.md`.

Result: NO caching — analysis eliminated both active options.

### Scenario 2: Prior decision exists — skip deliberation

Actions:
1. Grep `memory/deliberations/` for "vector database" — finds file with
   confidence 0.88 (HIGH).
2. Skip deliberation — report prior decision with stored rationale.

Result: Prior decision retrieved and applied. No redundant analysis.

### Scenario 3: "Restructuring the skill directory layout"

Actions:
1. Grep memory — no prior decision.
2. FRAME: "Should we reorganize `.claude/skills/` into category subdirectories?"
3-7. Full deliberation process.
8. DECIDE: Keep flat structure with migration plan at 30 skills. MED (0.74).
9. LOG: Write to `memory/deliberations/2026-03-15-skill-directory-layout.md`.

Result: Incremental approach chosen. Pre-mortem revealed migration risk.

## Troubleshooting

**Can't generate genuine alternatives**
Cause: The frame is too narrow or presupposes a solution.
Solution: Broaden the frame to the underlying goal. Add "do nothing" as an
explicit alternative.

**Devil's advocate finds a fatal flaw**
Cause: The ATTACK step exposes a critical defect.
Solution: This is the process working correctly. Eliminate the flawed option
and return to GENERATE.

**Deliberation is taking too long**
Cause: The decision frame is too broad.
Solution: Time-box at 5 minutes. Split into sub-decisions if needed.

**Confidence remains LOW after all 7 steps**
Cause: Insufficient information or genuine ambiguity.
Solution: Do not force a decision. Escalate to the user with a summary of
what was learned.

## Review Checklist

- [ ] All 7 steps completed — FRAME through LOG, none skipped
- [ ] At least 2 genuine alternatives generated (not strawmen)
- [ ] Devil's advocate challenged the premise, not just the implementation details
- [ ] Cost check covered all four dimensions: time, complexity, compute, maintenance
- [ ] Pre-mortem identifies at least one specific, concrete failure mode
- [ ] Confidence level is explicit (HIGH / MED / LOW) with numeric score
- [ ] Past decisions were queried in memory before generating alternatives
- [ ] Decision record written to `memory/deliberations/` with full frontmatter
- [ ] Deliberation was proportional to stakes (Type 1 decision, not a trivial fix)
- [ ] Decision is actionable — a clear next step or next action is identified
