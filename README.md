# Marvin

**A specialized AI assistant framework for Data Engineering and AI/ML built on Claude Code**

Marvin transforms Claude Code into a domain-specialized assistant with intelligent agent delegation, comprehensive domain knowledge, and persistent memory. Built for data engineers, ML engineers, and teams working with modern data stacks.

## What is Marvin?

Marvin is a configuration framework that extends Claude Code with:

- **Intelligent Agent Delegation**: Automatically routes tasks to specialized agents based on domain triggers
- **Domain Expertise**: Deep knowledge of dbt, Spark, Airflow, Snowflake, AWS, Docker, Terraform, and more
- **Persistent Memory**: Remembers preferences, architecture decisions, and lessons learned across sessions
- **Extensibility**: Easily add new agents, skills, and domain rules as your needs evolve
- **Best Practices Enforcement**: Built-in coding standards, security rules, and patterns from industry experts

Instead of a generic assistant, you get a specialized data engineering partner that knows your stack, follows your conventions, and delegates work to the right expert for each task.

## Key Features

### Agent Routing System
Marvin automatically delegates work to specialized agents based on context:
- **researcher**: Deep web research with Context7, Exa, and web search
- **coder**: Multi-file implementations with tests
- **verifier**: Quality checks and test validation
- **Domain experts**: dbt, Spark, Airflow, Snowflake, AWS, Docker, Terraform, Python
- **git-expert**: All git operations, commits, and pull requests
- **docs-expert**: Documentation, READMEs, API docs, ADRs, runbooks

### Domain Knowledge Base
Comprehensive rules and patterns for:
- **Data Warehousing**: dbt models, dimensional modeling, incremental patterns
- **Data Processing**: PySpark optimizations, partitioning strategies, shuffle management
- **Orchestration**: Airflow DAG patterns, idempotency, XCom handling
- **Infrastructure**: AWS best practices, Snowflake optimization, IaC patterns
- **Standards**: Coding conventions, security rules, testing requirements

### Slash Commands (Skills)
Quick access to common workflows:
- `/init` - Initialize project-specific Marvin config
- `/research` - Deep research with web search and documentation
- `/pipeline` - Design complete data pipelines
- `/dbt-model` - Generate dbt models with tests and docs
- `/dag` - Generate Airflow DAGs
- `/new-agent` - Scaffold new specialized agents
- `/remember` - Save to persistent memory

### Persistent Memory
Marvin remembers across sessions:
- User preferences and communication style
- Architecture decisions and their rationale
- Domain patterns and conventions
- Lessons learned from past mistakes

## Project Structure

```
marvin/
├── global/                    # Source of truth for ~/.claude/
│   ├── CLAUDE.md              # Marvin's core system prompt
│   ├── agents/                # Specialized agent definitions
│   │   ├── researcher/        # Web research and documentation
│   │   ├── coder/             # Multi-file code implementation
│   │   ├── verifier/          # Quality validation
│   │   ├── dbt-expert/        # dbt modeling and best practices
│   │   ├── spark-expert/      # PySpark optimization
│   │   ├── airflow-expert/    # Airflow DAG orchestration
│   │   ├── snowflake-expert/  # Snowflake data warehouse
│   │   ├── aws-expert/        # AWS data services
│   │   ├── git-expert/        # Git operations
│   │   ├── docker-expert/     # Container management
│   │   ├── terraform-expert/  # Infrastructure as code
│   │   ├── python-expert/     # Python best practices
│   │   └── docs-expert/       # Technical documentation
│   ├── skills/                # Slash command definitions
│   │   ├── init/              # Project initialization
│   │   ├── research/          # Deep research workflow
│   │   ├── pipeline/          # Pipeline scaffolding
│   │   ├── dbt-model/         # dbt model generation
│   │   ├── dag/               # Airflow DAG generation
│   │   ├── new-agent/         # Agent scaffolding
│   │   ├── new-skill/         # Skill scaffolding
│   │   ├── new-rule/          # Rule scaffolding
│   │   └── remember/          # Memory management
│   ├── rules/                 # Domain knowledge base
│   │   ├── coding-standards.md
│   │   ├── security.md
│   │   ├── dbt.md             # dbt conventions and patterns
│   │   ├── spark.md           # PySpark optimization rules
│   │   ├── airflow.md         # Airflow best practices
│   │   ├── snowflake.md       # Snowflake optimization
│   │   └── aws.md             # AWS data engineering patterns
│   ├── registry/              # Central registries
│   │   ├── agents.md          # Agent routing table
│   │   └── skills.md          # Skill catalog
│   ├── templates/             # Scaffolding templates
│   ├── hooks/                 # Shell hooks for automation
│   ├── settings.json          # Claude Code settings
│   └── memory.md              # Persistent memory (template)
├── project-templates/         # Templates for /init command
├── research/                  # Research documents
├── scripts/                   # Utility scripts
├── specs/                     # OpenSpec specifications
├── install.sh                 # Installation script
└── .claude/                   # Project-specific dev instructions
```

