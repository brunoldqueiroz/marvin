# Spec — Agent Hardening

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin's 5 specialist agents (implementer, reviewer, tester, researcher,
security) operate on narrative guidance — "be thorough", "follow conventions",
"iterate if needed". This leaves compliance gaps where agents can rationalize
skipping steps, retry indefinitely on stuck problems, or claim completion
without concrete evidence. Research across 6 open-source Claude Code frameworks
(superpowers, ring, GSD, Backlog.md, agent-starter-kit, agentspec) reveals
convergent patterns for closing these gaps through explicit, deterministic
guard rails.

Additionally, the SDD pipeline lacks two lightweight conventions that improve
traceability: pre-computed execution waves in tasks.md and per-task commit
messages that enable git-native audit trails.

## Desired Outcome

After implementation:

1. Each agent has a **Red Lines** section with an anti-rationalization table
   that names specific AI shortcuts and prescribes required actions.
2. All agents enforce a **3-failure stop rule** — after 3 failed attempts at
   the same problem, the agent stops and reports instead of continuing to patch.
3. The `/sdd-tasks` skill annotates each task with a **`Wave: N`** field
   computed at generation time, making parallel dispatch explicit and
   user-reviewable before execution.
4. The implementer agent follows a **per-task commit convention**
   (`feat({spec-id}-T-{task-id}): ...`) that makes `git log --grep` a reliable
   audit trail per spec.

## Requirements

### Functional

1. **FR-01**: Each of the 5 AGENT.md files MUST include a `## Red Lines`
   section containing an anti-rationalization table with at least 5 entries
   per agent, formatted as `| AI Shortcut | Required Action |`.
2. **FR-02**: Red Lines MUST be agent-specific — targeting failure modes
   unique to each agent's role (e.g., implementer skipping tests vs. reviewer
   soft-passing without reading files).
3. **FR-03**: All 5 agents MUST include a stop rule: "If the same problem
   persists after 3 attempts, STOP. Report: what was tried, hypothesis for
   each attempt, why each failed. Do not attempt a 4th fix."
4. **FR-04**: The stop rule MUST replace any existing inconsistent retry limits
   (implementer currently says 5, tester says 3) with a uniform limit of 3
   across all agents.
5. **FR-05**: The `/sdd-tasks` skill MUST compute and annotate each task with
   `Wave: N` based on the dependency graph, where Wave 1 = tasks with no
   dependencies, Wave N = tasks whose dependencies are all in waves < N.
6. **FR-06**: The tasks.md template MUST include a `Wave` field in the task
   format and an execution phases summary showing wave composition.
7. **FR-07**: The implementer agent MUST use the commit message convention
   `feat({spec-id}-T-{task-id}): <description>` when committing task work,
   where `{spec-id}` is the spec slug (e.g., `011-agent-hardening`) and
   `{task-id}` is the task ID (e.g., `T-01`).
8. **FR-08**: The `specs.md` rule MUST document the per-task commit convention
   in the Task Execution section.

### Non-Functional

1. **NFR-01**: Red Lines tables MUST NOT exceed 10 entries per agent — concise
   beats exhaustive. Target the highest-frequency failure modes.
2. **NFR-02**: Wave computation MUST handle cycles gracefully — if cycle
   detection (from existing step 4b) finds a cycle, wave assignment is skipped
   and the error is reported as before.
3. **NFR-03**: The commit convention is advisory when agents run in worktree
   isolation — the orchestrator handles final commit integration.
4. **NFR-04**: Total lines added per AGENT.md SHOULD NOT exceed 25 — guard
   rails must be scannable, not walls of text.

## Scope

### In Scope

- Adding `## Red Lines` section to all 5 AGENT.md files
- Unifying stop rule to 3-attempt limit across all agents
- Adding `Wave: N` computation to `/sdd-tasks` skill
- Updating tasks.md template with Wave field
- Adding per-task commit convention to implementer agent and specs.md
- Updating knowledge-map.md to reflect changes

### Out of Scope

- Verification gate / Definition of Done (separate spec — builds on tester agent)
- Two-stage review (separate spec — restructures reviewer workflow)
- `/sync-context` skill (separate spec — infrastructure concern)
- Model allocation by phase (documentation-only change, can be done standalone)
- Shared patterns library for agents (premature at 5 agents)
- Changes to hooks, skills other than sdd-tasks, or rules other than specs.md

## Constraints

- MUST NOT change agent tool allowlists or model assignments
- MUST NOT add new agents or skills
- MUST preserve all existing agent functionality — Red Lines are additive
- MUST follow existing AGENT.md structure conventions per `rules/agents.md`
- Red Lines content MUST be grounded in observed AI failure modes from the
  6-repo research, not speculative

## Open Questions

None — all patterns are well-documented across multiple source repos.

## References

- Research: superpowers (`obra/superpowers`) — anti-rationalization tables,
  verification gates, 3-failure stop rule
- Research: ring (`LerianStudio/ring`) — anti-rationalization tables, pressure
  resistance, hard escalation thresholds, severity calibration
- Research: GSD (`gsd-build/get-shit-done`) — pre-computed wave field,
  atomic per-task commits, model profile routing
- Research: Backlog.md (`MrLesk/Backlog.md`) — Definition of Done, sub-task
  IDs, per-task commits
- Research: agent-starter-kit (`ntorga/agent-starter-kit`) — Red Lines section,
  acceptance criteria in handoff, tiered review
- Research: agentspec (`luanmorenommaciel/agentspec`) — pre-flight checklists,
  build reports, lessons-learned, cascade detection
