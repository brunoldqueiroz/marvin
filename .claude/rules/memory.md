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
  timestamp) in error-pattern frontmatter
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
- Write the evaluation record to `memory/evaluations/{date}-{slug}.md`
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
domain (Grep in `memory/error-patterns/` filtered by `domain` frontmatter):

- **3+ high-confidence (>0.65) error patterns**: high-error domain. Bias toward
  loading `deliberation` and/or `self-consistency` skills. Slow down.
- **1-2 error patterns**: moderate awareness. Query patterns before acting but
  no forced skill loading.
- **0 error patterns**: clean domain. Allow fast execution without forced
  deliberation.

Calibration is advisory — override when context warrants it. Update calibration
data by running `/reflect` periodically.

## Memory Storage

All memory lives in `.claude/memory/` as Markdown files with YAML frontmatter.

### Directory Layout

```
.claude/memory/
├── MEMORY.md                 # HOT: curated index ≤200 lines
├── knowledge-map.md          # HOT: structural orientation
├── decisions/                # WARM: architectural decisions
│   └── {date}-{slug}.md
├── error-patterns/           # WARM: learned error classes
│   └── {domain}-{slug}.md
├── evaluations/              # WARM: self-consistency results
│   └── {date}-{slug}.md
├── deliberations/            # WARM: structured deliberation records
│   └── {date}-{slug}.md
└── archive/                  # COLD: expired/merged entries
    └── {date}-{slug}.md
```

### Topic File Format

```yaml
---
type: decision | error-pattern | evaluation | deliberation
domain: python | architecture | testing | claude-code | ...
project: marvin
confidence: 0.5        # 0.0–1.0, escalate with confirmations
priority: P0 | P1 | P2 # P0=permanent, P1=90d TTL, P2=30d TTL
created: 2026-03-15
updated: 2026-03-15
tags: [tag1, tag2]
files_affected: [file1.py, file2.py]
task_type: implementation | architecture | testing | review | planning
correction_count: 1     # error-patterns only
last_corrected: 2026-03-15  # error-patterns only
---

Synthesized content (2-3 sentences max).

**Why:** rationale
**How to apply:** trigger conditions
```

### Write Protocol

1. Grep in the relevant `memory/{type}/` directory for similar topics
2. If match found: decide ADD / UPDATE / DELETE
3. Deleted entries → move to `archive/` (never hard-delete)
4. Write/update topic file with full frontmatter
5. Update `MEMORY.md` index if entry is P0 or P1

### Read Protocol (progressive disclosure)

1. `MEMORY.md` injected automatically via SessionStart hook (always in context)
2. Analyze index → identify relevant topic files
3. Read topic files on demand
4. For deep dives: Read `archive/` if needed
5. When delegating to subagent: include relevant context in the prompt

### Maintenance Protocol (via /reflect)

1. Check `MEMORY.md` > 150 lines → consolidate
2. Scan frontmatter: P1 entries > 90 days without update → candidate for archive
3. P2 entries > 30 days without update → candidate for archive
4. Topic files > 2000 tokens → split or consolidate
5. Near-duplicates → merge (keep higher confidence)

## General Rules

- Use `Write` to store memories, `Read/Glob/Grep` to retrieve them.
- Memory directory: `.claude/memory/` with typed subdirectories.
- Valid types: `decision`, `error-pattern`, `evaluation`, `deliberation`.
- **Retrieve before storing** — avoid duplicate records; escalate confidence instead.
- **Graceful degradation**: if memory files are unavailable, continue without
  memory queries. Do not block the primary task.
- MUST NOT block on memory operations for simple, single-file, or mechanical tasks.
- Only log decisions that affect 2+ files or introduce new patterns — avoid pollution.
- Store **why**, not just **what** — rationale is more valuable than the decision itself.
- Project-scope all queries by default: filter by `project` frontmatter.
