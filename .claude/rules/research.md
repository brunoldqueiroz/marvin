# Parallel Research Delegation

When a research query is **comparative** (X vs Y vs Z) or **multi-faceted**
(multiple independent sub-questions):

1. Decompose into N independent sub-questions (max 5).
2. Spawn N `researcher` agents **in parallel** — one per sub-question.
3. Each writes to `.artifacts/researcher-{n}.md`.
4. After all complete, synthesize artifacts into a single response.
5. Clean up `.artifacts/researcher-*.md` after synthesis.

MUST NOT parallelize when sub-questions are **dependent** (answer to Q1
informs Q2).

PREFER parallel research when N >= 2 independent sub-questions and the
query warrants the additional token cost (~4x per agent).
