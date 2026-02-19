---
name: pipeline
description: Design and scaffold a complete data pipeline (ingestion → transformation → serving)
disable-model-invocation: true
argument-hint: "[pipeline description - source, destination, frequency]"
---

# Pipeline Designer

Pipeline request: $ARGUMENTS

## Process

### 1. Gather Requirements

Before designing, clarify these dimensions:
- **Source**: Where does the data come from? (API, database, S3, files, streaming)
- **Destination**: Where does it go? (Snowflake, S3, another system)
- **Frequency**: How often? (real-time, hourly, daily, weekly)
- **Volume**: How much data? (rows/day, GB/day)
- **SLA**: How fresh must the data be? (minutes, hours, end of day)
- **Transformations**: What business logic is needed?

If any of these are unclear from $ARGUMENTS, ask the user before proceeding.

### 2. Design the Architecture

Based on the requirements, design a pipeline using the user's stack:
- **Orchestration**: Airflow (DAGs with appropriate scheduling)
- **Ingestion**: Python scripts, AWS Lambda, or Airflow operators
- **Storage**: S3 (data lake) → Snowflake (data warehouse)
- **Transformation**: dbt (staging → intermediate → marts) or PySpark
- **Quality**: dbt tests, Great Expectations, or custom validation

Create a design document at `changes/pipeline-design.md`:
```markdown
# Pipeline Design: <Name>

## Overview
[What this pipeline does, source to destination]

## Architecture Diagram
```
[Source] → [Ingestion] → [S3 Raw] → [Snowflake Staging] → [dbt Transform] → [Snowflake Marts]
```

## Components
| Component | Technology | Purpose |
|-----------|-----------|---------|
| Orchestration | Airflow | Schedule and monitor |
| Ingestion | Python/Lambda | Extract from source |
| Storage | S3 + Snowflake | Raw + transformed data |
| Transform | dbt | Business logic |
| Quality | dbt tests | Data validation |

## Data Flow
1. [Step 1]
2. [Step 2]
...

## Schedule
[Cron expression and rationale]
```

### 3. Scaffold the Code

Delegate to specialized agents based on components:

- **Airflow DAG** → delegate to **airflow-expert** agent
  - Create the DAG file following Airflow conventions
  - Include error handling, retries, SLAs

- **dbt Models** → delegate to **dbt-expert** agent
  - Create staging, intermediate, and mart models
  - Include schema.yml with tests and documentation

- **Ingestion Script** → delegate to **python-expert** agent
  - Python script for extraction
  - Include error handling and logging

- **Snowflake Objects** → delegate to **snowflake-expert** agent
  - DDL for schemas, tables, stages, file formats
  - RBAC grants

### 4. Verify

Delegate to the **verifier** agent:
- Check all files were created
- Validate DAG syntax
- Validate dbt project compiles
- Check for security issues (no hardcoded credentials)
- Verify naming conventions match standards

### 5. Summary

Present to the user:
- List of all files created
- Architecture diagram
- Next steps (connections to configure, credentials to set up, testing plan)
- Any assumptions made

## Workflow Graph

| Node | Agent | Depends On | Output |
|------|-------|-----------|--------|
| requirements | (direct) | — | Requirements clarified |
| design | (direct) | requirements | changes/pipeline-design.md |
| airflow_dag | airflow-expert | design | DAG file |
| dbt_models | dbt-expert | design | dbt models + schema.yml |
| ingestion | python-expert | design | Ingestion script |
| snowflake | snowflake-expert | design | DDL + RBAC |
| verify | verifier | airflow_dag, dbt_models, ingestion, snowflake | Verification report |
| summary | (direct) | verify | User-facing summary |

`airflow_dag`, `dbt_models`, `ingestion`, and `snowflake` all depend only on
`design` — delegate all four in parallel using multiple Task calls.

## Notes
- Always use the user's existing project structure
- Follow existing patterns and conventions
- Prefer incremental loads over full loads for large tables
- Every pipeline must be idempotent
- Every pipeline must have monitoring and alerting
