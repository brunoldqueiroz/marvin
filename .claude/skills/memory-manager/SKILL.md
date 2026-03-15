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
  (implementer agent), deliberation process (deliberation skill), candidate
  comparison (self-consistency), periodic memory audit/consolidation (reflect),
  or documentation writing (docs-expert).
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
metadata:
  author: bruno
  version: 2.0.0
  category: knowledge
---

# Memory Manager

Advisory skill for storing and retrieving Marvin's persistent cross-session
memory using file-based storage in `.claude/memory/`.

## Tool Selection

| Need | Tool |
|------|------|
| Store a memory record | `Write` to `memory/{type}/{file}.md` |
| Retrieve past decisions or patterns | `Grep` + `Read` in `memory/{type}/` |
| Check for duplicates before storing | `Grep` in relevant `memory/{type}/` dir |
| Read or update knowledge map | `Read`, `Write`, `Edit` |
| Locate memory files | `Glob` |

## Core Principles

1. **Typed subdirectories**: memory types live in separate directories —
   `decisions/`, `error-patterns/`, `evaluations/`, `deliberations/`.
   Distinguish by directory, not metadata payload.
2. **YAML frontmatter for searchability**: every topic file has structured
   frontmatter with `type`, `domain`, `project`, `confidence`, `priority`,
   `created`, `updated`, `tags`, `files_affected`. Grep frontmatter fields
   for filtering.
3. **Content is a synthesized summary**: 2-3 sentences max in the body.
   Details go in frontmatter fields; the body is for quick scanning.
4. **Three-tier architecture**: HOT (MEMORY.md index, ≤200 lines, always
   in context via hook), WARM (topic files loaded on demand), COLD (archive/
   for expired entries).
5. **Confidence escalation**: 2 occurrences = pattern (confidence 0.65+);
   3+ = strong pattern (confidence 0.80+). Update existing file instead of
   creating a duplicate.
6. **Retrieve before storing**: always Grep for similar records first.
   If a match exists, escalate its confidence instead of inserting.
7. **Graceful degradation**: if memory directory is missing, create it.
   Never block the primary task for memory operations.
8. **Project-scoped by default**: filter all queries by `project` frontmatter
   unless the user explicitly requests cross-project retrieval.
9. **Store why, not just what**: rationale and rejected alternatives are more
   reusable than the decision itself. The "what" is usually in git.
10. **Prune periodically**: stale records with outdated outcomes mislead
    future queries. Run `/reflect` to audit and consolidate.

## Best Practices

1. **Decision record template**:
   ```yaml
   ---
   type: decision
   domain: [python | architecture | testing | ...]
   project: [project name]
   confidence: 0.7
   priority: P1
   created: [ISO date]
   updated: [ISO date]
   tags: [relevant, tags]
   files_affected: [file1.py, file2.py]
   ---

   Context: [what situation prompted this]
   Decision: [what was chosen]
   Alternatives: [what was rejected and why]

   **Why:** [rationale for the choice]
   **How to apply:** [when this decision should guide future work]
   ```

2. **Error pattern template**:
   ```yaml
   ---
   type: error-pattern
   domain: [domain tag]
   project: [project name]
   confidence: 0.5
   priority: P1
   created: [ISO date]
   updated: [ISO date]
   tags: [relevant, tags]
   files_affected: []
   task_type: [implementation | architecture | testing | review | planning]
   correction_count: 1
   last_corrected: [ISO date]
   ---

   Trigger: [task type or context that causes this]
   Symptom: [what the wrong output looks like]
   Root Cause: [why the error happens]
   Correct Approach: [what to do instead]

   **Why:** [class of error, not specific instance]
   **How to apply:** [check before acting in this domain]
   ```

3. **Pre-decision query pattern**: Grep in `memory/decisions/` for the topic
   keyword (e.g., `grep -r "module reorganization" memory/decisions/`),
   filter by `project` + `domain` in frontmatter. Review top matches.

4. **Post-decision store pattern**: format the decision using the template
   above, then Write to `memory/decisions/{date}-{slug}.md`. Update
   `MEMORY.md` index if it's a P0 or P1 entry.

5. **Error extraction pattern**: when a user correction arrives, identify the
   **class** of error (e.g., "forgets transitive imports when moving modules")
   not the specific instance. Store the class as an error pattern. Apply the
   3-level extraction model from `.claude/rules/memory.md`:
   - **Micro**: per-correction — extract error class immediately after correction
   - **Meso**: per-task — summarize patterns observed during a multi-step task
   - **Macro**: periodic — run `/reflect` to consolidate recurring patterns

6. **Confidence scoring**: start at 0.5 for newly observed patterns. Add 0.15
   per independent confirmation. Cap at 1.0. Never assign 1.0 on first
   observation.

7. **Recency preference**: when multiple similar records exist, prefer the most
   recently updated one. Check `updated` field in frontmatter.

