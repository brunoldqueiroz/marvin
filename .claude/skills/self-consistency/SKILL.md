---
name: self-consistency
user-invocable: true
description: >
  Self-consistency workflow: generate 3 candidate solutions in parallel,
  score against a weighted rubric, select the winner with explicit confidence.
  Use when: choosing between competing implementations, evaluating architectural
  options, or whenever a single first-pass answer feels insufficiently validated.
  Triggers: "verify this", "compare approaches", "what are my options",
  "generate alternatives", "evaluate candidates", "/verify", "is this the
  best way", "self-consistency check".
  Do NOT use for: simple one-file fixes (python-expert), structured 7-step
  decisions (deliberation), memory storage (memory-manager), or formatting/
  documentation changes. For structured deliberation use the deliberation skill;
  for memory persistence use memory-manager.
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Agent
metadata:
  author: bruno
  version: 2.0.0
  category: orchestration
---

# Self-Consistency

Parallel candidate generation + rubric scoring workflow for high-stakes tasks.
Produces a scored comparison table, a winner with confidence, and an evaluation
record stored in `.claude/memory/evaluations/` for cross-session reuse.

## Tool Selection

| Need | Tool |
|------|------|
| Generate 3 candidates in parallel | Agent (3 parallel calls) |
| Query prior evaluations | Grep + Read in `memory/evaluations/` |
| Store evaluation record | Write to `memory/evaluations/{date}-{slug}.md` |
| Read existing code/context | Read, Glob, Grep |

## Core Principles

1. **N=3 is the sweet spot** — research shows 1→3 candidates yields substantial
   quality gain; 3→5 is marginal. Always generate exactly 3 unless resources are
   severely constrained.
2. **Stance-based diversity is mandatory** — each candidate must use a distinct
   generation stance (simplicity, performance, extensibility). Minor variations
   of the same approach do not count as diverse candidates.
3. **Parallel generation, simultaneous scoring** — spawn all 3 Agent calls in
   parallel (NFR-02). The scorer sees all 3 candidates at once to prevent
   anchoring bias from sequential evaluation.
4. **Default rubric weights**: correctness 0.35, simplicity 0.25,
   maintainability 0.25, performance 0.15. Override per domain; never drop
   correctness below 0.25.
5. **Confidence from score spread**: compute spread as
   `(winner - runner_up) / runner_up × 100`. HIGH when >20%, MED when 10–20%,
   LOW when <10%. Map to float: LOW → 0.40–0.55, MED → 0.65–0.80,
   HIGH → 0.85–1.00. LOW confidence → escalate to user.
6. **Query memory before generating** — Grep `memory/evaluations/` for similar
   tasks. If a HIGH-confidence prior evaluation exists, reuse the approach and
   skip candidate generation entirely.
7. **Every evaluation is logged** — Write all candidates, scores, winner, and
   rubric to `memory/evaluations/{date}-{slug}.md`. No undocumented evaluations.
8. **Activation heuristics**: trigger on 3+ file changes, complex functions
   (>30 lines, multiple branches), MED/LOW deliberation confidence, or explicit
   user request ("compare", "alternatives", "verify", "/verify").
9. **Skip heuristics**: single-file changes with clear requirements,
   documentation/config/formatting, HIGH-confidence prior evaluation in memory,
   user requests speed ("just do it", "quick fix").
10. **Transparency is non-negotiable** — show the full comparison table and
    rationale. Never hide the evaluation or only report the winner.

## Best Practices

1. **Stance prompts for diversity** — use these exact stances when delegating:
   - Candidate A: "optimize for simplicity and minimal moving parts"
   - Candidate B: "optimize for performance and efficiency"
   - Candidate C: "optimize for extensibility and future maintainability"

2. **Default rubric**:

   | Criterion | Weight | Description |
   |-----------|--------|-------------|
   | Correctness | 0.35 | Meets requirements, handles edge cases |
   | Simplicity | 0.25 | Minimal complexity, easy to understand |
   | Maintainability | 0.25 | Clear, testable, follows conventions |
   | Performance | 0.15 | Efficient for expected load |

