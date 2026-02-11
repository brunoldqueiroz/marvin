# Airflow Rules

## Conventions

### File and Naming
- DAG files: `dag_<domain>_<action>.py` (e.g., `dag_sales_daily_load.py`, `dag_customer_churn_predict.py`)
- Task IDs: snake_case, descriptive, action-oriented (e.g., `extract_orders`, `transform_customers`, `load_to_warehouse`)
- DAG IDs: match filename without extension (e.g., `dag_sales_daily_load`)
- One DAG per file for clarity and maintainability
- Use tags for organization: `['team:data-eng', 'domain:sales', 'frequency:daily']`

### Configuration
- Always define explicit `default_args`:
  ```python
  default_args = {
      'owner': 'data-team',
      'retries': 3,
      'retry_delay': timedelta(minutes=5),
      'email_on_failure': True,
      'email': ['data-team@company.com'],
  }
  ```
- Set `catchup=False` unless backfill is explicitly required
- Set `max_active_runs=1` to prevent overlapping runs when needed
- Use explicit schedule intervals: cron expressions or timedelta objects
- Set `start_date` to a fixed date in the past (not `datetime.now()`)

### Code Organization
- Use TaskFlow API (`@task` decorator) for Python-based tasks
- Keep top-level DAG code lightweight (no heavy imports, DB queries, or computations at parse time)
- Import heavy libraries inside task functions, not at module level
- Use factory functions or Jinja templates for dynamic DAG generation
- Define dependencies explicitly with `>>` and `<<` operators

## Patterns

### DAG Design
- **Keep DAGs simple and linear** when possible
- Use **TaskGroup** for logical grouping of related tasks
- Define dependencies clearly:
  ```python
  extract >> transform >> load  # Linear
  [extract_a, extract_b] >> transform >> load  # Fan-in
  extract >> [transform_a, transform_b] >> load  # Fan-out
  ```
- Use **trigger rules** for complex flows:
  - `all_success` (default): run when all parents succeed
  - `one_success`: run when at least one parent succeeds
  - `none_failed`: run when no parent failed (skip is OK)
  - `all_done`: run regardless of parent status

### ELT Pattern
Standard data pipeline structure:
1. **Extract**: Sensors or operators to detect source data
2. **Load**: Move raw data to staging (S3, Snowflake staging)
3. **Transform**: Process with dbt or SQL operators

```python
@task
def extract_from_api():
    # Extract logic
    return s3_path

@task
def load_to_staging(s3_path: str):
    # Load to warehouse staging
    return staging_table

@task
def transform_in_warehouse(staging_table: str):
    # Run dbt or SQL transformations
    pass

extract_from_api() >> load_to_staging() >> transform_in_warehouse()
```

### Dynamic Task Mapping
For variable workloads (Airflow 2.3+):
```python
@task
def process_file(file_path: str):
    # Process single file
    pass

files = ['file1.csv', 'file2.csv', 'file3.csv']
process_file.expand(file_path=files)
```

### Branching
Use `BranchPythonOperator` for conditional logic:
```python
def check_data_quality(**context):
    if quality_check_passes():
        return 'load_to_prod'
    return 'send_alert'

branch = BranchPythonOperator(
    task_id='branch_on_quality',
    python_callable=check_data_quality,
)
```

### Idempotent Design
Every task must be safe to re-run:
```python
@task
def load_daily_data(execution_date):
    # Use execution_date for partitioning
    date_partition = execution_date.strftime('%Y-%m-%d')

    # Delete existing data for this partition
    DELETE FROM sales WHERE date = '{date_partition}'

    # Insert fresh data
    INSERT INTO sales SELECT * FROM staging WHERE date = '{date_partition}'
```

## Idempotency

### Core Principles
- Every task must produce the same result when re-run with the same inputs
- Use `logical_date` (Airflow 2.2+) or `execution_date` for time-based partitioning
- Never use `datetime.now()`, `datetime.today()`, or wall-clock time in task logic
- Prefer overwrite operations over append
- Use MERGE/UPSERT for incremental loads
- Implement delete-then-insert pattern for full refreshes

