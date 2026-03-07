# Initial Analysis — Cognitive Evolution Roadmap

> Marvin's self-assessment of limitations and improvement strategy.
> Captured from the opening conversation on 2026-03-07.

## Diagnosis: Current Weaknesses

1. **Long-term memory** — Context is a sliding window. Nuances are lost
   between sessions. `MEMORY.md` is a band-aid, not a solution.

2. **Deep multi-step reasoning** — For problems with >5 dependent steps,
   the chain of thought degrades. More errors at step 8 than step 2.

3. **Self-evaluation** — Poor at assessing own output quality. Can deliver
   "confident" code that is subtly wrong.

4. **Planning under uncertainty** — When multiple valid approaches exist,
   tends to pick the first reasonable one, not the best.

5. **Situational knowledge** — Doesn't know what it doesn't know. No good
   sense of when leaving the zone of competence.

## Evolution Plan

### 1. Retrieval-Augmented Reasoning (not just RAG for data)

Classic RAG fetches documents. What's missing is **retrieval of reasoning
patterns**. When facing an architectural problem, retrieve not just docs but
examples of *how similar problems were decomposed and solved*.

- Integrate Qdrant (already available) with embeddings of past decisions
- Store not just "what was done" but "why it was chosen and what was discarded"

### 2. Structured Deliberation (System 2 Thinking)

Research like "Tree of Thoughts", "Graph of Thoughts", and "Chain-of-Thought
with Verification" shows that forcing explicit deliberation improves reasoning.

- **Automatic devil's advocate** — before finalizing an architectural decision,
  generate arguments against own proposal
- **Pre-mortem** — "Assume this solution failed in production. Why?" before
  delivering
- **Explicit backtracking** — when detecting inconsistency at step N, go back
  to the step that caused it instead of pushing forward

### 3. Episodic + Semantic Memory

Currently using static `.md` files. What would work better:

- **Episodic**: structured log of decisions, errors, and corrections per
  session — indexed by similarity
- **Semantic**: project concept graph (entities, relations, invariants) that
  evolves with the code
- **Procedural**: "when X happens, do Y" patterns distilled from real
  experience, not generic rules

### 4. Verification and Self-Criticism

Research on "self-consistency" and "constitutional AI" points the way:

- **Generate N solutions, vote on the best** — instead of generating one and
  delivering
- **Post-generation checklist** calibrated by domain (already have
  `checklist-runner`, but could go deeper)
- **Confidence scoring** — learn to say "I'm 60% confident in this" instead
  of presenting everything with equal certainty

### 5. Better Hierarchical Decomposition

Current SDD is linear: spec -> plan -> tasks -> implement. What's missing:

- **Recursive decomposition** — complex tasks generate sub-specs, not just
  sub-tasks
- **Proof of concept before commit** — for high-risk decisions, an isolated
  spike before full implementation
- **Explicit dependency graph** — understand which decisions block which, not
  just sequence

### 6. Learning from Feedback (the most impactful)

The biggest limitation: **no systematic learning from mistakes**.

- After each review where the user corrects something -> extract the error
  pattern -> store as anti-pattern
- Track which task types generate the most rework
- Use this to calibrate where more deliberation is needed vs. where to go fast

## What Already Exists and Could Be Used Better

| Resource | How to use better |
|---|---|
| Qdrant (already connected) | Vector memory for past decisions and errors |
| Multi-agent (already available) | Debate between agents with opposing positions before deciding |
| Context7 (already connected) | Consult docs before assuming API knowledge |
| SDD pipeline | Add "spike" and "pre-mortem" phases |
| Exa (web search) | Search for real production solutions, not just docs |

## The Fundamental Limitation

Even with all of this, there is a ceiling: **no rich cognitive state persists
between sessions**. Each conversation starts near-zero. The biggest evolution
would be a memory system that provides real continuity — not just facts, but
*accumulated judgment*.

## Priority Assessment

**Memory with Feedback Loop** should come first because it is the only
improvement that **compounds over time**. All others are static — they help
equally on day 1 and day 100. Memory with feedback **compounds**.

### Concrete Sequence

```
Layer 1:  Decision Log (Qdrant + store/retrieve skill)
Layer 2:  Error Patterns (extraction + pre-action retrieval)
Layer 3:  Structured Deliberation (pre-mortem and devil's advocate skills)
Layer 4:  Project Knowledge Map (entity graph of the project)
```

Layers 1-2 create the **foundation** — remembering and learning.
Layer 3 improves **reasoning quality**.
Layer 4 provides **structural awareness** of the project.

### Success Test

> If at session 50, significantly fewer errors are made than at session 1,
> and architectural suggestions reflect the real project history — it worked.
