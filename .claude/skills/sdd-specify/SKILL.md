---
name: sdd-specify
user-invocable: true
description: >
  SDD workflow — capture feature specification. Use when: user invokes
  /sdd-specify, wants to define a new feature, or needs to capture intent
  before implementation.
  Triggers: "/sdd-specify", "create spec", "specify feature", "new feature
  spec".
  Do NOT use for project constitution (sdd-constitution), planning (sdd-plan),
  or generating tasks (sdd-tasks).
tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - AskUserQuestion
  - Agent
metadata:
  author: bruno
  version: 1.0.0
  category: workflow
---

# SDD Specify

You capture the intent (what + why) of a feature as a structured specification,
before any implementation begins.

## Workflow

1. **Read constitution**: Read `.specify/memory/constitution.md` if it exists.
   Use it as context for constraints and standards.
2. **Determine spec ID**: Read `.specify/specs/` directory to find the next
   available zero-padded 3-digit ID (e.g., if `001-*` exists, next is `002`).
   Generate a kebab-case slug from the feature description.
3. **Clarify intent**: Use `AskUserQuestion` to understand:
   - What problem does this solve?
   - Who is affected?
   - What does success look like?
   - What is explicitly out of scope?
4. **Identify unknowns**: Assess whether research is needed:
   - Unfamiliar technology or APIs?
   - Multiple viable approaches with unclear trade-offs?
   - External dependencies with unknown constraints?
5. **Research if needed**: If unknowns exist, delegate to the `researcher`
   agent (via `Agent` tool, `subagent_type: researcher`). Instruct it to write
   findings to `.specify/specs/{id}-{slug}/research.md` following the research
   template. Follow `@.claude/rules/research.md` for parallel research when
   sub-questions are independent.
6. **Read template**: Read `.specify/templates/spec.md` for structure.
7. **Write spec**: Create `.specify/specs/{id}-{slug}/spec.md` with all
   sections populated. Incorporate research findings if research.md was
   generated.
8. **Confirm**: Show the user the spec summary and ask for approval.

## Output

- File: `.specify/specs/{id}-{slug}/spec.md`
- Optional: `.specify/specs/{id}-{slug}/research.md` (if research was needed)
- Format: Markdown following the template structure

## Constraints

- MUST read constitution.md before writing the spec (if it exists)
- MUST NOT include placeholder text — every section must have real content
- MUST NOT start implementation — the spec captures intent only
- MUST ask the user for approval before finalizing
- MUST auto-increment the spec ID based on existing specs
- PREFER capturing scope exclusions explicitly — "out of scope" prevents
  scope creep during implementation
