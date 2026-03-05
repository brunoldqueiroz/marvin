# TaskFlow API & Advanced Patterns Reference

## TaskFlow API — Full Patterns

### `@dag` Instantiation (Required)

The `@dag`-decorated function MUST be called at module bottom to register the
DAG with the scheduler. Without the call, the DAG file parses but the DAG is
invisible in the UI.

```python
import pendulum
from airflow.decorators import dag, task

@dag(
    dag_id="my_pipeline",
    schedule="@daily",
    start_date=pendulum.datetime(2024, 1, 1, tz="UTC"),
    catchup=False,
    tags=["etl", "orders"],
    default_args={
        "retries": 2,
        "retry_delay": pendulum.duration(minutes=5),
        "owner": "data-team",
    },
)
def my_pipeline():
    @task
    def extract() -> dict:
        return {"rows": 42}

    @task
    def transform(data: dict) -> dict:
        return {"processed": data["rows"] * 2}

    @task
    def load(data: dict) -> None:
        print(f"Loading {data['processed']} records")

    load(transform(extract()))

my_pipeline()  # Required — registers the DAG
```

### Migrating PythonOperator to TaskFlow

```python
# BEFORE — PythonOperator with manual XCom
from airflow import DAG
from airflow.operators.python import PythonOperator

def extract_fn(**context):
    data = {"rows": 42}
    context["ti"].xcom_push(key="extract_result", value=data)

def transform_fn(**context):
    data = context["ti"].xcom_pull(task_ids="extract", key="extract_result")
    result = {"processed": data["rows"] * 2}
    context["ti"].xcom_push(key="transform_result", value=result)

with DAG("old_pipeline", schedule="@daily", catchup=False) as dag:
    extract = PythonOperator(task_id="extract", python_callable=extract_fn)
    transform = PythonOperator(task_id="transform", python_callable=transform_fn)
    extract >> transform

# AFTER — TaskFlow API with automatic XCom wiring
from airflow.decorators import dag, task

@dag(schedule="@daily", start_date=pendulum.datetime(2024, 1, 1), catchup=False)
def new_pipeline():
    @task
    def extract() -> dict:
        return {"rows": 42}

    @task
    def transform(data: dict) -> dict:
        return {"processed": data["rows"] * 2}

    transform(extract())  # Return values wire XCom automatically

new_pipeline()
```

### Multiple Return Values

```python
@task(multiple_outputs=True)
def extract_metadata() -> dict:
    return {
        "row_count": 1000,
        "file_path": "s3://bucket/data.parquet",
        "checksum": "abc123",
    }

@dag(...)
def pipeline():
    meta = extract_metadata()
    # Access individual keys as separate XCom values
    process(path=meta["file_path"], count=meta["row_count"])
```

## Dynamic Task Mapping

### Basic `.expand()`

Use `.expand()` for parallel processing instead of generating N near-identical
DAGs. Each mapped instance runs as a separate task instance.

```python
@dag(schedule="@daily", start_date=pendulum.datetime(2024, 1, 1), catchup=False)
def partitioned_pipeline():

    @task
    def get_partitions() -> list[str]:
        # In production: query metadata store or API
        return ["2024-01-01", "2024-01-02", "2024-01-03"]

    @task
    def process_partition(partition: str) -> str:
        # Runs N times in parallel, one per partition
        print(f"Processing {partition}")
        return f"s3://results/{partition}/output.parquet"

    @task
    def aggregate(paths: list[str]) -> None:
        print(f"Aggregating {len(paths)} partition results")

    partitions = get_partitions()
    results = process_partition.expand(partition=partitions)
    aggregate(results)  # Receives list of all mapped results

partitioned_pipeline()
```

### `.expand_kwargs()` for Multiple Parameters

```python
@task
def load_table(table: str, schema: str, mode: str) -> None:
    print(f"Loading {schema}.{table} using {mode}")

@task
def get_load_configs() -> list[dict]:
    return [
        {"table": "orders", "schema": "raw", "mode": "overwrite"},
        {"table": "customers", "schema": "raw", "mode": "append"},
        {"table": "products", "schema": "raw", "mode": "overwrite"},
    ]

@dag(...)
def multi_table_load():
    configs = get_load_configs()
    load_table.expand_kwargs(configs)
```

### Concurrency Limits on Mapped Tasks

```python
# Prevent overwhelming external systems
process_partition.expand(partition=partitions).override(
    pool="snowflake_pool",     # cap via pool slot count
    max_active_tis_per_dag=8,  # cap mapped instances running simultaneously
)
```

## Asset/Dataset Scheduling

### Producer–Consumer Pattern (Airflow 2.4+ / 3.x "Assets")

