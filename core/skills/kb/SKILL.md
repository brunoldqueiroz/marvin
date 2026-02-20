---
name: kb
description: Save to or search the shared knowledge base (Qdrant Cloud)
disable-model-invocation: true
argument-hint: "save <knowledge> | search <query>"
---

# Knowledge Base

Manage Marvin's shared knowledge base: `$ARGUMENTS`

## Process

### 1. Parse Operation

Extract the operation from `$ARGUMENTS`:
- If starts with `save` → go to **Save Flow** (Step 2)
- If starts with `search` or `find` → go to **Search Flow** (Step 6)
- Otherwise → tell the user: "Usage: `/kb save <knowledge>` or `/kb search <query>`"

---

## Save Flow

### 2. Extract Knowledge

Parse the knowledge to save from `$ARGUMENTS` (everything after "save").

### 3. Build Metadata

Determine metadata by analyzing the content:

| Field | How to Determine |
|-------|-----------------|
| `domain` | Match to: dbt, spark, airflow, snowflake, aws, docker, terraform, python, general |
| `type` | Classify as: pattern, decision, lesson, preference |
| `project` | Use current project name from git remote or directory, or "global" if not project-specific |
| `author` | Use `MARVIN_AUTHOR` env var, or "unknown" if not set |
| `date` | Today's date (YYYY-MM-DD) |
| `tags` | Extract 2-5 relevant keywords from the content |

### 4. Format Information String

Prefix the knowledge with `[domain/type]` for implicit scoping in semantic search:

```
[dbt/pattern] Use incremental models with merge strategy for slowly changing dimensions
```

### 5. Store in KB

Call `mcp__qdrant__qdrant-store` with:
- `information`: the formatted string from Step 4
- `metadata`: the metadata dict from Step 3

Confirm to the user what was saved, showing the formatted string and metadata.

**Done.**

---

## Search Flow

### 6. Search KB

Extract the query from `$ARGUMENTS` (everything after "search" or "find").

Call `mcp__qdrant__qdrant-find` with the query as natural language.

### 7. Present Results

Display results in a clear format:

```
## KB Results for "<query>"

### 1. [domain/type] <title>
<content>
- **Domain:** <domain> | **Type:** <type> | **Author:** <author> | **Date:** <date>
- **Tags:** <tags>

### 2. ...
```

If no results found, say so and suggest broadening the query.

**Done.**
