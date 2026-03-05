# Airflow Operator & Sensor Reference

## Operator Selection Guide

### When to Use Each Operator Type

| Scenario | Recommended Operator |
|---|---|
| Run Python function | `@task` decorator (TaskFlow API) |
| Run Python function (legacy) | `PythonOperator` — only for compatibility |
| Run Bash command | `BashOperator` |
| Run SQL on external DB | Provider operator (e.g., `SnowflakeOperator`, `BigQueryOperator`) |
| Trigger another DAG | `TriggerDagRunOperator` |
| Wait for external event | Deferrable sensor (see Sensor Selection below) |
| Branch on condition | `BranchPythonOperator` or `@task.branch` |
| No-op / short circuit | `ShortCircuitOperator` or `@task.short_circuit` |
| Kubernetes Pod execution | `KubernetesPodOperator` |
| Cross-task grouping | `TaskGroup` (not SubDAG) |

### Provider Operators — Prefer Over Custom Wrappers

Official provider operators (from `apache-airflow-providers-*` packages):
- Defer heavy imports to `execute()` time — no parse overhead
- Handle connection management and retries idiomatically
- Integrate with Airflow's connection/variable system
- Log consistently to the task log stream

Examples:
- `SnowflakeOperator`, `SnowflakeCheckOperator`
- `BigQueryInsertJobOperator`, `BigQueryCheckOperator`
- `S3CopyObjectOperator`, `S3DeleteObjectsOperator`
- `GCSToGCSOperator`, `GCSToBigQueryOperator`
- `SlackAPIPostOperator`, `PagerdutyEventsOperator`

## Sensor Selection

### Decision Matrix

| Wait duration | Worker resource concern | Recommended mode |
|---|---|---|
| < 30 seconds | Low | `poke` mode |
| 30s – several minutes | Moderate | `reschedule` mode |
| Minutes to hours | High (SLA-critical) | `deferrable=True` |

### Poke Mode (short waits only)

```python
from airflow.sensors.filesystem import FileSensor

wait_for_file = FileSensor(
    task_id="wait_for_file",
    filepath="/data/input.csv",
    poke_interval=10,   # seconds between checks
    timeout=300,        # fail after 5 minutes
    mode="poke",        # holds worker slot continuously
)
```

Use when: wait is reliably under 30 seconds. Worker slot is occupied for the full wait.

### Reschedule Mode (middle ground)

```python
from airflow.sensors.s3_key import S3KeySensor

wait_for_s3 = S3KeySensor(
    task_id="wait_for_s3",
    bucket_name="my-bucket",
    bucket_key="data/{{ ds }}/file.csv",
    poke_interval=60,
    timeout=3600,
    mode="reschedule",  # releases worker between checks
)
```

Use when: deferrable sensor is unavailable and waits are minutes. Releases worker slot between checks but still occupies a slot during each check.

### Deferrable Mode (preferred for long waits)

```python
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor

wait_for_s3 = S3KeySensor(
    task_id="wait_for_s3",
    bucket_name="my-bucket",
    bucket_key="data/{{ ds }}/file.csv",
    deferrable=True,    # fully releases worker slot
    poke_interval=30,
)
```

Set globally in `airflow.cfg`:
```ini
[operators]
default_deferrable = True
```

Use when: wait is expected to be > 30 seconds. Worker slot fully released to the async triggerer process. Critical for high-concurrency environments.

## Testing

### DAG Validation (CI Gate)

Run this test as the first step in every CI pipeline. A DAG with import errors
never reaches the scheduler.

```python
from airflow.models import DagBag

def test_no_import_errors():
    dagbag = DagBag(dag_folder="dags/", include_examples=False)
    assert dagbag.import_errors == {}, \
        f"DAG import errors: {dagbag.import_errors}"

def test_dagbag_loads():
    dagbag = DagBag(dag_folder="dags/", include_examples=False)
    assert len(dagbag.dags) > 0, "No DAGs found in dags/ directory"
```

