# Agent Registry

**You MUST delegate to these agents when their domain is involved.**

## Routing Table

| Agent | Triggers | Loads |
|-------|----------|-------|
| **researcher** | research, compare, find docs, how do I, what's the best | Context7 → Exa → WebSearch → WebFetch |
| **coder** | implement, refactor, write tests, fix bug, debug, 2+ files | Code changes with tests |
| **verifier** | verify, validate, check quality, run tests, after complex work | Pass/fail report |
| **dbt-expert** | dbt, data model, fact/dim table, staging, incremental, schema.yml | `~/.claude/rules/dbt.md` |
| **spark-expert** | spark, pyspark, dataframe, rdd, shuffle, partition, broadcast | `~/.claude/rules/spark.md` |
| **airflow-expert** | airflow, dag, operator, sensor, schedule, xcom | `~/.claude/rules/airflow.md` |
| **snowflake-expert** | snowflake, warehouse, clustering, rbac, time travel, stream | `~/.claude/rules/snowflake.md` |
| **aws-expert** | s3, glue, lambda, iam, cdk, step functions, kinesis | `~/.claude/rules/aws.md` |
| **git-expert** | commit, git push, pull request, PR, branch, any git operation | Git commands + commit messages |
| **docker-expert** | docker, dockerfile, container, image, docker-compose, ecr | Dockerfile + Compose configs |
| **terraform-expert** | terraform, hcl, tfvars, tf plan/apply, module, state, backend | HCL code + guidance |
| **python-expert** | python, pyproject.toml, pytest, typing, async, uv, pydantic | Python code + configs |
| **docs-expert** | documentation, README, API docs, ADR, docstrings, technical guide, runbook | Markdown documentation |

## Delegation Rules

**researcher**: Include tool priority in prompt — Context7 FIRST (ToolSearch → `resolve-library-id` → `query-docs`), then Exa (`web_search_exa`), WebSearch as fallback, WebFetch to go deep. All MCP tools require ToolSearch to load first.

**Domain specialists** (dbt/spark/airflow/snowflake/aws): Include in prompt: `Before starting, read the file at ~/.claude/rules/<domain>.md for conventions you must follow.`
