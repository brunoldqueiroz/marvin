---
name: sdd-plan
user-invocable: true
description: >
  SDD workflow — create implementation strategy from spec. Use when: user
  invokes /sdd-plan, a spec.md exists and needs an execution strategy, or the
  user wants to break a spec into ordered components before generating tasks.
  Triggers: "/sdd-plan", "plan implementation", "create plan from spec",
  "implementation strategy", "break spec into components".
  Do NOT use for project constitution (sdd-constitution), writing feature specs
  (sdd-specify), or generating task checklists (sdd-tasks). This skill produces
  strategy documents, not actionable task lists.
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

5a. **Complexity check**: For each component, evaluate against these heuristics:
   - (a) Touches 5+ files
   - (b) Involves 2+ architectural decisions
   - (c) Introduces a new technology or dependency not in the project
   - (d) Requires research that hasn't been done yet

   A component matching **2 or more** heuristics is flagged as **complex**.
   A component matching heuristic (c) or (d) is also annotated as **spike-first**
   (uncertain feasibility, new tech, or performance-critical path — validate
   approach before full implementation).

5b. **Sub-spec suggestion**: For each complex component:
   1. Check the current spec's path depth. Count how many parent directories
      sit between `.specify/specs/` and this spec's directory:
      - Depth 1 (e.g., `specs/001-foo/`) — at root level, sub-specs allowed.
      - Depth 2 (e.g., `specs/001-foo/001-bar/`) — at child level, sub-specs
        allowed (grandchild is the limit).
      - Depth 3+ — at grandchild level. Sub-specs are **not** allowed. Propose
        a separate top-level spec instead and skip to step 5c.
   2. For each complex component within the depth limit, present to the user
      via `AskUserQuestion`:
      - Component name
      - Which heuristics triggered
      - What the sub-spec would cover
      Ask the user to approve or reject each sub-spec individually.

5c. **Create approved sub-specs**: For each user-approved sub-spec:
   - Determine the next available sub-ID by listing
     `.specify/specs/{parent-id}-{slug}/` (zero-padded 3-digit, e.g., `001`).
   - Create `.specify/specs/{parent-id}-{slug}/{sub-id}-{sub-slug}/spec.md`
     following the spec template structure.
   - The sub-spec's scope is exactly the complex component it replaces.

6. **Write plan**: Create `.specify/specs/{id}-{slug}/plan.md`. The plan MUST
   include:
   - All standard sections from the template
   - A **Sub-Specs** section listing any sub-specs created, with their paths
     and the components they cover
   - A **Dependency Graph** section with a Mermaid `graph TD` diagram:
     - Each component is a node
     - Dependencies are directed edges
     - Sub-specs appear as `subgraph` blocks
     - Spike-first components use a distinct shape (e.g., `[/component/]`) or
       a `:::spike` class annotation

   Example graph shape (structure only — adapt to actual components):
   ```
   graph TD
     subgraph sub["001-auth-core (sub-spec)"]
       B[JWT handler]
     end
     A[API layer] --> B
     C[/Token refresh/]:::spike --> B
     classDef spike fill:#ffe0b2
   ```

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
- MUST run complexity check (step 5a) on every component before writing the plan
- MUST annotate spike-first components in the Mermaid graph and in the plan text
- MUST NOT create sub-specs beyond depth 2 (grandchild level) — escalate to a
  new top-level spec instead
- MUST include a Dependency Graph (Mermaid) and Sub-Specs section in plan.md
  (Sub-Specs section may note "None" if no sub-specs were created)
