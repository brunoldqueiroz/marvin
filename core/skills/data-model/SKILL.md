---
name: data-model
description: Design dimensional data models (star schema, snowflake schema, Data Vault)
disable-model-invocation: true
argument-hint: "[domain and description - e.g., 'e-commerce orders and customers']"
---

# Data Model Designer

Modeling request: $ARGUMENTS

## Process

### 1. Understand the Domain

Before modeling, clarify:
- **Business domain**: What area? (sales, marketing, finance, operations)
- **Key business questions**: What do stakeholders want to answer?
- **Source systems**: Where does the data come from?
- **Grain**: What is the lowest level of detail needed?
- **Modeling approach**: Star schema (default), snowflake schema, or Data Vault?
- **Target platform**: Snowflake (default)

If any are unclear from $ARGUMENTS, ask the user.

### 2. Identify Entities

Analyze the domain and identify:
- **Facts**: Events/transactions (orders, clicks, payments, shipments)
- **Dimensions**: Entities/context (customers, products, dates, locations)
- **Measures**: What's being counted/summed (amount, quantity, duration)
- **Attributes**: Descriptive fields on dimensions
- **Relationships**: How entities connect (1:1, 1:N, N:N)

### 3. Design the Model

Create a design document at `changes/data-model-design.md`:

```markdown
# Data Model: <Domain>

## Business Questions
- [Question 1 this model answers]
- [Question 2]

## Entity-Relationship Diagram
```
[dim_customer] ──1:N──┐
                       ├── [fct_orders] ──N:1── [dim_product]
[dim_date] ────1:N─────┘
```

## Fact Tables
### fct_<entity>
| Column | Type | Description |
|--------|------|-------------|
| surrogate_key | varchar | PK (surrogate) |
| customer_key | varchar | FK to dim_customer |
| order_date_key | date | FK to dim_date |
| amount | number(18,2) | Order total |

**Grain**: One row per order
**Materialization**: incremental (merge on surrogate_key)

## Dimension Tables
### dim_<entity>
| Column | Type | Description | SCD Type |
|--------|------|-------------|----------|
| surrogate_key | varchar | PK (surrogate) | - |
| natural_key | varchar | Business key | - |
| name | varchar | Display name | Type 2 |
| status | varchar | Current status | Type 1 |

**Materialization**: table
```

### 4. Generate DDL and dbt Models

Delegate to specialized agents:

- **Snowflake DDL** → delegate to **snowflake-expert** agent
  - CREATE TABLE statements for all fact and dimension tables
  - Proper data types for Snowflake (VARCHAR, NUMBER, TIMESTAMP_NTZ, etc.)
  - Clustering keys on large tables

- **dbt Models** → delegate to **dbt-expert** agent
  - Staging models for each source
  - Intermediate models for joining/enrichment
  - Mart models for each fact and dimension
  - schema.yml with tests and documentation
  - Surrogate keys using dbt_utils.generate_surrogate_key

### 5. Generate Documentation

Create:
- Data dictionary (all tables, columns, descriptions)
- Lineage diagram (sources → staging → intermediate → marts)
- Business glossary (key terms and definitions)

### 6. Verify

Delegate to the **verifier** agent:
- Check referential integrity (all FKs point to valid PKs)
- Check naming conventions (fct_, dim_, stg_, int_)
- Check all required tests exist (unique, not_null on PKs)
- Check documentation completeness
- Check Snowflake data types are appropriate

### 7. Summary

Present to the user:
- Entity-relationship diagram
- List of all tables with grain and materialization
- Files created
- Key design decisions and trade-offs
- Suggested next steps

## Modeling Principles
- Start with the business questions, not the source data
- Every fact table has a clear grain (one row = one _____)
- Every dimension has a surrogate key (not natural key as PK)
- Date dimension is almost always needed
- Prefer star schema unless there's a clear reason for snowflake or Data Vault
- Conformed dimensions shared across fact tables
- Slowly Changing Dimensions: Type 1 for non-historical, Type 2 for historical
- Keep it simple — only model what's needed now
