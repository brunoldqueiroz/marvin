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
  (docs-expert), memory storage (memory-manager), or one-file fixes.
tools:
  - Read
  - Glob
  - Grep
  - mcp__qdrant__qdrant-store
  - mcp__qdrant__qdrant-find
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# Deliberation

Structured "System 2" slow-thinking workflow for high-stakes decisions.
Produces a decision record stored in Qdrant for cross-session continuity.

## Tool Selection

| Need | Tool |
|------|------|
| Read existing code/config | Read, Glob, Grep |
| Query past decisions | mcp__qdrant__qdrant-find |
| Store deliberation result | mcp__qdrant__qdrant-store |

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
6. **Every deliberation produces a decision record** — stored in Qdrant via
   the memory-manager pattern with `type: deliberation`. No undocumented decisions.
7. **Confidence scoring is explicit** — HIGH (>0.85), MED (0.60–0.85),
   LOW (<0.60). Confidence below 0.60 after deliberation means reframe the question.
8. **Query past decisions before generating alternatives** — don't re-derive
   what has already been decided. Retrieve first; generate only if no match.
9. **Two alternatives minimum** — if only one approach comes to mind,
   the frame is too narrow. Consider "do nothing" as a valid option.

## Best Practices

### 1. The 7-Step Deliberation Process

