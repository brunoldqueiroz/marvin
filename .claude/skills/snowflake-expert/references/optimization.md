# Snowflake Expert — Optimization Reference

## Warehouse Sizing Details (Best Practice #1-2)

### Single-cluster sizing

Start at XS or S and scale based on Query Profile evidence, not guesswork.

| Signal in Query Profile | Recommendation |
|-------------------------|----------------|
| Spilling to local disk  | Scale up (need more memory) |
| Spilling to remote disk | Scale up significantly |
| High queuing time       | Add cluster (concurrency) |
| Low warehouse utilization | Scale down |

`AUTO_SUSPEND` tuning:
- ETL/batch: 60s (bursty, no cache benefit)
- BI dashboards: 300s (repeated queries benefit from result cache warmth)
- Ad-hoc: 120s (balance between cache and cost)

Always set `AUTO_RESUME = TRUE` and `INITIALLY_SUSPENDED = TRUE` on creation.

### Multi-cluster warehouses

Multi-cluster solves concurrency bottlenecks, not single-query performance.
If the bottleneck is a slow query, scale up. If many users queue, add clusters.

- `SCALING_POLICY = ECONOMY`: waits until cluster is fully loaded before adding.
  Better for batch workloads with variable concurrency.
- `SCALING_POLICY = STANDARD`: adds clusters more eagerly. Better for BI
  with latency-sensitive users.
- Recommended: `MIN_CLUSTER_COUNT = 1`, `MAX_CLUSTER_COUNT = 2` or `3`.
  Going above 4 usually signals a query optimization problem instead.

## Time Travel Configuration (Best Practice #3)

Set `DATA_RETENTION_TIME_IN_DAYS` per table based on business criticality.
Fail-safe adds 7 days of read-only recovery beyond Time Travel (Permanent tables only).

| Table Tier | Retention | Table Type | Notes |
|------------|-----------|------------|-------|
| Critical (raw, gold) | 30–90 days | Permanent | Maximum recovery window |
| Standard (silver) | 7 days | Permanent | Good balance of cost/recovery |
| Staging / transient | 0–1 day | TRANSIENT | No Fail-safe cost |
| Temp intermediates | 0 | TRANSIENT | Zero storage overhead |

`TRANSIENT` tables skip Fail-safe entirely — use for staging loads you can
replay from source. `TEMPORARY` tables exist only for the session.

## Streams and Tasks Details (Best Practice #4-5)

### Stream types

- **Standard stream**: captures `INSERT`, `UPDATE`, `DELETE` change metadata.
  Adds `METADATA$ACTION`, `METADATA$ISUPDATE`, `METADATA$ROW_ID` columns.
- **INSERT_ONLY stream**: only captures inserts; better performance for
  append-only ingestion pipelines where you never update/delete source rows.
- **Append-only stream** (on directory tables/external tables): inserts only.

Stream pointer advances only when the DML consuming the stream is committed
within the same transaction. If the transaction rolls back, the stream resets.

### Task DAG design

```sql
-- Root task: has SCHEDULE, no AFTER
CREATE TASK root_task
  SCHEDULE = 'USING CRON 0 * * * * UTC'
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
AS ...;

-- Child tasks: AFTER parent, no SCHEDULE
CREATE TASK child_task
  AFTER root_task
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
AS ...;

-- Resume in reverse order (children first, root last)
ALTER TASK child_task RESUME;
ALTER TASK root_task RESUME;
```

Always set `SUSPEND_TASK_AFTER_NUM_FAILURES = 3` to prevent runaway failures
billing continuously. Monitor with `TASK_HISTORY` view.

## Dynamic Tables (Best Practice #6)

Prefer Dynamic Tables over Streams+Tasks when:
- You need declarative ELT (define the query, not the pipeline)
- You don't need explicit change-type control (SCD2, conditional on DELETE vs UPDATE)
- Target latency is minutes, not seconds

Dynamic Tables handle their own incremental refresh logic. Use `TARGET_LAG`
to set acceptable staleness (e.g., `TARGET_LAG = '5 minutes'`).

Not appropriate when: you need to react differently to INSERTs vs DELETEs
(SCD2 patterns), or when you need sub-minute latency.

## VARIANT Access Patterns (Best Practice #7)

Always cast VARIANT extractions to concrete types to enable micro-partition pruning:

```sql
-- Bad: remains VARIANT, no pruning
SELECT v:user_id, v:created_at
FROM events;

-- Good: typed, enables pruning
SELECT v:user_id::NUMBER     AS user_id,
       v:created_at::DATE    AS event_date,
       v:event_type::STRING  AS event_type
FROM events;
```

