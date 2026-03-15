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
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
metadata:
  author: bruno
  version: 2.0.0
  category: workflow
---

# Reflect

Periodic memory audit skill. Scans `.claude/memory/` for stale records, weak
patterns, near-duplicates, and high-error domains. Produces a structured
reflection report and — with explicit user approval — prunes or consolidates
records.

## Tool Selection

| Need | Tool |
|------|------|
| Scan memory directories | `Glob` (`memory/{type}/*.md`) |
| Search by domain or topic | `Grep` (frontmatter fields) |
| Read topic file content | `Read` |
| Update or archive records | `Edit`, `Write` |
| Request prune/merge/update approval | `AskUserQuestion` |

## Core Principles

1. **Project-scoped queries only**: filter every Grep by `project` frontmatter.
   Never surface cross-project records unless explicitly requested.
2. **File scan budget — NFR-01**: scan all files in each typed directory
   (decisions, error-patterns, evaluations, deliberations). Strategy:
   Glob to list files, then Grep frontmatter for metadata extraction.
3. **Stale detection**: a record is stale when its content is contradicted
   by a more recent record or by the current codebase state (cross-check with
   `knowledge-map.md` or recent spec files).
4. **Weak pattern threshold**: confidence < 0.65 AND `updated` older than 30
   days AND no re-confirmation (`correction_count` ≤ 1) → candidate for pruning
   or escalation.
5. **Duplicate detection**: records in the same directory with highly similar
   content are near-duplicates. Merge by keeping the highest-confidence record
   and updating its `updated` date; archive the lower-confidence copy only
   after user approval.
6. **Consolidation rule**: 3+ weak patterns in the same domain/class → draft a
   single consolidated pattern at confidence 0.80+. Present the draft to the
   user before writing.
7. **User approval is mandatory**: never prune, merge, or update any record
   without explicit approval via `AskUserQuestion`. Report first; act second.
8. **Graceful degradation — NFR-02**: if memory directory is empty or missing,
   report "no records found" and suggest creating initial entries.
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

1. Start with Glob in each `memory/{type}/` directory to count files and
   establish the total record inventory before detailed scanning.
2. Group results by type first, then by domain within each type — do not
   mix types in a single analysis pass.
3. For stale detection, cross-reference file content against
   `.claude/memory/knowledge-map.md` and recently completed spec `tasks.md` files.
4. For weak patterns, always check `correction_count` in frontmatter — a pattern
   with `correction_count` of 0 is newly stored, not stale; leave it alone.
5. For near-duplicates, present pairs to the user with both record summaries
   before proposing a merge.
6. For consolidation, draft the merged content in the report body before
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

1. **Auto-pruning without approval** — deleting or archiving any record
   before `AskUserQuestion` returns explicit consent. The report is not consent.
2. **Skipping the scan** — making recommendations without reading all files
   in the relevant directories. Glob + Grep all directories first.
3. **Treating low confidence as stale** — a freshly stored pattern at confidence
   0.5 is new, not stale. Stale requires both low confidence AND age > 30 days
   AND no re-confirmation.
4. **Cross-domain consolidation** — merging a `python` error pattern with an
   `architecture` error pattern because they sound similar. Domain boundaries
   are consolidation boundaries.
5. **Running reflection every session** — reflection is periodic (post-spec or
   high-density), not constant. Frequent reflection with few records wastes
   time and produces noise.
6. **Ignoring correction_count** — `correction_count` is the primary signal for
   pattern strength. A pattern confirmed 3+ times at 0.55 confidence is stronger
   than one stored once at 0.70.
7. **Pruning recently created low-confidence records** — new observations start
   at 0.5. Time + re-confirmation builds confidence; age alone does not make a
   record stale.
8. **Reporting raw file content** — dumping the full file without synthesis.
   The report tables are the output; raw YAML is implementation detail.
9. **Skipping the error density summary** — it is required by FR-06 and drives
   future skill-loading calibration. Omitting it makes the report incomplete.
