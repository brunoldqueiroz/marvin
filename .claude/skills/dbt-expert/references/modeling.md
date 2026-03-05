# dbt Expert — Modeling Reference

## Incremental Strategy Details (Best Practice #2-3)

### Strategy selection guide

| Table size | Pattern | Strategy | Notes |
|------------|---------|----------|-------|
| <50M rows | Any | `merge` | Simple, safe default |
| >100M rows | Time-series | `merge` + `incremental_predicates` | Limits merge scan window |
| Append-only events | Immutable events | `append` | Fastest, no duplicate check |
| Large time-series (dbt 1.9+) | Daily batches | `microbatch` | Native batch processing |

### `merge` with `incremental_predicates`

```sql
{{
  config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    incremental_predicates=[
      "DBT_INTERNAL_DEST.updated_at >= dateadd(day, -3, current_date)"
    ]
  )
}}

SELECT order_id, customer_id, amount, status, updated_at
FROM {{ ref('stg_stripe__orders') }}
{% if is_incremental() %}
  WHERE updated_at >= (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

The predicate limits the target table scan to recent partitions.
Use a 3-day lookback to handle late-arriving data safely.

### Always wrap incremental filters

```sql
-- Correct: filter only applies during incremental runs
{% if is_incremental() %}
  WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}

-- Wrong: filter always applies, full refresh loads nothing
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
```

Without the `{% if is_incremental() %}` guard, full-refresh runs (`dbt run
--full-refresh`) will fail or return empty results because `{{ this }}` is
empty at the start of a full refresh.

## Testing Strategy Details (Best Practice #4)

### Test coverage by layer

**Staging layer** — schema correctness:
```yaml
models:
  - name: stg_stripe__orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: status
        tests:
          - not_null
      - name: amount
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
```

**Intermediate layer** — row count integrity:
```yaml
models:
  - name: int_orders_with_customers
    tests:
      - dbt_utils.equal_rowcount:
          compare_model: ref('stg_stripe__orders')
```

**Marts layer** — full coverage:
```yaml
models:
  - name: fct_revenue
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: customer_id
        tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'completed', 'refunded', 'failed']
```

## Documentation Conventions (Best Practice #5)

### Model and column descriptions

Every mart model must have a model-level description and column descriptions:

```yaml
models:
  - name: fct_revenue
    description: >
      One row per completed order. Primary grain is order_id.
      Excludes test orders and internal staff orders.
    meta:
      owner: data-platform@company.com
    columns:
      - name: order_id
        description: "Unique identifier for the order. Natural key from Stripe."
```

### Doc blocks for shared columns

For columns repeated across 3+ models (e.g., `created_at`, `updated_at`,
`customer_id`), use `{% docs %}` blocks in a `docs/` directory:

```
-- models/docs/shared_columns.md
{% docs customer_id %}
Unique identifier for the customer account. Sourced from the CRM system.
Joins to `dim_customers.customer_id`.
{% enddocs %}
```

Reference in YAML:
```yaml
- name: customer_id
  description: "{{ doc('customer_id') }}"
```

`meta.owner` is required on all public-facing marts — used by
dbt-project-evaluator and for data stewardship accountability.

## dbt-project-evaluator (Best Practice #6)

Install in `packages.yml`:
```yaml
packages:
  - package: dbt-labs/dbt_project_evaluator
    version: [">=0.8.0", "<0.9.0"]
```

Configure in `dbt_project.yml` or a dedicated var file:
```yaml
vars:
  dbt_project_evaluator:
    test_coverage_target: 80       # % of models with tests
    documentation_coverage_target: 90  # % of models with descriptions
    # Exclude staging from documentation requirement (optional)
    models_to_exclude_from_documentation: ["^stg_"]
