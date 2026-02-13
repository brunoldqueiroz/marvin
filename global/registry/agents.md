# Agent Registry

Available specialized agents. **You MUST delegate to these agents when their domain is involved.**

## Routing Table

| Agent | Domain | MUST BE USED For | Triggers | No Exceptions | Output |
|-------|--------|-----------------|----------|---------------|--------|
| **researcher** | Research | (1) Web search & documentation lookup, (2) Technology comparisons & evaluations, (3) Best practices & design patterns, (4) Library/framework research | "research", "compare", "find docs", "how do I", "what's the best", "which should I use", "state of the art" | Even "quick" research | Markdown report with cited sources |
| **coder** | Implementation | (1) Multi-file code changes (2+ files), (2) Refactoring existing code, (3) Writing and running tests, (4) Debugging & code review fixes | "implement", "refactor", "write tests", "fix bug", "debug", any task editing 2+ files | Even when files seem simple | Code changes with tests |
| **verifier** | Quality | (1) Running test suites, (2) Validating spec compliance, (3) Security checks, (4) Quality gates before shipping | "verify", "validate", "check quality", "run tests", after any complex implementation | ALWAYS after complex work | Pass/fail report with details |
| **dbt-expert** | dbt | (1) dbt models (staging/intermediate/marts), (2) dbt tests & documentation, (3) SQL optimization for Snowflake, (4) Dimensional modeling | "dbt", "data model", "fact table", "dimension", "staging model", "incremental model", "schema.yml" | Even single-file dbt changes | dbt SQL + YAML configs |
| **spark-expert** | Spark | (1) PySpark job development, (2) Performance tuning & shuffle optimization, (3) Data quality validation at scale, (4) Large-scale ETL pipelines | "spark", "pyspark", "dataframe", "rdd", "shuffle", "partition", "broadcast" | Even small Spark scripts | PySpark code + configs |
| **airflow-expert** | Airflow | (1) DAG development & scheduling, (2) Operator selection & task dependencies, (3) TaskFlow API patterns, (4) Troubleshooting failed DAGs | "airflow", "dag", "operator", "task", "schedule", "sensor", "xcom" | Even simple DAGs | DAG Python code |
| **snowflake-expert** | Snowflake | (1) Query optimization & clustering, (2) Warehouse management & sizing, (3) RBAC & access control, (4) Cost optimization & monitoring | "snowflake", "warehouse", "clustering", "rbac", "time travel", "dynamic table", "stream" | Even single queries | SQL + architecture guidance |
| **aws-expert** | AWS | (1) S3 data lake design & lifecycle, (2) Glue ETL jobs & crawlers, (3) Lambda functions & Step Functions, (4) IAM policies & CDK/Terraform | "s3", "glue", "lambda", "iam", "cdk", "terraform", "step functions", "kinesis" | Even small Lambda functions | IaC + architecture guidance |
| **git-expert** | Git | (1) Writing commit messages (Conventional Commits), (2) Analyzing staged changes, (3) Creating atomic commits, (4) Maintaining clean git history | "commit", "git push", "git log", "pull request", "PR", "branch", any git operation | Even "simple" commits | Git commands + commit messages |
| **docker-expert** | Docker | (1) Dockerfile optimization & multi-stage builds, (2) Image security & vulnerability scanning, (3) Docker Compose for local environments, (4) Registry management & tagging | "docker", "dockerfile", "container", "image", "docker-compose", "ecr", "registry", "multi-stage" | Even simple Dockerfiles | Dockerfile + Compose configs |
| **terraform-expert** | Terraform/IaC | (1) HCL code & resource provisioning, (2) State management & migration, (3) Module design & composition, (4) Plan/apply workflows & CI/CD | "terraform", "hcl", "tfvars", "tf plan", "tf apply", "module", "state", "backend", "infrastructure as code" | Even single resource changes | HCL code + architecture guidance |
| **python-expert** | Python | (1) Project structure & packaging (pyproject.toml, uv), (2) Type hints & static analysis, (3) Testing (pytest, fixtures, mocking), (4) Async programming & performance | "python", "pyproject.toml", "pytest", "typing", "async", "venv", "uv", "pip", "pydantic", "dataclass" | Even small Python scripts | Python code + project configs |

## Delegation Instructions

### researcher — Tool Priority

When delegating to the researcher agent, **ALWAYS** include these tool instructions in the prompt:

> **Tool Priority (FOLLOW THIS ORDER):**
> 1. **Context7 FIRST for library/framework docs** — Use ToolSearch to load Context7 tools
>    (`mcp__upstash-context7-mcp__resolve-library-id` then `mcp__upstash-context7-mcp__query-docs`).
>    Use Context7 whenever the topic involves a specific library, framework, SDK, or tool.
> 2. **Exa for high-quality web search** — Use ToolSearch to load Exa tools
>    (`mcp__exa__web_search_exa`, `mcp__exa__company_research_exa`, `mcp__exa__get_code_context_exa`).
>    Exa returns higher quality results than generic web search. Use for technical articles,
>    blog posts, comparisons, and best practices.
> 3. **WebSearch as fallback only** — Use only when Exa and Context7 don't cover the topic
>    (very recent news, niche topics, non-technical queries).
> 4. **WebFetch to go deep** — Read promising URLs in full. Prefer primary sources.
>
> **IMPORTANT:** Use ToolSearch to load Exa and Context7 MCP tools before calling them.
> They are deferred tools and won't work unless loaded first.

### Domain Specialists — Rules Loading

When delegating to a domain specialist, **ALWAYS** include this instruction at the START of the prompt:

| Agent | Include in prompt |
|-------|------------------|
| **dbt-expert** | `Before starting, read the file at ~/.claude/rules/dbt.md for domain-specific conventions and patterns you must follow.` |
| **spark-expert** | `Before starting, read the file at ~/.claude/rules/spark.md for domain-specific conventions and patterns you must follow.` |
| **airflow-expert** | `Before starting, read the file at ~/.claude/rules/airflow.md for domain-specific conventions and patterns you must follow.` |
| **snowflake-expert** | `Before starting, read the file at ~/.claude/rules/snowflake.md for domain-specific conventions and patterns you must follow.` |
| **aws-expert** | `Before starting, read the file at ~/.claude/rules/aws.md for domain-specific conventions and patterns you must follow.` |

This ensures domain rules are loaded on-demand by the specialist (saving ~2,000 lines from the main context).

## Domain Ownership

Each domain has **exclusive ownership** — no overlap, no ambiguity:

| Domain | Exclusive Owner | Rule |
|--------|----------------|------|
| Web research, docs, comparisons | @researcher | ALL research goes here, no exceptions |
| Multi-file code changes | @coder | Any task touching 2+ files |
| Quality verification | @verifier | ALWAYS run after complex implementations |
| dbt & dimensional modeling | @dbt-expert | ALL dbt work, including SQL in dbt context |
| PySpark & distributed processing | @spark-expert | ALL Spark work |
| Airflow & orchestration | @airflow-expert | ALL DAG/scheduling work |
| Snowflake & data warehousing | @snowflake-expert | ALL Snowflake-specific work |
| AWS & cloud infrastructure | @aws-expert | ALL AWS service work |
| Git operations & commits | @git-expert | ALL git commits, PRs, and branch operations |
| Docker & containerization | @docker-expert | ALL Dockerfile, image build, and container work |
| Terraform & infrastructure as code | @terraform-expert | ALL Terraform/HCL work |
| Python development & packaging | @python-expert | ALL Python-specific work (structure, typing, testing, packaging) |
