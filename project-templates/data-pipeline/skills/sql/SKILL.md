---
name: sql
description: Optimize, generate, or debug SQL queries
disable-model-invocation: true
argument-hint: "[optimize|generate|debug] [query or description]"
---

# SQL Skill

$ARGUMENTS

## Modes

### Optimize (when asked to optimize a query)

1. **Read the original query** carefully
2. **Analyze the execution plan:**
   ```sql
   EXPLAIN ANALYZE <query>;
   ```
3. **Identify bottlenecks:**
   - Sequential scans on large tables → add indexes
   - Nested loops on large joins → check join conditions and types
   - High row estimates vs actual → stale statistics
   - Sort/hash operations spilling to disk → memory settings or query rewrite
4. **Rewrite with optimizations:**
   - Replace subqueries with CTEs or JOINs
   - Add WHERE clauses to filter early
   - Use window functions instead of self-joins
   - Materialize expensive CTEs if referenced multiple times
   - Push filters into subqueries/CTEs
5. **Compare before/after:** Run EXPLAIN ANALYZE on both and show the difference

### Generate (when asked to write a query)

1. **Understand the data model** — Read relevant schema files, dbt models, or ask
2. **Clarify the question** — What exactly should the query return?
3. **Write the query:**
   - Use CTEs for complex logic (one CTE per logical step)
   - Lowercase keywords, snake_case identifiers
   - One column per line in SELECT
   - Qualify all column names in JOINs
   - Add comments for non-obvious logic
4. **Include sample output** — Show what the result should look like
5. **Add edge case handling** — NULLs, empty results, division by zero

### Debug (when asked to fix a query)

1. **Understand the error** — Read the error message carefully
2. **Check common issues:**
   - Column name typos or ambiguous references
   - Type mismatches in JOINs or WHERE
   - GROUP BY missing non-aggregated columns
   - NULL handling (use COALESCE, IS NULL, etc.)
   - Window function frame specification
3. **Fix and explain** — Show the fix and why it was wrong

## Conventions
- Lowercase keywords: `select`, `from`, `where`, `join`
- snake_case identifiers: `user_events`, `created_at`
- CTEs over subqueries: readable, testable, reusable
- Explicit JOIN types: `inner join`, `left join` — never implicit
- One column per line in SELECT for clean diffs
- Always qualify columns in JOINs: `t1.id`, not just `id`