3. **Domain rubric overrides** — apply when domain is identified:

   | Domain | Correctness | Domain-Specific | Simplicity | Maintainability |
   |--------|-------------|-----------------|------------|-----------------|
   | security | 0.30 | security: 0.30 | 0.20 | 0.20 |
   | performance | 0.25 | performance: 0.35 | 0.20 | 0.20 |
   | data-engineering | 0.30 | reliability: 0.25 | performance: 0.25 | 0.20 |

   Data-engineering uses 5 criteria; scoring table adds a Reliability column.

4. **Scoring table format** — score each criterion 1–5, compute weighted total:

   | Candidate | Correctness (0.35) | Simplicity (0.25) | Maintainability (0.25) | Performance (0.15) | Total |
   |-----------|-------------------|-------------------|------------------------|-------------------|-------|
   | A (simple) | 4 → 1.40 | 5 → 1.25 | 4 → 1.00 | 3 → 0.45 | **4.10** |
   | B (perf) | 4 → 1.40 | 3 → 0.75 | 3 → 0.75 | 5 → 0.75 | **3.65** |
   | C (ext.) | 5 → 1.75 | 2 → 0.50 | 5 → 1.25 | 3 → 0.45 | **3.95** |

5. **Close-call handling** — if top two totals are within 10% of each other,
   flag as "close call" and include the runner-up rationale in the output.

6. **Pre-task query pattern**:
   ```
   Grep memory/evaluations/ for "[task description]" or "[domain]"
   Read matching files for confidence and winner
   ```
   If result has confidence ≥ 0.85, skip generation and reuse.

7. **Evaluation record template** for file storage:
   ```yaml
   ---
   type: evaluation
   domain: [domain tag]
   project: [project name]
   confidence: [0.0–1.0]
   priority: P1
   created: [ISO date]
   updated: [ISO date]
   tags: [relevant, tags]
   files_affected: [list or "TBD"]
   ---

   Task: [one-sentence description]
   Winner: [candidate name + stance]
   Runners-up: [summaries + scores]
   Rubric: [domain rubric used + weights]
   Confidence: [HIGH|MED|LOW] ([spread %])

   **Why:** [why winner beats alternatives]
   **How to apply:** [when to reuse this evaluation]
   ```

8. **Integration with deliberation** — at the GENERATE step, optionally invoke
   self-consistency to produce and score alternatives. The deliberation skill
   then uses the scored candidates as its GENERATE output. This is additive;
   deliberation's 7-step process is unchanged.

9. **Integration with implementer** — for high-stakes code generation, wrap the
   implementer delegation: generate 3 implementations via parallel Agent calls,
   score with the rubric, then pass the winner to the implementer for final
   production-quality output.

10. **Output format** — always include: (1) comparison table, (2) winner name
    + confidence level, (3) concise rationale (2-3 sentences), (4) close-call
    note if applicable. Keep total output under 400 words.

## Anti-Patterns

1. **Applying to trivial tasks** — self-consistency triples cost. One-liner
   fixes, variable renames, and config tweaks do not warrant 3 candidates.
   Apply activation heuristics strictly.
2. **Non-diverse candidates** — generating minor variations of the same approach
   (e.g., three slightly different for-loops) defeats the purpose. Each
   candidate must embody a genuinely different design stance.
3. **Sequential scoring with anchoring** — scoring candidate B after seeing A's
   score biases the evaluation. Always score all candidates from a clean state,
   seeing all three simultaneously.
4. **Skipping the rubric** — declaring a winner by feel without numeric scoring
   is not self-consistency; it is opinion. Every evaluation must produce a
   scored table.
5. **Not logging evaluations** — future sessions will re-derive the same
   comparison without the benefit of prior scoring. Every evaluation must be
   stored in `memory/evaluations/`.
6. **Ignoring close calls** — when top two scores are within 10%, suppressing
   the runner-up hides meaningful uncertainty. Flag it explicitly.
7. **Forcing a decision at LOW confidence** — if the winner's margin is <10%,
   the candidates are too similar or the rubric is poorly calibrated. Escalate
   to the user; do not silently pick one.
