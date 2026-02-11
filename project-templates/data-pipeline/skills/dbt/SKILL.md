---
name: dbt
description: Generate dbt models, tests, and documentation
disable-model-invocation: true
argument-hint: "[model name or description]"
---

# dbt Skill

$ARGUMENTS

## Process

### 1. Understand the Requirement

Determine what's needed:
- **New model** — Create from scratch based on description
- **Modify model** — Read existing model first, then change
- **Add tests** — Read model, add appropriate schema tests
- **Generate docs** — Read model, write schema.yml descriptions

### 2. Identify the Model Layer

Based on the data flow, determine where this model fits:

| Layer | Prefix | Purpose | Example |
|-------|--------|---------|---------|
| Staging | `stg_` | 1:1 with source. Rename, retype, clean. | `stg_stripe_payments` |
| Intermediate | `int_` | Business logic, joins, filters. | `int_payments_with_customers` |
| Fact | `fct_` | Immutable events at a specific grain. | `fct_orders` |
| Dimension | `dim_` | Descriptive attributes of entities. | `dim_customers` |

### 3. Create the Model

**Staging models (`stg_`):**
```sql
with source as (
    select * from {{ source('source_name', 'table_name') }}
),

renamed as (
    select
        -- rename to snake_case, cast types
        id as payment_id,
        amount::numeric(10,2) as payment_amount,
        created::timestamp as created_at
    from source
)

select * from renamed
```

**Intermediate models (`int_`):**
```sql
with payments as (
    select * from {{ ref('stg_stripe_payments') }}
),

customers as (
    select * from {{ ref('stg_app_customers') }}
),

joined as (
    select
        p.payment_id,
        p.payment_amount,
        c.customer_name,
        c.customer_segment
    from payments as p
    inner join customers as c
        on p.customer_id = c.customer_id
)

select * from joined
```

**Mart models (`fct_`/`dim_`):**
- Aggregations, final business logic
- Should be consumption-ready (no further joins needed by analysts)
- Document the grain explicitly in a comment

### 4. Add Schema Tests

Create or update `schema.yml` alongside the model:

```yaml
models:
  - name: model_name
    description: "Clear description of what this model represents"
    columns:
      - name: primary_key_column
        description: "Description"
        data_tests:
          - unique
          - not_null
      - name: foreign_key_column
        description: "Description"
        data_tests:
          - not_null
          - relationships:
              to: ref('related_model')
              field: id
      - name: status_column
        data_tests:
          - accepted_values:
              values: ['active', 'inactive', 'pending']
```

**Minimum tests per model:**
- `unique` + `not_null` on primary key (mandatory)
- `not_null` on required business columns
- `relationships` on foreign keys
- `accepted_values` on status/category columns

### 5. Add Sources (if new source)

Create or update `sources.yml`:

```yaml
sources:
  - name: source_name
    description: "Description of the source system"
    database: "{{ env_var('DB_NAME', 'dev') }}"
    schema: raw
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    tables:
      - name: table_name
        description: "Description"
        loaded_at_field: updated_at
```

### 6. Validate

Run dbt commands to validate:

```bash
# Compile to check SQL syntax
dbt compile --select model_name

# Run the model
dbt run --select model_name

# Run tests
dbt test --select model_name

# Build everything (run + test)
dbt build --select +model_name
```

### 7. Document

Ensure the model has:
- Clear `description` in schema.yml
- Column descriptions for all columns
- Grain documented in the model's SQL as a comment
- Dependencies visible via `ref()` and `source()`
