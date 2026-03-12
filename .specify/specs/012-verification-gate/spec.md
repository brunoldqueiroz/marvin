# Spec — Verification Gate + Two-Stage Review

> Captures the intent (what + why) of the feature before any implementation.

## Problem Statement

Marvin's agents can currently claim `SIGNAL:DONE` without producing verifiable
evidence. The implementer's Red Lines say "include actual pytest output" but
there is no structural enforcement — the output format template has placeholder
fields (`ruff: [clean / N issues fixed]`) that an agent can fill with
unverified claims. Similarly, the reviewer's workflow already has automated
(steps 3-4) and deep (step 5) phases, but they are not formally separated —
the reviewer can skip static analysis and jump straight to a surface-level
"APPROVE" verdict.

Research across 6 open-source Claude Code frameworks shows convergence on two
complementary patterns:

1. **Verification gate** (superpowers, ring, GSD): Agents must attach concrete
   evidence (tool output, test results, diff) to their completion signal.
   "Done" without evidence is treated as "not done."
2. **Two-stage review** (agent-starter-kit, ring): Review is split into a fast
   automated first-pass (linters, type checkers) and a slower deep second-pass
   (logic, security, design). Stage 1 catches mechanical issues cheaply;
   Stage 2 catches design issues thoroughly.

## Desired Outcome

After implementation:

1. Every agent's output report includes a **## Evidence** section with
   mandatory fields that must contain actual tool output (not placeholders).
   An agent cannot emit `SIGNAL:DONE` without populating the evidence section.
2. The reviewer agent operates in two explicit stages: **Stage 1 (Automated)**
   runs static analysis tools and reports findings; **Stage 2 (Deep)** performs
   logic, security, and design review. Stage 1 findings feed into Stage 2.
3. The orchestrator (specs.md) can optionally request Stage 1 only for
   low-risk changes (documentation, config, Markdown edits).

## Requirements

### Functional

1. **FR-01**: The implementer's output format MUST include a `## Evidence`
   section with mandatory fields: `ruff_output`, `mypy_output`,
   `pytest_output`. Each field must contain actual terminal output (truncated
   if long), not summary text like "clean" or "passed."
2. **FR-02**: The tester's output format MUST include a `## Evidence` section
   with mandatory fields: `pytest_output`, `coverage_output` (if coverage was
   requested). Each must contain actual terminal output.
3. **FR-03**: The reviewer's output format MUST include a `## Evidence` section
   with mandatory fields: `ruff_output`, `mypy_output`. The section also
   includes `coderabbit_output` (marked "not installed" if unavailable).
4. **FR-04**: The researcher and security agents MUST include a `## Evidence`
   section listing the tool calls made (search queries, URLs fetched, scanners
   run) — verifying they actually searched rather than guessed.
5. **FR-05**: All agents MUST NOT emit `SIGNAL:DONE` if any mandatory evidence
   field is empty. This rule is added to the Red Lines table of each agent.
6. **FR-06**: The reviewer's "How You Work" section MUST be restructured into
   two explicit stages:
   - **Stage 1 — Automated**: Run ruff, mypy, CodeRabbit. Report findings in
     a `## Stage 1: Automated Findings` section.
   - **Stage 2 — Deep Review**: Analyze logic, security, conventions, design.
     Report in a `## Stage 2: Deep Findings` section.
7. **FR-07**: The reviewer's output format MUST separate Stage 1 and Stage 2
   findings clearly, so the orchestrator and user can see which issues are
   mechanical vs. design-level.
8. **FR-08**: The orchestrator (specs.md) MUST document that for Markdown-only
   or config-only changes, the reviewer can be dispatched with a
   `stage: 1` instruction to skip the deep review phase.

### Non-Functional

1. **NFR-01**: Evidence sections MUST be concise — truncate tool output to the
   last 30 lines if it exceeds that. Full output should be available in the
   terminal, not in the report.
2. **NFR-02**: The two-stage split MUST NOT increase the reviewer's maxTurns.
   The current 15 turns is sufficient — Stage 1 uses ~3-4 turns, Stage 2 uses
   the remainder.
3. **NFR-03**: Evidence requirements MUST NOT apply to Markdown-only tasks
   (no ruff/mypy/pytest to run). When all modified files are .md, the evidence
   section states "N/A — Markdown-only changes" and SIGNAL:DONE is permitted.
4. **NFR-04**: Total lines added per AGENT.md SHOULD NOT exceed 20 — the
   evidence section replaces existing placeholder fields, not adds on top.

## Scope

### In Scope

- Adding `## Evidence` section to all 5 agent output formats
- Adding "empty evidence = no SIGNAL:DONE" to all 5 agents' Red Lines
- Restructuring reviewer's "How You Work" into Stage 1 + Stage 2
- Restructuring reviewer's output format into Stage 1 + Stage 2 sections
- Adding `stage: 1` dispatch option documentation to specs.md
- Updating knowledge-map.md

### Out of Scope

- Automated enforcement via hooks (checking evidence in agent output) —
  future improvement, requires parsing agent markdown output
- Adding new tools to any agent
- Changing agent model assignments or maxTurns
- `/sync-context` skill (separate concern)
- Model allocation by phase (separate concern)

## Constraints

- MUST preserve all existing agent functionality — changes are additive to
  output format and restructuring of reviewer workflow
- MUST NOT change agent tool allowlists or model assignments
- MUST NOT add new agents or skills
- MUST follow existing AGENT.md structure conventions per `rules/agents.md`
- Evidence section replaces the existing Quality Checks / Static Analysis
  sections in output templates (not an addition — a replacement with upgrade)

## Open Questions

None — the patterns are well-documented across the researched repos and the
current agent structure already has the scaffolding (implementer has Quality
Checks section, reviewer has Static Analysis section).

## References

- Spec 011 (agent hardening): Red Lines and stop rules already in place —
  this spec builds on that foundation with verification enforcement
- Research: superpowers (`obra/superpowers`) — verification gates, evidence
  requirements before claiming done
- Research: ring (`LerianStudio/ring`) — mandatory evidence, two-stage review
- Research: GSD (`gsd-build/get-shit-done`) — done = evidence-backed, not
  self-assessed
- Research: agent-starter-kit (`ntorga/agent-starter-kit`) — tiered review
  with automated first-pass
