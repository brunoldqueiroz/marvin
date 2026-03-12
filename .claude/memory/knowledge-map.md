# Project Knowledge Map
<!-- Auto-updated by Marvin. Human-editable. Last updated: 2026-03-07 -->

## Modules

- `.claude/` — Claude Code configuration: agents, skills, rules, hooks, memory, settings
- `.claude/agents/` — 5 specialist agents (implementer, reviewer, tester, researcher, security)
- `.claude/skills/` — 20 skill files covering domain expertise and SDD workflows
- `.claude/rules/` — 7 governance rules files (delegation, memory, specs, hooks, agents, skills, research)
- `.claude/hooks/` — 17 shell scripts wired into Claude lifecycle events
- `.claude/memory/` — persistent cognitive memory (knowledge-map, decisions, error-patterns)
- `.specify/` — SDD workspace: templates + 10 active specs (001–010); sub-specs supported
- `.specify/templates/` — 5 SDD templates (constitution, research, spec, plan, tasks); plan includes Dependency Graph and Sub-Specs sections; tasks template includes execution phases and dependency graph sections
- `.specify/specs/` — 12 specs: 001–007 (done), 008–009 (removed), 010-tdd-guidance (done), 011-agent-hardening (done), 012-verification-gate (active); sub-spec nesting supported
- `docs/` — project documentation: `development-standard.md`
- `.venv/` — Python 3.13 virtual environment managed by uv

## Skills (20)

- `python-expert` — advisory — Python 3.11+, typing, pytest, ruff, mypy
- `docker-expert` — advisory — Dockerfiles, Compose, container builds
- `git-expert` — advisory — Git workflow, commits, branching
- `aws-expert` — advisory — AWS services, IAM, infrastructure patterns
- `snowflake-expert` — advisory — Snowflake SQL, data warehousing
- `dbt-expert` — advisory — dbt models, tests, macros
- `spark-expert` — advisory — PySpark, distributed processing
- `airflow-expert` — advisory — DAG authoring, operators, scheduling
- `terraform-expert` — advisory — IaC, modules, state management
- `diagram-expert` — advisory — D2 diagrams, architecture visualization
- `docs-expert` — advisory — README and documentation authoring
- `checklist-runner` — workflow — structured checklist execution
- `memory-manager` — advisory — Qdrant memory store/retrieve patterns
- `deliberation` — workflow — structured System 2 deliberation for high-stakes decisions; scalar confidence scoring
- `self-consistency` — workflow — parallel candidate generation + rubric scoring
- `reflect` — advisory — periodic memory audit, pattern consolidation, error density analysis, adaptive calibration
- `sdd-constitution` — workflow — SDD project constitution creation
- `sdd-specify` — workflow — SDD spec authoring (`/sdd-specify`)
- `sdd-plan` — workflow — SDD plan authoring (`/sdd-plan`)
- `sdd-tasks` — workflow — SDD tasks authoring (`/sdd-tasks`); validates dependency graphs (cycles, missing refs, self-refs; isolated-task warnings); computes Wave: N annotations via topological sort; TDD advisory notes

## Agents (5)

- `implementer` — sonnet — writes code from specs; runs ruff/mypy/pytest until clean; Red Lines + 3-attempt stop rule; per-task commit convention; Evidence section (ruff/mypy/pytest output)
- `reviewer` — sonnet — two-stage review: Stage 1 (automated: ruff/mypy/coderabbit) + Stage 2 (deep: logic/security/design); Red Lines + 3-attempt stop rule; Evidence section; supports `stage: 1` dispatch
- `tester` — sonnet — test execution, failure analysis, coverage measurement; Red Lines + 3-attempt stop rule; Evidence section (pytest/coverage output)
- `researcher` — sonnet — technology evaluation, multi-source synthesis (memory: project); Red Lines + 3-attempt stop rule; Evidence section (tool call log)
- `security` — sonnet — SAST, dependency audit, secrets detection, OWASP checks; Red Lines + 3-attempt stop rule; Evidence section (scanner output log)

## Rules (9)

- `specs.md` — SDD pipeline: when to use, spec numbering, implementation flow; sub-spec and spike-first patterns; dependency-aware task execution with DAG parsing, parallel dispatch, blocked task handling; plan checkpoints; per-task commit convention; stage-1-only review dispatch for low-risk changes
- `agents.md` — agent authoring: frontmatter fields, body structure, signals
- `skills.md` — skill authoring: frontmatter fields, section order, body budget
- `delegation.md` — consolidated: IDS protocol, structured handoff, skill scaling rules
- `research.md` — parallel research delegation: decompose → N researchers → synthesize
- `memory.md` — memory triggers: when to log decisions, error patterns, knowledge-map updates; adaptive calibration rules; rework tracking fields (task_type, correction_count, last_corrected); error density query pattern
- `hooks.md` — hook authoring constraints and lifecycle event reference

