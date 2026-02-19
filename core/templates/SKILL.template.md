---
name: {{NAME}}
description: "{{DESCRIPTION}} Use when {{WHEN_TO_USE}}."
disable-model-invocation: true
argument-hint: "[{{ARGUMENT_HINT}}]"
---

# {{DISPLAY_NAME}}

{{CONTEXT_LABEL}}: $ARGUMENTS

## Process

### 1. Understand

Analyze $ARGUMENTS to determine what is being asked. If requirements are
ambiguous, ask the user before proceeding.

### 2. Plan

Determine the approach and identify which agents to delegate to.

### 3. Execute

Delegate to the **{{AGENT}}** agent:
- {{INSTRUCTION_1}}
- {{INSTRUCTION_2}}

### 4. Verify

Delegate to the **verifier** agent:
- Run tests and lint checks
- Validate output against requirements
- Check for security issues

### 5. Summary

Present to the user:
- What was done
- Files created or modified
- Next steps

<!-- ## Workflow Graph
Uncomment for orchestration skills with 3+ agent delegations.

| Node | Agent | Depends On | Output |
|------|-------|-----------|--------|
| understand | (direct) | — | Requirements clarified |
| execute | {{AGENT}} | understand | Implementation |
| verify | verifier | execute | Verification report |
| summary | (direct) | verify | User-facing summary |
-->

## Notes
- Follow project conventions
- Delegate to specialized agents for domain-specific work
- Write output to appropriate location
