# Spec — Cognitive Memory System

> Captures the intent (what + why) of building a persistent memory system that
> enables Marvin to learn from experience, accumulate judgment, and improve
> reasoning quality across sessions.

## Problem Statement

Marvin operates in a stateless loop: each session starts near-zero context.
The `MEMORY.md` file and Qdrant KB provide basic persistence, but they lack
structure for the three types of knowledge that compound over time:

1. **Decision memory** — Past architectural choices, their rationale, and
   outcomes are lost. Marvin re-derives decisions instead of building on them.

2. **Error memory** — When a user corrects Marvin, the correction fixes the
   immediate output but the *pattern* behind the error is not captured. The
   same class of mistake recurs across sessions.

3. **Deliberation quality** — Marvin defaults to the first reasonable approach
   instead of systematically evaluating alternatives. No structured "slow
   thinking" mechanism exists beyond chain-of-thought.

4. **Project awareness** — Marvin has no persistent model of project entities
   (modules, dependencies, invariants). Each session rebuilds this understanding
   from scratch by reading files.

These gaps mean Marvin's quality is *flat* across sessions — session 50 is not
meaningfully better than session 1 for the same project.

## Desired Outcome

After implementation:

- Marvin logs every significant decision (architectural, tool selection,
  approach) with context, alternatives considered, and rationale — retrievable
  by semantic similarity in future sessions.
- When a user corrects Marvin, the error pattern is extracted and stored.
  Before acting on similar tasks, Marvin retrieves relevant anti-patterns and
  adjusts behavior proactively.
- For non-trivial architectural decisions, Marvin can invoke a structured
  deliberation process (pre-mortem, devil's advocate) before committing.
- A lightweight project knowledge map persists across sessions, giving Marvin
  immediate awareness of modules, key files, dependencies, and invariants.
- Measurable improvement: fewer repeated errors, faster orientation in
  returning sessions, better architectural suggestions that reflect project
  history.

## Requirements

### Functional

#### Layer 1 — Decision Log (P0, implement first)

1. **F-01**: After each significant decision (architectural choice, approach
   selection, tool/library recommendation), store a structured record in Qdrant
   with: context, decision, alternatives considered, rationale, outcome (if
   known), and project identifier.

2. **F-02**: Before making a new decision, query Qdrant for semantically
   similar past decisions. Surface relevant history in the reasoning process.

3. **F-03**: Decision records must use a consistent schema that supports
   filtering by project, domain, and recency.

4. **F-04**: Provide a skill or prompt pattern that triggers decision logging
   naturally during Marvin's workflow — not as a separate manual step.

#### Layer 2 — Error Patterns (P0, implement alongside Layer 1)

5. **F-05**: When a user corrects Marvin's output, extract the *class* of
   error (not just the specific instance). Store as a reusable anti-pattern
   with: trigger conditions, what went wrong, correct approach, and domain tags.

6. **F-06**: Before acting on a task, query error patterns relevant to the
   task's domain and type. Inject retrieved anti-patterns into the reasoning
   context.

7. **F-07**: Error patterns should have a confidence/frequency score that
   increases when the same pattern is confirmed across multiple sessions.

#### Layer 3 — Structured Deliberation (P1)

8. **F-08**: Create a `deliberation` skill that can be invoked for non-trivial
   decisions. The skill should implement at minimum: (a) generate 2-3
   alternative approaches, (b) devil's advocate against each, (c) pre-mortem
   for the leading option, (d) final recommendation with confidence level.

9. **F-09**: The deliberation skill should be loadable by CLAUDE.md rules
   or manually via `/deliberation`. It integrates with the decision log —
   deliberation outputs are stored as rich decision records.

10. **F-10**: Deliberation should be proportional to stakes. Quick decisions
    (variable naming, simple refactors) should NOT trigger full deliberation.
    Provide heuristics for when to invoke it.

#### Layer 4 — Project Knowledge Map (P1)

11. **F-11**: Maintain a structured file (`.claude/memory/knowledge-map.md` or
    JSON) that captures: key modules and their responsibilities, critical
    dependencies, architectural invariants, and active conventions.

12. **F-12**: The knowledge map is updated incrementally — after significant
    code changes, new entries are added or existing ones updated. It is NOT
    regenerated from scratch each session.

13. **F-13**: On session start, the knowledge map is consulted to provide
    immediate project orientation without re-reading the entire codebase.

14. **F-14**: The knowledge map should be human-readable and editable — the
    user can correct or augment it directly.

### Non-Functional

1. **NFR-01**: Memory operations must not add perceptible latency to normal
   interactions. Qdrant queries should be async or batched where possible.

2. **NFR-02**: Total memory storage (Qdrant collections + local files) must
   be manageable — implement TTL or relevance decay for old, unused records.

3. **NFR-03**: Memory content must be project-scoped by default. Cross-project
   knowledge (e.g., "always use ruff for Python linting") is stored separately.

4. **NFR-04**: The system must degrade gracefully — if Qdrant is unavailable,
   Marvin falls back to local file memory and continues working.

5. **NFR-05**: All memory artifacts must be git-friendly (no binary blobs in
   the repo). Qdrant stores vectors; local files store human-readable context.

## Scope

### In Scope

- Qdrant collection schema for decisions and error patterns
- Decision logging skill/prompt integration
- Error pattern extraction and retrieval workflow
- Deliberation skill (`/deliberation`)
- Project knowledge map file format and update workflow
- Integration points with existing agents (researcher, implementer)
- Session orientation enhancement using knowledge map

### Out of Scope

- Automated decision outcome tracking (requires production monitoring)
- Graph database for knowledge map (use structured markdown/JSON instead)
- Automated embedding model selection (use Qdrant's default)
- Cross-project knowledge sharing (design for it, implement later)
- UI/dashboard for memory inspection (CLI-only)
- Automated deliberation triggering (manual or rule-based only for v1)

## Constraints

- MUST use Qdrant MCP tools already available (`qdrant-store`, `qdrant-find`)
- MUST NOT require new external dependencies beyond what's already configured
- MUST keep local memory files under version control (human-readable)
- MUST NOT modify existing agent AGENT.md files beyond adding memory queries
  to their workflow (structural changes are out of scope)
- PREFER convention over configuration — sensible defaults over settings
- PREFER incremental adoption — each layer works independently

## Open Questions

1. **Collection strategy**: Single Qdrant collection with metadata filtering
   vs. separate collections per memory type (decisions, errors, knowledge)?
   **Leaning**: Single collection with `type` metadata — simpler, and Qdrant
   handles filtering efficiently.

2. **Embedding granularity**: Store full decision records as single embeddings
   vs. embed the "context" field separately for better retrieval?
   **Leaning**: Embed a synthesized summary (context + decision in 2-3
   sentences) for retrieval; store full record as metadata payload.

3. **Knowledge map format**: Markdown vs. JSON? Markdown is human-friendly;
   JSON is machine-parseable.
   **Leaning**: Markdown with YAML frontmatter — human-editable, parseable
   enough for LLM consumption.

4. **Deliberation trigger threshold**: How to define "non-trivial" decisions
   that warrant full deliberation?
   **Leaning**: Rule-based heuristics: (a) touches 3+ files, (b) introduces
   new dependency, (c) changes public API, (d) user explicitly requests it.

## References

- [research.md](./research.md) — to be populated by researcher agent
- Spec 001 (skill architecture) — established patterns for skills and agents
- `.claude/agents/researcher/AGENT.md` — existing Qdrant integration pattern
- `.claude/rules/specs.md` — SDD workflow this spec follows
