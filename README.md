# Marvin

**An intelligent orchestrator for Claude Code with specialized agents for Data Engineering and AI/ML**

Marvin transforms Claude Code into a domain-specialized assistant that delegates tasks to expert agents, enforces best practices, and remembers your preferences across sessions.

## What is Marvin?

Marvin is an orchestration layer for Claude Code that automatically routes your requests to specialized agents based on domain triggers. Instead of handling everything directly, Marvin delegates to experts for dbt, Spark, Airflow, Snowflake, AWS, Git, Docker, and more.

**Key capabilities:**
- **Intelligent routing** to 13+ specialized agents
- **Domain expertise** loaded from comprehensive rule files
- **Persistent memory** for preferences and decisions
- **Structured handoffs** for complete context transfer
- **Extensible** with `/new-agent`, `/new-skill`, `/new-rule`

## How It Works

```mermaid
graph TB
    User[User Request] --> Marvin[Marvin Orchestrator]
    Marvin --> Think{Stop & Think<br/>Identify Domain}
    Think --> Registry[Check Agent Registry]
    Registry --> Match{Specialist<br/>Exists?}

    Match -->|Yes| Handoff[Construct Structured Handoff]
    Handoff --> Delegate[Delegate via Task Tool]

    Match -->|No| Direct[Handle Directly]
    Direct --> Suggest[Suggest /new-agent if recurring]

    Delegate --> Researcher[researcher]
    Delegate --> Coder[coder]
    Delegate --> DBT[dbt-expert]
    Delegate --> Spark[spark-expert]
    Delegate --> Airflow[airflow-expert]
    Delegate --> Snowflake[snowflake-expert]
    Delegate --> AWS[aws-expert]
    Delegate --> Git[git-expert]
    Delegate --> Other[... 5 more agents]

    Researcher --> Rules1[Load Rules]
    DBT --> Rules2[agents/dbt-expert/rules.md]
    Spark --> Rules3[agents/spark-expert/rules.md]
    Airflow --> Rules4[agents/airflow-expert/rules.md]
    AWS --> Rules5[agents/aws-expert/rules.md]

    Rules1 --> Execute[Execute Task]
    Rules2 --> Execute
    Rules3 --> Execute
    Rules4 --> Execute
    Rules5 --> Execute
    Other --> Execute
    Git --> Execute
    Coder --> Execute

    Execute --> Result[Return Result]
    Result --> Memory[Update Memory]
    Memory --> UserResponse[Response to User]
    Suggest --> UserResponse

    style Marvin fill:#4A90E2,stroke:#2E5C8A,stroke-width:3px,color:#fff
    style Think fill:#F5A623,stroke:#C77D0A,stroke-width:2px
    style Handoff fill:#7ED321,stroke:#5FA319,stroke-width:2px
    style Execute fill:#50E3C2,stroke:#2EB09A,stroke-width:2px
    style Memory fill:#BD10E0,stroke:#8B0AA8,stroke-width:2px
```

## Specialized Agents

| Agent | Triggers | Domain Knowledge |
|-------|----------|------------------|
| **researcher** | research, compare, find docs, how do I, what's the best | Context7 → Exa → WebSearch → WebFetch |
| **coder** | implement, refactor, write tests, fix bug, debug, 2+ files | Multi-file changes with tests |
| **verifier** | verify, validate, check quality, run tests | Quality checks and test execution |
| **dbt-expert** | dbt, data model, fact/dim table, staging, incremental | dbt conventions, testing, documentation |
| **spark-expert** | spark, pyspark, dataframe, rdd, shuffle, partition | PySpark optimization, performance tuning |
| **airflow-expert** | airflow, dag, operator, sensor, schedule, xcom | DAG patterns, idempotency, orchestration |
| **snowflake-expert** | snowflake, warehouse, clustering, rbac, time travel | Snowflake optimization, cost management |
| **aws-expert** | s3, glue, lambda, iam, cdk, step functions, kinesis | AWS data services, IaC patterns |
| **git-expert** | commit, git push, pull request, PR, branch | Git workflows, commit conventions |
| **docker-expert** | docker, dockerfile, container, image, docker-compose | Container optimization |
| **terraform-expert** | terraform, hcl, tfvars, tf plan/apply, module | Infrastructure as code |
| **python-expert** | python, pyproject.toml, pytest, typing, async | Python best practices |
| **docs-expert** | documentation, README, API docs, ADR, docstrings | Technical writing |

