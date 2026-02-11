# Project Context

This is a **data pipeline** project.

## Tech Stack
- **Language:** Python
- **Orchestration:** [Airflow / Prefect / Dagster — detect or ask]
- **Transformation:** [dbt / Spark / plain SQL — detect or ask]
- **Warehouse:** [PostgreSQL / BigQuery / Snowflake / DuckDB — detect or ask]
- **Data Quality:** [Great Expectations / Soda / dbt tests — detect or ask]

## Architecture
```
Sources → Ingestion → Staging → Transformation → Marts → Serving
```
- **Sources:** [describe source systems]
- **Staging:** Raw data landed as-is, append-only
- **Transformation:** Business logic applied, tested, documented
- **Marts:** Final tables consumed by downstream (BI, ML, APIs)

## Conventions
- SQL: lowercase keywords, snake_case identifiers, CTEs over subqueries
- Python: type hints, ruff formatting, pathlib
- dbt: `stg_` → `int_` → `fct_`/`dim_` naming convention
- Tests required for every new model/pipeline
- Incremental loads preferred over full refreshes

## Project-Specific Agents
@.claude/registry/agents.md

## Project-Specific Skills
@.claude/registry/skills.md

## Domain Rules
@.claude/rules/data-engineering.md
