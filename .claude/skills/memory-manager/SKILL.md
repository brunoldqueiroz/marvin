---
name: memory-manager
user-invocable: false
description: >
  Cognitive memory manager for persistent cross-session learning. Load
  proactively when making architectural decisions, after user corrections,
  or when reflecting on past work. Use when: storing decisions, extracting
  error patterns, querying past experience, updating project knowledge map.
  Triggers: "remember this", "what did we decide", "past decision", "error
  pattern", "knowledge map", "log decision", "reflect on errors".
  Do NOT use for: web research (researcher agent), code implementation
  (implementer agent), deliberation process (deliberation skill), or
  documentation writing (docs-expert).
tools:
  - mcp__qdrant__qdrant-store
  - mcp__qdrant__qdrant-find
  - Read
  - Write
  - Edit
  - Glob
metadata:
  author: bruno
  version: 1.0.0
  category: advisory
---

# Memory Manager

Advisory skill for storing and retrieving Marvin's persistent cross-session memory
using Qdrant MCP.

## Tool Selection

| Need | Tool |
|------|------|
| Store a memory record | `mcp__qdrant__qdrant-store` |
| Retrieve past decisions or patterns | `mcp__qdrant__qdrant-find` |
| Read or update knowledge map | `Read`, `Write`, `Edit` |
| Locate memory files | `Glob` |

## Core Principles

1. **Single collection**: all memory types live in `marvin-kb`. Distinguish
   by `type` metadata (`decision`, `error-pattern`, `knowledge`, `deliberation`).
2. **Content is a synthesized summary**: 2-3 sentences max. Embedding quality
   degrades sharply beyond 512 tokens — keep it tight.
3. **Full metadata payload**: every record MUST include `type`, `project`,
   `domain`, `timestamp`, `confidence` (0.0–1.0), `session_id`,
   `files_affected`, `outcome`.
4. **Chunk sizes**: 256 tokens for facts and patterns; 512 tokens for session
   summaries. Never store raw conversation turns.
5. **Confidence escalation**: similarity > 0.85 → update existing record,
   don't create a duplicate. 2 occurrences = pattern (confidence 0.65+);
   3+ = strong pattern (confidence 0.80+).
6. **Retrieve before storing**: always query for similar records first.
   If a match exists, escalate its confidence instead of inserting.
7. **Graceful degradation**: if Qdrant is unavailable, fall back to local
   `MEMORY.md`. Log a warning; do not block the primary task.
8. **Project-scoped by default**: filter all queries by `project` metadata
   unless the user explicitly requests cross-project retrieval.
9. **Store why, not just what**: rationale and rejected alternatives are more
   reusable than the decision itself. The "what" is usually in git.
10. **Prune periodically**: stale records with outdated `outcome` fields
    mislead future queries. Review on `/reflect` sessions.

## Best Practices

1. **Decision record template**:
   ```
   Context: [what situation prompted this]
   Decision: [what was chosen]
   Alternatives: [what was rejected and why]
   Rationale: [why the chosen option wins]
   Domain: [python | architecture | testing | ...]
   Project: [project name]
   Files Affected: [list]
   ```

2. **Error pattern template**:
   ```
   Trigger: [task type or context that causes this]
   Symptom: [what the wrong output looks like]
   Root Cause: [why the error happens]
   Correct Approach: [what to do instead]
   Domain: [domain tag]
   Confidence: [0.5 initial, escalate per confirmation]
   ```

3. **Pre-decision query pattern**: search with a phrase capturing the
   task context (e.g., "module reorganization python"), filter by
   `project` + `domain`. Review top 3 results before choosing an approach.

4. **Post-decision store pattern**: format the decision using the template
   above, synthesize into a 2-3 sentence content summary, then store with
   full metadata. Never store the raw template — synthesize first.

5. **Error extraction pattern**: when a user correction arrives, identify the
   **class** of error (e.g., "forgets transitive imports when moving modules")
   not the specific instance. Store the class as an error pattern. Apply the
   3-level extraction model from `.claude/rules/memory.md`:
   - **Micro**: per-correction — extract error class immediately after correction
   - **Meso**: per-task — summarize patterns observed during a multi-step task
   - **Macro**: periodic — run `/reflect` to consolidate recurring patterns into strong signals

6. **Confidence scoring**: start at 0.5 for newly observed patterns. Add 0.15
   per independent confirmation. Cap at 1.0. Never assign 1.0 on first
   observation.

7. **Recency preference**: when multiple similar records exist, prefer the most
   recently updated one. Check `timestamp` in the metadata payload.

8. **Domain tagging**: use specific tags — `python`, `architecture`,
   `testing`, `dependencies`, `airflow`, `sql`, etc. Avoid `general` — it
   makes filtering useless.

