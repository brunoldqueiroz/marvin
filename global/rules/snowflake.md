# Snowflake Rules

## Conventions

### Naming Standards
- **Databases**: UPPERCASE (e.g., `RAW`, `ANALYTICS`, `DEV`, `PROD`)
- **Schemas**: UPPERCASE (e.g., `STAGING`, `MARTS`, `SEEDS`, `SNAPSHOTS`)
- **Tables/Views**: snake_case (e.g., `dim_customer`, `fct_orders`, `stg_users`)
- **Columns**: snake_case (e.g., `customer_id`, `created_at`, `order_total`)
- **Warehouses**: UPPERCASE with purpose suffix (e.g., `ETL_WH`, `ANALYTICS_WH`, `DEV_WH`)
- **Roles**: UPPERCASE with purpose suffix (e.g., `ANALYST_ROLE`, `ETL_ROLE`, `ADMIN_ROLE`)
- **File Formats**: UPPERCASE (e.g., `CSV_FORMAT`, `PARQUET_FORMAT`)
- **Stages**: UPPERCASE (e.g., `S3_STAGE`, `AZURE_STAGE`)

### Architecture Layers
Use a three-tier layered architecture:

1. **RAW Layer** (`RAW` database)
   - Data as-is from sources (immutable)
   - No transformations applied
   - Preserve source structure and types
   - Use transient tables to reduce costs

2. **STAGING Layer** (`STAGING` database or schema)
   - Cleaned and typed data
   - Light transformations (type casting, deduplication)
   - Standardized column names
   - Data quality checks applied

3. **ANALYTICS Layer** (`ANALYTICS` database)
   - Business-ready models
   - Facts, dimensions, and aggregates
   - Optimized for analytics queries
   - Documented with business context

### Warehouse Separation
- **ETL_WH**: For data loading and transformation pipelines
- **ANALYTICS_WH**: For BI tools and analyst queries
- **DEV_WH**: For development and testing
- **DATASCIENCE_WH**: For ML and data science workloads

## Patterns

### Query Optimization
- **Column Pruning**: Select only needed columns, never `SELECT *` in production
- **Clustering Keys**: Use on large tables (>1TB) with clear access patterns
  - Choose columns frequently used in WHERE, JOIN, and ORDER BY
  - Limit to 3-4 columns maximum
  - Monitor clustering depth and reclustering costs
- **Result Caching**: Snowflake caches query results for 24 hours
  - Identical queries return instantly
  - Use consistent query patterns to leverage caching
- **QUALIFY Clause**: Use for window function filtering (Snowflake-specific optimization)
  ```sql
  select customer_id, order_date, row_number() over (partition by customer_id order by order_date desc) as rn
  from orders
  qualify rn = 1
  ```
- **LIMIT for Development**: Always use LIMIT during query development to avoid large result sets

### Data Loading Best Practices
- **COPY INTO**: Use for bulk batch loads from cloud storage
  ```sql
  copy into target_table
  from @s3_stage/path/
  file_format = (type = parquet)
  on_error = continue
  ```
- **Snowpipe**: Use for continuous/micro-batch streaming ingestion
- **MERGE**: Use for upsert patterns with deduplication
  ```sql
  merge into target using source
  on target.id = source.id
  when matched then update set ...
  when not matched then insert ...
  ```
- **Validation Mode**: Test COPY statements before full load
  ```sql
  copy into target_table
  from @stage
  validation_mode = return_errors
  ```

### Cost Management
- **Auto-Suspend**: Set aggressively to minimize idle costs
  - 60 seconds for interactive/development warehouses
  - 300 seconds (5 min) for ETL warehouses
- **Auto-Resume**: Always set to `true` for convenience
- **Right-Sizing**: Start with smaller warehouses, scale up as needed
  - XS/S for light queries and development
  - M/L for regular ETL workloads
  - XL+ for heavy transformations or large data volumes
- **Multi-Cluster Warehouses**: Use for high concurrency scenarios
  - Set min/max clusters based on expected load
  - Use with auto-scale mode
- **Resource Monitors**: Set up alerts and limits
  ```sql
  create resource monitor monthly_limit with
    credit_quota = 1000
    frequency = monthly
    triggers
      on 80 percent do notify
      on 100 percent do suspend
      on 110 percent do suspend_immediate;
  ```
- **Transient Tables**: Use for staging/intermediate data (no Fail-safe, 50% cost savings)
  ```sql
  create transient table staging.tmp_data as
  select * from raw.source_data;
  ```
- **Table Types by Use Case**:
  - Permanent: Production analytics tables requiring time travel + fail-safe
  - Transient: Staging, temp tables, easily reproducible data
  - Temporary: Session-specific work, automatically dropped

### Security & Access Control
- **Role Hierarchy**: Follow standard Snowflake RBAC pattern
  ```
  ACCOUNTADMIN (emergency only)
    └── SYSADMIN (infrastructure management)
        ├── ETL_ROLE (data pipeline operations)
        ├── ANALYST_ROLE (read access to analytics)
        └── DEVELOPER_ROLE (dev environment access)
  ```
- **Principle of Least Privilege**: Grant only necessary permissions
- **Never Use ACCOUNTADMIN**: For regular operations, only for account-level changes
- **Grant to Roles, Not Users**: Always assign privileges to roles, then roles to users
- **Secure Views**: Use for row/column-level security
  ```sql
  create secure view secure_customers as
  select * from customers
  where region = current_role();
  ```
