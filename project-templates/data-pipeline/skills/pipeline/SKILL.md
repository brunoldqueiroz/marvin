---
name: pipeline
description: Design and implement a data pipeline
disable-model-invocation: true
argument-hint: "[source] [destination] [description]"
---

# Data Pipeline Design

Design a data pipeline for: $ARGUMENTS

## Process

### 1. Understand Requirements

Parse `$ARGUMENTS` to determine:
- **Source(s):** Where is the data coming from? (API, database, files, streams)
- **Destination:** Where should it land? (warehouse, lake, another database)
- **Description:** What transformation/business logic is needed?

If details are missing, ask the user:
- What's the data volume? (rows/day, GB)
- How fresh does the data need to be? (real-time, hourly, daily)
- Is this a one-time migration or ongoing pipeline?

### 2. Design the Architecture

Create a pipeline design document:

```
Source(s) → Extraction → Staging → Transformation → Loading → Target
```

For each stage, decide:
- **Extraction:** Full vs incremental, CDC vs polling, API pagination
- **Staging:** Raw landing zone (append-only, partitioned by load date)
- **Transformation:** Business rules, joins, aggregations, data quality checks
- **Loading:** Insert vs upsert vs partition overwrite

### 3. Design the Data Model

Before writing any code, design the target schema:
- Define the grain (one row = what?)
- List all columns with types
- Identify primary keys, foreign keys
- Decide partitioning strategy
- Document slowly changing dimensions (if applicable)

### 4. Implement

Delegate to the **data-eng** agent with specific instructions:

- Write idempotent extraction code
- Create staging models (rename, retype, deduplicate)
- Create transformation models (business logic, joins)
- Create final mart models (consumption-ready)
- Add data quality checks at each stage:
  - Source: row count, freshness
  - Staging: not null on PKs, unique business keys
  - Marts: referential integrity, accepted values

### 5. Test

- Unit tests for transformation logic
- Integration tests with sample data
- Run full pipeline on a subset to validate
- Verify row counts match expectations

### 6. Document

Write pipeline spec to `specs/pipeline-<name>.md`:
- Source description and schema
- Transformation rules
- Target schema and grain
- Refresh strategy (incremental/full, schedule)
- Data quality checks included
- Known limitations
