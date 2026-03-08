---
name: reflect
user-invocable: true
description: >
  Periodic memory audit and consolidation for cross-session learning. Load
  when auditing stored patterns, pruning stale records, consolidating weak
  signals, or reviewing domain error density. Use when: user invokes /reflect,
  after completing a multi-task spec (5+ tasks), or when session memory density
  is high (10+ records stored).
  Triggers: "/reflect", "audit memory", "consolidate patterns", "prune stale
  records", "review error density", "memory health check".
  Do NOT use for: storing individual decisions or error patterns (memory-manager),
  structured deliberation on decisions (deliberation skill), candidate comparison
  (self-consistency), or code implementation (implementer agent).
tools:
  - mcp__qdrant__qdrant-find
  - mcp__qdrant__qdrant-store
  - Read
  - Glob
  - AskUserQuestion
metadata:
  author: bruno
  version: 1.0.0
  category: advisory
---

# Reflect

Periodic memory audit skill. Queries Qdrant for stale records, weak patterns,
near-duplicates, and high-error domains. Produces a structured reflection report
and — with explicit user approval — prunes or consolidates records.

## Tool Selection

| Need | Tool |
|------|------|
| Query records by type or domain | `mcp__qdrant__qdrant-find` |
| Update or consolidate records | `mcp__qdrant__qdrant-store` |
| Read knowledge map or spec files | `Read` |
| Locate memory or spec files | `Glob` |
| Request prune/merge/update approval | `AskUserQuestion` |

## Core Principles

1. **Project-scoped queries only**: filter every `qdrant-find` call by `project`
   metadata. Never surface cross-project records unless explicitly requested.
2. **Batch query budget — NFR-01**: max 10 Qdrant queries per reflection session.
   Strategy: 5 type-based queries (`decision`, `error-pattern`, `knowledge`,
   `deliberation`, `evaluation`), then up to 5 optional domain-specific queries
   for high-error domains identified in the first pass.
3. **Stale detection**: a record is stale when its `outcome` field is contradicted
   by a more recent record or by the current codebase state (cross-check with
   `knowledge-map.md` or recent spec files).
4. **Weak pattern threshold**: confidence < 0.65 AND `timestamp` older than 30
   days AND no re-confirmation (`correction_count` ≤ 1) → candidate for pruning
   or escalation.
5. **Duplicate detection**: records with content similarity > 0.85 are near-
   duplicates. Merge by keeping the highest-confidence record and updating its
   `timestamp`; discard the lower-confidence copy only after user approval.
6. **Consolidation rule**: 3+ weak patterns in the same domain/class → draft a
   single consolidated pattern at confidence 0.80+. Present the draft to the
   user before writing.
7. **User approval is mandatory**: never prune, merge, or update any record
   without explicit approval via `AskUserQuestion`. Report first; act second.
8. **Graceful degradation — NFR-02**: if Qdrant is unavailable, report the
   failure, skip all record operations, and continue with file-based findings
   (knowledge map, spec directory).
9. **Report over action**: the primary deliverable is the reflection report.
   Record modifications are optional follow-ons, not the goal.
10. **Error density for calibration**: calculate error patterns per domain as
    the final section of every report. High-density domains should trigger
    `deliberation` skill on future tasks in that domain.

### Reflection Report Format (FR-06)

Every reflection session produces this report:

```
## Reflection Report — {project} ({date})

### Record Inventory
| Type | Count | Domains |
|------|-------|---------|

### Stale Records
| Record | Reason | Action |

### Weak Patterns
| Record | Confidence | Last Updated | Suggestion |

### Near-Duplicates
| Pair | Similarity | Suggestion |

### Consolidated Patterns
| From | To | New Confidence |

### Domain Error Density
| Domain | Error Patterns | High-Confidence (>0.65) | Calibration |

### Recommended Actions
- [ ] {action with record reference}
```

## Best Practices

1. Start with a broad project query to establish total record count before
   diving into type-based queries.
2. Group results by `type` first, then by `domain` within each type — do not
   mix types in a single analysis pass.
3. For stale detection, cross-reference `outcome` fields against
   `.claude/memory/knowledge-map.md` and recently completed spec `tasks.md` files.
4. For weak patterns, always check `correction_count` in metadata — a pattern
   with `correction_count` of 0 is newly stored, not stale; leave it alone.
5. For near-duplicates, present pairs to the user with the similarity score and
   both record summaries before proposing a merge.
6. For consolidation, draft the merged content field in the report body before
   asking user approval. Show what will be written, not just that something
   will be written.
7. Include the domain error density summary in every reflection report, even
   when no actions are needed — it is calibration data for future sessions.
8. Suggest `/reflect` to the user proactively after completing a spec with 5+
   tasks, noting the approximate number of records stored during the session.
9. Suggest `/reflect` when 10+ records have been stored in the current session
   — memory density is high enough that consolidation will yield signal.
10. Keep the reflection report concise: use tables for inventories, bullet lists
    for actions. Avoid prose for data that fits in a table.

## Anti-Patterns

1. **Auto-pruning without approval** — deleting or overwriting any Qdrant record
   before `AskUserQuestion` returns explicit consent. The report is not consent.
2. **One-at-a-time queries** — issuing a separate `qdrant-find` per record to
   check recency or confidence. Batch by type; extract metadata from results.
3. **Treating low confidence as stale** — a freshly stored pattern at confidence
   0.5 is new, not stale. Stale requires both low confidence AND age > 30 days
   AND no re-confirmation.
