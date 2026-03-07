# Project Knowledge Map
<!-- Auto-updated by Marvin. Human-editable. Last updated: 2026-03-07 -->

## Modules

- `.claude/` — Claude Code configuration: agents, skills, rules, hooks, memory, settings
- `.claude/agents/` — 5 specialist agents (implementer, reviewer, tester, researcher, security)
- `.claude/skills/` — 18 skill files covering domain expertise and SDD workflows
- `.claude/rules/` — 9 governance rules files (delegation, memory, specs, hooks, etc.)
- `.claude/hooks/` — 17 shell scripts wired into Claude lifecycle events
- `.claude/memory/` — persistent cognitive memory (knowledge-map, decisions, error-patterns)
- `.specify/` — SDD workspace: templates + 2 active specs (001, 002)
- `.specify/templates/` — 5 SDD templates (constitution, research, spec, plan, tasks)
- `.specify/specs/` — 2 specs: 001-skill-architecture-improvements (done), 002-cognitive-memory (active)
- `docs/` — project documentation: `development-standard.md`
- `.venv/` — Python 3.13 virtual environment managed by uv

## Skills (18)

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
- `deliberation` — workflow — structured System 2 deliberation for high-stakes decisions
- `sdd-constitution` — workflow — SDD project constitution creation
- `sdd-specify` — workflow — SDD spec authoring (`/sdd-specify`)
- `sdd-plan` — workflow — SDD plan authoring (`/sdd-plan`)
- `sdd-tasks` — workflow — SDD tasks authoring (`/sdd-tasks`)

## Agents (5)

- `implementer` — sonnet — writes code from specs; runs ruff/mypy/pytest until clean
- `reviewer` — sonnet — code quality, convention enforcement, diff review
- `tester` — sonnet — test execution, failure analysis, coverage measurement
- `researcher` — sonnet — technology evaluation, multi-source synthesis (memory: project)
- `security` — sonnet — SAST, dependency audit, secrets detection, OWASP checks

## Rules (9)

- `specs.md` — SDD pipeline: when to use, spec numbering, implementation flow
- `agents.md` — agent authoring: frontmatter fields, body structure, signals
- `skills.md` — skill authoring: frontmatter fields, section order, body budget
- `handoff.md` — structured handoff format between sequential agents (max 500 tokens)
- `research.md` — parallel research delegation: decompose → N researchers → synthesize
- `memory.md` — memory triggers: when to log decisions, error patterns, knowledge-map updates
- `hooks.md` — hook authoring constraints and lifecycle event reference
- `scaling.md` — effort scaling heuristics for agent selection and task decomposition
- `ids.md` — ID generation conventions for specs and other artifacts

## Key Dependencies

- `mcp__exa__*` — Exa web search: discovery, code context, deep research, company/people lookup
- `mcp__context7__*` — Context7: library docs and code examples by library ID
- `mcp__qdrant__*` — Qdrant vector DB: persistent cross-session memory store (`marvin-kb`)

## Architectural Invariants

- MUST delegate to specialist agents when one exists — Marvin is an orchestrator, not an implementer
- MUST NOT create/modify agents, hooks, or settings without consulting `docs/development-standard.md`
- MUST enter plan mode for multi-file changes or uncertain approach
- SDD pipeline order: constitution → specify → plan → tasks → implement → review → test
- Spec IDs are zero-padded 3-digit integers; slugs are kebab-case
- Agent output signals: `SIGNAL:DONE`, `SIGNAL:BLOCKED`, `SIGNAL:PARTIAL` — exactly one per response
- Tool allowlists are explicit — no wildcards in agent `tools` field
- Qdrant collection: `marvin-kb`; memory metadata MUST include type, project, domain, timestamp, confidence
- Memory types: `decision`, `error-pattern`, `knowledge`, `deliberation`

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

## Error Patterns

<!-- Populated over time when corrections occur. Format: [date] domain — pattern — fix -->
