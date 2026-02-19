---
name: audit-agents
description: "Scan a codebase for technologies in use and identify gaps in agent coverage. Use when setting up Marvin on a new project or after the tech stack has grown."
disable-model-invocation: true
argument-hint: "[--scope global|project]"
---

# Audit Agent Coverage

Scan the current codebase, map all technologies in use, cross-reference with the agent registry, and report coverage gaps with prioritized recommendations.

## Steps

### 1. Scan Codebase

Detect technologies present in the project by scanning:

**Config files** (search for these in the project root and common subdirectories):
- `docker-compose.yml`, `Dockerfile` → Docker / Containerization
- `Makefile` → Build automation
- `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt` → Python project
- `package.json`, `tsconfig.json` → Node.js / TypeScript
- `dbt_project.yml`, `profiles.yml` → dbt
- `terraform/`, `*.tf` → Terraform / IaC
- `k8s/`, `kubernetes/`, `*.yaml` with `apiVersion:` → Kubernetes
- `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` → CI/CD
- `airflow/`, `dags/` → Airflow
- `spark/`, files with `from pyspark` → PySpark
- `snowflake/`, files with `snowflake.connector` → Snowflake
- `.aws/`, `cdk.json`, `samconfig.toml` → AWS
- `go.mod`, `go.sum` → Go
- `Cargo.toml` → Rust
- `pom.xml`, `build.gradle` → Java/Kotlin
- `Gemfile` → Ruby
- `.eslintrc`, `.prettierrc` → Frontend tooling
- `next.config.js`, `nuxt.config.ts` → Frontend frameworks
- `docker-compose.yml` services (e.g., kafka, redis, postgres) → Infrastructure services
- `great_expectations/`, `soda/` → Data quality frameworks
- `mlflow/`, `wandb/`, files with `import mlflow` → ML/MLOps
- `streamlit/`, files with `import streamlit` → Data apps

**Code imports** (scan `.py`, `.ts`, `.js`, `.go`, `.rs` files for import patterns):
- Python: `import X`, `from X import`
- JavaScript/TypeScript: `import ... from 'X'`, `require('X')`
- Go: `import "X"`

**Directory structure** (presence of known patterns):
- `models/staging/`, `models/marts/` → dbt
- `dags/` → Airflow
- `src/`, `lib/`, `pkg/` → Application code
- `infra/`, `infrastructure/` → IaC

For each technology found, record:
- Technology name
- Evidence (file path where detected)
- Domain category

### 2. Map Technologies

Group detected technologies by domain:

Example output format:
```
## Detected Technologies

| Domain | Technologies | Evidence |
|--------|-------------|----------|
| Containerization | Docker, Docker Compose | Dockerfile, docker-compose.yml |
| Orchestration | Airflow | dags/, pyproject.toml (apache-airflow) |
| Data Modeling | dbt | dbt_project.yml, models/ |
| Cloud | AWS (S3, Glue, Lambda) | cdk.json, infra/lambda/ |
| CI/CD | GitHub Actions | .github/workflows/ |
| Data Quality | Great Expectations | great_expectations/ |
```

### 3. Cross-Reference Registry

Read the agent registries to check coverage:

1. Read global registry: `~/.claude/registry/agents.md`
2. Read project registry (if exists): `.claude/registry/agents.md`
3. For each detected domain, check if an agent covers it

Build a coverage map:
- **Covered**: Technology domain has a matching agent in the registry
- **Gap**: Technology domain has NO matching agent

Use these known mappings for the existing global agents:
| Agent | Covers |
|-------|--------|
| researcher | Web research, documentation, comparisons |
| coder | Multi-file code changes, refactoring, tests |
| verifier | Quality verification, test suites |
| dbt-expert | dbt, dimensional modeling, SQL in dbt context |
| spark-expert | PySpark, distributed processing |
| airflow-expert | Airflow, DAG scheduling, orchestration |
| snowflake-expert | Snowflake, data warehousing |
| aws-expert | AWS services (S3, Glue, Lambda, IAM, CDK, Terraform on AWS) |
| git-expert | Git operations, commits, PRs |

### 4. Report Gaps

Generate a structured report:

```
# Agent Coverage Audit Report

## ✅ Covered Technologies
| Domain | Agent | Technologies |
|--------|-------|-------------|
| ... | ... | ... |

## ❌ Coverage Gaps
| Domain | Technologies | Priority | Recommended Agent |
|--------|-------------|----------|-------------------|
| Containerization | Docker, K8s | HIGH | docker-expert |
| CI/CD | GitHub Actions | MEDIUM | cicd-expert |
| Data Quality | Great Expectations | MEDIUM | data-quality-expert |

## Priority Criteria
- **HIGH**: Core technology used across the project (config files + frequent imports + dedicated directories)
- **MEDIUM**: Regular usage (config files or multiple imports)
- **LOW**: Peripheral usage (few references, utility-level)
```

Determine priority based on:
- **HIGH**: Technology has dedicated config file + directory structure + frequent code references (central to the project)
- **MEDIUM**: Technology has config file or multiple code references (used regularly)
- **LOW**: Technology appears in few references or is a utility dependency (peripheral)

For each gap, suggest:
- Agent name (kebab-case)
- Domain description
- Suggested model (haiku for simple, sonnet for most, opus for complex)

### 5. Offer Creation

After presenting the report, for each HIGH and MEDIUM priority gap:

Ask the user: "Want me to create agents for any of these gaps?"

Present options using AskUserQuestion with the gaps as choices (multiSelect: true).

For each gap the user selects, execute `/new-agent <name> <domain description>` to scaffold the agent.

If no gaps found, congratulate: "Your agent coverage is complete! All detected technologies have specialist agents."
