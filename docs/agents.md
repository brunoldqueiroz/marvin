# Agents

Marvin has 12 specialist agents. Every request that matches a specialist's domain is delegated to that agent — even simple ones. Specialists load domain-specific rules before executing, ensuring consistent conventions across every task.

## Specialists

| Agent | Domain | Model |
|-------|--------|-------|
| **researcher** | Research, comparisons, documentation lookup, technology evaluation | sonnet |
| **python-expert** | Python implementation, refactoring, tests, debugging, multi-file changes, packaging, typing, design patterns | sonnet |
| **verifier** | Quality verification, test execution, lint, security scan | haiku |
| **dbt-expert** | dbt models, data transformation, SQL optimization, schema.yml, testing | sonnet |
| **spark-expert** | PySpark jobs, performance tuning, shuffle optimization, ETL pipelines | sonnet |
| **airflow-expert** | DAG development, scheduling, operators, TaskFlow API, error handling | sonnet |
| **snowflake-expert** | Query optimization, RBAC, cost optimization, streams, tasks, data loading | sonnet |
| **aws-expert** | S3, Glue, Lambda, IAM, CDK/Terraform, cost optimization | sonnet |
| **git-expert** | Commits, branches, PRs, git history, Conventional Commits | haiku |
| **docker-expert** | Dockerfiles, multi-stage builds, Compose, image security, registries | sonnet |
| **terraform-expert** | HCL code, state management, modules, plan/apply, workspaces | sonnet |
| **docs-expert** | READMEs, API docs, ADRs, docstrings, technical guides, runbooks | haiku |

## Routing Triggers

Each agent responds to domain keywords in the user's request:

| Agent | Triggers |
|-------|----------|
| **researcher** | research, compare, find docs, how do I, what's the best |
| **python-expert** | python, pyproject.toml, pytest, typing, async |
| **verifier** | verify, validate, check quality, run tests |
| **dbt-expert** | dbt, data model, fact/dim table, staging, incremental |
| **spark-expert** | spark, pyspark, dataframe, rdd, shuffle, partition |
| **airflow-expert** | airflow, dag, operator, sensor, schedule, xcom |
| **snowflake-expert** | snowflake, warehouse, clustering, rbac, time travel |
| **aws-expert** | s3, glue, lambda, iam, cdk, step functions, kinesis |
| **git-expert** | commit, git push, pull request, PR, branch |
| **docker-expert** | docker, dockerfile, container, image, docker-compose |
| **terraform-expert** | terraform, hcl, tfvars, tf plan/apply, module |
| **docs-expert** | documentation, README, API docs, ADR, docstrings |

## How Delegation Works

1. Marvin identifies the domain from the user's request
2. Looks up the matching agent in the registry
3. Constructs a structured handoff with: objective, acceptance criteria, constraints, context, and return protocol
4. Delegates to the specialist via the Task tool
5. The specialist loads its `rules.md` and executes the task
6. Results and learnings are stored in memory

For full details on the handoff protocol format, see [concepts.md](concepts.md#4-structured-handoff-protocol).

## Delegation Rules

**researcher:** Uses MCP tools in priority order — Context7 first (`resolve-library-id` → `query-docs`), then Exa (`web_search_exa`), WebSearch as fallback, WebFetch for deep reads.

**Domain specialists** (dbt/spark/airflow/snowflake/aws): Handoffs must include the constraint `MUST: Read ~/.claude/agents/<domain>-expert/rules.md for conventions before starting.`

**Cross-domain tasks:** Delegate sequentially to each relevant specialist. For example, "create a dbt model and deploy with Terraform" → dbt-expert first, then terraform-expert.

## Model Strategy

- **Sonnet** — complex synthesis, domain implementation, research
- **Haiku** — deterministic tasks: verification, commits, docs

## Adding a New Agent

```bash
> /new-agent kafka-expert "Kafka streaming patterns and consumer group optimization"
```

This scaffolds a new `agents/kafka-expert/` directory with `AGENT.md` and `rules.md` templates. See [concepts.md](concepts.md#11-auto-extension) for how the extension system works.