8. **Generating sequentially instead of in parallel** — sequential Agent calls
   triple latency unnecessarily. All 3 generation calls must be dispatched in
   parallel.
9. **Using the default rubric for domain-specific tasks** — applying
   correctness 0.35 to security-critical code under-weights vulnerabilities.
   Always check domain rubric overrides before scoring.
10. **Skipping the pre-task memory query** — the evaluation may already exist
    at HIGH confidence. Always Grep `memory/evaluations/` before generating.

## Examples

### Scenario 1: Architectural decision — "How should we structure the new API module?"

User asks how to organize a new HTTP API module that other agents will call.

Actions:
1. Grep `memory/evaluations/` for "API module structure" — no prior match.
2. Identify domain: architecture. Apply default rubric.
3. Spawn 3 parallel Agent calls with stances: simplicity, performance, extensibility.
   - A: Flat functions in one module file.
   - B: Class-based client with connection pooling.
   - C: Abstract base + concrete implementations per provider.
4. Score all three simultaneously against rubric. A scores 4.10, C scores 3.95,
   B scores 3.65. Spread A vs C = 3.7% — close call.
5. Winner: A (simplicity stance). Confidence: LOW (spread <10%). Flag close call
   between A and C. Escalate to user.
6. Write evaluation to `memory/evaluations/2026-03-15-api-module-structure.md`.

Result: User makes an informed choice. Evaluation record prevents re-deriving
the same comparison in a future session.

### Scenario 2: Code generation — "Implement a retry mechanism for HTTP calls"

Actions:
1. Grep `memory/evaluations/` for "retry HTTP" — no high-confidence match.
2. Domain: python. Apply default rubric.
3. Spawn 3 parallel Agent calls. B (exponential backoff) scores 4.20 vs
   A (simple) 3.80 vs C (circuit breaker) 3.40. Spread = 10.5% — MED.
4. Write to `memory/evaluations/2026-03-15-http-retry.md` with confidence 0.72.

Result: Best implementation with full transparency. MED confidence surfaces trade-off.

### Scenario 3: Prior evaluation exists — skip generation

Actions:
1. Grep `memory/evaluations/` for "caching query results" — finds file with
   confidence 0.88 (HIGH). Winner: in-process LRU cache.
2. Skip candidate generation. Report prior evaluation with stored rationale.

Result: Redundant work avoided. Prior reasoning surfaced without regeneration.

## Troubleshooting

**Candidates are too similar despite different stances**
Cause: Task is too narrow — only one meaningful solution exists.
Solution: If genuine diversity cannot be forced, the task likely does not warrant
self-consistency. Apply skip heuristic and proceed with a single implementation.

**Scoring results in a tie**
Cause: Rubric weights poorly calibrated for this domain, or candidates are
genuinely equivalent.
Solution: Check domain rubric overrides. If tie persists, this is a valid
LOW-confidence result — escalate to the user.

**Memory directory empty**
Cause: First evaluation in the project.
Solution: Skip pre-task query. Proceed normally. Log will create the first file.

**Confidence is always LOW**
Cause: Rubric weights don't differentiate candidates, or stances don't
produce genuinely diverse solutions.
Solution: Review stance prompts. Consider domain rubric override. If LOW
persists, escalate with candidate summaries.

## Review Checklist

- [ ] Activated only for tasks meeting the heuristics (3+ files, >30 lines complex, MED/LOW prior confidence, or explicit user request)
- [ ] Skipped for single-file, docs/config, HIGH-confidence prior, or "just do it" requests
- [ ] Memory queried before generating — prior HIGH-confidence evaluation reused if found
- [ ] Exactly 3 candidates generated with genuinely distinct stances (simplicity, performance, extensibility)
- [ ] All 3 candidates generated in parallel via Agent calls
- [ ] Rubric domain override applied when task domain is identified
- [ ] All candidates scored simultaneously (not sequentially) against weighted rubric
- [ ] Comparison table shown in output with per-criterion scores and weighted totals
- [ ] Confidence level is explicit (HIGH/MED/LOW) derived from score spread
- [ ] Evaluation record written to `memory/evaluations/` with full frontmatter
