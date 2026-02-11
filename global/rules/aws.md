# AWS Data Engineering Rules

## Conventions

### Resource Naming
- Use pattern: `{env}-{project}-{service}-{purpose}`
  - Example: `prod-analytics-s3-raw-data`
  - Example: `dev-pipeline-glue-customer-etl`
- Keep names descriptive but concise (max 63 chars for most resources)
- Use hyphens for separation, not underscores

### S3 Bucket Naming
- Lowercase only
- Use hyphens, not underscores
- Must be globally unique
- Include environment and project identifier
- Example: `prod-analytics-raw-data-us-east-1`
- Example: `dev-pipeline-staging-layer`

### IAM Role Naming
- Use PascalCase with descriptive purpose
- Pattern: `{Service}{Purpose}Role`
- Examples:
  - `GlueETLRole`
  - `LambdaDataValidatorRole`
  - `StepFunctionsOrchestratorRole`
  - `EC2SparkProcessorRole`

### Lambda Function Naming
- Use kebab-case
- Pattern: `{env}-{project}-{purpose}`
- Example: `prod-analytics-s3-event-handler`
- Example: `dev-pipeline-data-validator`

### Mandatory Resource Tags
Apply to ALL resources:
- `Environment`: dev | staging | prod
- `Project`: project identifier
- `Owner`: team or individual email
- `CostCenter`: billing code
- `ManagedBy`: terraform | cdk | cloudformation
- `DataClassification`: public | internal | confidential | restricted (for data resources)

### Optional But Recommended Tags
- `Application`: specific application name
- `BackupPolicy`: daily | weekly | none
- `Compliance`: hipaa | gdpr | sox (if applicable)
- `AutoShutdown`: true | false (for dev resources)

## S3 (Data Lake Architecture)

### Layer Organization
Structure buckets by data processing stage:
```
s3://bucket/raw/          # Landing zone for source data
s3://bucket/staging/      # Cleaned, validated data
s3://bucket/analytics/    # Business-ready aggregated data
s3://bucket/archive/      # Long-term cold storage
```

### Partitioning Strategy
- Partition by date for time-series data: `.../year=YYYY/month=MM/day=DD/`
- Add business dimensions when needed: `.../region=us-east/product=widget/`
- Keep partition granularity appropriate to query patterns
- Avoid too many small files (merge when possible)
- Example full path: `s3://prod-data/analytics/sales/year=2026/month=02/day=11/part-00000.parquet`

### File Formats
- Use Parquet for analytical workloads (columnar, efficient compression)
- Use ORC for Hive-compatible systems
- Use CSV/JSON only for raw ingestion layer
- Avoid storing CSV in analytics layers
- Use Avro for schema evolution requirements

### Compression
- Use Snappy for Parquet (good balance of speed and compression)
- Use gzip for cold storage/archive (better compression ratio)
- Use brotli for web-facing compressed assets
- Never store uncompressed data in analytics/staging layers

### Security
- Block public access on ALL data buckets (no exceptions)
- Enable bucket versioning on critical data (raw, analytics)
- Enable server-side encryption (SSE-S3 or SSE-KMS)
- Use KMS for sensitive/regulated data
- Enable MFA Delete for production buckets
- Use bucket policies to restrict access by VPC/IP when possible

### Lifecycle Policies
- Move raw data to Glacier after 90 days (adjust per use case)
- Move staging data to Glacier after 30 days
- Delete temporary/scratch data after 7 days
- Keep analytics layer in Standard or Intelligent-Tiering
- Use S3 Intelligent-Tiering for unpredictable access patterns
- Archive older partitions automatically: `year < CURRENT_YEAR - 2`

### Event Notifications
- Use S3 Event Notifications to trigger pipelines on new data arrival
- Send to SNS for fan-out patterns
- Send to SQS for buffered processing
- Send directly to Lambda for simple transformations
- Filter events by prefix/suffix to avoid spurious triggers

### Performance
- Use S3 Transfer Acceleration for cross-region uploads
- Enable S3 Select for server-side filtering (reduce data transfer)
- Use multipart upload for files > 100MB
- Randomize key prefixes if high request rate (legacy consideration)
- Use byte-range fetches for large file processing

## IAM (Security & Access Control)

### Principle of Least Privilege
- Grant only permissions required for the task
- Start with minimal permissions, add as needed
- Review permissions quarterly
- Use IAM Access Analyzer to identify overly permissive policies
- Never use `*` for resources or actions in production

