# Tasks — Verification Gate + Two-Stage Review

> Actionable checklist derived from the plan. Each task is a discrete,
> delegatable unit of work.
>
> Task markers: `[ ]` pending, `[x]` completed, `[-]` skipped (dependency
> failed or user chose to skip). Omitting `Depends on:` is equivalent to
> `Depends on: none`.

## Tasks

- [x] **T-01: Add Evidence section to implementer agent** — Replace `## Quality Checks` in output format with `## Evidence` containing mandatory `ruff_output`, `mypy_output`, `pytest_output` fields for actual terminal output. Add Markdown-only exemption. Add Red Line entry for empty evidence + SIGNAL:DONE.
  - Files: `.claude/agents/implementer/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-02: Add Evidence section to tester agent** — Add `## Evidence` section to output format with mandatory `pytest_output` and conditional `coverage_output` fields. Add Markdown-only exemption. Add Red Line entry for empty evidence + SIGNAL:DONE.
  - Files: `.claude/agents/tester/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-03: Restructure reviewer into two stages and add Evidence** — Restructure "How You Work" into Stage 1 (Automated: ruff, mypy, CodeRabbit) and Stage 2 (Deep: logic, security, design). Replace `## Static Analysis` and `## Issues` with `## Evidence`, `## Stage 1: Automated Findings`, and `## Stage 2: Deep Findings`. Add `stage: 1` task prompt instruction. Add Markdown-only exemption. Add Red Line entry for empty evidence.
  - Files: `.claude/agents/reviewer/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-04: Add Evidence section to researcher agent** — Add `## Evidence` section to output format listing tool calls made (search queries, URLs fetched, KB queries). Add Red Line entry for empty evidence + SIGNAL:DONE.
  - Files: `.claude/agents/researcher/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-05: Add Evidence section to security agent** — Add `## Evidence` section to output format listing scanners run and their output. Note unavailable scanners. Add Red Line entry for empty evidence + SIGNAL:DONE.
  - Files: `.claude/agents/security/AGENT.md`
  - Agent: implementer
  - Depends on: none
  - Wave: 1

- [x] **T-06: Add stage-1-only dispatch documentation to specs.md** — Document in Task Execution section that for Markdown-only or config-only changes (.md, .yml, .yaml, .json, .toml, .cfg), the orchestrator may dispatch the reviewer with `stage: 1` to skip deep review.
  - Files: `.claude/rules/specs.md`
  - Agent: implementer
  - Depends on: T-03
  - Wave: 2

- [x] **T-07: Review all modified files for spec compliance** — Verify Evidence sections have correct mandatory fields per agent type, Red Lines entries are present in all 5 agents, reviewer workflow is clearly split into Stage 1/Stage 2, output format separates findings, specs.md documents stage-1 dispatch. Check NFR-04 (≤20 lines added per agent).
  - Files: `.claude/agents/implementer/AGENT.md`, `.claude/agents/reviewer/AGENT.md`, `.claude/agents/tester/AGENT.md`, `.claude/agents/researcher/AGENT.md`, `.claude/agents/security/AGENT.md`, `.claude/rules/specs.md`
  - Agent: reviewer
  - Depends on: T-01, T-02, T-03, T-04, T-05, T-06
  - Wave: 3

- [x] **T-08: Update knowledge map** — Update `.claude/memory/knowledge-map.md` to reflect: agents now include Evidence sections, reviewer operates in two stages, stage-1-only dispatch available for low-risk changes.
  - Files: `.claude/memory/knowledge-map.md`
  - Agent: implementer
  - Depends on: T-07
  - Wave: 4

## Execution Phases

| Wave | Tasks | Parallel? | Notes |
|------|-------|-----------|-------|
| 1 | T-01, T-02, T-03, T-04, T-05 | Yes | No shared files — all independent |
| 2 | T-06 | No | Modifies specs.md after T-03 establishes two-stage structure |
| 3 | T-07 | No | Review pass — reads all modified files |
| 4 | T-08 | No | Knowledge map summary after review |

## Task Dependency Graph

```
T-01 ──┐
T-02 ──┤
T-03 ──┼──→ T-06 ──┐
T-04 ──┤            ├──→ T-07 ──→ T-08
T-05 ──┴────────────┘
```

## Acceptance Criteria

- [ ] All 5 AGENT.md files contain `## Evidence` section with agent-appropriate mandatory fields (FR-01..FR-04)
- [ ] Implementer evidence: `ruff_output`, `mypy_output`, `pytest_output` (FR-01)
- [ ] Tester evidence: `pytest_output`, `coverage_output` (FR-02)
- [ ] Reviewer evidence: `ruff_output`, `mypy_output`, `coderabbit_output` (FR-03)
- [ ] Researcher evidence: tool call log (FR-04)
- [ ] Security evidence: scanner output log (FR-04)
- [ ] All 5 agents have Red Line entry for empty evidence + SIGNAL:DONE (FR-05)
- [ ] Reviewer "How You Work" split into Stage 1 (Automated) and Stage 2 (Deep) (FR-06)
- [ ] Reviewer output format has separate Stage 1 and Stage 2 findings sections (FR-07)
- [ ] specs.md documents `stage: 1` dispatch for low-risk changes (FR-08)
- [ ] Evidence truncated to last 30 lines if long (NFR-01)
- [ ] Reviewer maxTurns unchanged at 15 (NFR-02)
- [ ] Markdown-only exemption documented ("N/A — Markdown-only changes") (NFR-03)
- [ ] No AGENT.md gains more than 20 net lines (NFR-04)
- [ ] Knowledge map reflects all changes
