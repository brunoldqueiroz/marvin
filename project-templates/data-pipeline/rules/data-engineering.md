# Data Engineering Rules

## SQL Conventions
- Lowercase keywords (select, from, where, join)
- snake_case for all identifiers (tables, columns, schemas)
- CTEs over subqueries for readability
- Always qualify column names in JOINs
- Use explicit JOIN types (inner join, left join — never implicit comma joins)
- One column per line in SELECT for clean diffs
- Trailing commas in SELECT lists
- Always alias tables in JOINs

## Pipeline Patterns
- Prefer ELT over ETL (transform in the warehouse, not in Python)
- Idempotent operations always (use MERGE/upsert, DELETE+INSERT, or partition overwrite)
- Incremental loads over full refreshes when data volume > 1M rows
- Partition large tables by date (created_at or event_date)
- Add `created_at` and `updated_at` metadata columns to all tables
- Use surrogate keys (hash of business keys) for dimension tables
- Never modify raw/staging data — transformations happen downstream

## Data Modeling
- Star schema for analytics (fact + dimension tables)
- One grain per fact table — document the grain explicitly
- Conformed dimensions shared across fact tables
- Slowly Changing Dimensions Type 2 for historical tracking
- Use `_id` suffix for foreign keys, `_at` for timestamps, `is_` for booleans

## dbt Conventions
- Staging models: `stg_{source}_{table}` — 1:1 with source, rename + retype only
- Intermediate: `int_{description}` — business logic, joins, aggregations
- Facts: `fct_{event}` — immutable events at a specific grain
- Dimensions: `dim_{entity}` — descriptive attributes of entities
- One model per file, one test per model minimum
- Use `ref()` for all model references, `source()` for raw data
- Schema tests: `unique` + `not_null` on primary keys always
- Document all models in `schema.yml`

## Data Quality
- Not null constraints on primary keys and required fields
- Unique constraints on business keys
- Freshness checks on source data (alert if data is stale)
- Row count monitoring (alert on >20% deviation from expected)
- Schema drift detection (new/removed columns in sources)
- Validate data types at ingestion boundaries

## Orchestration
- DAGs should be idempotent and retryable
- Use date parameters for backfilling
- Separate extraction, transformation, and loading into distinct tasks
- Set meaningful timeouts and retries
- Alert on failure, not just log

## Anti-patterns (Avoid)
- SELECT * in production queries
- Implicit type conversions in JOINs
- Hardcoded dates or environment-specific values
- Circular dependencies between models
- Storing derived data as source of truth
- Running full refreshes on tables > 10M rows without reason