## Getting Started

### Prerequisites

- [Claude Code CLI](https://claude.com/code) installed and configured
- Git (for version control)
- Bash shell (Linux/macOS or WSL on Windows)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url> ~/Projects/marvin
   cd ~/Projects/marvin
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

   This copies Marvin's configuration to `~/.claude/`, making it available globally across all Claude Code sessions.

3. Start Claude Code in any project:
   ```bash
   cd ~/Projects/your-project
   claude
   ```

4. Greet Marvin:
   ```
   > Hello Marvin!
   ```

### Quick Start

Initialize Marvin for your project type:

```bash
# For data engineering projects
> /init data-pipeline

# For AI/ML projects
> /init ai-ml

# For generic projects
> /init
```

Try some commands:

```bash
# Research a topic
> /research best practices for incremental dbt models

# Generate a dbt model
> /dbt-model orders fact table with customer and product dimensions

# Create an Airflow DAG
> /dag daily ETL pipeline from S3 to Snowflake

# Generate a data pipeline
> /pipeline ingest CSV from S3, validate, transform with Spark, load to Snowflake
```

## Agents

Marvin automatically delegates work to specialized agents based on task triggers:

| Agent | Triggers | Capabilities |
|-------|----------|--------------|
| **researcher** | research, compare, find docs, how do I, what's the best | Web search with Context7, Exa, and WebFetch |
| **coder** | implement, refactor, write tests, fix bug, debug, 2+ files | Code changes with comprehensive tests |
| **verifier** | verify, validate, check quality, run tests, after complex work | Quality validation with pass/fail reports |
| **dbt-expert** | dbt, data model, fact/dim table, staging, incremental, schema.yml | dbt modeling, testing, and documentation |
| **spark-expert** | spark, pyspark, dataframe, rdd, shuffle, partition, broadcast | PySpark optimization and best practices |
| **airflow-expert** | airflow, dag, operator, sensor, schedule, xcom | Airflow DAG design and orchestration |
| **snowflake-expert** | snowflake, warehouse, clustering, rbac, time travel, stream | Snowflake optimization and features |
| **aws-expert** | s3, glue, lambda, iam, cdk, step functions, kinesis | AWS data services and infrastructure |
| **git-expert** | commit, git push, pull request, PR, branch, any git operation | Git workflows and best practices |
| **docker-expert** | docker, dockerfile, container, image, docker-compose, ecr | Container management and optimization |
| **terraform-expert** | terraform, hcl, tfvars, tf plan/apply, module, state, backend | Infrastructure as code with Terraform |
| **python-expert** | python, pyproject.toml, pytest, typing, async, uv, pydantic | Python code and project configuration |
| **docs-expert** | documentation, README, API docs, ADR, docstrings, technical guide, runbook | Technical writing and documentation |

**Note**: Delegation is mandatory. When you mention a trigger keyword, Marvin routes your request to the appropriate specialist automatically.

## Skills (Slash Commands)

### Meta-Skills
- `/init` - Initialize Marvin project config
- `/new-agent` - Scaffold a new specialized agent
- `/new-skill` - Scaffold a new skill/slash command
- `/new-rule` - Scaffold a new domain knowledge rule
- `/audit-agents` - Audit codebase for agent coverage gaps

### Universal Skills
- `/research` - Deep research (web search + Exa + Context7)
- `/review` - Code review (quality, security, best practices)
- `/spec` - OpenSpec Spec-Driven Development workflow
- `/ralph` - Ralph Loop for long-running autonomous tasks
- `/remember` - Save to Marvin's persistent memory
- `/meta-prompt` - Generate an optimized prompt

### Data Engineering Skills
- `/pipeline` - Design and scaffold a complete data pipeline
- `/dbt-model` - Generate dbt models with tests and docs
- `/dag` - Generate Airflow DAGs from a description
- `/data-model` - Design dimensional data models

## Extending Marvin

Marvin is designed to grow with your needs. You can easily add new capabilities:

### Adding a New Agent

```bash
> /new-agent kafka-expert "Specialized agent for Kafka streaming patterns and optimization"
```

This scaffolds a new agent with:
- Agent definition file in `global/agents/kafka-expert/AGENT.md`
- Entry in the agent registry
- Template for rules in `global/rules/kafka.md`

### Adding a New Skill

```bash
> /new-skill schema-registry "Generate and validate Avro schemas"
```

Creates a new slash command with template and registration.

### Adding a New Rule

```bash
> /new-rule kafka
```

Creates a domain knowledge file with conventions, patterns, and anti-patterns.

### Saving to Memory

Marvin learns from your work:

```bash
> /remember We always use Snappy compression for Parquet files in production
```

This saves the preference to persistent memory for future sessions.

## Development Workflow

**Important**: Always edit source files in this repository, never in `~/.claude/` directly.

| To Change... | Edit in... | NOT in... |
|--------------|-----------|-----------|
| Core system prompt | `global/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Agent definitions | `global/agents/<name>/AGENT.md` | `~/.claude/agents/` |
| Skills | `global/skills/<name>/SKILL.md` | `~/.claude/skills/` |
| Domain rules | `global/rules/<domain>.md` | `~/.claude/rules/` |
| Agent registry | `global/registry/agents.md` | `~/.claude/registry/agents.md` |
| Settings | `global/settings.json` | `~/.claude/settings.json` |

### Making Changes

1. Edit source files in `global/`
2. Test your changes
3. Commit to git:
   ```bash
   git add global/
   git commit -m "feat: add kafka-expert agent"
   ```
4. Deploy to `~/.claude/`:
   ```bash
   ./install.sh
   ```

### Install Script Options

```bash
./install.sh           # Install with confirmation and backup
./install.sh --force   # Install without prompts
./install.sh --dry-run # Preview what would be installed
```

The installer automatically:
- Backs up existing files before overwriting
- Preserves your `memory.md` (never overwrites)
- Makes hooks executable
- Creates necessary directories

## Design Philosophy

### Stop and Think
Marvin pauses before every action to:
1. Identify the domain
2. Check the agent registry
3. Delegate to a specialist if one exists
4. Handle directly only for greetings, clarifications, or single-file edits with no specialist

This "plan before execute" approach ensures the right expert handles each task.

### Mandatory Delegation
Every agent has exclusive domain ownership. When a trigger keyword appears, delegation is mandatory - no exceptions, even for "simple" tasks. This ensures consistency and leverages specialized knowledge.

### Persistent Learning
Marvin saves key information to persistent memory:
- User preferences → global memory
- Architecture decisions → project memory
- Lessons learned → appropriate scope

Memory entries use format: `- [YYYY-MM-DD] <description>`

### Extensibility First
No specialist for a domain? Marvin handles the task, then suggests creating a new agent/skill/rule if the domain is recurring or complex.

## Examples

### Generate a dbt Model

```bash
> /dbt-model Create a fact table for orders with customer and product dimensions
```

Marvin delegates to **dbt-expert** which:
- Reads dbt conventions from `~/.claude/rules/dbt.md`
- Generates staging models, intermediate transformations, and fact table
- Adds schema tests (unique, not_null, relationships)
- Creates documentation in `schema.yml`

### Design a Data Pipeline

```bash
> /pipeline Ingest JSON events from Kinesis, enrich with customer data, aggregate by hour, load to Redshift
```

Marvin:
- Delegates to **aws-expert** for Kinesis/Redshift patterns
- May involve **spark-expert** for enrichment logic
- Provides complete architecture with code examples

### Research Best Practices

```bash
> /research What are the best practices for handling late-arriving data in Airflow?
```

Marvin delegates to **researcher** which:
- Searches with Context7 (technical documentation)
- Falls back to Exa (curated web search)
- Synthesizes findings with code examples

### Create a Git Commit

```bash
> Commit these changes with an appropriate message
```

Marvin delegates to **git-expert** which:
- Reviews `git status` and `git diff`
- Drafts a descriptive commit message following conventions
- Creates the commit with co-authoring tag
- Never uses `--no-verify` unless explicitly requested

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-agent`
3. Make your changes in `global/`
4. Test thoroughly with `./install.sh --dry-run`
5. Commit with descriptive messages
6. Push and create a pull request

### Contribution Ideas

- New domain agents (Kafka, Flink, Ray, etc.)
- Additional skills for common workflows
- Expanded domain rules with more patterns
- Project templates for different tech stacks
- Integration with new MCP tools

## License

[Add your license here]

## Acknowledgments

Built with Claude Opus 4.6 using the Claude Code CLI.

Inspired by the need for specialized AI assistants that understand data engineering workflows, enforce best practices, and delegate intelligently.

---

**Ready to get started?**

```bash
cd ~/Projects/marvin
./install.sh
claude
> Hello Marvin!
```
