# Agent Registry

Available specialized agents. **You MUST delegate to these agents when their domain is involved.**

## Routing Table

| Agent | Domain | MUST BE USED For | Triggers | Output |
|-------|--------|-----------------|----------|--------|
| **researcher** | Research | (1) Web search & documentation lookup, (2) Technology comparisons & evaluations, (3) Best practices & design patterns, (4) Library/framework research | "research", "compare", "find docs", "how do I", "what's the best", "which should I use", "state of the art" | Markdown report with cited sources |
| **coder** | Implementation | (1) Multi-file code changes (2+ files), (2) Refactoring existing code, (3) Writing and running tests, (4) Debugging & code review fixes | "implement", "refactor", "write tests", "fix bug", "debug", any task editing 2+ files | Code changes with tests |
| **verifier** | Quality | (1) Running test suites, (2) Validating spec compliance, (3) Security checks, (4) Quality gates before shipping | "verify", "validate", "check quality", "run tests", after any complex implementation | Pass/fail report with details |
| **dbt-expert** | dbt | (1) dbt models (staging/intermediate/marts), (2) dbt tests & documentation, (3) SQL optimization for Snowflake, (4) Dimensional modeling | "dbt", "data model", "fact table", "dimension", "staging model", "incremental model", "schema.yml" | dbt SQL + YAML configs |
| **spark-expert** | Spark | (1) PySpark job development, (2) Performance tuning & shuffle optimization, (3) Data quality validation at scale, (4) Large-scale ETL pipelines | "spark", "pyspark", "dataframe", "rdd", "shuffle", "partition", "broadcast" | PySpark code + configs |
| **airflow-expert** | Airflow | (1) DAG development & scheduling, (2) Operator selection & task dependencies, (3) TaskFlow API patterns, (4) Troubleshooting failed DAGs | "airflow", "dag", "operator", "task", "schedule", "sensor", "xcom" | DAG Python code |
| **snowflake-expert** | Snowflake | (1) Query optimization & clustering, (2) Warehouse management & sizing, (3) RBAC & access control, (4) Cost optimization & monitoring | "snowflake", "warehouse", "clustering", "rbac", "time travel", "dynamic table", "stream" | SQL + architecture guidance |
| **aws-expert** | AWS | (1) S3 data lake design & lifecycle, (2) Glue ETL jobs & crawlers, (3) Lambda functions & Step Functions, (4) IAM policies & CDK/Terraform | "s3", "glue", "lambda", "iam", "cdk", "terraform", "step functions", "kinesis" | IaC + architecture guidance |
| **git-expert** | Git | (1) Writing commit messages (Conventional Commits), (2) Analyzing staged changes, (3) Creating atomic commits, (4) Maintaining clean git history | "commit", "git push", "git log", "pull request", "PR", "branch", any git operation | Git commands + commit messages |

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
