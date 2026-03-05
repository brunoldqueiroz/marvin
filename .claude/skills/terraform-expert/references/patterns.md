# Terraform Expert — Patterns Reference

## Lifecycle Rules (Best Practice #7)

`create_before_destroy` ensures zero-downtime replacement for resources that
cannot exist in parallel (certificates, load balancer listeners). The new
resource is created before the old one is destroyed.

`ignore_changes` exempts externally-managed attributes from drift detection.
Keep the list as narrow as possible — one or two attributes. Broad ignore lists
mask real drift and defeat IaC purpose.

`replace_triggered_by` forces replacement of a resource when a referenced
resource or attribute changes. Useful for auto-scaling groups linked to launch
templates, or for secrets rotation.

```hcl
resource "aws_instance" "app" {
  # ...
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["LastDeployedBy"]]
    replace_triggered_by  = [aws_launch_template.app.latest_version]
  }
}
```

## CI/CD Workflow Details (Best Practice #9)

Full PR workflow:

1. `terraform fmt -check` — format gate (fail fast, no parse errors)
2. `terraform validate` — syntax and provider schema validation
3. `terraform plan -out=tfplan` — deterministic plan artifact
4. Post plan diff as PR comment (use `tfcmt` or Atlantis)
5. Required reviewer approval before merge
6. `terraform apply tfplan` on merge to main — applies the exact plan reviewed

Concurrency: Use GitHub Actions `concurrency.group` with
`cancel-in-progress: false` to serialize applies per environment. Never allow
parallel applies to the same state file.

OIDC setup: Configure `aws_iam_openid_connect_provider` in a bootstrap stack.
Never use long-lived `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in CI.

```yaml
# GitHub Actions concurrency block
concurrency:
  group: terraform-${{ github.ref }}-prod
  cancel-in-progress: false
```

## Drift Detection (Best Practice #10)

Schedule on a cron (daily or every 6 hours for production):

```bash
terraform plan -detailed-exitcode -refresh=true -out=/dev/null
# Exit code 0 = no changes
# Exit code 1 = error
# Exit code 2 = drift detected
```

On exit code 2, auto-create a GitHub issue or PagerDuty alert with the plan
output. Do NOT auto-apply drift — require human review. Drift in production
is often intentional (hotfixes, manual emergency changes).

## State Operations (Best Practice #11)

| Operation | Command | When |
|-----------|---------|------|
| List all resources | `terraform state list` | Inspect current state |
| Show resource details | `terraform state show <addr>` | Debug mismatches |
| Rename resource | `terraform state mv <old> <new>` | Module restructure |
| Adopt existing resource | `terraform import <addr> <id>` | Bring under management |
| Detect drift only | `terraform plan -refresh-only` | Non-destructive check |
| Remove without destroy | `terraform state rm <addr>` | Orphan removal |

State file backups: Before any `state mv` or `state rm`, run
`terraform state pull > backup-$(date +%Y%m%d).tfstate`. S3 backend versioning
is a safety net, not a substitute for explicit backups before risky operations.

Import workflow:
1. Write HCL resource block matching existing infrastructure
2. `terraform import <resource_type>.<name> <cloud_id>`
3. `terraform plan` — verify zero changes (config matches reality)
4. Fix any attribute drift before proceeding

## Tag Management (Best Practice #12)

Accept a `tags` variable in every module. Merge with module-level defaults
and resource-specific overrides:

```hcl
variable "tags" {
  type        = map(string)
  description = "Tags to apply to all taggable resources"
  default     = {}
}

locals {
  default_tags = {
    terraform   = "true"
    env         = var.environment
    owner       = var.owner
    cost_center = var.cost_center
  }
  merged_tags = merge(local.default_tags, var.tags)
}

resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name
  tags   = merge(local.merged_tags, { Name = var.bucket_name })
}
```

Required tags: `terraform = "true"`, `env`, `owner`. Recommended: `cost_center`,
`project`, `managed_by`. Enforce via AWS Config rules or OPA policy.

## Troubleshooting Details

### Error: Terraform wants to destroy and recreate resources when modifying a list with `count`

Cause: `count` uses numeric indices — adding/removing items shifts indices,
making Terraform think resources changed identity.

Solution: Migrate to `for_each` with string keys.

```bash
# Step 1: Identify existing state addresses
terraform state list | grep aws_subnet

# Step 2: Move each resource to its new key-based address
terraform state mv 'aws_subnet.this[0]' 'aws_subnet.this["us-east-1a"]'
terraform state mv 'aws_subnet.this[1]' 'aws_subnet.this["us-east-1b"]'

# Step 3: Update HCL to use for_each, verify plan shows no changes
terraform plan
```

### Error: State lock — "Error acquiring the state lock"

Cause: A previous apply crashed without releasing the DynamoDB lock, or
another user is running a concurrent apply.

Solution:
1. Verify no active applies: check CI/CD logs and ask teammates
2. If lock is stale: `terraform force-unlock <LOCK_ID>` (requires the lock ID
   from the error message)
3. Prevent recurrence: use CI/CD concurrency groups to serialize applies

Never use `force-unlock` while another apply is in progress — this can corrupt
state. Always verify the locking process is truly dead first.

### Error: Provider version mismatch after running `terraform init`

Cause: Version constraints too loose or `.terraform.lock.hcl` not committed,
allowing different provider versions across environments.

Solution:
1. Pin providers with `~>` in `required_providers`
2. Commit `.terraform.lock.hcl` to version control
3. Run `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`
   to generate multi-platform lock entries in CI
4. Use `terraform init -upgrade` only when intentionally bumping a provider
