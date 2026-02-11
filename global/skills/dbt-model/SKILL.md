---
name: dbt-model
description: Generate dbt models with proper layering, tests, and documentation
disable-model-invocation: true
argument-hint: "[model name and description - e.g., 'customers from source CRM']"
---

# dbt Model Generator

Model request: $ARGUMENTS

## Process

### 1. Understand the Requirement

Before generating, determine:
- **Source**: What source table(s)? Are they already defined in sources.yml?
- **Layer**: Which layer? (staging, intermediate, marts)
- **Grain**: What is one row? (one customer, one order, one event)
- **Business Logic**: What transformations are needed?
- **Consumers**: Who will use this model? (analysts, dashboards, other models)

If the layer isn't specified:
- If it's a 1:1 mapping of a source → **staging** (stg_)
- If it combines multiple staging models → **intermediate** (int_)
- If it's business-ready (fact/dimension) → **marts** (fct_ or dim_)

### 2. Generate the Model

Delegate to the **dbt-expert** agent with these instructions:

#### For Staging Models (stg_)
Create:
1. `models/staging/<source>/stg_<source>__<entity>.sql`
   - SELECT from {{ source('source_name', 'table_name') }}
   - Rename columns to snake_case
   - Cast to correct types
   - Trim strings, lowercase where appropriate
   - Materialized as view
2. `models/staging/<source>/_<source>__sources.yml` (if not exists)
   - Define the source with database, schema, table
3. `models/staging/<source>/_<source>__models.yml`
   - Model description, column descriptions
   - Tests: unique + not_null on primary key

#### For Intermediate Models (int_)
Create:
1. `models/intermediate/<domain>/int_<domain>__<description>.sql`
   - JOINs between staging models using {{ ref() }}
   - Business logic applied here
   - Materialized as ephemeral or view
2. `models/intermediate/<domain>/_int_<domain>__models.yml`
   - Description, column docs, tests

#### For Mart Models (fct_ / dim_)
Create:
1. `models/marts/<domain>/fct_<entity>.sql` or `dim_<entity>.sql`
   - Surrogate key with dbt_utils.generate_surrogate_key
   - Business-ready columns with clear names
   - Materialized as table (or incremental for large facts)
2. `models/marts/<domain>/_<domain>__models.yml`
   - Full documentation for business users
   - Tests: unique, not_null, relationships, accepted_values

### 3. Generate Tests

For every model, ensure at minimum:
```yaml
models:
  - name: <model_name>
    description: "<clear business description>"
    columns:
      - name: <primary_key>
        description: "Primary key"
        tests:
          - unique
          - not_null
      - name: <foreign_key>
        tests:
          - relationships:
              to: ref('<parent_model>')
              field: <parent_key>
```

### 4. Verify

Delegate to the **verifier** agent:
- Check SQL compiles (no syntax errors)
- Check all ref() and source() references exist
- Check naming follows conventions (stg_, int_, fct_, dim_)
- Check tests are defined
- Check documentation exists in schema.yml

### 5. Summary

Show the user:
- Files created (with paths)
- Model lineage (what it depends on, what depends on it)
- Tests included
- Suggested next steps (run dbt build, add more tests, etc.)

## Notes
- Always check existing project structure first
- Reuse existing sources.yml if the source is already defined
- Follow the project's existing dbt conventions
- Use {{ ref() }} for all internal references
- Never hardcode database or schema names