### Roles Over Access Keys
- Use IAM roles for ALL service-to-service communication
- Use IAM roles for EC2/ECS/Lambda (instance profiles)
- Never hardcode access keys in code or config files
- Rotate access keys every 90 days if absolutely required
- Use temporary credentials (STS) for human access

### Role Separation
- One role per service or job function
- Separate roles for:
  - Glue crawlers (read S3, write Catalog)
  - Glue ETL jobs (read/write S3, read Catalog, write CloudWatch)
  - Lambda functions (specific to each function's needs)
  - Step Functions (orchestration, invoke other services)
  - Developers (read-only in prod, full in dev)

### Policy Conditions
Restrict access using conditions:
- Source IP: `aws:SourceIp`
- VPC: `aws:SourceVpc`
- Time window: `aws:CurrentTime`
- MFA: `aws:MultiFactorAuthPresent`
- SSL only: `aws:SecureTransport`

Example:
```json
{
  "Effect": "Deny",
  "Action": "s3:*",
  "Resource": "*",
  "Condition": {
    "Bool": {"aws:SecureTransport": "false"}
  }
}
```

### Human Access
- Enable MFA for console access (mandatory for admins)
- Use AWS SSO for centralized identity management
- Use groups for permission assignment, not individual users
- Enforce password policy (12+ chars, rotation, complexity)
- Enable CloudTrail for all API calls (audit trail)

### Service Control Policies (Multi-Account)
- Use SCPs in AWS Organizations to enforce guardrails
- Prevent disabling CloudTrail, GuardDuty, Config
- Prevent leaving organization
- Restrict regions to approved list
- Deny root user actions

## Glue (ETL & Data Catalog)

### Glue Crawlers
- Use for automatic schema discovery on new data sources
- Schedule crawlers to run after data ingestion (e.g., daily at 2 AM)
- Configure exclusion patterns to skip temp/staging files
- Use multiple crawlers for different data layers (raw, staging, analytics)
- Enable schema versioning in Data Catalog
- Set up SNS notifications for crawler failures

### Glue Jobs (PySpark)
- Use Glue 4.0+ for latest Spark optimizations and Python 3.10
- Set appropriate worker type:
  - G.1X: 1 DPU (4 vCPU, 16 GB RAM) for light workloads
  - G.2X: 2 DPU (8 vCPU, 32 GB RAM) for medium workloads
  - G.4X, G.8X: for heavy processing
- Start with minimum workers, scale based on monitoring
- Enable job bookmarks for incremental processing (avoid reprocessing)
- Use Glue DynamicFrames for schema flexibility
- Convert to Spark DataFrames for complex transformations

### Glue Job Best Practices
- Parameterize jobs (use job parameters, not hardcoded values)
- Enable continuous logging to CloudWatch
- Set meaningful job timeout (avoid default 2880 minutes)
- Use pushdown predicates to filter at source
- Partition data on write: `partitionBy(['year', 'month', 'day'])`
- Use repartition/coalesce to control output file size
- Enable metrics to track DPU utilization

### Glue Data Catalog
- Use as central Hive-compatible metastore
- Share catalog across accounts using AWS Lake Formation
- Version schema changes automatically
- Add table descriptions and column comments
- Use catalog encryption for sensitive metadata
- Integrate with Athena, Redshift Spectrum, EMR

### Development Workflow
- Use Glue Studio or Glue notebooks for interactive development
- Test on sample data in dev environment
- Use local development endpoints for faster iteration
- Version control Glue job scripts in Git
- Deploy via CDK/Terraform (never upload manually)

## Lambda (Serverless Processing)

### Function Design
- Keep functions small and focused (single responsibility)
- One function per task: validate, transform, load
- Avoid monolithic functions that do everything
- Limit function size to < 10 MB (unzipped code)
- Use layers for shared dependencies (libs, utilities)

### Configuration
- Set memory based on actual usage (monitor CloudWatch metrics)
  - More memory = more CPU proportionally
  - Start at 512 MB, adjust based on profiling
- Set timeout appropriately:
  - API responses: 5-30 seconds
  - Data processing: 1-5 minutes
  - Batch jobs: up to 15 minutes (max)
- Use ephemeral storage (/tmp) wisely (max 10 GB)
  - Clean up after use
  - Not guaranteed to persist between invocations

### Environment Variables
- Use for configuration (S3 bucket names, table names)
- Never store secrets (use Secrets Manager or Parameter Store)
- Keep count low (impacts cold start time)
- Use AWS Lambda environment variable encryption

### Runtime & Architecture
- Prefer ARM64 (Graviton2) for 20% better price-performance
- Use latest runtime versions (Python 3.11+, Node.js 20+)
- Avoid deprecated runtimes (will be disabled)

### Error Handling
- Use dead-letter queues (DLQ) for failed events
- Send to SQS or SNS for retry/analysis
- Log errors with context (request ID, input data)
- Use structured logging (JSON format)
- Set up CloudWatch alarms for error rate

### Concurrency
- Set reserved concurrency for critical functions (avoid throttling)
- Use provisioned concurrency to eliminate cold starts
- Monitor concurrent executions in CloudWatch
- Implement backoff/retry logic for downstream API calls

### Networking
- Use VPC for access to private resources (RDS, Redshift, etc.)
- Attach to private subnets with NAT Gateway for internet access
- Use VPC endpoints to avoid NAT charges (S3, DynamoDB)
- Security groups: allow only necessary outbound traffic

## Step Functions (Orchestration)

### Workflow Design
- Use for complex multi-step workflows (> 2 steps)
- Keep Lambda functions simple, Step Functions handles orchestration
- Use Standard workflows for long-running processes
- Use Express workflows for high-volume, short-duration tasks
- Implement error handling with Retry and Catch blocks
- Use Map state for parallel processing of batches

### Patterns
- ETL Pipeline: S3 trigger → Validate → Transform → Load → Notify
- Fan-out: Single input → Parallel Lambda invocations → Aggregate results
- Human-in-the-loop: Process → Wait for approval → Continue/Abort
- Saga pattern: Multi-step transaction with compensating actions on failure

## Infrastructure as Code

### Tool Selection
- Use AWS CDK (Python) for complex logic and type safety
- Use Terraform for multi-cloud or team preference
- Use CloudFormation for AWS-native simplicity
- Never create production resources manually in console

### CDK Best Practices
- Use constructs for reusability (L2/L3 constructs)
- Separate stacks by environment (dev, staging, prod)
- Use context values for environment-specific config
- Pin CDK version in requirements.txt
- Use `cdk diff` before deploying
- Tag all resources at stack level

### Terraform Best Practices
- Store state in S3 with DynamoDB locking
- Use remote backend for team collaboration
- Pin provider versions (avoid `latest`)
- Use modules for reusable components
- Separate state files by environment
- Use workspaces or separate state files for environments
- Run `terraform plan` before apply

### Version Control
- Store all IaC in Git
- Use feature branches for changes
- Require pull request reviews for production changes
- Use CI/CD for deployment (GitHub Actions, GitLab CI)
- Tag releases with semantic versioning

### Secrets Management
- Use AWS Secrets Manager for database credentials
- Use Systems Manager Parameter Store for config values
- Reference secrets in IaC, never hardcode
- Rotate secrets automatically (30-90 days)
- Use CDK SecretValue or Terraform data sources to reference

## Cost Optimization

### S3 Storage
- Use S3 Intelligent-Tiering for unpredictable access patterns
- Move old data to Glacier/Deep Archive with lifecycle policies
- Delete temporary data after defined retention period
- Use S3 Storage Lens for visibility across buckets
- Enable S3 request metrics to identify hot spots

### Glue Jobs
- Right-size DPU allocation (monitor actual usage in CloudWatch)
- Use Glue Flex execution for non-time-sensitive jobs (saves ~35%)
- Enable auto-scaling for variable workloads
- Shut down development endpoints when not in use
- Use Spot instances for Glue (if available/tolerable)

### Lambda
- Right-size memory allocation (impacts CPU and cost)
- Use ARM64 for 20% savings
- Reduce package size (faster cold starts, lower memory)
- Avoid unnecessary invocations (batch when possible)

### Data Transfer
- Use VPC endpoints for S3/DynamoDB access (avoid NAT charges)
- Use S3 Transfer Acceleration only when necessary
- Keep data in same region as compute (avoid cross-region transfer)
- Use CloudFront for frequent external access

### Compute
- Use Spot instances for non-critical batch jobs (EMR, Glue Flex)
- Purchase Reserved Capacity for steady-state workloads (RDS, Redshift)
- Use Savings Plans for flexible compute discount
- Shut down dev/test resources outside business hours (use Lambda scheduler)

### Monitoring
- Set billing alarms at account and project level
- Review AWS Cost Explorer monthly
- Use Cost Allocation Tags to track spending by project
- Enable Cost Anomaly Detection
- Review Trusted Advisor cost recommendations

## Patterns

### Event-Driven Ingestion
```
S3 Event (new file) → SNS → Lambda (validate) → Glue Job (ETL) → Athena-ready data
```
- Decoupled, scalable, automatic
- Use SNS for fan-out to multiple consumers
- Use Lambda for lightweight validation/routing
- Use Glue for heavy transformations

### Batch ETL Pipeline
```
Airflow/MWAA → Glue Crawler → Glue Job → S3 (Parquet) → Snowflake COPY INTO
```
- Scheduled processing (daily, hourly)
- Orchestrated with Airflow or Step Functions
- Glue for Spark-based transformations
- Load to warehouse via COPY (fast bulk load)

### Streaming Ingestion
```
Kinesis Data Streams → Kinesis Firehose → S3 (buffered) → Glue/Athena
```
- Real-time or near-real-time
- Firehose handles batching, compression, partitioning
- Use Lambda transform in Firehose for simple transformations
- Alternative: Kinesis → Lambda → S3/Snowflake directly

### Data Validation Pattern
```
S3 Event → Lambda (schema validation) → Valid: move to staging | Invalid: move to quarantine + alert
```
- Validate early (fail fast)
- Use Pandera, Great Expectations, or custom validation
- Quarantine bad data for investigation
- Send SNS alert on validation failure

### Multi-Step Orchestration
```
Step Functions: Start → Lambda (prepare) → Glue Job (ETL) → Lambda (quality check) → SNS (notify)
```
- Complex workflows with conditional logic
- Built-in error handling and retry
- Visual workflow in console
- Auditability via execution history

### Incremental Processing
```
Glue Job with bookmarks → Read only new S3 files → Transform → Write partitioned Parquet
```
- Avoid reprocessing old data
- Use Glue job bookmarks or custom state tracking (DynamoDB)
- Partition output by date for efficient queries

## Anti-patterns

### Security Anti-patterns (NEVER DO)
- Never hardcode AWS credentials in code or config files
- Never use root account for daily operations
- Never create public S3 buckets for data storage
- Never use `*` wildcard for resources in production IAM policies
- Never commit secrets to Git (use .gitignore for .env, credentials)
- Never disable SSL/TLS for data transfer
- Never share IAM credentials across team members

### S3 Anti-patterns (AVOID)
- Don't create S3 buckets without lifecycle policies (data will accumulate)
- Don't store uncompressed data in analytics layers (wastes storage and query time)
- Don't use sequential keys for high request rate (legacy issue, but avoid anyway)
- Don't create too many small files (< 1 MB) in Parquet (impacts query performance)
- Don't ignore S3 costs (monitor and optimize storage class)

### Glue Anti-patterns (AVOID)
- Don't run Glue jobs without CloudWatch monitoring and alarms
- Don't use maximum DPU allocation for small datasets (wastes money)
- Don't skip job bookmarks for incremental data (will reprocess everything)
- Don't ignore Glue job failures (set up SNS notifications)
- Don't use Glue for real-time streaming (use Kinesis + Lambda instead)

### Lambda Anti-patterns (AVOID)
- Don't store state in Lambda (it's stateless, use DynamoDB/S3 for state)
- Don't create monolithic functions (keep functions small and focused)
- Don't ignore cold starts for latency-sensitive APIs (use provisioned concurrency)
- Don't use Lambda for long-running batch jobs > 15 min (use Glue, Batch, or ECS)
- Don't poll for data in Lambda (use event triggers instead)