- **Masking Policies**: Apply to PII columns
  ```sql
  create masking policy email_mask as (val string) returns string ->
    case
      when current_role() in ('ADMIN_ROLE') then val
      else '***@*****.com'
    end;

  alter table customers modify column email
    set masking policy email_mask;
  ```

### Advanced Patterns
- **Zero-Copy Cloning**: Create instant copies for dev/test without storage duplication
  ```sql
  create database dev clone prod;
  ```
- **Time Travel**: Recover from mistakes or access historical data (up to 90 days)
  ```sql
  select * from table_name at(offset => -60*5); -- 5 minutes ago
  select * from table_name before(statement => 'query_id');
  ```
- **Streams + Tasks**: Implement CDC (Change Data Capture) pipelines
  ```sql
  create stream customer_stream on table customers;

  create task process_changes
    warehouse = etl_wh
    schedule = '5 minute'
  when system$stream_has_data('customer_stream')
  as
    merge into target using customer_stream ...;
  ```
- **Dynamic Tables**: Declarative ELT with automatic refresh
  ```sql
  create dynamic table daily_sales
    target_lag = '1 hour'
    warehouse = etl_wh
  as
    select date, sum(amount) as total
    from orders
    group by date;
  ```
- **External Tables**: Query data in S3/Azure without loading
  ```sql
  create external table raw_logs
    with location = @s3_stage/logs/
    file_format = (type = parquet);
  ```
- **Materialized Views**: Pre-compute aggregations for frequently accessed queries
  ```sql
  create materialized view monthly_revenue as
  select date_trunc('month', order_date) as month,
         sum(amount) as revenue
  from fct_orders
  group by 1;
  ```

### Monitoring & Observability
- **Query History**: Monitor with `ACCOUNT_USAGE.QUERY_HISTORY`
  ```sql
  select query_text, warehouse_name, execution_time, credits_used
  from snowflake.account_usage.query_history
  where start_time >= dateadd(day, -7, current_timestamp())
  order by execution_time desc;
  ```
- **Warehouse Metering**: Track credit consumption
  ```sql
  select warehouse_name, sum(credits_used) as total_credits
  from snowflake.account_usage.warehouse_metering_history
  where start_time >= dateadd(day, -30, current_timestamp())
  group by warehouse_name
  order by total_credits desc;
  ```
- **Storage Usage**: Monitor table sizes and growth
  ```sql
  select table_catalog, table_schema, table_name,
         bytes / (1024*1024*1024) as size_gb
  from snowflake.account_usage.table_storage_metrics
  where deleted is null
  order by bytes desc;
  ```

## Anti-patterns

### Security Anti-patterns
- **Never use ACCOUNTADMIN for daily operations**: Reserve for account-level configuration only
- **Don't grant privileges directly to users**: Always use role-based access control
- **Never store credentials in Snowflake**: Use Snowflake secrets manager or external vaults
- **Don't share ACCOUNTADMIN credentials**: Each admin should have their own access

### Cost Anti-patterns
- **Don't leave warehouses running without auto-suspend**: Idle warehouses drain credits
- **Don't use XS warehouse for heavy ETL**: Causes disk spilling and query failures
- **Avoid excessive micro-partitioning**: Don't run many small inserts; batch them instead
- **Don't over-cluster**: Only cluster tables >1TB with proven access patterns
- **Never use XXL warehouses without analysis**: Often multiple M warehouses are more cost-effective

### Query Anti-patterns
- **Avoid SELECT * in production**: Wastes compute and network bandwidth
- **Don't use implicit joins**: Always use explicit `INNER JOIN`, `LEFT JOIN` syntax
- **Avoid unqualified column names in joins**: Always prefix with table/alias
- **Don't nest subqueries deeply**: Use CTEs for readability and maintainability
- **Never query without WHERE on large tables**: Always filter data appropriately

### Architecture Anti-patterns
- **Don't mix layers**: Keep RAW, STAGING, and ANALYTICS separate
- **Avoid updating RAW data**: RAW should be immutable
- **Don't create tables without schema planning**: Design before implementing
- **Never skip data quality checks**: Validate early in the pipeline
- **Avoid single-purpose databases**: Group related data logically

### Data Loading Anti-patterns
- **Don't use INSERT for bulk loads**: Use COPY INTO instead
- **Avoid loading CSV when Parquet is available**: Columnar formats are 10x faster
- **Don't skip file format objects**: Creates inconsistent parsing logic
- **Never ignore load errors**: Use `ON_ERROR` parameters and monitor failures
- **Avoid uncompressed files**: Always compress before loading (gzip, snappy, etc.)

### Development Anti-patterns
- **Don't develop directly in production**: Use DEV/TEST environments
- **Avoid hardcoded values**: Use variables and configuration tables
- **Don't skip testing**: Test transformations before deploying to production
- **Never commit without version control**: Track all DDL and DML changes
- **Avoid magic numbers**: Use named constants or configuration

## Performance Tuning Checklist

When optimizing slow queries:
1. Check query profile for bottlenecks (disk spilling, large scans)
2. Verify appropriate warehouse size for workload
3. Add clustering keys if table >1TB with clear access patterns
4. Ensure predicates are on clustered columns
5. Use column pruning (select only needed columns)
6. Leverage result caching with consistent query patterns
7. Consider materialized views for repeated aggregations
8. Partition large operations with date ranges
9. Use EXPLAIN to understand query plan
10. Monitor with QUERY_HISTORY for execution patterns