Preferred for cross-DAG dependencies. Eliminates `ExternalTaskSensor` polling.
Consumer triggers immediately when producer marks the dataset as updated.

```python
from airflow.datasets import Dataset

# Shared asset definition — import in both DAGs
orders_dataset = Dataset("s3://data-lake/orders/{{ ds }}/")

# Producer DAG
@dag(
    schedule="@daily",
    start_date=pendulum.datetime(2024, 1, 1),
    catchup=False,
    tags=["producer"],
)
def orders_producer():

    @task(outlets=[orders_dataset])  # Marks dataset as updated on success
    def write_orders() -> None:
        # Write orders data to S3
        print("Orders written to S3")

orders_producer()


# Consumer DAG — triggered by dataset update, not schedule
@dag(
    schedule=[orders_dataset],       # Triggered when dataset is updated
    start_date=pendulum.datetime(2024, 1, 1),
    catchup=False,
    tags=["consumer"],
)
def orders_consumer():

    @task
    def read_orders() -> None:
        print("Processing updated orders")

orders_consumer()
```

### Multiple Dataset Dependencies

```python
orders_ds = Dataset("s3://data-lake/orders/")
customers_ds = Dataset("s3://data-lake/customers/")

# Triggers only when BOTH datasets have been updated
@dag(schedule=[orders_ds, customers_ds], ...)
def joined_report():
    ...
```

### Replacing ExternalTaskSensor

```python
# BEFORE — ExternalTaskSensor (polling, fragile, schedule-coupled)
from airflow.sensors.external_task import ExternalTaskSensor

wait_for_producer = ExternalTaskSensor(
    task_id="wait_for_producer",
    external_dag_id="orders_producer",
    external_task_id="write_orders",
    timeout=7200,
    mode="reschedule",
)

# AFTER — Dataset scheduling (event-driven, immediate, decoupled)
orders_dataset = Dataset("s3://data-lake/orders/")

@dag(schedule=[orders_dataset], ...)   # No sensor task needed
def orders_consumer():
    @task
    def process(): ...
```

## TaskGroups for Visual Organization

Replaces deprecated SubDAGs. No deadlock risk. Groups tasks visually in the UI.

```python
from airflow.utils.task_group import TaskGroup

@dag(...)
def etl_pipeline():

    with TaskGroup("extract", tooltip="Data extraction tasks") as extract_group:
        @task
        def extract_orders(): ...

        @task
        def extract_customers(): ...

        [extract_orders(), extract_customers()]

    with TaskGroup("transform") as transform_group:
        @task
        def join_tables(): ...

        join_tables()

    with TaskGroup("load") as load_group:
        @task
        def load_warehouse(): ...

        load_warehouse()

    extract_group >> transform_group >> load_group
```

## Secrets and Connections

### Secrets Lookup Order

1. Configured secrets backend (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager)
2. `AIRFLOW_CONN_<CONN_ID>` environment variables
3. Metastore database (Admin → Connections in UI)

### Never Hardcode Credentials

```python
# BAD — credentials in DAG code
snowflake_hook = SnowflakeHook(
    account="myaccount",
    user="myuser",
    password="supersecret",  # NEVER
)

# GOOD — connection ID resolved from secrets backend
snowflake_hook = SnowflakeHook(snowflake_conn_id="snowflake_prod")
```

### AWS Secrets Manager Backend

```ini
# airflow.cfg
[secrets]
backend = airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend
backend_kwargs = {"connections_prefix": "airflow/connections", "variables_prefix": "airflow/variables"}
```

### Variable Access Patterns

```python
# BAD — top-level Variable.get() runs every ~30s during parsing
API_URL = Variable.get("api_url")

@task
def call_api():
    requests.get(API_URL)

# GOOD — inside task callable, runs only at execution time
@task
def call_api():
    api_url = Variable.get("api_url")
    requests.get(api_url)

# ALSO GOOD — Jinja template (zero DB overhead, resolved at runtime)
@task
def call_api(api_url: str):
    requests.get(api_url)

call_api(api_url="{{ var.value.api_url }}")

# BEST for non-sensitive, stable config — env var (zero parse overhead)
@task
def call_api():
    import os
    api_url = os.getenv("API_URL")
    requests.get(api_url)
```

## Pool Management

Create one pool per external system to cap concurrent connections.

```python
# Create pools via CLI or Admin → Pools UI
# airflow pools set snowflake_pool 5 "Snowflake connection limit"
# airflow pools set external_api_pool 3 "External API rate limit"

@task(pool="snowflake_pool", pool_slots=1)
def query_snowflake():
    ...

@task(pool="snowflake_pool", pool_slots=2)  # heavier query, counts as 2 slots
def heavy_snowflake_query():
    ...
```