### IAM Anti-patterns (AVOID)
- Don't create IAM users for applications (use roles)
- Don't attach policies directly to users (use groups)
- Don't reuse roles across unrelated services (separation of concerns)
- Don't ignore IAM Access Analyzer findings (review and remediate)

### Infrastructure Anti-patterns (AVOID)
- Don't create resources manually in AWS console for production (use IaC)
- Don't skip `terraform plan` or `cdk diff` before applying changes
- Don't use `latest` for provider/runtime versions (pin versions for reproducibility)
- Don't store Terraform state locally (use S3 + DynamoDB backend)

### Cost Anti-patterns (AVOID)
- Don't ignore CloudWatch alarms and cost alerts
- Don't leave unused resources running (dev instances, old snapshots, orphaned volumes)
- Don't use on-demand pricing for predictable workloads (use Reserved/Savings Plans)
- Don't skip tagging resources (can't track costs by project)
- Don't over-provision resources "just in case" (start small, scale based on metrics)

### Data Pipeline Anti-patterns (AVOID)
- Don't process data synchronously in API paths (use async/background jobs)
- Don't skip data validation at ingestion (garbage in = garbage out)
- Don't create fragile pipelines without retry/error handling
- Don't ignore data quality metrics (monitor schema drift, null rates, duplicates)
- Don't build pipelines without observability (logs, metrics, traces)
