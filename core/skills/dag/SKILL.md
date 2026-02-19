---
name: dag
description: Generate Airflow DAGs from a description with best practices built in
disable-model-invocation: true
argument-hint: "[DAG description - what it does, schedule, dependencies]"
---

# Airflow DAG Generator

DAG request: $ARGUMENTS

## Process

### 1. Understand the Workflow

Before generating, determine:
- **Purpose**: What does this DAG do? (ETL, data sync, report generation, etc.)
- **Schedule**: How often? (cron expression or preset)
- **Dependencies**: What must run before this? (sensors, other DAGs, external systems)
- **Tasks**: What are the individual steps?
- **Error Handling**: What happens on failure? (retry, alert, skip)
- **SLA**: By when must it complete?

If any are unclear from $ARGUMENTS, ask the user.

### 2. Design the DAG

Determine:
- Task graph (dependencies between tasks)
- Operator selection for each task:
  - SQL execution → SnowflakeOperator
  - S3 operations → S3 operators
  - dbt → BashOperator (`dbt run`) or DbtCloudRunJobOperator
  - Python logic → @task decorator (TaskFlow API)
  - Wait for data → S3KeySensor (deferrable mode)
  - Conditional logic → BranchPythonOperator
  - Parallel dynamic → .expand() (dynamic task mapping)

### 3. Generate the DAG

Delegate to the **airflow-expert** agent to create the DAG file:

**File**: `dags/dag_<domain>_<action>.py`

Template structure:
```python
"""
DAG: <name>
Description: <what it does>
Schedule: <cron>
Owner: data-engineering
"""
from __future__ import annotations

from datetime import datetime, timedelta

from airflow.decorators import dag, task

default_args = {
    "owner": "data-engineering",
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "email_on_failure": True,
    "email_on_retry": False,
}


@dag(
    schedule="<cron>",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["team:<team>", "domain:<domain>", "freq:<frequency>"],
    default_args=default_args,
    doc_md=__doc__,
)
def dag_<domain>_<action>():
    # Tasks defined here using TaskFlow API or operators
    ...

dag_<domain>_<action>()
```

Requirements:
- Use TaskFlow API (@task) for Python tasks
- Use provider operators for cloud services
- Include error handling callbacks
- Set appropriate retries and timeouts
- Make all tasks idempotent
- Use logical_date, never datetime.now()
- Keep XCom payloads small (pass paths, not data)
- Add docstring for DAG documentation in Airflow UI

### 4. Verify

Delegate to the **verifier** agent:
- Check Python syntax is valid
- Check imports exist
- Check DAG has catchup=False (unless backfill is intended)
- Check all tasks have retries configured
- Check no heavy processing at parse time
- Check no hardcoded credentials or connection strings
- Check idempotency of each task

### 5. Summary

Show the user:
- File created (with path)
- Task graph visualization (text-based)
- Schedule explanation
- Connections/Variables needed in Airflow
- Suggested next steps (test locally, deploy, configure connections)

## Notes
- Always check existing DAGs in the project for conventions
- Use the project's existing Airflow provider packages
- Follow the project's DAG naming convention
- Include inline comments for complex task logic
- Keep DAGs simple — avoid deep nesting