### Time-Based Operations
```python
# GOOD
@task
def extract_daily_data(logical_date):
    target_date = logical_date.strftime('%Y-%m-%d')
    df = fetch_data(date=target_date)
    return df

# BAD
@task
def extract_daily_data():
    target_date = datetime.now().strftime('%Y-%m-%d')  # Not idempotent!
    df = fetch_data(date=target_date)
    return df
```

## Operators

### Selection Guidelines
- Use **provider-specific operators** when available (e.g., `SnowflakeOperator`, `S3ToSnowflakeOperator`, `BigQueryOperator`)
- Prefer **operators over BashOperator** for cloud services (better error handling, typing, connection management)
- Use **PythonOperator** or **TaskFlow API** for custom Python logic
- Use **deferrable operators** (`*Async` variants) for long-running tasks to free up worker slots
- Use **sensors sparingly** (they occupy worker slots while waiting)

### Sensor Best Practices
```python
# Set timeout and poke_interval
wait_for_file = S3KeySensor(
    task_id='wait_for_file',
    bucket_name='my-bucket',
    bucket_key='data/{{ ds }}/file.csv',
    timeout=3600,  # 1 hour max wait
    poke_interval=300,  # Check every 5 minutes
    mode='reschedule',  # Free up worker between pokes
)
```

### Operator Configuration
- Always use Airflow **Connections** for credentials (never hardcode)
- Set appropriate timeouts for external API calls
- Use connection pooling when available
- Leverage operator's built-in retry logic

## XCom & Data Passing

### Guidelines
- **Keep XCom small**: Pass references (S3 paths, table names, record IDs), not data
- Never pass DataFrames, large dictionaries, or binary data through XCom
- Use TaskFlow API return values for simple primitives (strings, numbers, small dicts)
- For large data, write to intermediate storage (S3, GCS, Snowflake staging tables)

### Examples
```python
# GOOD: Pass reference
@task
def extract_to_s3():
    s3_path = 's3://bucket/data/output.parquet'
    df.to_parquet(s3_path)
    return s3_path  # Small string reference

@task
def load_from_s3(s3_path: str):
    df = pd.read_parquet(s3_path)
    load_to_warehouse(df)

# BAD: Pass data
@task
def extract():
    df = fetch_large_dataset()
    return df.to_dict()  # Huge XCom!

@task
def load(data: dict):
    df = pd.DataFrame(data)
    load_to_warehouse(df)
```

### XCom Sizing
- Default XCom backend stores in metadata DB (limited size)
- For larger XCom, use custom XCom backend (S3, GCS)
- Monitor XCom table size in metadata DB

## Error Handling

### Retry Configuration
```python
default_args = {
    'retries': 3,  # Retry 3 times for transient failures
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,  # 5min, 10min, 20min
    'max_retry_delay': timedelta(minutes=30),
}
```

### Callbacks
```python
def alert_on_failure(context):
    """Send alert when task fails after all retries"""
    task_instance = context['task_instance']
    send_slack_alert(f"Task {task_instance.task_id} failed")

default_args = {
    'on_failure_callback': alert_on_failure,
    'on_retry_callback': log_retry,
}
```

### SLAs
```python
with DAG(
    dag_id='critical_pipeline',
    sla_miss_callback=notify_sla_miss,
    default_args={'sla': timedelta(hours=2)},
) as dag:
    # Tasks must complete within 2 hours of start_date
```

### Task-Level Error Handling
```python
@task
def robust_api_call():
    try:
        response = call_external_api()
        response.raise_for_status()
        return response.json()
    except requests.exceptions.Timeout:
        # Let Airflow retry transient failures
        raise
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            # Don't retry for permanent failures
            raise AirflowSkipException("Resource not found")
        raise
```

## DAG Design Patterns

