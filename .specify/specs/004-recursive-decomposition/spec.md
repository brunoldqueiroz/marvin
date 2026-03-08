# Spec — Recursive Decomposition

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

The current SDD pipeline is strictly linear: specify → plan → tasks → implement.
When a spec contains components of vastly different complexity, the plan treats
them uniformly — a simple config change and a new module architecture get the
same level of task granularity. This leads to:

1. **Oversized tasks** — a single task like "implement the data pipeline module"
   hides 3+ files, 2 architectural decisions, and integration work that should
   be separately specified.
2. **No recursive depth** — there is no mechanism for a plan component to
   spawn its own spec/plan/tasks cycle. The only decomposition available is
   splitting into more tasks, not into sub-specs with their own research,
   planning, and review phases.
3. **No spike phase** — high-risk components (new technology, unfamiliar API,
   uncertain feasibility) go straight to implementation without a lightweight
   proof-of-concept step.
4. **Flat dependency tracking** — task dependencies are listed but not
   visualized or analyzed. Cross-component dependencies are invisible.

This affects Marvin (the orchestrator) and the user — complex features take
more iterations because the plan doesn't match the actual problem structure.

## Desired Outcome

After implementation:

1. `/sdd-plan` detects components that exceed a complexity threshold and
   **suggests sub-specs** for them. The user approves or rejects each
   suggestion — semi-automatic, not forced.
2. Sub-specs follow the full SDD cycle (specify → plan → tasks → implement →
   review → test) independently, with results flowing back to the parent spec.
3. Plan documents include a **Mermaid dependency graph** showing the
   relationships between components, sub-specs, and decision points.
4. High-risk components can be marked as **"spike first"** in the plan,
   triggering a lightweight PoC before full implementation.
5. The user experiences a natural recursive structure: complex problems are
   broken into manageable sub-problems, each with its own specification depth.

## Requirements

### Functional

1. **FR-01: Complexity detection in /sdd-plan** — When designing a plan,
   evaluate each component against complexity heuristics: (a) touches 5+
   files, (b) involves 2+ architectural decisions, (c) introduces a new
   technology or dependency, (d) requires research that hasn't been done.
   Components exceeding 2+ heuristics are flagged as "complex."
2. **FR-02: Sub-spec suggestion** — For each complex component, suggest
   creating a sub-spec. Present the suggestion to the user with: component
   name, why it's complex (which heuristics triggered), and what the sub-spec
   would cover. User approves or rejects.
3. **FR-03: Sub-spec creation** — Approved sub-specs are created at
   `.specify/specs/{parent-id}-{slug}/{sub-id}-{sub-slug}/spec.md`. Sub-spec
   IDs are scoped to the parent (e.g., `003-self-consistency/001-rubric-engine/`).
   Sub-specs follow the full SDD cycle independently.
4. **FR-04: Sub-spec result integration** — When a sub-spec's tasks are
   complete, the parent plan references the sub-spec's outputs. The parent
   task that spawned the sub-spec is marked as complete when the sub-spec
   reaches its own "all tasks done" state.
5. **FR-05: Mermaid dependency graph** — Every plan.md includes a Mermaid
   graph showing: components as nodes, dependencies as edges, sub-specs as
   subgraphs, spike-first components with a distinct marker. The graph is
   generated during `/sdd-plan` and updated when sub-specs are added.
6. **FR-06: Spike-first pattern** — Plan components can be annotated as
   "spike first" when they involve: (a) new technology not used in the
   project, (b) uncertain feasibility, (c) performance-critical paths where
   the approach needs validation. Spikes are implemented as time-boxed
   implementer tasks in a worktree, with a findings report as output.
7. **FR-07: Spike findings integration** — Spike results (feasibility:
   yes/no, approach validated, risks discovered) are written to
   `.specify/specs/{id}-{slug}/spike-{component}.md` and referenced in the
   plan. If the spike invalidates the planned approach, the plan must be
   updated before proceeding.
8. **FR-08: Depth limit** — Sub-specs can recurse at most 2 levels deep
   (parent → child → grandchild). If a grandchild component is still too
   complex, it should be escalated to the user as a separate top-level spec.
9. **FR-09: Updated /sdd-tasks with sub-spec awareness** — When generating
   tasks from a plan that contains sub-specs, emit a "sub-spec" task type
   that represents the entire sub-spec lifecycle (specify → plan → tasks →
   implement → review). This task blocks downstream parent tasks.
10. **FR-10: Plan template update** — Add a "Dependency Graph" section and a
    "Sub-Specs" section to the plan template. The dependency graph section
    contains the Mermaid diagram. The sub-specs section lists each sub-spec
    with status (pending/in-progress/complete).

### Non-Functional

1. **NFR-01: Backward compatibility** — Existing specs (001, 002, 003) must
   continue to work. The new features are additive — plans without sub-specs
   or spikes are still valid.
2. **NFR-02: User control** — Sub-spec suggestions are always presented for
   approval. The user can reject any suggestion and keep the component as a
   regular task. No forced recursion.
3. **NFR-03: Minimal new files** — This spec modifies existing SDD skills and
   rules rather than creating new skills. The changes are to: sdd-plan skill,
   sdd-tasks skill, specs.md rules, and the plan template.
4. **NFR-04: Mermaid compatibility** — Dependency graphs must use standard
   Mermaid syntax renderable by GitHub, VS Code, and common markdown viewers.
5. **NFR-05: Spike cost control** — Spikes are time-boxed (max 15 minutes of
   agent time). If the spike exceeds the time-box, it reports partial findings
   and the user decides whether to continue or pivot.

## Scope

### In Scope

- Complexity heuristics for detecting components that need sub-specs
- Semi-automatic sub-spec suggestion during `/sdd-plan`
- Sub-spec directory structure and lifecycle
- Mermaid dependency graph in plan.md
- Spike-first pattern documented in specs.md rules
- Spike findings file format and integration
- Plan template update with Dependency Graph and Sub-Specs sections
- /sdd-tasks awareness of sub-spec task type
- Depth limit (max 2 levels)

### Out of Scope

- Automatic sub-spec execution (user still drives the SDD cycle manually)
- Visual rendering of Mermaid graphs (relies on existing tooling)
- Changes to /sdd-specify or /sdd-constitution skills
- New standalone skills (no /sdd-decompose or /sdd-spike skill)
- Changes to agent definitions
- Cross-spec dependency tracking (dependencies between top-level specs)

## Constraints

- Must follow skill authoring rules for any skill modifications
- Sub-spec paths must follow existing spec numbering conventions (zero-padded)
- Mermaid graphs must be valid syntax — test with `mermaid.live` examples
- Spike tasks use worktree isolation (existing Agent `isolation: "worktree"`)
- Must not increase CLAUDE.md beyond 200 lines
- Changes to rules/specs.md must stay under reasonable length

## Open Questions

- Should the complexity threshold be configurable per project (via
  constitution.md) or fixed? Recommendation: fixed defaults with optional
  constitution override. Start with fixed; add override later if needed.
- Should spike findings be stored in Qdrant as well as in the spike file?
  Recommendation: yes, as type `spike` — but defer to a future spec to avoid
  scope creep. For now, file-only.

## References

- `.specify/specs/002-cognitive-memory/initial-analysis.md` — section 5
  (Better Hierarchical Decomposition)
- `.claude/rules/specs.md` — current SDD pipeline and directory structure
- `.claude/skills/sdd-plan/SKILL.md` — skill to be modified
- `.claude/skills/sdd-tasks/SKILL.md` — skill to be modified
- `.specify/templates/plan.md` — template to be updated
