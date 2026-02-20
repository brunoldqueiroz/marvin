# Hooks & Settings

## Hooks

Marvin uses shell hooks to enforce quality automatically at each stage of Claude Code's execution. Hooks live in `core/hooks/` and are configured in `core/settings.json`.

### Hook Reference

| Event | Script | Matcher | Purpose |
|-------|--------|---------|---------|
| PreToolUse | `block-secrets.sh` | `Bash` | Block commands that expose secrets (env vars, credentials) |
| PreToolUse | `protect-files.sh` | `Edit\|Write` | Block edits to sensitive or lock files |
| PostToolUse | `validate-python.sh` | `Edit\|Write` | Auto-format Python with ruff/black |
| PostToolUse | `validate-sql.sh` | `Edit\|Write` | Auto-lint SQL with sqlfluff/sqlfmt |
| PostToolUse | `validate-dockerfile.sh` | `Edit\|Write` | Lint Dockerfiles with hadolint |
| PostToolUse | `validate-terraform.sh` | `Edit\|Write` | Auto-format Terraform with `terraform fmt` |
| PostToolUse | `validate-marvin.sh` | `Edit\|Write` | Validate Marvin-specific files (agents, settings) |
| PostToolUseFailure | `tool-failure-context.sh` | (all) | Inject remediation hints when tools fail |
| SessionStart | `compact-reinject.sh` | `compact` | Restore Marvin's identity and memory after context compaction |
| SessionStart | `session-context.sh` | `startup` | Inject git state (branch, status, recent commits) at session start |
| PreCompact | `pre-compact-save.sh` | (all) | Save session state before context is compacted |
| Stop | `stop-quality-gate.sh` | (all) | Block responses that handle domain tasks without delegating |
| Stop | `session-persist.sh` | (all) | Persist session log to `.claude/dev/` |
| SubagentStop | `subagent-quality-gate.sh` | (all) | Validate subagent output quality before returning to orchestrator |
| Notification | `notify.sh` | (all) | Desktop notification on Linux, macOS, and WSL |

### Shared Utilities

- `_lib.sh` — Shared helper included by all hooks. Provides `json_val()`: reads a JSON field using `jq` with a `python3` fallback, so hooks work without jq installed.
- `status-line.sh` — Provides the dynamic status bar shown in Claude Code's UI. Configured via `statusLine` in `settings.json`.

### Stop Quality Gate

`stop-quality-gate.sh` enforces the delegation protocol. When Marvin's response mentions domain keywords (dbt, spark, airflow, snowflake, terraform, docker, pipeline, DAG, warehouse) without evidence of delegation (Task tool, handoff, subagent), the hook blocks the response with exit code 2 and sends a remediation message back to Claude.

Short responses (under 100 characters) and responses that already triggered the hook are always allowed through.

## Settings

`core/settings.json` is copied to `<project>/.claude/settings.json` during installation. It configures Claude Code's behavior for all sessions in that project.

### Permission Model

Marvin uses a three-tier permission model:

| Tier | Behavior | Examples |
|------|----------|---------|
| `allow` | Run without confirmation | `Bash(git status*)`, `Read`, `Edit`, `Write`, `Bash(uv *)`, MCP tools |
| `ask` | Prompt the user before running | `Bash(git push*)`, `Bash(terraform apply*)`, `Bash(docker compose up*)` |
| `deny` | Block entirely | `Bash(rm -rf /)`, `Bash(git push --force*)`, `Read(.env)`, `Read(*.pem)` |

The full allow list includes common development tools (Python, uv, pytest, ruff, git read commands, npm, dbt, gh) and all Exa and Context7 MCP tool names. Pre-approving MCP tools is required for subagents, which cannot handle interactive permission prompts.

### Key Settings

| Setting | Value | Description |
|---------|-------|-------------|
| `env.MARVIN_ENABLED` | `"1"` | Environment variable injected into every session |
| `statusLine` | `status-line.sh` | Dynamic status bar command |
| `respectGitignore` | `true` | Honor `.gitignore` patterns in file operations |
| `cleanupPeriodDays` | `30` | Auto-cleanup period for old session data |
| `attribution.commit` | `""` | Suppress AI attribution in commits |
| `attribution.pr` | `""` | Suppress AI attribution in pull requests |

### MCP Servers

Marvin ships with two MCP server configurations in `core/.mcp.json`:

| Server | Purpose | Key |
|--------|---------|-----|
| Context7 (via Upstash) | Official library documentation lookup | `CONTEXT7_API_KEY` |
| Exa | Web search, company research, crawling | `EXA_API_KEY` |

The installer reads API keys from `.env` and resolves `${CONTEXT7_API_KEY}` / `${EXA_API_KEY}` placeholders in the template before writing `.mcp.json` to the project. If no `.env` exists, the template is deployed unresolved and the MCP servers will not authenticate.

To set up keys:

```bash
cp .env.example .env
# Edit .env with your real keys, then reinstall
make install PROJECT=~/Projects/my-project
```
