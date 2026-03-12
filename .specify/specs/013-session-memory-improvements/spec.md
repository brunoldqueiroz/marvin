# Spec — Session Memory Improvements

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin's session memory system captures a **git status snapshot** on session
end but fails to preserve **user intent, work progress, and session outcome**.
When a new session starts, Marvin knows "you were on branch main with 3 dirty
files" but not "you were implementing spec 011, completed tasks T-01 to T-03,
T-04 is pending." This creates a continuity gap that forces users to re-explain
context every session.

Additionally, there is no bridge between the short-term session logs (last 10
sessions, local files) and the long-term Qdrant memory. Important context from
session 12+ is lost forever if it wasn't explicitly stored to Qdrant during
the session. The pre-compact state file can also become stale across sessions,
and session logs lack basic telemetry (duration, outcome).

Affected: any user across multi-session workflows — especially during spec
implementations, debugging arcs, and iterative feature development.

## Desired Outcome

After implementation, starting a new Marvin session should feel like resuming
a conversation rather than starting from scratch:

- Marvin knows **what you were working on** (not just git state)
- Marvin knows **what's left to do** (pending tasks, next steps)
- Important decisions from older sessions are accessible via Qdrant even
  after session logs rotate out
- Pre-compact recovery doesn't inject stale context from a previous session
- Session logs include enough metadata to reconstruct timeline and outcomes

## Requirements

### Functional

1. **FR-01 — Work summary in session logs**: `stop-persist.sh` must capture
   the active spec (ID + progress), recently edited files (from metrics.jsonl),
   and pending tasks from `.specify/specs/*/tasks.md` (unchecked items).
2. **FR-02 — Auto-summarize to Qdrant**: After every N sessions (configurable,
   default 5), automatically summarize the last N session logs into a single
   Qdrant record of type `knowledge` with domain `session-history`. This
   bridges the gap between ephemeral logs and permanent memory.
3. **FR-03 — Clean pre-compact state after reinject**: `session-start-reinject.sh`
   must delete `.pre-compact-state.json` after successfully reading it, so it
   is not re-injected in a future session or compaction cycle.
4. **FR-04 — Session duration in logs**: `stop-persist.sh` must record session
   start time (from the latest `session_start` event in metrics.jsonl) and
   compute duration. Format: `duration: Xm` (minutes, rounded).
5. **FR-05 — Session outcome in logs**: `stop-persist.sh` must include the
   stop reason from the hook input (the `stop_hook_active` field or similar)
   and a summary line: `outcome: completed | interrupted | error`.

### Non-Functional

1. **NFR-01 — Fail-open**: All hook changes must follow the fail-open
   philosophy. A failure in work summary extraction must never prevent session
   end or corrupt existing logs.
2. **NFR-02 — Performance**: Hooks must complete within 2 seconds. The Qdrant
   auto-summarize (FR-02) is async — it runs on session start (reading past
   logs), not session end (which is latency-sensitive).
3. **NFR-03 — No new dependencies**: All changes must use existing tools
   (bash, jq/python3 fallback, existing `_lib.sh` utilities).
4. **NFR-04 — Backward compatibility**: New session log fields are additive.
   `session-start-context.sh` must gracefully handle both old-format and
   new-format logs without breaking.

## Scope

### In Scope

- Modifying `stop-persist.sh` (FR-01, FR-04, FR-05)
- Modifying `session-start-reinject.sh` (FR-03)
- Creating or modifying a session-start hook for Qdrant auto-summarize (FR-02)
- Updating `session-start-context.sh` to surface new fields (work summary)
- Updating `.claude/rules/hooks.md` inventory table with changed hooks

### Out of Scope

- Changing the session log format from raw text to structured (JSON/YAML) —
  the `hooks.md` rule explicitly requires raw text
- Modifying Qdrant schema or collection configuration
- Adding new MCP servers or dependencies
- Changing metrics.jsonl format or rotation logic
- Modifying the pre-compact-save.sh hook (only reinject is touched)
- User-facing CLI or commands for session history browsing

## Constraints

- Hooks MUST follow the naming convention and role separation defined in
  `.claude/rules/hooks.md` — one responsibility per hook
- Session logs MUST remain raw text (per hooks.md convention)
- Qdrant operations MUST degrade gracefully if the MCP server is unavailable
  (per `memory.md` graceful degradation rule)
- The `session-start-context.sh` head limit (currently `head -20`) may need
  adjustment to accommodate the richer log content

## Open Questions

- **FR-02 cadence**: Is 5 sessions the right interval for Qdrant
  auto-summarize, or should it be time-based (e.g., daily)?
- **FR-02 trigger**: Should auto-summarize run as a separate hook
  (`session-start-summarize.sh`) or be appended to `session-start-context.sh`?
  Hook role separation rules suggest a separate hook.
- **FR-05 outcome classification**: The Stop hook input may not always carry a
  clear reason. What heuristic should determine
  `completed | interrupted | error`?

## References

- `.claude/hooks/stop-persist.sh` — current session end persistence
- `.claude/hooks/session-start-context.sh` — current session start injection
- `.claude/hooks/session-start-reinject.sh` — post-compaction recovery
- `.claude/hooks/pre-compact-save.sh` — pre-compaction state capture
- `.claude/hooks/_lib.sh` — shared hook utilities
- `.claude/rules/hooks.md` — hook authoring rules and inventory
- `.claude/rules/memory.md` — cognitive memory rules (Qdrant integration)
