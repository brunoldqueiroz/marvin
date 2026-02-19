# dbt Rules

## Conventions

### Model Naming
- **Staging models**: `stg_<source>__<entity>.sql` (e.g., `stg_salesforce__accounts.sql`)
- **Intermediate models**: `int_<entity>__<description>.sql` (e.g., `int_orders__pivoted.sql`)
- **Fact tables**: `fct_<entity>.sql` (e.g., `fct_orders.sql`)
- **Dimension tables**: `dim_<entity>.sql` (e.g., `dim_customers.sql`)
- **Mart models**: descriptive business names (e.g., `customer_lifetime_value.sql`)

### Source Naming
- Define all sources in `sources.yml` with `src_` prefix in staging layer references
- Source table names should match exactly as they appear in the database
- Group sources by data platform or domain (e.g., `salesforce`, `stripe`, `internal`)

### File Organization
```
models/
├── staging/
│   ├── <source_name>/
│   │   ├── _<source>__sources.yml
│   │   ├── _<source>__models.yml
│   │   └── stg_<source>__<entity>.sql
├── intermediate/
│   ├── <domain>/
│   │   ├── _int_<domain>__models.yml
│   │   └── int_<entity>__<description>.sql
└── marts/
    ├── <business_area>/
    │   ├── _<business_area>__models.yml
    │   ├── fct_<entity>.sql
    │   └── dim_<entity>.sql
```

### Naming Standards
- **snake_case** for all identifiers (files, models, columns, macros)
- One model per file, filename must match model name exactly
- Boolean columns: prefix with `is_` or `has_` (e.g., `is_active`, `has_trial`)
- Timestamp columns: suffix with `_at` (e.g., `created_at`, `updated_at`)
- Date columns: suffix with `_date` (e.g., `order_date`, `birth_date`)
- Primary keys: `<entity>_id` (e.g., `order_id`, `customer_id`)

### References
- **Always use `ref()`** for internal dbt models (never hardcode table names)
- **Always use `source()`** for raw data tables (never hardcode source tables)
- Never hardcode database or schema names in SELECT statements
- Use `{{ target.schema }}` or `{{ target.database }}` for dynamic references

## SQL Style

### Keywords and Formatting
- Lowercase keywords: `select`, `from`, `where`, `join`, `group by`, `order by`
- One column per line in `select` statements for readability and clean diffs
- Trailing commas on all lines except the last
- Indent nested queries and CTEs consistently (4 spaces)

### CTEs Over Subqueries
```sql
-- GOOD: Use CTEs
with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
)

select
    orders.order_id,
    customers.customer_name,
    orders.order_total
from orders
inner join customers
    on orders.customer_id = customers.customer_id

-- BAD: Nested subqueries
select
    o.order_id,
    c.customer_name,
    o.order_total
from (select * from raw.orders) o
inner join (select * from raw.customers) c
    on o.customer_id = c.customer_id
```

### Joins
- Always use explicit `inner join`, `left join`, `right join`, `full outer join`
- Never use implicit joins (comma-separated tables in FROM)
- Always qualify column names in joins: `table.column`
- Put join conditions on separate lines for readability

### Column Selection
- Be explicit in `select` statements (avoid `select *` in marts)
- `select *` is acceptable in staging models only (1:1 with source)
- Order columns logically: IDs, dimensions, metrics, timestamps

## Testing

### Required Tests
- **Every model** must have a `unique` test on its primary key
- **Every model** must have a `not_null` test on its primary key
- Foreign keys must have `relationships` tests
- Required business columns must have `not_null` tests

### Test Types
```yaml
# schema.yml
models:
  - name: fct_orders
    description: "Order facts table"
    columns:
      - name: order_id
        description: "Primary key"
        tests:
          - unique
          - not_null

      - name: customer_id
        description: "Foreign key to customers"
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id

      - name: order_status
        description: "Status of the order"
        tests:
          - not_null
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']

      - name: order_total
        description: "Total order amount"
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1000000
```

### Test Packages
- Use `dbt-utils` for common test patterns
- Use `dbt-expectations` for advanced data quality tests
- Create custom generic tests in `tests/generic/` for reusable business logic
- Singular tests in `tests/` for one-off validation queries

## Materialization

### Strategy by Layer
- **Staging**: `view` (lightweight, no Snowflake storage cost)
- **Intermediate**: `ephemeral` (compiled into dependent models) or `view`
- **Marts (dimensions)**: `table` (faster query performance)
- **Marts (facts)**: `table` or `incremental` (use incremental for large tables)

### Incremental Models
```sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='fail',
        incremental_strategy='merge',
        cluster_by=['order_date']
    )
}}

select
    order_id,
    customer_id,
    order_date,
    order_total,
    updated_at
from {{ source('raw', 'orders') }}

{% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

### Snowflake-Specific Optimizations
- Use `cluster_by` for large tables with common filter columns
- Use `transient=true` for tables that don't need Fail-safe (7-day recovery)
- Consider `secure=true` for tables with sensitive data (disables query preview)
- Use `copy_grants=true` to maintain grants during full-refreshes

### Materialization Best Practices
- Always define `on_schema_change` for incremental models: `fail`, `append_new_columns`, or `sync_all_columns`
- Always define `unique_key` for incremental models using merge strategy
- Use `delete+insert` strategy only when merge is not suitable
- Test incremental logic with `dbt run --full-refresh` regularly

## Documentation

### Model Documentation
```yaml
# models/marts/finance/_finance__models.yml
version: 2

