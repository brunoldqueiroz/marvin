# Plan — Recursive Decomposition

> Implementation strategy derived from the spec. Reviewable checkpoint before
> writing code.

## Approach

Extend the existing SDD skills and rules to support recursive decomposition
without creating new skills or agents. The changes are additive: the sdd-plan
skill gains complexity detection and sub-spec suggestion logic, the sdd-tasks
skill gains a sub-spec task type, specs.md rules document the spike-first
pattern and sub-spec lifecycle, and the plan template adds Dependency Graph
and Sub-Specs sections. All existing specs continue to work unchanged.

## Components

### C1: Update sdd-plan skill with complexity detection and sub-spec suggestion

- **What**: Add complexity heuristics (5+ files, 2+ architectural decisions,
  new tech, unresearched topics) to the planning workflow. When a component
  exceeds 2+ heuristics, suggest creating a sub-spec. Include Mermaid
  dependency graph generation as a planning step. Add sub-spec depth check
  (max 2 levels).
- **Files**: `.claude/skills/sdd-plan/SKILL.md` (edit)
- **Dependencies**: none

### C2: Update specs.md rules with sub-spec and spike patterns

- **What**: Add sub-spec directory structure documentation, sub-spec lifecycle
  rules, spike-first pattern (when to use, time-box, findings format, worktree
  isolation), depth limit rule, and updated directory tree showing nested
  sub-specs and spike files.
- **Files**: `.claude/rules/specs.md` (edit)
- **Dependencies**: none

### C3: Update plan template with Dependency Graph and Sub-Specs sections

- **What**: Add two new sections to the plan template: a "Dependency Graph"
  section with a Mermaid diagram placeholder and a "Sub-Specs" section with a
  status table (pending/in-progress/complete). Keep existing sections intact.
- **Files**: `.specify/templates/plan.md` (edit)
- **Dependencies**: none

### C4: Update sdd-tasks skill with sub-spec task type

- **What**: Add awareness of sub-spec task type in the task generation
  workflow. When a plan contains sub-specs, emit a "sub-spec" task that
  represents the full SDD lifecycle and blocks downstream parent tasks.
  Document the sub-spec task format.
- **Files**: `.claude/skills/sdd-tasks/SKILL.md` (edit)
- **Dependencies**: none

### C5: Integration updates (knowledge-map, scaling)

- **What**: Update knowledge-map.md to reflect the new capabilities
  (sub-spec support, spike pattern, Mermaid graphs in plans). Update
  specs.md entry in the Rules section if the description changed. No new
  skills are added, so scaling.md count stays at 19.
- **Files**: `.claude/memory/knowledge-map.md` (edit)
- **Dependencies**: C1, C2, C3, C4

### C6: Review and E2E validation

- **What**: Review all modified files for consistency, backward compatibility,
  and adherence to authoring rules. Validate Mermaid syntax in the template.
  Walk through a hypothetical complex spec to verify the workflow makes sense
  end-to-end.
- **Files**: all modified files (read-only)
- **Dependencies**: C5

## Execution Order

1. **C1 || C2 || C3 || C4** (parallel) — All four modify different files with
   no dependencies between them. Each is a self-contained edit to a single file.
2. **C5** — Integration updates require knowing the final state of C1-C4.
3. **C6** — Review and validation after all changes are complete.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| sdd-plan skill exceeds 500-line body budget after adding complexity detection + Mermaid + sub-spec logic | Medium | Keep instructions concise and principle-based. Use numbered rules, not verbose prose. Target ~120 lines total (current 71 + ~50 new). |
| specs.md becomes too long with sub-spec + spike documentation | Medium | Keep each new section to ~15-20 lines. Use bullet lists, not paragraphs. Target ~120 lines total (current 75 + ~45 new). |
| Mermaid syntax varies across renderers | Low | Use only basic `graph TD` syntax with subgraphs. Avoid advanced features. Reference mermaid.live for validation. |
| Sub-spec depth limit is hard to enforce without tooling | Low | Document as a rule with clear escalation path (promote to top-level spec). Rely on the planning agent following the documented constraint. |
| Spike time-box is advisory, not enforced | Low | Document clearly in specs.md. Spikes use worktree isolation which naturally bounds scope. |

## Testing Strategy

- **Manual verification**: Walk through each modified file and verify:
  - sdd-plan SKILL.md has all 7 mandatory sections, description < 1024 chars, body < 500 lines
  - sdd-tasks SKILL.md has all 7 mandatory sections, description < 1024 chars, body < 500 lines
  - specs.md is internally consistent (directory tree matches rules)
  - plan template Mermaid placeholder is valid syntax
  - knowledge-map reflects all changes accurately
- **Backward compatibility**: Verify existing specs (001, 002, 003) structure
  is still valid under the updated rules — no breaking changes.
- **E2E walkthrough**: Trace through a hypothetical complex spec to verify:
  - Complexity heuristics correctly identify a component as "complex"
  - Sub-spec suggestion workflow makes sense
  - Sub-spec task type in tasks.md correctly represents the lifecycle
  - Spike-first flow produces expected artifacts

## Alternatives Considered

| Alternative | Why rejected |
|-------------|-------------|
| Create a new `/sdd-decompose` skill for complexity detection | Spec explicitly requires NFR-03 (minimal new files — modify existing skills). Adding a skill increases routing complexity and skill count. |
| Create a new `/sdd-spike` skill for spike management | Same NFR-03 constraint. Spike is a pattern within planning, not a standalone workflow. Documenting it in specs.md rules is sufficient. |
| Automated sub-spec execution (no user approval) | Spec requires NFR-02 (user control). Semi-automatic with approval is the right balance. |
| Store complexity scores in Qdrant | Out of scope per spec. File-based tracking in plan.md is sufficient for now. |
