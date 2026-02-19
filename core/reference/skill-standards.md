# Skill Authoring Standards

Reference for creating and maintaining Marvin skills. Not auto-loaded — consult
when authoring or reviewing skills.

## Skill Anatomy

Every skill is a `SKILL.md` file at `core/skills/<name>/SKILL.md` with this structure:

```
1. YAML frontmatter (name, description, flags)
2. Title + $ARGUMENTS echo
3. Numbered phases (### 1. Phase Name)
4. Agent delegations within phases
5. ## Workflow Graph (orchestration skills with 3+ delegations)
6. ## Notes (constraints, guardrails)
```

## Frontmatter

```yaml
---
name: <kebab-case>
description: "<What it does. Use when [trigger].>"
disable-model-invocation: true
argument-hint: "[<hint text>]"
---
```

- **description**: Two sentences. First: what the skill does. Second: when to use it,
  starting with "Use when".
- **disable-model-invocation**: Always `true` — skills are user-invoked only.
- **argument-hint**: Bracketed hint shown in the CLI.

## Title and Arguments

```markdown
# <Display Name>

<Context label>: $ARGUMENTS
```

The context label describes the argument semantics (e.g., "Feature:", "Task:",
"Pipeline request:", "Decision:").

## Phases

Use numbered `###` headings. Each phase is a discrete step:

```markdown
### 1. Understand
### 2. Plan
### 3. Execute
### 4. Verify
### 5. Summary
```

Phase names should be verbs or verb phrases. The exact phases depend on the skill's
workflow, but most skills should include a verification step.

## Agent Delegation

Use this sentence format to delegate work:

```markdown
Delegate to the **<agent-name>** agent:
- <specific instruction 1>
- <specific instruction 2>
```

Bold the agent name. Follow with a bullet list of specific instructions.

## Verifier Gate

All multi-agent workflow skills MUST include a verification phase. Place it as the
penultimate step (before Summary). Delegate to the **verifier** agent with explicit
checks:

```markdown
### N. Verify

Delegate to the **verifier** agent:
- Run full test suite
- Check lint / type errors
- Validate naming conventions
- Confirm no security issues
```

## Workflow Graph

Skills with 3 or more agent delegations MUST include a `## Workflow Graph` section.
Place it after the last phase and before `## Notes`.

Format as a markdown table:

```markdown
## Workflow Graph

| Node | Agent | Depends On | Output |
|------|-------|-----------|--------|
| requirements | (direct) | — | Requirements clarified |
| design | (direct) | requirements | Design document |
| component_a | agent-a | design | Component A files |
| component_b | agent-b | design | Component B files |
| verify | verifier | component_a, component_b | Verification report |
| summary | (direct) | verify | User-facing summary |
```

### Columns

- **Node**: Short snake_case identifier for the step.
- **Agent**: The specialist agent, or `(direct)` for work done by the orchestrator.
- **Depends On**: Comma-separated list of node names that must complete first.
  Use `—` for entry nodes.
- **Output**: What this node produces.

### Parallel Execution Rule

Nodes that share the same `Depends On` value and have no dependency on each other
SHOULD be delegated in parallel using multiple Task tool calls in a single message.

Example: If `component_a`, `component_b`, and `component_c` all depend only on
`design`, launch all three as parallel Task calls.

## Notes Section

Every skill ends with `## Notes` containing constraints and guardrails:

```markdown
## Notes
- <Constraint or best practice 1>
- <Constraint or best practice 2>
```

## Skill Categories

| Category | Degrees of Freedom | Description |
|----------|-------------------|-------------|
| **Meta** | HIGH | Self-extension skills (/new-agent, /new-skill, /new-rule) |
| **Workflow** | MEDIUM | Multi-phase orchestration (/spec, /pipeline, /tdd) |
| **Utility** | LOW | Focused single-purpose (/remember, /review) |
| **Generator** | MEDIUM | Scaffold output from input (/dbt-model, /dag, /adr) |

- **HIGH**: Skill adapts structure to input, creates novel artifacts.
- **MEDIUM**: Skill follows a fixed workflow but adapts content to input.
- **LOW**: Skill performs a narrow, predictable operation.

## Progressive Disclosure

When a skill template or phase exceeds ~40 lines, consider splitting:
- Extract long templates into separate files in the skill's directory.
- Reference them with "Use the template at `core/skills/<name>/template.md`".
- Keep the main SKILL.md as the orchestration flow.

## Checklist for New Skills

- [ ] Frontmatter has two-sentence description ("What. Use when.")
- [ ] `$ARGUMENTS` is echoed with a context label
- [ ] Phases use numbered `###` headings
- [ ] Agent delegations use bold name + bullet list format
- [ ] Multi-agent skills have a verifier gate
- [ ] Skills with 3+ delegations have a `## Workflow Graph`
- [ ] `## Notes` section exists with constraints
- [ ] Skill is registered in `core/registry/skills.md`