FLATTEN anti-pattern — filter BEFORE flattening:

```sql
-- Bad: exponential row growth, then filter
SELECT f.value:tag::STRING
FROM events, LATERAL FLATTEN(input => v:tags) f
WHERE v:event_type::STRING = 'purchase';

-- Good: filter first, then flatten
SELECT f.value:tag::STRING
FROM events,
     LATERAL FLATTEN(input => v:tags) f
WHERE v:event_type::STRING = 'purchase';  -- same SQL but optimizer matters
-- Actually: use a subquery/CTE to filter first
WITH purchases AS (
  SELECT v FROM events WHERE v:event_type::STRING = 'purchase'
)
SELECT f.value:tag::STRING
FROM purchases, LATERAL FLATTEN(input => purchases.v:tags) f;
```

For hot VARIANT paths queried in >50% of queries, extract to typed columns:

```sql
ALTER TABLE events ADD COLUMN event_type STRING;
UPDATE events SET event_type = v:event_type::STRING;
-- Creates a proper typed column — 40-45% speedup on filter queries
```

## Query Optimization (Best Practice #8)

Key optimization techniques:

| Pattern | Bad | Good |
|---------|-----|------|
| Window function filter | `SELECT * FROM (SELECT ..., ROW_NUMBER() OVER (...) rn) WHERE rn = 1` | `SELECT ..., ROW_NUMBER() OVER (...) QUALIFY ROW_NUMBER() OVER (...) = 1` |
| Date functions on filter cols | `WHERE YEAR(created_at) = 2024` | `WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'` |
| Column selection | `SELECT *` | List only needed columns |
| Join order | Large table driven | Filter smaller table first |

`QUALIFY` clause eliminates a subquery layer for window function filtering —
cleaner and often faster.

Check micro-partition pruning in Query Profile: "Partitions scanned" should be
much less than "Partitions total" for selective queries.

## Cost Monitoring (Best Practice #10)

Key views to query regularly:

```sql
-- Warehouse spend by day
SELECT warehouse_name, DATE(start_time) AS day,
       SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP)
GROUP BY 1, 2 ORDER BY 3 DESC;

-- Most expensive queries
SELECT query_id, warehouse_name, total_elapsed_time/1000 AS seconds,
       credits_used_cloud_services, bytes_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP)
ORDER BY credits_used_cloud_services DESC LIMIT 20;

-- Clustering credit consumption
SELECT TABLE_NAME, DATE(START_TIME), SUM(CREDITS_USED)
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
GROUP BY 1, 2 ORDER BY 3 DESC;
```

Use Snowflake Budgets for serverless features (Snowpipe, Serverless Tasks,
Dynamic Tables) — these don't show in warehouse metering.

## Troubleshooting Details

### Error: Warehouse costs unexpectedly high despite low query volume

Cause: `AUTO_SUSPEND` set too high (warehouse idles for hours), or tasks
running on warehouse without `SYSTEM$STREAM_HAS_DATA` gate, billing 60-second
minimum on every schedule interval.

Solution:
1. Check `WAREHOUSE_METERING_HISTORY` to identify which warehouse is burning credits
2. Set `AUTO_SUSPEND = 60` for ETL, `300` for BI warehouses
3. Add resource monitors: `NOTIFY_USERS` at 75%, `SUSPEND` at 100%,
   `SUSPEND_IMMEDIATE` at 110%
4. Review all tasks: add `WHEN SYSTEM$STREAM_HAS_DATA('stream_name')` clause

### Error: Task runs every schedule interval but processes zero rows

Cause: Missing `WHEN SYSTEM$STREAM_HAS_DATA('stream_name')` condition — task
evaluates, starts warehouse, bills minimum, processes nothing.

Solution:
```sql
ALTER TASK my_task SUSPEND;
ALTER TASK my_task SET
  WHEN SYSTEM$STREAM_HAS_DATA('my_stream');
ALTER TASK my_task RESUME;
```
For serverless tasks, empty-stream runs are free. For warehouse tasks, this
avoids the 60-second minimum billing on every empty schedule interval.

### Error: Query not pruning micro-partitions despite WHERE clause

Cause: Functions applied to filter columns prevent the optimizer from using
micro-partition metadata (min/max values per partition).

Solution: Rewrite as range predicates:
```sql
-- Before (no pruning)
WHERE YEAR(created_at) = 2024 AND MONTH(created_at) = 3

-- After (full pruning)
WHERE created_at >= '2024-03-01' AND created_at < '2024-04-01'
```
Verify with `SYSTEM$CLUSTERING_INFORMATION('table', '(created_at)')` and
check "Partitions scanned vs total" in Query Profile.