## Available Skills (Slash Commands)

| Category | Skill | Description |
|----------|-------|-------------|
| **Meta** | `/init` | Initialize project-specific Marvin config |
| | `/new-agent` | Scaffold a new specialized agent |
| | `/new-skill` | Create a new slash command |
| | `/new-rule` | Add domain knowledge rules |
| | `/audit-agents` | Audit codebase for agent coverage gaps |
| | `/handoff-reference` | Full handoff protocol reference |
| **Research** | `/research` | Deep web research with Context7 and Exa |
| | `/review` | Code review for quality and security |
| **Data Engineering** | `/pipeline` | Design complete data pipelines |
| | `/dbt-model` | Generate dbt models with tests |
| | `/dag` | Create Airflow DAGs |
| | `/data-model` | Design dimensional models |
| **Workflow** | `/spec` | OpenSpec Spec-Driven Development |
| | `/ralph` | Ralph Loop for autonomous tasks |
| | `/remember` | Save to persistent memory |
| | `/meta-prompt` | Generate optimized prompts |

## Getting Started

### Installation

```bash
# Clone the repository
git clone <repository-url> ~/Projects/marvin
cd ~/Projects/marvin

# Install to a project
make install PROJECT=~/Projects/my-project

# Dev mode (symlinks for rapid iteration on Marvin itself)
make install-dev PROJECT=~/Projects/my-project

# Preview changes without modifying anything
make dry-run PROJECT=~/Projects/my-project
```

#### Makefile Targets

| Target | Description |
|--------|-------------|
| `make install` | Install Marvin to a project |
| `make install-dev` | Install in dev mode (symlinks) |
| `make dry-run` | Preview installation without changes |
| `make uninstall` | Remove Marvin from a project |
| `make test` | Run all checks (lint + hook tests) |
| `make lint` | Run all linters (JSON + shellcheck) |
| `make hooks-chmod` | Ensure all hooks are executable |
| `make list-hooks` | List all hook scripts |
| `make list-agents` | List all specialist agents |
| `make help` | Show all available targets |

All project-targeting commands require `PROJECT=<path>`.

### Quick Start

```bash
# Initialize for your project type
> /init data-pipeline

# Try some commands
> /research best practices for incremental dbt models
> /dbt-model orders fact table with customer and product dimensions
> /dag daily ETL pipeline from S3 to Snowflake
> Commit these changes with an appropriate message
```

Marvin automatically delegates each request to the right specialist.

## Project Structure

```
marvin/
├── core/                  # Source of truth (deployed to <project>/.claude/)
│   ├── CLAUDE.md          # Marvin orchestrator system prompt
│   ├── agents/            # Agent definitions + domain rules (13 specialists)
│   ├── skills/            # Slash command implementations
│   ├── rules/             # Universal rules (coding-standards, security)
│   ├── registry/          # Agent and skill registries
│   ├── reference/         # Workflow and protocol documentation
│   ├── templates/         # Scaffolding templates
│   ├── hooks/             # Shell hooks
│   ├── settings.json      # Claude Code settings
│   └── memory.md          # Persistent memory template
├── docs/                  # Architecture and concept documentation
├── scripts/               # Utility scripts (install.sh, etc.)
├── research/              # Research artifacts and notes
├── Makefile               # Build targets (install, test, lint)
└── .claude/               # Project dev instructions
```

## Development Workflow

**Critical Rule**: Always edit source files in `core/`, never in the deployed `.claude/` directly.

| What to Change | Edit Here | NOT Here |
|----------------|-----------|----------|
| Orchestrator logic | `core/CLAUDE.md` | `<project>/.claude/CLAUDE.md` |
| Agent definitions | `core/agents/<name>/AGENT.md` | `<project>/.claude/agents/` |
| Domain rules | `core/agents/<domain>-expert/rules.md` | `<project>/.claude/agents/` |
| Skills | `core/skills/<name>/SKILL.md` | `<project>/.claude/skills/` |