### Fan-Out/Fan-In
Parallel processing converging to single task:
```python
extract = extract_data()
process_tasks = [process_chunk.override(task_id=f'process_{i}')(chunk)
                 for i, chunk in enumerate(chunks)]
aggregate = aggregate_results(process_tasks)

extract >> process_tasks >> aggregate
```

### Sensor-Trigger Pattern
Wait for external event, then process:
```python
wait = S3KeySensor(task_id='wait_for_file', ...)
process = process_file()
notify = send_notification()

wait >> process >> notify
```

### Multiple Sources to Single Target
```python
[extract_mysql, extract_postgres, extract_api] >> merge >> load_to_warehouse
```

## Anti-patterns

### Never Do This
1. **Heavy work at parse time**:
   ```python
   # BAD: Runs on every scheduler heartbeat
   data = expensive_query()  # Top-level query

   with DAG(...) as dag:
       process_data(data)

   # GOOD: Work happens in task
   @task
   def fetch_and_process():
       data = expensive_query()  # Only runs when task executes
       process_data(data)
   ```

2. **Variable.get() at top level**:
   ```python
   # BAD: DB query every parse
   threshold = Variable.get('threshold')

   with DAG(...) as dag:
       check_threshold(threshold)

   # GOOD: Get variable in task
   @task
   def check():
       threshold = Variable.get('threshold')
       return check_threshold(threshold)
   ```

3. **Pass large data through XCom**:
   ```python
   # BAD
   df = extract_data()  # 1GB DataFrame
   return df.to_json()  # Breaks XCom

   # GOOD
   s3_path = 's3://bucket/temp/data.parquet'
   df.to_parquet(s3_path)
   return s3_path
   ```

4. **SubDagOperator** (deprecated):
   ```python
   # BAD
   subdag = SubDagOperator(...)

   # GOOD: Use TaskGroup
   with TaskGroup('processing_group'):
       task1 = process_step_1()
       task2 = process_step_2()
   ```

5. **Dynamic tasks without mapping**:
   ```python
   # BAD: Creates task at parse time
   for file in list_files():  # Parse-time work!
       PythonOperator(task_id=f'process_{file}', ...)

   # GOOD: Dynamic task mapping
   @task
   def process_file(file):
       ...

   process_file.expand(file=list_files())
   ```

6. **Hardcoded credentials**:
   ```python
   # BAD
   conn_str = 'postgresql://user:pass@host/db'

   # GOOD
   from airflow.hooks.base import BaseHook
   conn = BaseHook.get_connection('my_postgres_conn')
   ```

7. **Tight DAG coupling**:
   ```python
   # BAD: DAG polling another DAG's state

   # GOOD: Use TriggerDagRunOperator or Dataset triggers
   produce = produce_dataset(outlets=[Dataset('s3://bucket/data')])

   # In consumer DAG:
   with DAG(schedule=[Dataset('s3://bucket/data')]) as consumer:
       consume_data()
   ```

8. **Missing ownership and error handling**:
   ```python
   # BAD: No owner, no retries, no alerts
   with DAG(dag_id='important_pipeline') as dag:
       risky_task()

   # GOOD
   with DAG(
       dag_id='important_pipeline',
       default_args={
           'owner': 'data-team',
           'retries': 3,
           'on_failure_callback': alert_team,
       }
   ) as dag:
       risky_task()
   ```

## Performance

### Optimization
- Use connection pooling for database operators
- Batch operations when possible (bulk insert vs. row-by-row)
- Set appropriate `parallelism` and `max_active_runs`
- Use deferrable operators for long-running tasks
- Monitor task duration and optimize slow tasks
- Use TaskGroup instead of SubDAG (better scheduler performance)

### Monitoring
- Set up task-level SLAs for critical paths
- Monitor DAG parse time (should be <2 seconds)
- Track XCom usage and size
- Monitor scheduler performance metrics
- Use Airflow metrics export (StatsD/Prometheus)
