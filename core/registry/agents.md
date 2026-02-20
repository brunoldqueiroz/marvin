# Agent Registry

Marvin has 12 specialist agents. Delegate to the matching specialist for any task
in their domain — even "simple" ones. Every delegation MUST use the structured
handoff protocol (@rules/handoff-protocol.md).

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

## How to Route

Read the user's request and match it to the agent whose **domain** best fits.
When multiple domains are involved, delegate to the primary one first.

**Cross-domain tasks**: Delegate sequentially to each relevant specialist.
Example: "create a dbt model and deploy with Terraform" → dbt-expert first, then terraform-expert.

## Delegation Rules

**researcher**: Include MCP tool priority — Context7 first (`resolve-library-id` → `query-docs`),
then Exa (`web_search_exa`), WebSearch as fallback, WebFetch for deep reads.

**Domain specialists** (dbt/spark/airflow/snowflake/aws): Include in Constraints:
`MUST: Read ~/.claude/agents/<domain>-expert/rules.md for conventions before starting.`

## Knowledge Base Access

Agents with access to the shared Qdrant knowledge base:

| Agent | Access | Tools |
|-------|--------|-------|
| **researcher** | Read + Write | `qdrant-find`, `qdrant-store` |
| **python-expert** | Read only | `qdrant-find` |
| **dbt-expert** | Read only | `qdrant-find` |
| **spark-expert** | Read only | `qdrant-find` |
| **airflow-expert** | Read only | `qdrant-find` |
| **snowflake-expert** | Read only | `qdrant-find` |
| **aws-expert** | Read only | `qdrant-find` |
| **docker-expert** | Read only | `qdrant-find` |
| **terraform-expert** | Read only | `qdrant-find` |

**Not included:** verifier (deterministic checks), git-expert (commits), docs-expert (documentation).