models:
  - name: fct_orders
    description: >
      Order facts table containing one row per order with associated
      customer, product, and financial metrics. Updated daily at 6am UTC.

    meta:
      owner: "data-team@company.com"
      refresh_schedule: "daily"

    columns:
      - name: order_id
        description: "Unique identifier for each order (primary key)"
        tests:
          - unique
          - not_null

      - name: customer_id
        description: "Foreign key to dim_customers"

      - name: order_total_usd
        description: >
          Total order value in USD, including taxes and shipping.
          Excludes refunds and discounts.
```

### Documentation Requirements
- Every model must have a description in `schema.yml`
- Every column in marts must have a description
- Use doc blocks (`{% docs %}`) for complex explanations that are reused
- Maintain `sources.yml` for every external data source
- Document freshness expectations for critical sources

### Doc Blocks
```sql
-- models/docs.md
{% docs order_status_logic %}
Order status is derived from the following rules:
- `pending`: Order created but not paid
- `paid`: Payment confirmed
- `shipped`: Order dispatched from warehouse
- `delivered`: Confirmed delivery to customer
- `cancelled`: Customer or system cancellation
{% enddocs %}
```

## Patterns

### Surrogate Keys
```sql
-- Use dbt_utils for consistent hashing
{{ dbt_utils.generate_surrogate_key(['customer_id', 'order_date']) }} as order_key
```

### Date Spine
```sql
-- Generate continuous date series for gap filling
{{ dbt_utils.date_spine(
    datepart="day",
    start_date="cast('2020-01-01' as date)",
    end_date="current_date()"
) }}
```

### Incremental Models
```sql
-- Use is_incremental() macro for conditional logic
{% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

### Column Pivoting
```sql
-- Use dbt_utils.pivot for dynamic pivots
{{ dbt_utils.pivot(
    column='metric_name',
    values=dbt_utils.get_column_values(ref('metrics'), 'metric_name'),
    agg='sum',
    then_value='metric_value'
) }}
```

### Pre/Post Hooks
```sql
-- Grant permissions after model runs
{{
    config(
        post_hook=[
            "grant select on {{ this }} to role reporter",
            "grant select on {{ this }} to role analyst"
        ]
    )
}}
```

### Model Tagging
```sql
-- Tag models for selective runs
{{
    config(
        tags=['daily', 'finance', 'pii']
    )
}}

-- Run with: dbt run --select tag:daily
```

### Snapshots for SCD Type 2
```sql
-- snapshots/orders_snapshot.sql
{% snapshot orders_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='order_id',
        strategy='timestamp',
        updated_at='updated_at',
    )
}}

select * from {{ source('raw', 'orders') }}

{% endsnapshot %}
```

## Anti-patterns

### Never Do This
- **Don't hardcode database/schema names**: Use `{{ target.database }}`, `{{ target.schema }}`, or `ref()`/`source()`
- **Don't skip ref()**: Never use raw table names for dbt models (`select * from analytics.fct_orders` → `select * from {{ ref('fct_orders') }}`)
- **Don't materialize staging as table**: Staging should be lightweight views (wasteful storage costs)
- **Don't use SELECT * in marts**: Be explicit about columns for maintainability and performance
- **Don't put business logic in staging**: Staging is 1:1 with source (renaming/casting only)
- **Don't create circular dependencies**: Models should form a DAG (directed acyclic graph)
- **Don't use incremental without unique_key**: Merge strategy requires a reliable unique identifier
- **Don't ignore on_schema_change**: Always define behavior for schema changes in incremental models
- **Don't overuse Jinja**: Keep SQL readable; extract complex macros to `macros/` directory

### Avoid These Patterns
- **Overly complex CTEs**: Break large models into intermediate models instead
- **Nested CTEs**: Keep CTEs at the top level; use intermediate models for complexity
- **Implicit joins**: Always use explicit `inner join`, `left join`, etc.
- **Mixing grain**: Ensure each model has a clear grain (one row per...)
- **Untested models**: Every model should have at least primary key tests
- **Undocumented models**: Every model should have a description
- **Generic model names**: Use descriptive names that convey business meaning
- **Mixing concerns**: Keep data loading (staging), transformation (intermediate), and business logic (marts) separate
- **Running full DAG unnecessarily**: Use `dbt run --select` to run subsets during development

### Common Mistakes
```sql
-- BAD: Hardcoded table names
select * from raw.salesforce.accounts

-- GOOD: Use source()
select * from {{ source('salesforce', 'accounts') }}

-- BAD: No grain definition
-- What does one row represent?

-- GOOD: Clear grain in description
-- One row per customer per day

-- BAD: Business logic in staging
select
    account_id,
    case when status = 'A' then 'Active' else 'Inactive' end as status_label
from {{ source('salesforce', 'accounts') }}

-- GOOD: Business logic in intermediate/marts
-- Staging: 1:1 with source
select
    account_id,
    status
from {{ source('salesforce', 'accounts') }}
```

## Performance Tips

### Snowflake Optimization
- Use `cluster_by` on large tables with common filter patterns
- Use `transient=true` for non-critical tables to save costs
- Partition incremental models by date when possible
- Use `query_tag` config for cost attribution and monitoring
- Leverage Snowflake's result cache with deterministic queries

### Query Optimization
- Filter early in CTEs to reduce data volume
- Use `where` before `group by` when possible
- Avoid `distinct` when `group by` suffices
- Use window functions efficiently (partition wisely)
- Pre-aggregate in intermediate models instead of complex mart queries

### Development Workflow
- Use `dbt run --select model_name+` to run a model and its downstream dependencies
- Use `dbt run --select +model_name` to run a model and its upstream dependencies
- Use `--defer` flag to run only modified models against production
- Use `--fail-fast` to stop execution on first failure
- Leverage `state:modified+` for CI/CD selective runs