10. **Updating records without refreshing `updated`** — any record modification
    MUST update the `updated` field. Stale timestamps corrupt recency sorting.

## Examples

### Scenario 1: Post-spec reflection

After completing a 10-task spec, the user runs `/reflect`.

Actions:
1. Glob `memory/decisions/*.md` — 6 files. Glob `memory/error-patterns/*.md` — 5 files.
   Glob `memory/evaluations/*.md` — 1 file. Glob `memory/deliberations/*.md` — 1 file.
2. Grep frontmatter: extract `domain`, `confidence`, `updated` from all 13 files.
3. Stale detection: 2 decision files reference a module path that was renamed
   in the spec — content contradicted by `knowledge-map.md`.
4. Weak patterns: 3 error-patterns have confidence < 0.65 and age > 30 days.
   One of the three has `correction_count: 2` — recently reconfirmed, skip.
5. Report presented: 2 stale decisions recommended for archiving; 1 weak pattern
   recommended for confidence boost (reconfirmed by recent error in the spec).
6. User approves archiving 2 stale records and boost of 1 weak pattern.
7. Records moved to `archive/`; boosted pattern gets updated frontmatter.

Result: 2 misleading records archived; 1 confirmed pattern strengthened.

### Scenario 2: Duplicate cleanup

`/reflect` finds 2 near-duplicate error patterns about import handling.

Actions:
1. Present both records: File A (confidence 0.75, 45 days old,
   `correction_count: 3`) and File B (confidence 0.55, 10 days old, `correction_count: 1`).
2. Draft merged content: keep File A's content (higher confidence, more
   confirmations), update `updated` to today, archive File B.
3. Ask user via `AskUserQuestion`: "Found near-duplicate import error patterns.
   Merge B into A, keeping A's content at confidence 0.75?"
4. User approves. File A updated; File B moved to `archive/`.

Result: Duplicate eliminated. Signal concentrated in a single,
higher-confidence record.

### Scenario 3: Domain density review

`/reflect` after a long python-heavy session.

Actions:
1. Glob `memory/error-patterns/*.md` — 8 files. Grep `domain: python` — 5 matches.
2. Of the 5 python patterns: 3 have confidence > 0.65, 2 are weak.
3. No stale records, no near-duplicates.
4. Report section "Domain Error Density": python has the highest error density
   at 5 patterns (3 high-confidence). Calibration note: load `deliberation`
   skill proactively on future python architectural tasks.
5. No record modifications needed.

Result: Report delivered with calibration recommendation. No record changes.

## Troubleshooting

**Memory directory empty or missing**
Cause: Fresh project or accidental deletion.
Solution: Report "no records found." Suggest creating initial entries via
memory-manager skill. Create missing directories if needed.

**Too many files to review**
Cause: Project has grown a large memory corpus without consolidation.
Solution: Prioritize `error-patterns/` first (highest learning value), then
`decisions/`. Defer `evaluations/` and `deliberations/` to a follow-up
`/reflect` session. Report the deferral in Recommended Actions.

**No actionable findings**
Cause: Memory is recent, well-maintained, or the project is early-stage.
Solution: Report "memory is healthy" with the record count table and domain
density summary. No modifications needed. This is a valid and common outcome.

**User declines all suggestions**
Cause: User disagrees with archiving or merging recommendations.
Solution: Record the reflection as informational — no changes made. Note in
the report that the suggested actions were reviewed and deferred.

## Review Checklist

- [ ] All directories scanned: decisions, error-patterns, evaluations, deliberations
- [ ] Stale records identified with specific contradicting evidence cited
- [ ] Weak patterns checked against both `correction_count` and record age
- [ ] Near-duplicates identified by content similarity in the same directory
- [ ] Consolidation candidates are within the same domain (no cross-domain merges)
- [ ] User approval obtained via `AskUserQuestion` before any record modification
- [ ] Reflection report includes all 7 sections from FR-06 format
- [ ] Domain error density summary included for calibration review
- [ ] All modified records have a refreshed `updated` field
- [ ] Archived records moved to `archive/` directory (never hard-deleted)
