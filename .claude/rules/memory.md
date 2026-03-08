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
- Include `task_type` (implementation | architecture | testing | review |
  planning), `correction_count` (starts at 1), and `last_corrected` (ISO
  timestamp) in error-pattern metadata
- On re-occurrence of an existing pattern: increment `correction_count` and
  update `last_corrected` instead of creating a duplicate

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

## Reflection Triggers

Run `/reflect` when:
- User explicitly invokes `/reflect`
- After completing a spec implementation with 5+ tasks (suggest to user)
- When 10+ memory records have been stored in the current session (suggest to user)

These triggers are **advisory** — suggest to the user, do not force. Reflection
audits stored records, prunes stale patterns, and consolidates weak signals.

## Adaptive Calibration

Before acting on a non-trivial task, query error patterns for the relevant
domain (`type: error-pattern`, filtered by `domain` and `project`):

- **3+ high-confidence (>0.65) error patterns**: high-error domain. Bias toward
  loading `deliberation` and/or `self-consistency` skills. Slow down.
- **1-2 error patterns**: moderate awareness. Query patterns before acting but
  no forced skill loading.
- **0 error patterns**: clean domain. Allow fast execution without forced
  deliberation.

Calibration is advisory — override when context warrants it. Update calibration
data by running `/reflect` periodically.

## Session Confidence

Ephemeral per-domain tracker. Resets on session start; never persisted to Qdrant.

**Levels** (per domain: python, architecture, testing, terraform, data-engineering):
- **NEUTRAL** (default): no corrections this session. Execute normally, zero overhead.
- **CAUTIOUS** (1 correction): query Qdrant for error patterns in this domain before the next task. Note elevated caution in output.
- **DELIBERATE** (2+ corrections): load `deliberation` or `self-consistency` skill before acting. Tell the user: "Session confidence in {domain} is low — deliberating before proceeding."

**Degrades one level when**:
- User corrects output in that domain
- Reviewer agent requests changes to work in that domain
- A task produces output requiring backtracking

**Domain scoping**: corrections without a clear domain map to `general`, which affects all non-trivial tasks.

**Cross-session integration**: if Adaptive Calibration already flags a domain as high-error (3+ Qdrant patterns), session confidence starts at CAUTIOUS instead of NEUTRAL. Conversely, if session confidence degrades to DELIBERATE in a domain with 0 Qdrant patterns, deliberation is still triggered — session evidence takes precedence.

**Zero overhead**: when no corrections occur, the tracker is silent — no queries, no skill loading, no output.

**Example**: User corrects a Python typing error → `python` degrades to CAUTIOUS. Next Python task: query Qdrant for python error patterns, note elevated caution. User corrects another Python output → `python` degrades to DELIBERATE. Next Python task: load deliberation before acting. Meanwhile, a Terraform task remains at NEUTRAL throughout.

## General Rules

- Use `qdrant-store` to write memories, `qdrant-find` to retrieve them.
- Collection name: `marvin-kb` (configured in Qdrant MCP server).
- Content field: synthesized 2-3 sentence summary (embedding quality depends on conciseness).
- Always include metadata: `type`, `project`, `domain`, `timestamp`, `confidence`
  (0.0–1.0), `session_id`, `files_affected`, `outcome`.
- Deliberation records may include optional `confidence_dimensions: {feasibility: 0.0-1.0, cost: 0.0-1.0, risk: 0.0-1.0}`. Existing records without this field remain valid.
- Valid types: `decision`, `error-pattern`, `knowledge`, `deliberation`, `evaluation`.
- **Retrieve before storing** — avoid duplicate records; escalate confidence instead.
- **Graceful degradation**: if Qdrant is unavailable, continue without memory queries.
- MUST NOT block on memory operations for simple, single-file, or mechanical tasks.
- Only log decisions that affect 2+ files or introduce new patterns — avoid pollution.
- Store **why**, not just **what** — rationale is more valuable than the decision itself.
- Project-scope all queries by default: filter by `project` metadata.