4. **Cross-domain consolidation** — merging a `python` error pattern with an
   `architecture` error pattern because they sound similar. Domain boundaries
   are consolidation boundaries.
5. **Running reflection every session** — reflection is periodic (post-spec or
   high-density), not constant. Frequent reflection with few records wastes
   queries and produces noise.
6. **Ignoring correction_count** — `correction_count` is the primary signal for
   pattern strength. A pattern confirmed 3+ times at 0.55 confidence is stronger
   than one stored once at 0.70.
7. **Pruning recently created low-confidence records** — new observations start
   at 0.5. Time + re-confirmation builds confidence; age alone does not make a
   record stale.
8. **Reporting raw Qdrant output** — dumping the full record payload without
   synthesis. The report tables are the output; raw JSON is implementation detail.
9. **Skipping the error density summary** — it is required by FR-06 and drives
   future skill-loading calibration. Omitting it makes the report incomplete.
10. **Updating records without refreshing timestamp** — any record modification
    MUST update the `timestamp` field. Stale timestamps corrupt recency sorting.

## Examples

### Scenario 1: Post-spec reflection

After completing a 10-task spec, the user runs `/reflect`.

Actions:
1. Query `marvin-kb` by project — 15 records found across 5 types.
2. Type pass: 6 decisions, 5 error-patterns, 2 knowledge, 1 deliberation, 1 evaluation.
3. Stale detection: 2 decision records reference a module path that was renamed
   in the spec — `outcome` field contradicted by `knowledge-map.md`.
4. Weak patterns: 3 error-patterns have confidence < 0.65 and age > 30 days.
   One of the three has `correction_count` = 2 — recently reconfirmed, skip.
5. Report presented: 2 stale decisions recommended for pruning; 1 weak pattern
   recommended for confidence boost (reconfirmed by recent error in the spec).
6. User approves pruning of 2 stale records and boost of 1 weak pattern.
7. Records updated with fresh `timestamp`.

Result: 2 misleading records removed; 1 confirmed pattern strengthened.
Memory is cleaner and more accurate after the spec cycle.

### Scenario 2: Duplicate cleanup

`/reflect` finds 2 near-duplicate error patterns about import handling (similarity 0.91).

Actions:
1. Present both records side by side: Record A (confidence 0.75, 45 days old,
   `correction_count` = 3) and Record B (confidence 0.55, 10 days old, `correction_count` = 1).
2. Draft merged content: keep Record A's content (higher confidence, more
   confirmations), update `timestamp` to today, discard Record B.
3. Ask user via `AskUserQuestion`: "Found near-duplicate import error patterns
   (similarity 0.91). Merge B into A, keeping A's content at confidence 0.75?"
4. User approves. Record A timestamp updated; Record B removed.

Result: Duplicate eliminated. Retrieval signal concentrated in a single,
higher-confidence record.

### Scenario 3: Domain density review

`/reflect` after a long python-heavy session.

Actions:
1. Type pass: 8 error-patterns found. Domain breakdown: `python` = 5,
   `architecture` = 1, `testing` = 2.
2. Of the 5 python patterns: 3 are high-confidence (> 0.65), 2 are weak.
3. No stale records, no near-duplicates meeting the 0.85 threshold.
4. Report section "Domain Error Density": python has the highest error density
   at 5 patterns (3 high-confidence). Calibration note: load `deliberation`
   skill proactively on future python architectural tasks.
5. No record modifications needed. User declines suggested consolidation of 2
   weak python patterns (not enough evidence yet).

Result: Report delivered with calibration recommendation. No record changes.
Future sessions will be more deliberate on python architecture decisions.

## Troubleshooting

**Qdrant unavailable**
Cause: MCP server not running or connection refused.
Solution: Log the failure, skip all record queries and modifications, report
"Qdrant unavailable — skipping record analysis." If `knowledge-map.md` is
accessible, include a file-based inventory instead.

**Too many records to process within the 10-query budget**
Cause: Project has grown a large memory corpus.
Solution: Prioritize `error-pattern` type first (highest learning value), then
`decision`. Defer `knowledge`, `deliberation`, and `evaluation` to a follow-up
`/reflect` session. Report the deferral in the Recommended Actions section.

**No actionable findings**
Cause: Memory is recent, well-maintained, or the project is early-stage.
Solution: Report "memory is healthy" with the record count table and domain
density summary. No modifications needed. This is a valid and common outcome.

**User declines all suggestions**
Cause: User disagrees with pruning or merging recommendations.
Solution: Record the reflection as informational — no changes made. Note in
the report that the suggested actions were reviewed and deferred. Future
`/reflect` sessions may reconsider if patterns become stronger.

## Review Checklist

- [ ] All queries filtered by project scope (no cross-project leakage)
- [ ] Total Qdrant queries in this session is 10 or fewer (NFR-01)
- [ ] Stale records identified with specific contradicting evidence cited
- [ ] Weak patterns checked against both `correction_count` and record age
- [ ] Near-duplicates identified by content similarity threshold > 0.85
- [ ] Consolidation candidates are within the same domain (no cross-domain merges)
- [ ] User approval obtained via `AskUserQuestion` before any record modification
- [ ] Reflection report includes all 7 sections from FR-06 format
- [ ] Domain error density summary included for calibration review
- [ ] All modified records have a refreshed `timestamp` field
