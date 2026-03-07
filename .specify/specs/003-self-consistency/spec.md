# Spec — Self-Consistency & Verification

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin generates a single solution and delivers it with uniform confidence,
regardless of problem difficulty. For non-trivial tasks, the first solution
is often not the best — subtle bugs, suboptimal patterns, and missed edge
cases survive because there is no systematic comparison against alternatives.

This affects both **architectural decisions** (where the deliberation skill
picks one approach without seeing competing implementations) and **code
generation** (where the implementer agent produces one solution without
evaluating alternatives).

Research on self-consistency (Wang et al. 2022) shows that generating N
candidate solutions and selecting via majority vote or scoring significantly
improves accuracy — especially on multi-step reasoning tasks. The gain from
1→3 candidates is substantial; 3→5 is marginal.

## Desired Outcome

After implementation, Marvin can:

1. Generate 3 candidate solutions for high-stakes tasks (decisions or code)
2. Evaluate each candidate against a domain-calibrated rubric with weighted
   criteria
3. Select the winner with an explicit confidence score reflecting the margin
   of victory
4. Log the evaluation (all candidates + scores) to Qdrant for cross-session
   learning
5. Skip self-consistency for trivial tasks (same Type 1/Type 2 heuristic
   from the deliberation skill)

The user experiences higher-quality output on hard problems, with transparency
into why a particular solution was chosen over alternatives.

## Requirements

### Functional

1. **FR-01: Candidate generation** — Generate N=3 independent candidate
   solutions for a given task. Candidates must be genuinely diverse (not
   minor variations). Each candidate is generated with a distinct "stance"
   prompt to force diversity (e.g., "optimize for simplicity", "optimize for
   performance", "optimize for extensibility").
2. **FR-02: Rubric definition** — Define scoring rubrics with 4-6 weighted
   criteria. Provide a default rubric (correctness, simplicity,
   maintainability, performance) and allow domain-specific overrides
   (e.g., security weight for auth code, latency weight for hot paths).
3. **FR-03: Rubric scoring** — Score each candidate against the rubric on
   a 1-5 scale per criterion. Compute weighted total. The scorer must see
   all candidates simultaneously to enable relative comparison (not
   sequential evaluation, which suffers from anchoring bias).
4. **FR-04: Winner selection** — Select the highest-scoring candidate. If
   the top two are within 10% of each other, flag as "close call" and
   include the runner-up rationale in the output.
5. **FR-05: Confidence scoring** — Derive confidence from the score
   distribution: HIGH when winner leads by >20%, MED when 10-20%, LOW when
   <10%. LOW confidence triggers user escalation.
6. **FR-06: Activation heuristics** — Define when self-consistency activates:
   - Architectural decisions affecting 3+ files
   - Code generation for complex functions (>30 lines, multiple branches)
   - When the deliberation skill's confidence is MED or lower
   - When the user explicitly requests comparison ("compare approaches",
     "what are my options", "generate alternatives")
7. **FR-07: Skip heuristics** — Define when to skip:
   - Single-file changes with clear requirements
   - Documentation, config, and formatting changes
   - Tasks where a HIGH-confidence prior decision exists in Qdrant
   - When the user requests speed over quality ("just do it", "quick fix")
8. **FR-08: Result logging** — Store the evaluation record in Qdrant
   (`marvin-kb`) with type `evaluation`, including: all candidates (summary),
   rubric used, scores, winner, confidence, domain, project.
9. **FR-09: Pre-task query** — Before generating candidates, query Qdrant
   for prior evaluations on similar tasks. If a HIGH-confidence evaluation
   exists, reuse the approach instead of re-generating.
10. **FR-10: Integration with deliberation** — When the deliberation skill
    reaches the GENERATE step, optionally invoke self-consistency to produce
    and score the alternatives instead of manual listing.
11. **FR-11: Integration with implementer** — When delegating code generation
    to the implementer agent on high-stakes tasks, the self-consistency
    process wraps the delegation: generate 3 implementations, score, select.
12. **FR-12: Transparency** — The full evaluation (candidates, scores,
    rationale) must be visible to the user, not hidden. Show a comparison
    table in the output.

### Non-Functional

1. **NFR-01: Token cost** — Self-consistency triples generation cost.
   Activation heuristics must be strict enough that it only triggers on
   tasks where the quality gain justifies the cost (~15% of tasks).
2. **NFR-02: Latency** — The 3 candidates should be generated in parallel
   (via parallel Agent calls) to minimize wall-clock time. Scoring is
   sequential (needs all candidates).
3. **NFR-03: Graceful degradation** — If Qdrant is unavailable, skip
   pre-task query and result logging. Self-consistency still works without
   memory.
4. **NFR-04: No skill circular dependencies** — The self-consistency skill
   must not require loading the deliberation skill, and vice versa.
   Integration is optional and additive.
5. **NFR-05: Rubric extensibility** — Domain rubrics should be easy to add
   without modifying the core skill. Use a rubric registry pattern
   (section in the skill body, not external files).

## Scope

### In Scope

- Self-consistency skill with candidate generation, rubric scoring, and
  winner selection
- Default rubric + domain-specific rubric overrides (security, performance,
  data engineering)
- Activation/skip heuristics
- Qdrant integration for logging evaluations and querying prior results
- Integration hooks with deliberation and implementer workflows
- Confidence scoring derived from score distribution
- Rules file updates for when to trigger self-consistency

### Out of Scope

- Pairwise comparison or tournament-style evaluation (future optimization)
- Automated rubric learning from user feedback (future — requires more data)
- Multi-model evaluation (using different LLMs as judges)
- UI/dashboard for browsing past evaluations
- Changes to the deliberation skill's 7-step process (integration is additive)
- Recursive self-consistency (evaluating the evaluator)

## Constraints

- Must follow skill authoring rules (`.claude/rules/skills.md`): 7 mandatory
  sections, <500 lines body, description <1024 chars
- Must use Qdrant collection `marvin-kb` with metadata schema from
  `.claude/rules/memory.md`
- Candidates must be generated in parallel (Agent tool) to keep latency
  acceptable
- Rubric scoring must see all candidates simultaneously (no sequential
  anchoring)
- Must not break existing deliberation or memory-manager skills
- Skill count will go to 19 — still under the 30-skill flat selection
  threshold (per `scaling.md`)

## Open Questions

- Should the self-consistency skill be user-invocable (e.g., `/verify`) or
  only triggered automatically by heuristics? Recommendation: both — user
  can invoke explicitly, and rules trigger it automatically.
- What is the right rubric weight distribution for the default rubric?
  Recommendation: correctness 0.35, simplicity 0.25, maintainability 0.25,
  performance 0.15. Calibrate after real usage.

## References

- `.specify/specs/002-cognitive-memory/initial-analysis.md` — section 4
  (Verification and Self-Criticism)
- Wang et al. 2022 — "Self-Consistency Improves Chain of Thought Reasoning
  in Language Models" (arXiv:2203.11171)
- Zheng et al. 2023 — "Judging LLM-as-a-Judge" (arXiv:2306.05685) — rubric
  scoring patterns and position bias mitigation
- `.claude/skills/deliberation/SKILL.md` — integration point at GENERATE step
- `.claude/rules/memory.md` — Qdrant metadata schema for evaluation records
