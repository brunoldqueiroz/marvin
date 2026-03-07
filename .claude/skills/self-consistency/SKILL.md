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
  - Glob
  - Grep
  - Agent
  - mcp__qdrant__qdrant-store
  - mcp__qdrant__qdrant-find
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# Self-Consistency

Parallel candidate generation + rubric scoring workflow for high-stakes tasks.
Produces a scored comparison table, a winner with confidence, and an evaluation
record stored in Qdrant for cross-session reuse.

## Tool Selection

| Need | Tool |
|------|------|
| Generate 3 candidates in parallel | Agent (3 parallel calls) |
| Query prior evaluations | mcp__qdrant__qdrant-find |
| Store evaluation record | mcp__qdrant__qdrant-store |
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
   LOW when <10%. Map to float for Qdrant: LOW → 0.40–0.55, MED → 0.65–0.80,
   HIGH → 0.85–1.00. LOW confidence → escalate to user.
6. **Query Qdrant before generating** — if a HIGH-confidence prior evaluation
   exists for a sufficiently similar task, reuse the approach and skip candidate
   generation entirely.
7. **Every evaluation is logged** — store all candidates, scores, winner, and
   rubric in `marvin-kb` with `type: evaluation`. No undocumented evaluations.
8. **Activation heuristics**: trigger on 3+ file changes, complex functions
   (>30 lines, multiple branches), MED/LOW deliberation confidence, or explicit
   user request ("compare", "alternatives", "verify", "/verify").
9. **Skip heuristics**: single-file changes with clear requirements,
   documentation/config/formatting, HIGH-confidence prior evaluation in Qdrant,
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

6. **Pre-task Qdrant query pattern**:
   ```
   qdrant-find: "[task description] [domain] [project]"
   filter: type=evaluation, project=[current]
   ```
   If result has confidence ≥ 0.85, skip generation and reuse.

7. **Evaluation record template** for Qdrant storage:
   ```
   Task: [one-sentence description]
   Winner: [candidate name + stance]
   Runners-up: [summaries + scores]
   Rubric: [domain rubric used + weights]
   Confidence: [HIGH|MED|LOW] ([spread %])
   Rationale: [why winner beats alternatives]
   Domain: [domain tag]
   Project: [project name]
   Files Affected: [list or "TBD"]
   ```
   Metadata: `type=evaluation, confidence=[0.0–1.0], domain, project, timestamp, session_id`

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
   stored in Qdrant.
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
10. **Skipping the Qdrant pre-task query** — the evaluation may already exist
    at HIGH confidence. Always query before generating to avoid redundant work.

## Examples

### Scenario 1: Architectural decision — "How should we structure the new API module?"

User asks how to organize a new HTTP API module that other agents will call.

Actions:
1. Query Qdrant: "API module structure architecture marvin" — no prior match.
2. Identify domain: architecture. Apply default rubric.
3. Spawn 3 parallel Agent calls with stances: simplicity, performance, extensibility.
   - A: Flat functions in one module file.
   - B: Class-based client with connection pooling.
   - C: Abstract base + concrete implementations per provider.
4. Score all three simultaneously against rubric. A scores 4.10, C scores 3.95,
   B scores 3.65. Spread A vs C = 3.7% — close call.
5. Winner: A (simplicity stance). Confidence: LOW (spread <10%). Flag close call
   between A and C. Escalate to user: "A and C are nearly equivalent — do you
   prioritize simplicity now or extensibility for future providers?"
6. Log evaluation to Qdrant with type=evaluation, confidence=0.45.

Result: User makes an informed choice. Evaluation record prevents re-deriving
the same comparison in a future session.

### Scenario 2: Code generation — "Implement a retry mechanism for HTTP calls"

User requests a retry utility for unreliable external HTTP endpoints.

Actions:
1. Query Qdrant: "retry HTTP implementation python marvin" — no high-confidence match.
2. Domain: python. Apply default rubric.
3. Spawn 3 parallel Agent calls:
   - A (simple): fixed delay, max N retries, `time.sleep`.
   - B (perf): exponential backoff with jitter, no blocking.
   - C (ext): circuit breaker pattern with state machine.
4. Score simultaneously. B scores 4.20, A scores 3.80, C scores 3.40.
   Spread B vs A = 10.5% — MED confidence. B wins; flag A as runner-up.
5. Output: comparison table, winner B (exponential backoff), confidence MED,
   note "A (simple) is a viable alternative if backoff complexity is undesired."
6. Log to Qdrant with confidence=0.72.

Result: User gets the best implementation with full transparency. MED confidence
surfaces the trade-off without blocking delivery.

### Scenario 3: Prior evaluation exists — skip generation

User asks how to implement caching for Qdrant query results.

Actions:
1. Query Qdrant: "caching Qdrant query results marvin" — finds evaluation record
   with confidence=0.88 (HIGH). Winner: in-process LRU cache. Redis rejected due
   to operational overhead.
2. Skip candidate generation. Report: "A prior HIGH-confidence evaluation exists
   for this task. Winner: in-process LRU cache. Rationale: [stored rationale]."
3. No new evaluation logged (no new candidates generated).

Result: Redundant work avoided. Prior reasoning (including rejected Redis option)
surfaced without regeneration.

## Troubleshooting

**Candidates are too similar despite different stances**
Cause: The task is too narrowly specified — only one meaningful solution exists,
or the problem is simpler than the activation threshold.
Solution: If genuine diversity cannot be forced, the task likely does not warrant
self-consistency. Apply skip heuristic and proceed with a single implementation.

**Scoring results in a tie or near-tie across all candidates**
Cause: Rubric weights are poorly calibrated for this domain, or candidates are
genuinely equivalent.
Solution: Check domain rubric overrides. If the tie persists, this is a valid
LOW-confidence result — escalate to the user and present both options with their
distinct trade-offs.

**Qdrant unavailable**
Cause: MCP server not running or connection refused.
Solution: Skip pre-task query and result logging. Self-consistency proceeds
without memory (NFR-03). Log a warning in the response. Do not block generation.

**Confidence is always LOW across all evaluations**
Cause: Either the rubric weights do not differentiate candidates well, or the
stances are not producing genuinely diverse solutions.
Solution: Review stance prompts to ensure they pull in meaningfully different
directions. Consider whether the default rubric needs a domain override. If LOW
persists after adjustment, escalate the task to the user with candidate summaries.

## Review Checklist

- [ ] Activated only for tasks meeting the heuristics (3+ files, >30 lines complex, MED/LOW prior confidence, or explicit user request)
- [ ] Skipped for single-file, docs/config, HIGH-confidence prior, or "just do it" requests
- [ ] Qdrant queried before generating — prior HIGH-confidence evaluation reused if found
- [ ] Exactly 3 candidates generated with genuinely distinct stances (simplicity, performance, extensibility)
- [ ] All 3 candidates generated in parallel via Agent calls
- [ ] Rubric domain override applied when task domain is identified
- [ ] All candidates scored simultaneously (not sequentially) against weighted rubric
- [ ] Comparison table shown in output with per-criterion scores and weighted totals
- [ ] Confidence level is explicit (HIGH/MED/LOW) derived from score spread
- [ ] Evaluation record logged to Qdrant (marvin-kb, type=evaluation) with full metadata
