# Skills (Slash Commands)

Skills are slash commands that Marvin loads on demand. Each skill is an orchestration workflow stored in `core/skills/<name>/SKILL.md`. Invoke any skill from the Claude Code prompt.

## Meta-Skills

Skills for extending and managing Marvin itself.

| Skill | Description |
|-------|-------------|
| `/init` | Bootstrap a `.claude/` directory with CLAUDE.md, memory, registry, rules, and settings for a new project |
| `/new-agent` | Scaffold a new specialized agent with AGENT.md and rules.md |
| `/new-skill` | Scaffold a new skill/slash command |
| `/new-rule` | Add domain knowledge rules to an existing or new agent |
| `/audit-agents` | Scan a codebase for technologies in use and identify gaps in agent coverage |
| `/handoff-reference` | Full handoff protocol reference with annotated examples |

## Universal Skills

General-purpose workflows applicable to any project.

| Skill | Description |
|-------|-------------|
| `/research` | Deep research using Context7, Exa, and web search |
| `/review` | Code review for quality, security, and best practices |
| `/spec` | Spec-Driven Development: plan → specify → implement → verify with atomic commits |
| `/ralph` | Run a long autonomous task across multiple context windows using filesystem checkpointing |
| `/remember` | Save a preference, decision, or lesson to Marvin's persistent memory |
| `/meta-prompt` | Generate an optimized prompt for any task, agent, or skill |
| `/tdd` | RED-GREEN-REFACTOR test-driven development cycle |
| `/debug` | Systematic root cause analysis: reproduce → isolate → fix → verify |
| `/adr` | Document architecture decisions in standard ADR format |

## Data Engineering Skills

Domain-specific generators for the data engineering stack.

| Skill | Description |
|-------|-------------|
| `/pipeline` | Design and scaffold a complete data pipeline with source, transform, and load stages |
| `/dbt-model` | Generate dbt models with schema tests and documentation |
| `/dag` | Generate Airflow DAGs from a plain-language description |
| `/data-model` | Design dimensional data models (star schema, Kimball conventions) |

## Usage Examples

```bash
# Research a technology decision
> /research compare dbt incremental strategies: merge vs delete+insert

# Generate a dbt model
> /dbt-model orders fact table with customer_id, product_id, amount, order_date

# Create a DAG
> /dag daily pipeline: read from S3, transform with Spark, load to Snowflake

# Start spec-driven development
> /spec add retry logic to the pipeline runner

# Save a team preference
> /remember We always use Snappy compression for Parquet files

# Document an architecture decision
> /adr use dbt for all SQL transformations instead of raw Spark SQL
```

## Adding a New Skill

```bash
> /new-skill schema-registry "Generate and validate Avro schemas for Kafka topics"
```

This scaffolds `core/skills/schema-registry/SKILL.md` with a template. Edit the file to define the skill's workflow, then redeploy with `make install PROJECT=<path>`.
