---
name: sdd-plan
user-invocable: true
description: >
  SDD workflow — create implementation plan from spec. Use when: user invokes
  /sdd-plan, a spec.md exists and needs an implementation strategy, or the user
  wants to break a spec into components before coding.
  Triggers: "/sdd-plan", "plan implementation", "create plan from spec",
  "implementation strategy".
  Do NOT use for project constitution (sdd-constitution), writing specs
  (sdd-specify), or generating tasks (sdd-tasks).
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

# SDD Plan

You create an implementation plan from an existing spec — breaking it into
components, defining execution order, and identifying risks.

## Workflow

1. **Find the spec**: If the user specifies a spec ID or slug, read that spec.
   Otherwise, list `.specify/specs/` and ask which spec to plan.
2. **Read context**:
   - `.specify/specs/{id}-{slug}/spec.md` (required — abort if missing)
   - `.specify/specs/{id}-{slug}/research.md` (if it exists)
   - `.specify/memory/constitution.md` (if it exists)
3. **Explore codebase**: Use `Glob`, `Grep`, and `Read` to understand the
   existing code relevant to the spec. Identify:
   - Files that will be created or modified
   - Existing patterns to follow
   - Dependencies between components
4. **Read template**: Read `.specify/templates/plan.md` for structure.
5. **Design the plan**: Break the spec into components with:
   - Clear responsibilities per component
   - Files to create or modify
   - Execution order (what must come first)
   - Risks and mitigations
   - Testing strategy
   - Alternatives considered (and why rejected)
6. **Write plan**: Create `.specify/specs/{id}-{slug}/plan.md`.
7. **Confirm**: Show the user the plan summary and ask for approval.

## Output

- File: `.specify/specs/{id}-{slug}/plan.md`
- Format: Markdown following the template structure

## Constraints

- MUST have a spec.md before creating a plan — abort with a clear message
  if spec.md does not exist for the given ID
- MUST explore the existing codebase to ground the plan in reality — do not
  plan in a vacuum
- MUST identify at least one risk and mitigation
- MUST define execution order — parallel-safe steps should be noted
- MUST NOT include code — the plan describes strategy, not implementation
- MUST ask the user for approval before finalizing