## Key Dependencies

- `mcp__exa__*` — Exa web search: discovery, code context, deep research, company/people lookup
- `mcp__context7__*` — Context7: library docs and code examples by library ID
- `mcp__qdrant__*` — Qdrant vector DB: persistent cross-session memory store (`marvin-kb`)

## Architectural Invariants

- MUST delegate to specialist agents when one exists — Marvin is an orchestrator, not an implementer
- MUST NOT create/modify agents, hooks, or settings without consulting `docs/development-standard.md`
- MUST enter plan mode for any non-trivial task (2+ files, multiple steps, or uncertain approach)
- SDD pipeline order: constitution → specify → plan → tasks → implement → review → test
- Spec IDs are zero-padded 3-digit integers; slugs are kebab-case
- Sub-spec nesting is max 2 levels deep (spec → sub-spec only; no further decomposition)
- Agent output signals: `SIGNAL:DONE`, `SIGNAL:BLOCKED`, `SIGNAL:PARTIAL` — exactly one per response
- Tool allowlists are explicit — no wildcards in agent `tools` field
- Qdrant collection: `marvin-kb`; memory metadata MUST include type, project, domain, timestamp, confidence
- Memory types: `decision`, `error-pattern`, `knowledge`, `deliberation`, `evaluation`

## Active Conventions

- Artifacts written to `.artifacts/{agent-name}.md`; cleaned up after workflow completes
- Agent `model: sonnet` is default; `haiku` for triage; `opus` for architecture decisions
- `memory: user` for most agents; `memory: project` for researcher
- SDD specs live at `.specify/specs/{id}-{slug}/` with spec.md, plan.md, tasks.md
- Hooks use `_lib.sh` for shared utilities; all scripts must pass `bash -n` syntax check
- Settings validated with: `python3 -c "import json; json.load(open('.claude/settings.json'))"`

## Recent Decisions

<!-- Populated automatically via memory.md triggers and manually as needed -->
- 2026-03-07 — Spec 001 (skill architecture): separated advisory vs workflow skill categories,
  added required frontmatter fields (user-invocable, triggers, metadata.category)
- 2026-03-07 — Spec 002 (cognitive memory): Qdrant as persistent memory backend;
  knowledge-map.md as human-editable structural orientation file in `.claude/memory/`
- 2026-03-07 — Spec 003 (self-consistency): parallel candidate generation + rubric
  scoring workflow; `evaluation` memory type added to Qdrant schema
- 2026-03-07 — Spec 004 (recursive decomposition): sub-spec suggestions in /sdd-plan with complexity heuristics; spike-first pattern; Mermaid dependency graphs in plans; [SUB-SPEC] task type in /sdd-tasks
- 2026-03-07 — Spec 005 (feedback learning): /reflect skill for periodic memory audit; rework tracking fields (task_type, correction_count, last_corrected); adaptive calibration rules in memory.md; error density query pattern
- 2026-03-07 — Spec 006 (task dependency graph): dependency-aware task execution rules in specs.md; DAG validation in sdd-tasks; execution phases and dependency graph sections in tasks template
- 2026-03-07 — Spec 007 (dynamic replanning): lightweight plan checkpoints in Task Execution; three signal checks (failure, contradiction, coherence); suggest-only plan adjustments with phase-derivation restart on approval
- 2026-03-11 — Spec 008 (intra-session adaptation): **REMOVED** — session confidence tracker added overhead without proven value; adaptive calibration (spec 005) covers cross-session needs
- 2026-03-11 — Spec 009 (multidimensional confidence): **REMOVED** — dimensional confidence (feasibility/cost/risk) reverted to scalar; simpler model is sufficient
- 2026-03-07 — Spec 010 (TDD guidance): advisory TDD heuristic in sdd-tasks (complex logic, APIs, bug fixes, data transformations); [TEST-FIRST] 3-task pattern; test-first dispatch note in specs.md Task Execution
- 2026-03-11 — Spec 011 (agent hardening): Red Lines anti-rationalization tables + uniform 3-attempt stop rule added to all 5 agents; Wave: N computation in sdd-tasks; per-task commit convention in implementer + specs.md
- 2026-03-11 — Spec 012 (verification gate + two-stage review): Evidence sections with mandatory tool output in all 5 agents; reviewer restructured into Stage 1 (automated) + Stage 2 (deep); stage-1-only dispatch for low-risk changes in specs.md

## Error Patterns

<!-- Populated over time when corrections occur. Format: [date] domain — pattern — fix -->
