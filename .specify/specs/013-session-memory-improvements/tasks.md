# Tasks — Session Memory Improvements

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

- [x] **T-01: Enrich stop-persist.sh with work summary, duration, and outcome** — Add active spec detection (scan `.specify/specs/*/tasks.md` modified in last 60min), task progress counting (`[ ]` vs `[x]`), recently edited files (from `metrics.jsonl` tail), session duration (computed from last `session_start` event in metrics.jsonl), and outcome classification (from hook input `stop_reason`: empty/"end_turn" → completed, "interrupt"/"cancel" → interrupted, else → completed). All new fields are additive to the existing log format. Wrap each extraction in fail-open guards.
  - Files: `.claude/hooks/stop-persist.sh`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-02: Delete pre-compact state file after reinject** — Add `rm -f "$STATE_FILE"` after the state extraction block in `session-start-reinject.sh` (after extracting all fields, before outputting JSON). This prevents stale state from a prior session being re-injected in a future compaction cycle.
  - Files: `.claude/hooks/session-start-reinject.sh`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-03: Expand session-start-context.sh read limit to head -40** — Change `head -20` to `head -40` on line 38 to accommodate the richer log content from T-01 (~8-10 additional lines). Backward-compatible — old short logs simply have fewer lines to read.
  - Files: `.claude/hooks/session-start-context.sh`
  - Agent: implementer
  - Depends on: T-01
  - Wave: 2

- [x] **T-04: Create session-start-summarize.sh and register in settings.json** — Create a new SessionStart (startup) hook that: (1) counts `.log` files in `session_logs/`, (2) checks if count >= threshold (default 5, configurable via `MARVIN_SUMMARIZE_INTERVAL`), (3) checks `.claude/dev/.last-summarized` marker to avoid re-triggering, (4) concatenates all logs, extracts key patterns (specs, branches, outcomes), composes a 2-3 sentence summary, (5) outputs `additionalContext` with an instruction for Marvin to store the summary to Qdrant (type: `knowledge`, domain: `session-history`), (6) writes `.last-summarized` marker. Register the hook in `settings.json` under SessionStart startup matcher.
  - Files: `.claude/hooks/session-start-summarize.sh` (new), `.claude/settings.json`
  - Agent: implementer
  - Depends on: T-01
  - Wave: 2

- [x] **T-05: Update hooks.md inventory and session log documentation** — Add `session-start-summarize.sh` to the Current Hook Inventory table (Event: SessionStart (startup), Role: persist, Philosophy: advisory). Update the Session Logs section to document the new log fields (duration, outcome, working-on, recent-files).
  - Files: `.claude/rules/hooks.md`
  - Agent: implementer
  - Depends on: T-04
  - Wave: 3

- [x] **T-06: Review all hook changes** — Review all modified and new hooks for: correctness of fail-open guards, adherence to `hooks.md` conventions (naming, role separation, exit codes, `_lib.sh` usage), no regressions in existing log format, proper JSON output escaping, and performance (no unbounded operations).
  - Files: `.claude/hooks/stop-persist.sh`, `.claude/hooks/session-start-reinject.sh`, `.claude/hooks/session-start-context.sh`, `.claude/hooks/session-start-summarize.sh`, `.claude/settings.json`, `.claude/rules/hooks.md`
  - Agent: reviewer
  - Depends on: T-01, T-02, T-03, T-04, T-05
  - Wave: 4

- [x] **T-07: Syntax check and manual verification of all hooks** — Run `bash -n .claude/hooks/*.sh` to verify syntax of all hooks. Manually verify: (1) start+stop a session and check new fields in session log, (2) verify `session-start-context.sh` injects richer log content, (3) verify `.pre-compact-state.json` is deleted after reinject, (4) verify summarize hook outputs context when threshold is met.
  - Files: `.claude/hooks/*.sh`
  - Agent: tester
  - Depends on: T-06
  - Wave: 5

## Execution Phases

| Phase | Tasks | Parallel? | Notes |
|-------|-------|-----------|-------|
| 1 | T-01, T-02 | Yes | Independent files, no conflicts |
| 2 | T-03, T-04 | Yes | Both depend on T-01 only, different files |
| 3 | T-05 | No | Documentation, depends on T-04 |
| 4 | T-06 | No | Review of all changes |
| 5 | T-07 | No | Final verification |

## Task Dependency Graph

```
T-01 ──┬──→ T-03 ──┐
       │            │
       └──→ T-04 ──→ T-05 ──┐
                             ├──→ T-06 ──→ T-07
T-02 ────────────────────────┘
```

## Acceptance Criteria

- [ ] Session logs include `duration:`, `outcome:`, `working-on:`, and `recent-files:` fields
- [ ] `session-start-context.sh` injects richer log (up to 40 lines) without errors
- [ ] `.pre-compact-state.json` is deleted after successful reinject
- [ ] `session-start-summarize.sh` triggers after 5 sessions and outputs Qdrant instruction
- [ ] `session-start-summarize.sh` is registered in `settings.json`
- [ ] `hooks.md` inventory table includes the new hook
- [ ] All hooks pass `bash -n` syntax check
- [ ] Old-format session logs are handled gracefully (backward compatibility)
- [ ] No hook takes longer than 2 seconds to execute
