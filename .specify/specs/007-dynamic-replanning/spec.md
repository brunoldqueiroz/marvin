# Spec — Dynamic Replanning

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Once a `plan.md` is written in the SDD pipeline, it is treated as immutable
during execution. The orchestrating agent follows the task checklist
faithfully, even when early tasks reveal that later tasks are based on
invalidated assumptions — wrong file paths, unexpected complexity, an approach
that doesn't work as planned, or a component that turned out to be unnecessary.

This causes two concrete problems:

1. **Wasted work**: the agent completes tasks that are no longer relevant
   because the landscape changed during earlier tasks. For example, task T-03
   assumes a module structure decided in T-01, but T-01's reviewer suggests a
   different structure. T-03 proceeds with the original plan and produces work
   that must be redone.

2. **Silent drift**: the agent notices something is off but has no mechanism
   to pause and report it. It either powers through (producing suboptimal
   output) or gets blocked without explaining why. The user only discovers the
   drift during the final review, when the cost of correction is highest.

Spec 006 added dependency-aware task execution with a re-evaluation loop after
each batch. This spec extends that loop with a **plan checkpoint** — a
lightweight validity check that catches deviations early and surfaces them to
the user before wasted work accumulates.

## Desired Outcome

After implementation:

1. The Task Execution section in `specs.md` includes a plan checkpoint step
   in the re-evaluation loop (after marking tasks complete, before deriving
   the next batch).
2. The checkpoint evaluates three quick signals:
   - **Failure signal**: did any task in the batch fail or get skipped (`[-]`)?
   - **Contradiction signal**: did any task produce output (files modified,
     reviewer feedback) that contradicts a plan assumption?
   - **Coherence signal**: does the next batch of tasks still make sense given
     what just happened?
3. If all signals pass, execution continues silently (no user interruption).
4. If any signal fails, the agent pauses, reports the deviation with specifics
   (which signal, what evidence), and suggests one of: (a) continue as-is,
   (b) adjust the plan (with specific proposed changes), (c) abort execution.
5. Plan modifications require explicit user approval — the agent suggests but
   does not auto-edit `plan.md`.
6. The checkpoint is lightweight — no file re-reads or heavyweight analysis.
   The agent uses information already available from the just-completed batch.

## Requirements

### Functional

1. **FR-01: Plan checkpoint in re-evaluation loop** — Add a checkpoint step
   to the Task Execution section of `specs.md`, positioned after marking tasks
   `[x]` and before deriving the next ready batch. The checkpoint evaluates
   three signals (FR-02, FR-03, FR-04).

2. **FR-02: Failure signal** — Check if any task in the just-completed batch
   was marked `[-]` (skipped) or failed (agent returned SIGNAL:BLOCKED or
   produced an error). If yes, the checkpoint fails. Report which task(s)
   failed and what downstream tasks are affected.

3. **FR-03: Contradiction signal** — Check if any task in the batch produced
   output that contradicts a known plan assumption. Contradiction indicators:
   (a) a reviewer requested changes that alter the component's interface or
   structure, (b) an implementer modified files not listed in the task's
   `Files:` field (unexpected scope expansion), (c) an implementer reported
   that the planned approach doesn't work and used an alternative. If any
   indicator fires, the checkpoint fails. Report the specific contradiction.

4. **FR-04: Coherence signal** — Inspect the next batch of ready tasks and
   verify they still make sense. Coherence fails if: (a) a next-batch task
   references a file or component that was renamed, deleted, or restructured
   in the current batch, (b) a next-batch task's description assumes an
   approach that was changed during the current batch. This is a lightweight
   scan of task descriptions, not a full re-read of plan.md.

5. **FR-05: Deviation report** — When any signal fails, present a structured
   deviation report to the user:
   ```
   ## Plan Checkpoint — Deviation Detected

   **After**: {batch description, e.g., "Phase 2 (T-05)"}
   **Signal**: {failure | contradiction | coherence}
   **Evidence**: {specific details}
   **Affected tasks**: {downstream task IDs}

   **Options**:
   (a) Continue as-is — proceed despite the deviation
   (b) Adjust plan — {specific proposed changes to plan.md}
   (c) Abort — stop spec execution
   ```
   Use `AskUserQuestion` to get the user's decision.

6. **FR-06: Plan adjustment flow** — If the user chooses "adjust plan":
   (a) The agent proposes specific edits to `plan.md` (component changes,
   reordering, scope reduction).
   (b) The agent also proposes corresponding edits to `tasks.md` (task
   modifications, additions, removals, dependency updates).
   (c) User approves the edits before they are applied.
   (d) After edits, the re-evaluation loop restarts from phase derivation
   (re-parse the updated tasks.md).

7. **FR-07: Silent pass** — If all three signals pass, the checkpoint produces
   no output and execution continues without interruption. The checkpoint
   should be invisible to the user when everything is on track.

### Non-Functional

1. **NFR-01: Lightweight execution** — The checkpoint must not re-read
   `plan.md` or perform heavyweight analysis. It uses only information already
   available: the batch results, the task list in memory, and the agent's
   knowledge of what files were modified.

2. **NFR-02: No new files or skills** — The checkpoint logic lives entirely
   within the Task Execution section of `specs.md`. No new rules files, skills,
   or templates are created.

3. **NFR-03: Backward compatible** — Specs without plan checkpoints (all
   existing specs) continue to work. The checkpoint is part of the execution
   flow, not a mandatory section in tasks.md or plan.md.

4. **NFR-04: Minimal overhead on happy path** — When all signals pass (the
   common case), the checkpoint adds zero user-visible overhead. No messages,
   no pauses, no confirmations.

## Scope

### In Scope

- Plan checkpoint step in specs.md Task Execution section
- Three signal checks (failure, contradiction, coherence)
- Deviation report format with user decision point
- Plan adjustment flow with user approval
- Knowledge-map update

### Out of Scope

- Automatic plan modification without user approval
- Heavyweight checkpoint (re-reading plan.md, running diffs)
- New skills, templates, or rules files
- Checkpoint configuration or thresholds (fixed lightweight approach)
- Changes to sdd-plan or sdd-tasks skills (checkpoint is in execution, not
  generation)
- Tracking checkpoint history across sessions

## Constraints

- specs.md must remain under 170 lines total after this addition
- The checkpoint must integrate naturally into the existing re-evaluation loop
  from spec 006 (not a separate section)
- Plan adjustments follow the suggest-only pattern — agent proposes, user
  approves

## Open Questions

- Should the deviation report be stored in Qdrant as a learning record?
  Recommendation: no — deviations are session-specific. If the deviation
  reveals a recurring pattern, the user can run `/reflect` to capture it.

## References

- `.claude/rules/specs.md` — Task Execution section (spec 006)
- `.specify/specs/006-task-dependency-graph/spec.md` — the execution rules
  this spec extends
