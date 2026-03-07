# Cognitive Memory Rules

## Decision Logging Triggers

Log a decision record when:
- An architectural decision affects 2+ files (new patterns, module layout, dependency choices)
- A tool, library, or framework is chosen over alternatives
- A convention is established that future work should follow

Query past decisions before:
- Choosing an approach for any non-trivial change
- Introducing a new pattern or dependency to the project

## Error Pattern Triggers

Store an error pattern when:
- The user corrects output — extract the **class** of error, not the instance
- A task produces a wrong result that required backtracking

Query error patterns before:
- Acting on a task in a domain where past mistakes are likely (check by domain + project)

Extraction levels:
- **Micro**: per-correction — extract error class immediately after user corrects output
- **Meso**: per-task — summarize patterns observed during a multi-step task
- **Macro**: periodic — run `/reflect` to consolidate recurring patterns into strong signals

## Knowledge Map Triggers

Update `knowledge-map.md` after:
- Implementing features that add new modules, dependencies, or conventions
- Structural changes (renamed directories, new config files, new agents/skills)

Consult `knowledge-map.md` on:
- Session start for quick project orientation
- Before making architectural decisions to check existing conventions

## Self-Consistency Triggers

Consider self-consistency (`/verify`) when:
- Complex code generation or architectural decisions with MED/LOW confidence
- Choosing between 2+ viable approaches where trade-offs are unclear
- User explicitly requests comparison ("compare", "alternatives", "verify")

After self-consistency evaluation:
- Log the evaluation record to Qdrant with `type: evaluation`
- Include all candidates, scores, rubric used, winner, and confidence

## General Rules

- Use `qdrant-store` to write memories, `qdrant-find` to retrieve them.
- Collection name: `marvin-kb` (configured in Qdrant MCP server).
- Content field: synthesized 2-3 sentence summary (embedding quality depends on conciseness).
- Always include metadata: `type`, `project`, `domain`, `timestamp`, `confidence`
  (0.0–1.0), `session_id`, `files_affected`, `outcome`.
- Valid types: `decision`, `error-pattern`, `knowledge`, `deliberation`, `evaluation`.
- **Retrieve before storing** — avoid duplicate records; escalate confidence instead.
- **Graceful degradation**: if Qdrant is unavailable, continue without memory queries.
- MUST NOT block on memory operations for simple, single-file, or mechanical tasks.
- Only log decisions that affect 2+ files or introduce new patterns — avoid pollution.
- Store **why**, not just **what** — rationale is more valuable than the decision itself.
- Project-scope all queries by default: filter by `project` metadata.