9. **Concise summaries**: write the content field as if explaining to a
   colleague in two sentences. Specifics go in metadata fields; the content
   is for embedding similarity, not detailed reference.

10. **Periodic review**: during `/reflect` sessions, query all records for
    the project, identify contradictions or stale outcomes, and prune or
    update them. Recalibrate confidence scores based on recent evidence.

## Anti-Patterns

1. **Storing every minor decision** — variable names, formatting tweaks, and
   one-liner fixes pollute the collection and degrade retrieval signal.
   Only log decisions affecting 2+ files or introducing new patterns.

2. **Storing instances instead of patterns** — "used `pd.read_csv` here"
   doesn't generalize. Store "prefers pandas CSV loading over custom parsers
   for tabular data ingestion in this project."

3. **Skipping alternatives in decision records** — the value of a decision
   record is knowing what was rejected and why. Without it, future sessions
   re-evaluate the same options.

4. **Creating duplicate records** — never insert a new record without first
   querying for similar ones (similarity > 0.85). Duplicate records split
   confidence and corrupt retrieval rankings.

5. **Storing without querying first** — always check existing knowledge before
   writing. The new information may already be captured at higher confidence.

6. **Over-long content fields** — embedding quality degrades beyond 512 tokens.
   If details won't fit in 2-3 sentences, move them to metadata fields.

7. **Missing metadata** — records without `type`, `project`, or `domain`
   cannot be filtered and will surface irrelevant results in every query.

8. **Storing user corrections verbatim** — "you got the import wrong" is
   not a memory. Extract: "tends to forget transitive imports when moving
   code between modules in Python projects."

9. **Ignoring confidence scores** — treating a 0.5 pattern the same as a
   0.9 pattern leads to repeating unconfirmed behaviors. Always check
   confidence before acting on retrieved patterns.

10. **Storing project-specific details in cross-project knowledge** — a
    convention from one repo should not bleed into another. Always set
    the `project` field; use cross-project scope only for universal patterns.

## Examples

### Scenario 1: Architectural decision — module reorganization

User asks to restructure the project's module layout.

Actions:
1. Query `marvin-kb` with "module reorganization architecture" filtered by project.
2. Find a past decision: "flat module structure chosen over nested for this project due to import simplicity."
3. Incorporate existing constraint into the new restructuring plan.
4. After implementing, log the new decision with updated `files_affected` and rationale.

Result: New session doesn't re-debate the flat vs. nested question; past reasoning informs the change.

### Scenario 2: User correction — import error

User corrects a mistake in import handling after a module move.

Actions:
1. Identify the error class: "omits re-export of submodule symbols when moving modules."
2. Query for existing error patterns matching "import re-export python."
3. No match found — store a new error pattern with confidence 0.5.
4. On next similar task, retrieve pattern and proactively check all re-exports before submitting.

Result: Error class captured once, avoided on future module moves.

### Scenario 3: Session start — project orientation

Starting a new session on a long-running project.

Actions:
1. Read `knowledge-map.md` for current module inventory and conventions.
2. Query `marvin-kb` with "recent decisions" filtered by project, sorted by recency.
3. Surface top 3 decisions: last architectural choice, last dependency added, last error pattern.
4. Begin work with full context — no need for user to re-explain project history.

Result: Session starts informed; user doesn't repeat prior context.

## Troubleshooting

**Qdrant MCP unavailable**
Cause: MCP server not running or connection refused.
Solution: Fall back to reading/writing `MEMORY.md` locally. Log a warning in
the response. Do not block the primary task.

**Too many irrelevant results**
Cause: Query is too broad or metadata filters are missing.
Solution: Narrow the query phrase. Add `project` and `domain` filters. Use
`type` filter when querying only decisions or only error patterns.

**Duplicate records accumulating**
Cause: `qdrant-find` was skipped before storing, or similarity threshold was
too low.
Solution: Always query first. If duplicates exist, merge them: keep the
highest-confidence record, update its `timestamp`, and delete the others.

**Stale memories surfacing**
Cause: Old records with outdated `outcome` fields match current queries.
Solution: Check `timestamp` on retrieved records. During `/reflect` sessions,
query all project records, identify outdated outcomes, and prune or update them.

## Review Checklist

- [ ] Decision record includes alternatives considered and rationale for the choice
- [ ] Error pattern captures the error class, not a specific instance
- [ ] Content summary is 2-3 sentences and under 512 tokens
- [ ] All metadata fields are populated (type, project, domain, timestamp, confidence, session_id, files_affected, outcome)
- [ ] Queried before storing — no duplicate records introduced
- [ ] Confidence score reflects observed frequency (not default 0.5 for confirmed patterns)
- [ ] Project field is set to the correct project name
- [ ] Domain tags are specific (python, architecture, testing — not "general")
- [ ] Knowledge map updated after any structural change to the project
- [ ] No sensitive data stored (credentials, tokens, personal information)
