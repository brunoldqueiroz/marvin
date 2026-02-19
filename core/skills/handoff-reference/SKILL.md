# Handoff Protocol — Full Reference

This is the complete reference for the structured handoff protocol.
For the compact version auto-loaded every session, see `~/.claude/rules/handoff-protocol.md`.

## Protocol Overview

Structured handoffs replace free-text delegation to reduce coordination failures. Every delegation to a specialized agent uses this protocol to ensure complete context transfer and clear success criteria.

**Failure modes this addresses:**
- Incomplete context transfer (missing files, decisions, preferences)
- Ambiguous acceptance criteria (unclear "done" definition)
- Missing constraints (policy violations, forgotten guardrails)
- Unclear return protocol (lost work, missing decisions)

## Field Justification

Each field prevents specific failure modes:

| Field | Prevents |
|-------|----------|
| Objective | Ambiguous task scope, scope creep |
| Acceptance Criteria | Unclear "done" definition, incomplete work |
| Constraints (MUST/MUST NOT) | Missing guardrails, policy violations, forgotten requirements |
| Context | Incomplete context transfer, redundant questions |
| Return Protocol | Lost decisions, missing assumptions, unclear next steps |
| Error History | Repeated failed approaches, wasted effort |
| Detailed Background | Misunderstanding system architecture, breaking dependencies |

## Examples

### Example 1: dbt Model Creation (Standard)

**Before (free-text):**
> "Create a staging model for the orders table from Salesforce source"

**After (structured):**
```markdown
## Handoff: dbt-expert

### Objective
Create staging model `stg_salesforce__orders` from raw Salesforce orders table.

### Acceptance Criteria
- [ ] Model follows naming convention `stg_salesforce__orders.sql`
- [ ] Includes unique and not_null tests on primary key
- [ ] Column names use snake_case
- [ ] Model documented in schema.yml

### Constraints
MUST: Follow conventions in `~/.claude/agents/dbt-expert/rules.md`
MUST: Use `source()` function, never hardcode table names
MUST NOT: Add business logic (staging is 1:1 with source)
PREFER: Explicit column selection over SELECT *

### Context
**Key Files:** `models/staging/salesforce/_salesforce__sources.yml` (source schema)
**Prior Decisions:** Using Snowflake as warehouse, materialized as view
**User Preferences:** User prefers explicit column selection in staging

### Return Protocol
Report: Model file path, tests added, any schema assumptions made.
On failure: Describe blocker (missing source, schema mismatch).
On ambiguity: Ask about nullable columns or data type conversions.
```

### Example 2: Git Commit (Minimal)

**Before (free-text):**
> "Commit the changes to the handoff protocol file"

**After (structured):**
```markdown
## Handoff: git-expert

### Objective
Commit the new handoff protocol rule file.

### Acceptance Criteria
- [ ] Conventional commit format used
- [ ] Commit message explains purpose (why, not what)
- [ ] Only handoff-protocol.md staged

### Constraints
MUST: Include co-authored-by trailer
MUST NOT: Push to remote
MUST NOT: Commit unrelated files
```

## For Receiving Agents

When you receive a structured handoff:

1. **Parse systematically** — Read each section to understand full scope before starting
2. **Work through acceptance criteria** — Check off each item as you complete it
3. **Follow constraints strictly** — MUST takes absolute priority, MUST NOT are violations, PREFER when feasible
4. **Use the return protocol** — Report using the specified format, include all requested information

If acceptance criteria conflict with constraints, or context is insufficient, ask for clarification immediately using the return protocol.