8. **Domain tagging**: use specific tags — `python`, `architecture`,
   `testing`, `dependencies`, `airflow`, `sql`, etc. Avoid `general` — it
   makes filtering useless.

9. **Naming convention**: decision files use `{date}-{slug}.md` (e.g.,
   `2026-03-15-qdrant-to-file-memory.md`). Error pattern files use
   `{domain}-{slug}.md` (e.g., `python-transitive-imports.md`).

10. **MEMORY.md maintenance**: keep the index under 200 lines. Critical facts
    (P0) at the top. Active patterns (P1) below. Topic index at bottom.
    Update index whenever adding P0/P1 entries.

11. **Error density query pattern**: before acting in a domain, Grep
    `memory/error-patterns/` for files with matching `domain:` frontmatter.
    Count files with `confidence` > 0.65. If 3+ high-confidence patterns,
    load deliberation and/or self-consistency skill before proceeding.

12. **Reflect integration**: suggest `/reflect` to the user when: (a) a
    multi-task spec completes (5+ tasks), (b) 10+ records have been stored in
    the current session, (c) the user explicitly asks about memory health.

## Anti-Patterns

1. **Storing every minor decision** — variable names, formatting tweaks, and
   one-liner fixes pollute the directories and degrade scanning signal.
   Only log decisions affecting 2+ files or introducing new patterns.

2. **Storing instances instead of patterns** — "used `pd.read_csv` here"
   doesn't generalize. Store "prefers pandas CSV loading over custom parsers
   for tabular data ingestion in this project."

3. **Skipping alternatives in decision records** — the value of a decision
   record is knowing what was rejected and why. Without it, future sessions
   re-evaluate the same options.

4. **Creating duplicate records** — never insert a new record without first
   Grepping for similar ones. Duplicate records split confidence and corrupt
   retrieval.

5. **Storing without querying first** — always check existing knowledge before
   writing. The new information may already be captured at higher confidence.

6. **Over-long content** — keep body to 2-3 sentences. If details won't fit,
   add structured sections (Context, Decision, Alternatives) but stay concise.

7. **Missing frontmatter** — records without `type`, `project`, or `domain`
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
1. Grep `memory/decisions/` for "module reorganization" or "module structure".
2. Find a past decision: "flat module structure chosen over nested for this
   project due to import simplicity."
3. Incorporate existing constraint into the new restructuring plan.
4. After implementing, Write new decision to `memory/decisions/{date}-module-restructure.md`.

Result: New session doesn't re-debate the flat vs. nested question; past
reasoning informs the change.

### Scenario 2: User correction — import error

User corrects a mistake in import handling after a module move.

Actions:
1. Identify the error class: "omits re-export of submodule symbols when moving modules."
2. Grep `memory/error-patterns/` for "import re-export python".
3. No match found — Write new error pattern to `memory/error-patterns/python-reexport-omission.md`
   with confidence 0.5.
4. On next similar task, Grep finds the pattern and proactively check all
   re-exports before submitting.

Result: Error class captured once, avoided on future module moves.

### Scenario 3: Session start — project orientation

Starting a new session on a long-running project.

Actions:
1. MEMORY.md automatically injected by SessionStart hook — index is in context.
2. Read `knowledge-map.md` for current module inventory and conventions.
3. Scan MEMORY.md index for recent decisions and active patterns.
4. Read relevant topic files for full context on recent architectural choices.

Result: Session starts informed; user doesn't repeat prior context.

## Troubleshooting

**Memory directory missing**
Cause: First-time setup or accidental deletion.
Solution: Create `memory/{decisions,error-patterns,evaluations,deliberations,archive}/`
with `.gitkeep` files. Create `MEMORY.md` with the standard template.

**Too many files to scan**
Cause: Memory has grown large without consolidation.
Solution: Run `/reflect` to archive stale entries, merge duplicates, and
consolidate weak patterns. Use Glob + Grep to filter by frontmatter fields.

**Duplicate records accumulating**
Cause: Grep was skipped before storing, or search terms were too narrow.
Solution: Always Grep first. If duplicates exist, merge them: keep the
highest-confidence record, update its `updated` date, archive the other.

**Stale memories surfacing**
Cause: Old records with outdated outcomes match current queries.
Solution: Check `updated` field on retrieved records. During `/reflect`,
scan all files, identify outdated entries, and move them to `archive/`.

## Review Checklist

- [ ] Decision record includes alternatives considered and rationale for the choice
- [ ] Error pattern captures the error class, not a specific instance
- [ ] Content summary is 2-3 sentences in the body
- [ ] All frontmatter fields are populated (type, project, domain, confidence, priority, created, updated, tags, files_affected)
- [ ] Grepped before storing — no duplicate records introduced
- [ ] Confidence score reflects observed frequency (not default 0.5 for confirmed patterns)
- [ ] Project field is set to the correct project name
- [ ] Domain tags are specific (python, architecture, testing — not "general")
- [ ] Knowledge map updated after any structural change to the project
- [ ] No sensitive data stored (credentials, tokens, personal information)