After editing, run `make install PROJECT=<path>` to deploy changes. Use `make install-dev PROJECT=<path>` during
development so directories are symlinked and changes take effect immediately. Run `make test` and `make lint` to validate before committing.

## How Delegation Works

1. **Stop and Think**: Marvin identifies the domain before acting
2. **Check Registry**: Looks up the agent routing table
3. **Structured Handoff**: Constructs a complete context transfer with:
   - Objective (clear task description)
   - Acceptance criteria (definition of done)
   - Constraints (MUST/MUST NOT/PREFER)
   - Context (relevant files, decisions, preferences)
   - Return protocol (how to report results)
4. **Delegate**: Sends handoff to specialist via Task tool
5. **Execute**: Agent loads domain rules and completes task
6. **Memory**: Updates persistent memory with learnings

## Hooks & Quality Gates

Marvin uses 13 shell hooks across 8 event types to enforce quality automatically:

| Event | Script | Purpose |
|-------|--------|---------|
| PreToolUse | `block-secrets.sh` | Block commands exposing secrets |
| PreToolUse | `protect-files.sh` | Block edits to sensitive/lock files |
| PostToolUse | `validate-python.sh` | Auto-format Python (ruff/black) |
| PostToolUse | `validate-sql.sh` | Auto-lint SQL (sqlfluff/sqlfmt) |
| PostToolUse | `validate-dockerfile.sh` | Lint Dockerfiles (hadolint) |
| PostToolUse | `validate-terraform.sh` | Auto-format Terraform |
| PostToolUseFailure | `tool-failure-context.sh` | Inject remediation hints on failures |
| SessionStart | `compact-reinject.sh` | Restore identity + memory after compaction |
| SessionStart | `session-context.sh` | Inject git state on startup |
| PreCompact | `pre-compact-save.sh` | Save state before compaction |
| Stop | `stop-quality-gate.sh` | Enforce delegation protocol |
| SubagentStop | `subagent-quality-gate.sh` | Validate subagent output quality |
| Notification | `notify.sh` | Desktop notification (Linux/macOS/WSL) |

Additionally, `status-line.sh` provides a dynamic status bar and `_lib.sh` is a shared helper with `json_val()` (jq with python3 fallback) used by all hooks.

## Settings

Marvin ships a `settings.json` with a 3-tier permission model:

| Tier | Behavior | Examples |
|------|----------|---------|
| `allow` | Run without asking | `Bash(git status*)`, `Read`, `Edit`, `Write` |
| `ask` | Prompt for confirmation | `Bash(git push*)`, `Bash(terraform apply*)` |
| `deny` | Block entirely | `Bash(rm -rf /)`, `Bash(git push --force*)`, `Read(.env)` |

Other key settings:

- **`$schema`** — JSON Schema validation for settings structure
- **`env`** — Environment variables injected into sessions (`MARVIN_ENABLED=1`)
- **`statusLine`** — Dynamic status bar via `status-line.sh`
- **`respectGitignore`** — Honor `.gitignore` patterns in file operations
- **`cleanupPeriodDays`** — Auto-cleanup period for old session data (default: 30)
- **`attribution`** — Suppress AI attribution in commits and PRs

## Extending Marvin

```bash
# Add a new agent for a domain
> /new-agent kafka-expert "Kafka streaming patterns and optimization"

# Add a new skill/command
> /new-skill schema-registry "Generate and validate Avro schemas"

# Add domain knowledge
> /new-rule kafka

# Save a preference
> /remember We always use Snappy compression for Parquet files in production
```

## Contributing

Contributions welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Edit files in `core/`
4. Validate with `make dry-run PROJECT=<path>` and `make test`
5. Submit a pull request

Ideas: new domain agents, additional skills, expanded rule patterns.

## License

MIT

## Acknowledgments

Built with Claude Opus 4.6 using the Claude Code CLI.

---

**Ready to get started?**

```bash
cd ~/Projects/marvin
make install PROJECT=~/Projects/my-project
cd ~/Projects/my-project
claude
> Hello Marvin!
```