```

Run in CI:
```bash
dbt run --select package:dbt_project_evaluator
dbt test --select package:dbt_project_evaluator
```

Failures block merge. Common violations: models with no tests, marts with no
descriptions, sources used directly in marts (bypassing staging).

## Package Management (Best Practice #7)

Pin packages with version ranges in `packages.yml`:
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.1.0", "<2.0.0"]
  - package: calogica/dbt_expectations
    version: [">=0.9.0", "<1.0.0"]
  - package: dbt-labs/dbt_project_evaluator
    version: [">=0.8.0", "<0.9.0"]
```

Core packages every project should consider:
- `dbt-utils`: surrogate keys, union relations, date spine, pivot, safe math
- `dbt-expectations`: Great Expectations-style tests (value ranges, regex, row counts)
- `dbt-project-evaluator`: governance and coverage enforcement in CI

After updating `packages.yml`, run `dbt deps` to install. Commit
`package-lock.yml` (dbt 1.7+) for reproducible installs.

## Clustering/Partitioning Config (Best Practice #8)

Set via `config()` in model SQL or in `dbt_project.yml`:

```sql
-- In model SQL (preferred for model-specific config)
{{
  config(
    materialized='table',
    cluster_by=['event_date', 'event_type'],
    partition_by={
      "field": "event_date",
      "data_type": "date",
      "granularity": "day"
    }
  )
}}
```

Cluster on columns that appear in WHERE predicates and JOIN conditions.
Date columns and high-cardinality categorical keys are ideal.

For Snowflake: `cluster_by` maps to `CLUSTER BY (col1, col2)`.
For BigQuery: use `partition_by` for date partitioning and `cluster_by` for
up to 4 clustering columns.

## Unit Tests (dbt 1.8+) (Best Practice #10)

Define unit tests in YAML to test model SQL logic with mocked inputs:

```yaml
unit_tests:
  - name: test_revenue_excludes_refunds
    model: fct_revenue
    given:
      - input: ref('int_orders_with_payments')
        rows:
          - {order_id: 1, amount: 100, status: 'completed'}
          - {order_id: 2, amount: 50,  status: 'refunded'}
    expect:
      rows:
        - {order_id: 1, revenue: 100}
        # order_id 2 excluded because status = 'refunded'
```

Run with: `dbt test --select test_type:unit`

Use unit tests for:
- Models with conditional logic (CASE WHEN, IIF)
- Aggregation and windowing logic
- Surrogate key generation edge cases

Do NOT use for integration tests (use data tests for those). Unit tests run
against mocked data, not the actual warehouse.

## Troubleshooting Details

### Error: Incremental model reprocesses all rows on every run

Cause: Missing `{% if is_incremental() %}` guard — the WHERE clause runs
on every build including full refresh, or is absent when it should filter.

Solution:
```sql
-- Always guard the incremental filter
{% if is_incremental() %}
  WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

Verify: run `dbt run --select model_name` and check `INFORMATION_SCHEMA.QUERY_HISTORY`
for rows processed. On incremental run it should be much less than total rows.

### Error: Source freshness check fails with "Could not find loaded_at_field"

Cause: The `loaded_at_field` column name doesn't match the actual column in
the source table, or the source YAML is missing the `freshness` block.

Solution:
```yaml
sources:
  - name: stripe
    tables:
      - name: orders
        loaded_at_field: _fivetran_synced   # must match actual column name
        freshness:
          warn_after: {count: 6, period: hour}
          error_after: {count: 24, period: hour}
```

Verify the column exists: `SELECT _fivetran_synced FROM stripe.orders LIMIT 1`.

### Error: Duplicate rows appearing in mart models

Cause: Missing primary key tests allowed duplicates to propagate, or a join
produced a fan-out (many-to-many join without deduplication).

Solution:
1. Add `unique` + `not_null` tests on every model's PK — catch this early
2. For fan-out: compare row counts before/after join in intermediate model
3. Add `dbt_utils.equal_rowcount` test on intermediate if joining two sources
4. Use `QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1`
   to deduplicate before joining