### Structural Tests

Enforce DAG-level constraints across all DAGs uniformly.

```python
import pytest
from airflow.models import DagBag

@pytest.fixture(scope="module")
def dagbag():
    return DagBag(dag_folder="dags/", include_examples=False)

def test_all_dags_have_tags(dagbag):
    for dag_id, dag in dagbag.dags.items():
        assert dag.tags, f"DAG '{dag_id}' has no tags"

def test_all_dags_catchup_false(dagbag):
    for dag_id, dag in dagbag.dags.items():
        assert dag.catchup is False, \
            f"DAG '{dag_id}' has catchup=True"

def test_all_tasks_have_retries(dagbag):
    for dag_id, dag in dagbag.dags.items():
        for task_id, task in dag.task_dict.items():
            assert task.retries >= 1, \
                f"Task '{dag_id}.{task_id}' has no retries"
```

### Unit Tests for Business Logic

Extract business logic to helper modules and test directly.

```python
# dags/include/transforms.py
def normalize_order(record: dict) -> dict:
    return {
        "id": record["order_id"],
        "amount": round(float(record["total"]), 2),
        "status": record["status"].upper(),
    }

# tests/test_transforms.py
from include.transforms import normalize_order

def test_normalize_order():
    raw = {"order_id": "A1", "total": "99.999", "status": "pending"}
    result = normalize_order(raw)
    assert result == {"id": "A1", "amount": 100.0, "status": "PENDING"}
```

Mock Airflow hooks and connections:
```python
from unittest.mock import patch, MagicMock

def test_fetch_data_task():
    with patch("dags.my_dag.SnowflakeHook") as mock_hook:
        mock_hook.return_value.get_records.return_value = [("row1",)]
        result = fetch_data.function()
    assert result == [("row1",)]
```

### Local DAG Execution

```python
# At bottom of DAG file, guarded for CI safety
if __name__ == "__main__":
    dag.test()  # Airflow 2.5+ — runs DAG locally, no scheduler needed
```

## Performance Tuning

### Parse Time Targets

- Individual DAG: < 100–200ms
- Diagnose slow parsers: `airflow dags report`
- Profile a specific file: `time python dags/my_dag.py`

### Import Deferral

Move all heavy imports inside task callables. Module-level imports run on
every parse cycle (~every 30s per DAG).

```python
# BAD — runs every parse cycle
import pandas as pd
from google.cloud import bigquery

@task
def transform(data):
    return pd.DataFrame(data)

# GOOD — deferred to task execution time
@task
def transform(data):
    import pandas as pd  # imported only when task runs
    return pd.DataFrame(data)
```

### Scheduler Configuration

```ini
# airflow.cfg — for 200+ DAG environments
[scheduler]
min_file_process_interval = 120   # seconds between re-parsing each file
parsing_processes = 4             # parallel parser processes

[core]
max_active_tasks_per_dag = 16     # per-DAG task concurrency cap
```

### Task Count Guidelines

- Keep under 100–200 tasks per DAG
- Scheduler task dependency resolution grows ~O(n²)
- Use Dynamic Task Mapping with `max_map_length` limits for fan-out
- Split large DAGs into multiple DAGs connected via Dataset dependencies

### Database Recommendations

| Deployment size | Recommendation |
|---|---|
| Development / < 5 DAGs | SQLite (default) |
| Production / any scale | PostgreSQL (2.5x faster than SQLite) |
| High concurrency | PostgreSQL + pgBouncer connection pooling |

Maintenance: run `airflow db clean --clean-before-timestamp <ts>` regularly to
prune XCom, logs, and task instance history.

### Priority Weights

```python
SLA_CRITICAL_TASK = EmptyOperator(
    task_id="critical_step",
    priority_weight=10,  # default is 1; higher = scheduled first
    weight_rule="absolute",
)
```