```
1. FRAME      — State the decision in one sentence. Subject + verb + constraint.
                Bad: "caching". Good: "Should we add Redis caching to the
                memory query path to reduce Qdrant round-trips?"

2. GENERATE   — List 2–3 viable approaches. Each must be genuinely viable —
                no strawmen. Include "do nothing" when appropriate.

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

6. DECIDE     — State the chosen approach. Explicitly assign confidence:
                  HIGH (>0.85) — clear winner, low uncertainty
                  MED  (0.60–0.85) — reasonable choice, residual uncertainty
                  LOW  (<0.60) — insufficient information; escalate to user
                Include a clear next action.

7. LOG        — Store as a decision record in Qdrant (type: deliberation).
                Use the memory-manager decision record template.
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
- Decisions already logged in Qdrant with HIGH confidence

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

Before generating alternatives, query Qdrant:
```
qdrant-find: "[topic] [domain] [project]"
filter: type=deliberation OR type=decision, project=[current project]
```
If a HIGH-confidence match is found, skip deliberation and apply the
existing decision. Log a note that the prior decision was reused.

### 9. Decision Record Template

```
Context: [situation that prompted the decision]
Decision: [chosen approach]
Alternatives: [rejected options with objections]
Rationale: [why the winner beats the alternatives]
Pre-mortem failure mode: [what could go wrong]
Confidence: [HIGH|MED|LOW] ([score])
Domain: [domain tag]
Project: [project name]
Files Affected: [list or "TBD"]
```

### 10. Confidence Calibration

- Assign HIGH only when devil's advocate objections are all addressed and
  pre-mortem failure mode has a known mitigation.
- Assign MED when objections are partially addressed or pre-mortem reveals
  residual risk without a clear mitigation.
- Assign LOW when the pre-mortem reveals a fatal flaw in the leading option
  that has no known mitigation — return to GENERATE.

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
    already exist in Qdrant with a full rationale. Always query before generating.

## Examples

### Scenario 1: "Should we add a caching layer to the memory system?"

User asks about adding Redis caching for Qdrant query results.

Actions:
1. Query Qdrant: "caching memory Qdrant marvin" — no prior decision found.
2. FRAME: "Should we add a Redis caching layer between the agent and Qdrant to
   reduce retrieval latency for repeated queries?"
3. GENERATE: (A) Add Redis cache, (B) In-process LRU cache, (C) Do nothing.
4. ATTACK: (A) "Qdrant already uses approximate nearest-neighbor — adding Redis
   caches exact key lookups, not semantic similarity. Wrong tool for the job."
   (B) "In-process cache is per-session only; cross-session memory is the entire
   point of using Qdrant." (C) "Current latency is acceptable; this is premature
   optimization."
5. COST CHECK: (A) ~4h implementation + Redis infra + cache invalidation logic +
   ongoing ops. (B) ~2h + memory footprint per session. (C) 0h.
6. PREMORTEM (leading: do nothing): "6 months later: deliberation latency
   became a bottleneck as memory grew beyond 10K records. We needed caching but
   had no design. Mitigation: monitor Qdrant query times; revisit if P95 > 500ms."
7. DECIDE: Do nothing (C). Confidence HIGH (0.88). Next: add Qdrant latency
   monitoring to surface the threshold for reconsideration.
8. LOG: Store decision record with type=deliberation, confidence=0.88.

Result: NO decision reached through structured analysis. Cost check and
devil's advocate eliminated both active caching options.

### Scenario 2: "Choosing between Qdrant and ChromaDB for vector storage"

User asks which vector database to use for persistent memory.

Actions:
1. Query Qdrant: "vector database storage decision marvin" — finds existing
   HIGH-confidence decision: "Qdrant chosen over ChromaDB for marvin-kb
   due to MCP integration and metadata filtering support."
2. Skip deliberation — prior decision found with HIGH confidence.
3. Report: "This was already decided. Qdrant was selected over ChromaDB for
   the MCP integration and structured metadata filtering. No re-deliberation needed."

Result: Deliberation skipped. Prior decision retrieved and applied. Saves
redundant analysis; prior rationale (rejected alternatives) still accessible.

### Scenario 3: "Restructuring the skill directory layout"

User proposes reorganizing `.claude/skills/` into subdirectories by category.

Actions:
1. Query Qdrant: "skill directory structure marvin" — no prior decision.
2. FRAME: "Should we reorganize `.claude/skills/` into category subdirectories
   (advisory/, workflow/, etc.) to improve navigation as the library grows?"
3. GENERATE: (A) Flat structure (status quo), (B) Category subdirectories,
   (C) Two-stage routing with a registry file (no filesystem change).
4. ATTACK: (A) "Flat structure will become unnavigable past 30 skills —
   already at 17, growing quickly." (B) "Subdirectory change breaks all
   existing skill path references in agents, hooks, and CLAUDE.md. Migration
   cost is non-trivial." (C) "Registry adds indirection without solving
   discoverability for humans browsing the filesystem."
5. COST CHECK: (A) 0h. (B) ~3h migration + update all references across 10+
   files + risk of broken routing during transition. (C) ~2h + ongoing registry
   maintenance burden.
6. PREMORTEM (leading: B): "6 months later: a hook still referenced the old
   flat path and silently failed to load a skill. The bug was invisible until
   a skill wasn't applied in production. Mitigation: add a path validation
   step to CI before merging the migration."
7. DECIDE: Keep flat structure (A) with a migration plan triggered at 30 skills
   (per scaling.md thresholds). Confidence MED (0.75). Pre-mortem revealed
   migration risk outweighs benefit at current scale.
8. LOG: Store with type=deliberation, confidence=0.75, domain=architecture.

Result: Incremental approach chosen. Pre-mortem revealed migration risk;
cost check confirmed low urgency at current scale.

## Troubleshooting

**Can't generate genuine alternatives**
Cause: The frame is too narrow or presupposes a solution.
Solution: Broaden the frame to the underlying goal, not the proposed
implementation. Add "do nothing" as an explicit alternative. Ask: "what
problem does this solve, and are there other ways to solve it?"

**Devil's advocate finds a fatal flaw in the leading option**
Cause: The pre-mortem or ATTACK step exposes a critical defect.
Solution: This is the process working correctly. Eliminate the flawed option
and return to GENERATE. The correct response is to find a better option, not
to soften the objection.

**Deliberation is taking too long**
Cause: The decision frame is too broad — it contains multiple sub-decisions.
Solution: Time-box at 5 minutes. If analysis is still incomplete, the frame
needs to be split. Identify the two smallest independent sub-decisions and
deliberate each separately.

**Confidence remains LOW after completing all 7 steps**
Cause: Insufficient information, genuine ambiguity, or the question is
outside current expertise.
Solution: Do not force a decision. Escalate to the user with a summary of
what was learned from the deliberation. Include the best available option
and its known risks so the user can make an informed call.

## Review Checklist

- [ ] All 7 steps completed — FRAME through LOG, none skipped
- [ ] At least 2 genuine alternatives generated (not strawmen)
- [ ] Devil's advocate challenged the premise, not just the implementation details
- [ ] Cost check covered all four dimensions: time, complexity, compute, maintenance
- [ ] Pre-mortem identifies at least one specific, concrete failure mode
- [ ] Confidence level is explicit (HIGH / MED / LOW) with numeric score
- [ ] Past decisions were queried in Qdrant before generating alternatives
- [ ] Decision record stored in Qdrant with type=deliberation and full metadata
- [ ] Deliberation was proportional to stakes (Type 1 decision, not a trivial fix)
- [ ] Decision is actionable — a clear next step or next action is identified
