# Marvin Concepts

This document explains all architectural concepts and patterns used in the Marvin project. Marvin is an orchestration layer for Claude Code that transforms the assistant into a multi-domain specialist for Data Engineering and AI/ML.

## Table of Contents

1. [Orchestration Layer](#1-orchestration-layer)
2. [Specialized Agents](#2-specialized-agents)
3. [Mandatory Delegation and Routing](#3-mandatory-delegation-and-routing)
4. [Structured Handoff Protocol](#4-structured-handoff-protocol)
5. [Ralph Loop](#5-ralph-loop)
6. [Spec-Driven Development (SDD/OpenSpec)](#6-spec-driven-development-sddopenspec)
7. [Skills System (Slash Commands)](#7-skills-system-slash-commands)
8. [Persistent Memory System](#8-persistent-memory-system)
9. [Deterministic Verification](#9-deterministic-verification)
10. [Universal Rules vs Domain Rules](#10-universal-rules-vs-domain-rules)
11. [Auto-Extension](#11-auto-extension)
12. [Source of Truth Pattern](#12-source-of-truth-pattern)
13. [Project Initialization](#13-project-initialization)
14. [Humanized Commits](#14-humanized-commits)
15. [Stop and Think Pattern](#15-stop-and-think-pattern)
16. [Model Selection by Complexity](#16-model-selection-by-complexity)
17. [Hooks and Extensions](#17-hooks-and-extensions)

---

## 1. Orchestration Layer

### What it is

Marvin is not a direct assistant, but an **orchestration layer** that intercepts all requests and decides who should execute them. It functions as the system's "brain," living in `~/.claude/CLAUDE.md`, which is automatically loaded in every Claude Code session.

### Why it exists

Claude Code, by default, responds to all requests directly. This works well for general tasks, but results in inconsistent quality for specialized domains (dbt, Airflow, Spark, etc.). Marvin solves this by:

- **Specialization**: Each domain has its own specialist with specific rules
- **Consistency**: Conventions are automatically applied by agents
- **Separation of concerns**: Orchestration vs execution are distinct roles
- **Extensibility**: New domains can be added without altering the core

### How it works in Marvin

1. **Automatic loading**: When you start `claude`, the file `~/.claude/CLAUDE.md` is loaded as system context
2. **Request interception**: Every user request passes through the orchestrator first
3. **Intelligent routing**: Marvin analyzes the request's domain and consults the agent registry
4. **Delegation decision**:
   - If specialist exists → constructs structured handoff and delegates
   - If no specialist exists → handles directly or suggests `/new-agent`
5. **Coordination**: Marvin coordinates multiple agents when necessary (e.g., coder → verifier → git-expert)

```
┌─────────────────────────────────────────────────────────┐
│  User                                                   │
│  "Create a dbt model for the orders table"             │
└──────────────────┬──────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Marvin Orchestrator (~/.claude/CLAUDE.md)             │
│  1. Stop and Think                                      │
│  2. Identifies domain: "dbt"                            │
│  3. Consults registry/agents.md                         │
│  4. Finds: dbt-expert                                   │
│  5. Constructs structured handoff                       │
└──────────────────┬──────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────┐
│  dbt-expert (Task tool)                                 │
│  - Loads agents/dbt-expert/rules.md                     │
│  - Applies naming conventions                           │
│  - Generates model, tests, schema.yml                   │
│  - Returns structured result                            │
└──────────────────┬──────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Marvin                                                 │
│  - Updates memory.md if necessary                       │
│  - Presents result to user                              │
└─────────────────────────────────────────────────────────┘
```

**Critical point**: The orchestrator **never executes domain tasks directly**. Its only responsibility is routing and coordination.

---

## 2. Specialized Agents

### What they are

Agents are personas specialized in specific domains. Each agent has:
- **AGENT.md**: Complete agent definition with structured frontmatter
- **rules.md**: Domain knowledge (for technical specialists)
- **Exclusive ownership**: Each agent owns its domain

### Why they exist

A single generalist LLM cannot maintain consistency across multiple complex technical domains. Specialization enables:
- **Deep knowledge**: Each agent carries detailed rules from its domain
- **Focused context**: Less noise, more relevance
- **Independent evolution**: dbt rules can evolve without affecting Spark
- **Appropriate model selection**: Simple tasks use haiku, complex ones use opus

### How they work in Marvin

There are 13 specialized agents:

| Agent | Domain | Tools | Model |
|--------|---------|-------------|---------|
| researcher | Web research, documentation | Context7, Exa, WebSearch | sonnet |
| coder | Multi-file implementation | Read, Edit, Write, Bash | sonnet |
| verifier | Quality gate, tests | Bash (pytest, mypy, ruff) | haiku |
| dbt-expert | dbt, dimensional modeling | Read, Edit, Write, Bash | sonnet |
| spark-expert | PySpark, optimization | Read, Edit, Write, Bash | sonnet |
| airflow-expert | Orchestration, DAGs | Read, Edit, Write, Bash | sonnet |
| snowflake-expert | Snowflake, warehousing | Read, Edit, Write, Bash | sonnet |
| aws-expert | AWS data services, IaC | Read, Edit, Write, Bash | sonnet |
| git-expert | Git workflows, commits | Bash, Read, Grep | haiku |
| docker-expert | Containers, Docker Compose | Read, Edit, Write, Bash | sonnet |
| terraform-expert | IaC, HCL | Read, Edit, Write, Bash | sonnet |
| python-expert | Python, pytest, typing | Read, Edit, Write, Bash | sonnet |
| docs-expert | Technical documentation | Read, Edit, Write | sonnet |

**AGENT.md structure**:

```yaml
---
name: dbt-expert
color: purple
description: >
  dbt specialist. Use for: dimensional modeling, staging models,
  incremental strategies, dbt tests, schema.yml documentation.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
memory: project
---

# dbt Expert Agent

[Agent instructions...]
```

**Critical frontmatter**:
- `name`: Unique agent identifier
- `tools`: Allowed tools (security boundary)
- `model`: haiku (simple) | sonnet (standard) | opus (complex)
- `memory`: user (global) | project (local)

---

## 3. Mandatory Delegation and Routing

### What it is

Mandatory delegation means that Marvin **MUST** delegate to the specialist agent when a request involves a registered domain. No exceptions, even for "simple" tasks.

### Why it exists

Without mandatory delegation:
- ❌ Inconsistency: same task handled differently in each session
- ❌ Drift: conventions gradually forgotten
- ❌ Bugs: domain rules not applied (e.g., case-sensitive SQL in Snowflake)

With mandatory delegation:
- ✅ Quality guarantee: specialist always applies rules
- ✅ Predictability: same behavior every time
- ✅ Auditability: traceable task history

### How it works in Marvin

**Routing Table** (`~/.claude/registry/agents.md`):

| Agent | Triggers | Loads |
|--------|----------|---------|
| dbt-expert | dbt, data model, staging, incremental | rules.md with dbt conventions |
| spark-expert | spark, pyspark, dataframe, shuffle | rules.md with optimizations |
| git-expert | commit, push, PR, branch | None (pure executive) |

**Decision flow**:

```python
def process_request(user_message):
    # 1. Stop and Think (mandatory)
    domain = identify_domain(user_message)

    # 2. Consult registry
    agent = registry.find_agent(domain)

    # 3. Decision
    if agent:
        # Mandatory delegation
        handoff = construct_handoff(agent, user_message)
        result = delegate_via_task(agent, handoff)
        return result
    else:
        # Handle directly ONLY if:
        if is_greeting(user_message):
            return handle_greeting()
        elif is_clarification(user_message):
            return ask_clarification()
        elif is_concept_explanation(user_message):
            return explain_concept()
        else:
            # Suggest creating agent
            return handle_and_suggest_new_agent()
```

**Critical rule**: Even for "simple commit", delegate to git-expert. Even for "quick dbt model", delegate to dbt-expert. Zero exceptions.

**Triggers**: Keywords that trigger automatic delegation. Examples:
- "dbt" → dbt-expert
- "commit these changes" → git-expert
- "spark optimization" → spark-expert
- "research best practices" → researcher

---

## 4. Structured Handoff Protocol

### What it is

A formal protocol for transferring complete context from Marvin to the specialist agent. Replaces free-text delegation with predictable and complete structure.

### Why it exists

**Failure modes it prevents**:

| Problem | Without Protocol | With Protocol |
|----------|---------------|---------------|
| Incomplete context | "Create a dbt model" (which table? which columns?) | Context with key files, prior decisions |
| Ambiguous criteria | "Is it ready?" (ready how?) | Acceptance Criteria checklist |
| Silent violations | Forgets to use `source()`, hardcodes name | Constraints with MUST/MUST NOT |
| Lost work | Doesn't know what to report | Return Protocol specifies exactly |
| Retry loops | Tries same approach that failed | Error History documents previous attempts |

### How it works in Marvin

**Three verbosity levels**:

#### 1. Minimal (commits, formatting)
```markdown
## Handoff: git-expert

### Objective
Commit changes to handoff protocol file.

### Acceptance Criteria
- [ ] Conventional Commits format
- [ ] Only handoff-protocol.md staged
- [ ] Message explains purpose (why not what)

### Constraints
MUST: Include co-authored-by trailer
MUST NOT: Push to remote
MUST NOT: Commit unrelated files
```

#### 2. Standard (most delegations)
```markdown
## Handoff: dbt-expert

### Objective
Create staging model stg_salesforce__orders from raw Salesforce orders.

### Acceptance Criteria
- [ ] Naming convention: stg_salesforce__orders.sql
- [ ] unique + not_null tests on primary key
- [ ] snake_case column names
- [ ] schema.yml documentation

### Constraints
MUST: Follow ~/.claude/agents/dbt-expert/rules.md
MUST: Use source() function, never hardcode table names
MUST NOT: Add business logic (staging is 1:1 with source)
PREFER: Explicit column selection over SELECT *

### Context
**Key Files:** models/staging/salesforce/_salesforce__sources.yml
**Prior Decisions:** Snowflake warehouse, materialized as view
**User Preferences:** Explicit column selection in staging

### Return Protocol
Report: Model file path, tests added, schema assumptions.
On failure: Describe blocker (missing source, schema mismatch).
On ambiguity: Ask about nullable columns or data type conversions.
```

#### 3. Full (debugging, retry, complexity)
Adds:
- **Error History**: What was tried and why it failed
- **Detailed Background**: Complete architectural context, dependencies

**Field template**:

```markdown
## Handoff: <Agent Name>

### Objective
<Single clear sentence>

### Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

### Constraints
MUST: <Non-negotiable required behaviors>
MUST NOT: <Forbidden behaviors — violations fail the task>
PREFER: <Nice-to-have — follow when possible>

### Context (Standard+)
**Key Files:** <Paths + why>
**Prior Decisions:** <Relevant decisions>
**User Preferences:** <From memory.md>

### Return Protocol (Standard+)
Report: <What to include>
On failure: <How to report>
On ambiguity: <When to ask>

### Error History (Full only)
**Previous Attempt:** <What was tried, why it failed>

### Detailed Background (Full only)
<Architecture context, dependencies>
```

**Handoff construction**:

```python
def construct_handoff(agent, task, level="standard"):
    handoff = {
        "objective": extract_objective(task),
        "acceptance_criteria": define_done(task),
        "constraints": load_constraints(agent),
    }

    if level in ["standard", "full"]:
        handoff["context"] = {
            "key_files": identify_relevant_files(task),
            "prior_decisions": query_memory(task),
            "user_preferences": query_memory("preferences"),
        }
        handoff["return_protocol"] = define_return_protocol(task)

    if level == "full":
        handoff["error_history"] = get_previous_attempts(task)
        handoff["detailed_background"] = get_architecture_context()

    return format_handoff(handoff)
```

---

## 5. Ralph Loop

### What it is

A pattern for autonomous execution of long-running tasks that exceed a single context window. Works by executing Claude in a bash loop with `--continue`, using the **filesystem as API**.

### Why it exists

LLMs have context limitations. For large tasks (refactoring 50 files, implementing feature with 20 subtasks):
- ❌ Context exhausts before completion
- ❌ Lose progress when context overflows
- ❌ Requires constant manual supervision

Ralph Loop solves:
- ✅ Progress persists in filesystem (tasks.md)
- ✅ Auto-resume: each iteration reads current state
- ✅ Auto-termination: creates `.ralph-complete` when done
- ✅ Auditable: incremental commits show progress

### How it works in Marvin

**Components**:

1. **`prompts/PROMPT.md`**: Defines complete task
```markdown
# Task: Migrate from dbt 0.x to dbt 1.x

## Objective
Update all dbt models, tests, and configs to dbt 1.x syntax.

## Completion Criteria
- [ ] All models use new config syntax
- [ ] ref() and source() updated
- [ ] Tests pass in dbt 1.x
- [ ] Documentation updated

## Current State
[Read changes/tasks.md for progress]

## Instructions
1. Read changes/tasks.md
2. Pick next unchecked task
3. Implement it
4. Run tests
5. Check off task
6. If all done AND all criteria met: create .ralph-complete
```

2. **`changes/tasks.md`**: Atomic checklist
```markdown
# Tasks: dbt 1.x Migration

- [x] Update dbt_project.yml to version 1.x
- [x] Migrate model configs ({{ config(...) }})
- [ ] Update macro syntax
- [ ] Fix deprecated functions
- [ ] Run full test suite
- [ ] Update documentation
```

3. **Loop script** (`scripts/ralph.sh`):
```bash
while :; do
  claude -p "$(cat prompts/PROMPT.md)" \
    --continue \
    --allowedTools "Read,Edit,Write,Bash(pytest *)" \
    --max-turns 30

  # Check for completion signal
  if [ -f ".ralph-complete" ]; then
    rm -f .ralph-complete
    echo "Task completed!"
    break
  fi

  sleep 2
done
```

**Execution flow**:

```
Iteration 1:
  1. Claude reads PROMPT.md and tasks.md
  2. Sees first two tasks are checked
  3. Picks next: "Update macro syntax"
  4. Implements changes
  5. Tests: pytest models/
  6. Marks as [x] in tasks.md
  7. Context exhausts → terminates

Loop restarts:

Iteration 2:
  1. Claude reads PROMPT.md and tasks.md (fresh context)
  2. Sees three tasks are checked
  3. Picks next: "Fix deprecated functions"
  4. ... repeats process

Iteration N:
  1. Sees all tasks are [x]
  2. Runs full test suite
  3. Everything passes
  4. Creates .ralph-complete file
  5. Loop detects file → terminates
```

**Control signals**:
- `.ralph-complete`: Terminate loop (success)
- `.ralph-status`: Warnings/status (e.g., "WARN: test failing")

**Principles**:
- **Filesystem is the API**: All state in files, not in context
- **Atomic tasks**: Each item completable independently
- **Frequent git**: Commit after each task (rollback if necessary)
- **Scoped tools**: Allow only necessary tools

---

## 6. Spec-Driven Development (SDD/OpenSpec)

### What it is

A structured development workflow that follows: **Proposal → Specification → Implementation → Archive**. Separates "what to build" (specs) from "how to build" (code).

### Why it exists

Ad-hoc development results in:
- ❌ Scope creep (feature grows uncontrolled)
- ❌ Ambiguous requirements (interpretation bugs)
- ❌ Lack of documentation (nobody knows why something exists)

SDD solves:
- ✅ Clear contract: specs define expected behavior
- ✅ Testability: GIVEN/WHEN/THEN maps directly to tests
- ✅ Living documentation: archived specs explain decisions
- ✅ Easier review: approving spec is faster than reviewing code

### How it works in Marvin

**Phase 1: Proposal** (Design)

Creates proposal documents:
- `changes/proposal.md`: What, why, scope, risks
- `changes/design.md`: Architecture, technical decisions, trade-offs
- `changes/tasks.md`: Atomic implementation checklist

```markdown
# Proposal: Incremental Load for Orders

## What
Add incremental loading to orders_daily table using watermark strategy.

## Why
Full refresh takes 4 hours. Business needs hourly updates.

## Scope
- In scope: orders table, watermark in metadata table
- Out of scope: Other tables (will migrate later)

## Approach
Use updated_at as watermark. Track last successful run in metadata.

## Risks
- Risk: Clock skew between source and warehouse
  Mitigation: 5-minute overlap window

## Status: DRAFT
```

**Phase 2: Specification** (Contract)

For each requirement, writes scenarios in `changes/specs/`:

```markdown
# Spec: Incremental Orders Load

## Scenario 1: Normal incremental run
GIVEN orders table has records with updated_at from Jan 1-10
AND last successful run was Jan 10 00:00:00
WHEN incremental load runs at Jan 11 00:00:00
THEN only records with updated_at > Jan 10 00:00:00 are extracted
AND metadata.last_run is updated to Jan 11 00:00:00

## Scenario 2: First run (no checkpoint)
GIVEN no checkpoint exists in metadata table
WHEN incremental load runs
THEN full historical load is performed
AND checkpoint is created

## Scenario E1: Clock skew handling
GIVEN some records have future timestamps due to clock skew
WHEN incremental load runs
THEN records up to current_timestamp + 5 minutes are included
AND no data loss occurs
```

**BDD Scenarios**: GIVEN/WHEN/THEN format:
- **GIVEN**: Initial state / preconditions
- **WHEN**: Action executed
- **THEN**: Expected result
- **AND**: Additional expectations

**Phase 3: Implementation** (Code)

Executes tasks.md sequentially:
1. Delegates to **coder** agent
2. After implementation, runs **verifier** agent
3. If passes, marks task as [x]
4. Repeats for next task

```markdown
# Tasks: Incremental Orders

- [x] Add watermark column to metadata table
- [x] Implement watermark read/write functions
- [ ] Update orders extraction query with WHERE filter
- [ ] Add watermark update after successful load
- [ ] Write tests for scenarios 1, 2, E1
- [ ] Run verifier
```

**Phase 4: Archive** (Permanent documentation)

When complete:
1. Moves specs from `changes/specs/` to `specs/` (permanent record)
2. Updates proposal status to `DONE`
3. Documents deviations (if there were changes vs original proposal)

**File structure**:

```
project/
├── changes/              # Work area (transient)
│   ├── proposal.md
│   ├── design.md
│   ├── tasks.md
│   └── specs/
│       └── incremental-orders.spec.md
├── specs/                # Permanent archive
│   └── incremental-orders.spec.md
└── src/
    └── etl/
        └── orders_incremental.py
```

---

## 7. Skills System (Slash Commands)

### What they are

Skills are slash commands (`/skill-name`) that load on-demand `SKILL.md` files with specialized instructions. They function as "functionality modules" that extend Marvin.

### Why they exist

Loading all instructions for all functionalities in every session would be:
- ❌ Context waste (90% irrelevant to current task)
- ❌ Slow (parsing too much text)
- ❌ Confusing (conflicting instructions)

Skills solve:
- ✅ On-demand loading: only when necessary
- ✅ Modular: each skill is independent
- ✅ Extensible: adding skill doesn't affect existing ones

### How they work in Marvin

**Skill structure** (`global/skills/<name>/SKILL.md`):

```yaml
---
name: ralph
description: Start a Ralph Loop for long-running autonomous tasks
disable-model-invocation: true
argument-hint: "[task description]"
---

# Ralph Loop

Task: $ARGUMENTS

[Complete Ralph Loop instructions...]
```

**Frontmatter**:
- `name`: Command name (user calls with `/ralph`)
- `description`: What the skill does
- `disable-model-invocation`: If true, doesn't call LLM after loading
- `argument-hint`: Expected syntax

**Variables**:
- `$ARGUMENTS`: Everything after slash command (e.g., `/ralph migrate to dbt 1.x` → $ARGUMENTS = "migrate to dbt 1.x")

**Skill Categories**:

#### Meta-Skills (self-management)
- `/init` — Initialize Marvin project config
- `/new-agent` — Scaffold new specialized agent
- `/new-skill` — Scaffold new skill
- `/new-rule` — Scaffold new domain knowledge rule
- `/audit-agents` — Audit codebase for coverage gaps
- `/handoff-reference` — Full handoff protocol reference with examples

#### Universal Skills
- `/research` — Deep research (Context7 + Exa + WebSearch)
- `/review` — Code review (quality, security, best practices)
- `/spec` — OpenSpec Spec-Driven Development workflow
- `/ralph` — Start Ralph Loop
- `/remember` — Save to Marvin's persistent memory
- `/meta-prompt` — Generate optimized prompt

#### Data Engineering Skills
- `/pipeline` — Design and scaffold complete data pipeline
- `/dbt-model` — Generate dbt models with tests and docs
- `/dag` — Generate Airflow DAGs
- `/data-model` — Design dimensional data models

**Invocation**:

```
User: /ralph refactor legacy pipeline
         ↓
Marvin: 1. Detects skill "ralph"
        2. Loads ~/.claude/skills/ralph/SKILL.md
        3. Replaces $ARGUMENTS with "refactor legacy pipeline"
        4. Executes SKILL.md instructions
```

**Registry** (`~/.claude/registry/skills.md`):
Lists all available skills with short descriptions. User consults to discover capabilities.

---

## 8. Persistent Memory System

### What it is

A two-scope system (global and project) for saving information that must persist between sessions. Simple format: markdown with dated entries.

### Why it exists

LLMs are stateless by nature. Without persistent memory:
- ❌ Repeats preference questions in each session
- ❌ Forgets architectural decisions made earlier
- ❌ Doesn't learn from past mistakes

Persistent memory solves:
- ✅ Remembered preferences (e.g., "use Snappy compression")
- ✅ Documented decisions (e.g., "chose Snowflake because...")
- ✅ Discovered patterns (e.g., "always validate PII before logging")

### How it works in Marvin

**Two scopes**:

1. **Global Memory** (`~/.claude/memory.md`): Valid across all projects
   - User preferences
   - Cross-project patterns
   - General lessons

2. **Project Memory** (`.claude/memory.md`): Project-specific
   - Project architectural decisions
   - Tech stack and conventions
   - Patterns discovered in project
   - Project lessons

**Template** (`global/memory.md`):

```markdown
# Marvin Memory — Global

## User Preferences
- [2026-02-13] Always use type hints in Python
- [2026-02-10] Prefer f-strings over format()

## Architecture Decisions
- [2026-02-12] Use PostgreSQL for metadata in pipelines

## Patterns & Conventions
- [2026-02-11] Name dbt stages as stg_<source>__<entity>

## Lessons Learned
- [2026-02-09] Always validate timezone before comparing timestamps
```

**Scope choice heuristic**:

```python
def choose_memory_scope(information):
    question = "Would this information be useful in other projects?"

    if answer_yes(question):
        return "~/.claude/memory.md"  # Global
    else:
        return ".claude/memory.md"    # Project
```

**Examples**:

| Information | Scope | Why |
|------------|--------|---------|
| "User prefers black formatter" | Global | Personal preference |
| "This project uses dbt 1.5" | Project | Project-specific |
| "Always add tests in non-trivial changes" | Global | General principle |
| "Orders table has 500M rows, use incremental" | Project | Local architectural decision |
| "Learned that clock skew causes bugs" | Global | Generally applicable lesson |
| "This company uses OrdersDaily convention" | Project | Organizational convention |

**Skill `/remember`**:

```
User: /remember Always use Parquet with Snappy compression for outputs
         ↓
Marvin: 1. Parse: "Parquet + Snappy compression"
        2. Choose scope: Global (useful in multiple projects)
        3. Classify: Patterns & Conventions
        4. Add entry: "- [2026-02-13] Use Parquet + Snappy for outputs"
        5. Confirm: "Saved in ~/.claude/memory.md > Patterns & Conventions"
```

**Proactive saving**:

Marvin saves automatically (without skill) when it detects:
- Expressed preferences: "I prefer...", "Always use..."
- Decisions made: "Let's go with...", "We chose X because..."
- Lessons learned: "This failed because...", "Note for future..."

**Entry format**:
```markdown
- [YYYY-MM-DD] <concise description>
```

**Rules**:
- One line per entry (concise)
- Always with date (traceability)
- Don't duplicate: update existing entry if similar
- Never overwrite file: always append or edit

---

## 9. Deterministic Verification

### What it is

A four-phase verification process that separates **facts (deterministic)** from **opinions (LLM)**. The verifier agent executes automated tools before any subjective review.

### Why it exists

Traditional LLM verification is non-deterministic and expensive:
- ❌ "I reviewed the code, looks good" (but didn't run tests)
- ❌ False positives: LLM sees problem where there isn't one
- ❌ False negatives: LLM doesn't see obvious bug that compiler would catch

Deterministic verification solves:
- ✅ Facts first: compilation, tests, types — zero ambiguity
- ✅ Short-circuit: if tests fail, stop (don't waste time)
- ✅ Confidence: exit code 0 = passed, non-zero = failed
- ✅ Clear separation: report separates machine-verified from LLM opinion

### How it works in Marvin

**verifier agent** (`agents/verifier/AGENT.md`):

**Phase 1: Environment Detection**

```bash
# Detect project type
test -f pyproject.toml && echo "PYTHON"
test -f package.json && echo "NODE"
test -f Cargo.toml && echo "RUST"

# Detect available tools
command -v pytest && echo "HAS: pytest"
command -v mypy && echo "HAS: mypy"
command -v ruff && echo "HAS: ruff"
```

Records what's available. Only runs checks for tools that exist.

**Phase 2: Deterministic Checks** (exact order)

1. **Syntax/Compilation Check**
   ```bash
   # Python
   python -m py_compile src/pipeline.py

   # Exit 0 = syntax OK
   # Exit 1 = syntax error
   ```

   **Short-circuit**: If fails, STOP. Don't run tests on code that doesn't compile.

2. **Type Checking**
   ```bash
   mypy src/ --no-error-summary
   ```

   Records: N errors, M warnings. Errors are blocking, warnings are informative.

3. **Test Suite Execution**
   ```bash
   pytest --tb=short --no-header -q
   ```

   Records: total, passed, failed, skipped.

   **Short-circuit**: If ANY test fails, STOP. Don't proceed to Phase 3 (LLM review).

4. **Linting**
   ```bash
   ruff check .
   ```

   Records: error count, warnings. Doesn't block subsequent checks.

5. **Security Scan**
   ```bash
   # Hardcoded secrets
   grep -rn 'password\s*=\s*['\''"]' --include="*.py" .
   grep -rn 'api_key\s*=\s*['\''"]' --include="*.py" .

   # SQL injection
   grep -rn 'f".*SELECT.*{' --include="*.py" .

   # .env files staged
   git diff --cached --name-only | grep -E '\.env$'
   ```

   HIGH severity findings (confirmed secrets) are blocking.

6. **Coverage Analysis**
   ```bash
   pytest --cov --cov-report=term-missing -q
   ```

   Informative. Doesn't block.

**Phase 3: LLM Quality Review** (ONLY if Phase 2 passed)

Only executes if all blocking checks passed.

1. **Spec Compliance**: Reads specs in `specs/` or `changes/specs/`, verifies each GIVEN/WHEN/THEN
2. **Design Quality**: Names, complexity, code smells (advisory)
3. **Architectural Fit**: Patterns, consistency (advisory)

**Phase 4: Report** (clear separation)

```markdown
# Verification Report

## Status: PASS / FAIL

## Machine-Verified Checks

### Syntax
- Status: PASS
- All files compiled successfully

### Type Checking
- Status: FAIL (3 errors, 2 warnings)
- src/pipeline.py:42: error: Incompatible types (int vs str)
- src/models.py:18: error: Missing return type annotation
- src/utils.py:91: error: Argument has incompatible type

### Tests
- Total: 47 | Passed: 45 | Failed: 2 | Skipped: 0
- Coverage: 87% (23 lines uncovered in changed files)
- FAILURES:
  * test_incremental_load: AssertionError watermark not updated
  * test_error_handling: TypeError on None input

### Linting
- Status: PASS (0 errors, 3 warnings)
- src/pipeline.py:100: W unused import 'datetime'

### Security
- Status: PASS
- No secrets found
- No SQL injection patterns detected

## LLM Quality Review (Advisory)

### Spec Compliance
Scenario 1 (Normal incremental): ✅ Met
Scenario 2 (First run): ✅ Met
Scenario E1 (Clock skew): ❌ Gap - no 5-minute overlap implemented

### Design Observations
- Function `extract_orders` is 150 lines - consider splitting
- Variable name `x` in line 42 is not descriptive
- No error handling for database connection failures

## Issues Summary

| # | Issue | Source | Severity | Blocking? |
|---|-------|--------|----------|-----------|
| 1 | Type error: int vs str | mypy | HIGH | YES |
| 2 | test_incremental_load failed | pytest | HIGH | YES |
| 3 | Missing clock skew handling | Spec review | MEDIUM | YES |
| 4 | Long function | LLM review | LOW | NO |

## Recommendation
Fix blocking issues first (3 items). Consider design improvements after.
```

**Principles**:
- **Always execute bash commands**: Reading code is not verification
- **Never mark PASS without executed tests**: If pytest unavailable, report it
- **Never skip execution order**: syntax → types → tests
- **Short-circuit on critical failures**: don't run tests if syntax fails
- **Separate machine from LLM**: confidence levels are different
- **False PASS is worse than false FAIL**: be skeptical by default
- **Exit codes are truth**: exit 0 = pass, non-zero = investigate

---

## 10. Universal Rules vs Domain Rules

### What they are

Two categories of knowledge:
- **Universal Rules**: Apply to all code in any project
- **Domain Rules**: Specific to a technology/framework

### Why they exist

Loading dbt rules in a Docker session makes no sense. Separation enables:
- ✅ Efficiency: only relevant rules loaded
- ✅ Clarity: less noise, more focus
- ✅ Maintenance: rules evolve independently

### How they work in Marvin

**Universal Rules** (`global/rules/`):

Auto-loaded in EVERY session (via CLAUDE.md):

1. **coding-standards.md**:
   ```markdown
   # Coding Standards

   ## SQL
   - Lowercase keywords (select, from, where)
   - snake_case identifiers
   - Explicit JOIN types

   ## Testing
   - Tests are not optional

   ## Git
   - Commit messages: imperative mood
   - Atomic commits
   ```

2. **security.md**:
   ```markdown
   # Security Rules

   ## Secrets
   - Never hardcode secrets
   - Never commit .env files

   ## Code Safety
   - Parameterized queries (never string concatenation)
   - Quote file paths in shell
   ```

3. **handoff-protocol.md**:
   Structured delegation template.

**Domain Rules** (`global/agents/<domain>-expert/rules.md`):

Loaded ONLY when specialist agent is delegated:

**Example: `dbt-expert/rules.md`**:
```markdown
# dbt Expert Rules

## Naming Conventions
- Staging: stg_<source>__<entity>.sql
- Intermediate: int_<entity>__<verb>.sql
- Marts: <entity>_<grain>.sql (e.g., orders_daily.sql)

## Materialization Strategy
- Staging: always view (1:1 with source)
- Intermediate: view or ephemeral
- Marts: table or incremental (based on size)

## Testing Standards
- MUST: unique + not_null on all primary keys
- MUST: foreign key relationships tested
- PREFER: accepted_values for status columns

## Schema Documentation
- Every model MUST have description in schema.yml
- Every column with business logic MUST be documented
```

**Example: `spark-expert/rules.md`**:
```markdown
# Spark Expert Rules

## Performance
- ALWAYS use broadcast for joins with tables < 10M rows
- Repartition after filtering to avoid skew
- Persist DataFrames used multiple times

## Partitioning
- Files: 128MB-1GB each
- Partitions for processing: 2-3x number of cores
- Never partition on high-cardinality columns

## Anti-patterns
- NEVER use collect() on large datasets
- NEVER use UDFs without caching
- Avoid count() after every transformation (lazy eval)
```

**Colocation**:

```
global/
├── rules/                          # Universal (auto-load)
│   ├── coding-standards.md
│   ├── security.md
│   └── handoff-protocol.md
└── agents/
    ├── dbt-expert/
    │   ├── AGENT.md
    │   └── rules.md                # Domain-specific (load on delegation)
    ├── spark-expert/
    │   ├── AGENT.md
    │   └── rules.md
    └── airflow-expert/
        ├── AGENT.md
        └── rules.md
```

**Loading**:

```markdown
## Handoff: dbt-expert

### Constraints
MUST: Read ~/.claude/agents/dbt-expert/rules.md before starting
MUST: Follow naming conventions from rules
```

Agent reads its rules.md when starting execution.

**Why not centralize everything**:
- ❌ Loading 5000 lines of rules in every session: waste
- ❌ Conflicts: dbt rule about materialization irrelevant for Docker
- ❌ Maintenance: changing dbt convention requires editing huge file

**Why not keep everything in AGENT.md**:
- ❌ AGENT.md is behavior instruction, rules.md is domain knowledge
- ❌ Rules can be shared (e.g., via external links)
- ✅ Clear separation of concerns

---

## 11. Auto-Extension

### What it is

Marvin's ability to create new agents, skills, and rules for domains it doesn't yet cover. Automatic scaffolding system.

### Why it exists

No system can cover all possible domains. Auto-extension enables:
- ✅ Organic growth: add domains as they arise
- ✅ No bottleneck: user doesn't need to wait for maintenance
- ✅ Consistency: templates guarantee correct structure

### How it works in Marvin

**Four meta-skills**:

#### 1. `/new-agent <name> <description>`

Creates complete structure for new agent:

```bash
User: /new-agent kafka-expert "Kafka streaming specialist"

Marvin creates:
global/agents/kafka-expert/
├── AGENT.md           # Populated template
└── rules.md           # Empty template to fill

AGENT.md contents:
---
name: kafka-expert
color: orange
description: >
  Kafka streaming specialist. Use for: Kafka configuration,
  consumer/producer patterns, stream processing, Kafka Streams.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
memory: project
---

# Kafka Expert Agent

[Agent instruction template...]

Adds to registry/agents.md:
| kafka-expert | kafka, stream, consumer, producer | rules.md |
```

#### 2. `/new-skill <name> <description>`

Creates new skill/slash command:

```bash
User: /new-skill schema-registry "Generate Avro schemas"

Marvin creates:
global/skills/schema-registry/
└── SKILL.md

Contents:
---
name: schema-registry
description: Generate and validate Avro schemas
argument-hint: "[schema name]"
---

# Schema Registry

Target: $ARGUMENTS

[Instruction template...]

Adds to registry/skills.md:
- /schema-registry — Generate and validate Avro schemas
```

#### 3. `/new-rule <domain>`

Creates domain rules file:

```bash
User: /new-rule kafka

Marvin creates:
global/agents/kafka-expert/rules.md

Contents (template):
# Kafka Expert Rules

## Configuration
[Placeholder - add production configs]

## Consumer Patterns
[Placeholder - add patterns]

## Performance
[Placeholder - add optimization rules]

## Anti-patterns
[Placeholder - add things to avoid]
```

#### 4. `/audit-agents`

Analyzes codebase and identifies coverage gaps:

```bash
User: /audit-agents

Marvin:
1. Reads project files (Glob "**/*.{py,sql,yml,tf}")
2. Identifies technologies:
   - dbt_project.yml → dbt ✅ (agent exists)
   - kafka imports → kafka ❌ (agent does NOT exist)
   - terraform files → terraform ✅ (agent exists)
   - flink imports → flink ❌ (agent does NOT exist)

Report:
## Coverage Audit

### Covered Domains
- dbt ✅ (dbt-expert)
- terraform ✅ (terraform-expert)

### Gaps Detected
- kafka ❌ — Found in: src/streaming/consumer.py, src/streaming/producer.py
  Suggestion: /new-agent kafka-expert "Kafka streaming specialist"

- flink ❌ — Found in: src/flink/jobs/
  Suggestion: /new-agent flink-expert "Apache Flink specialist"
```

**Templates** (`global/templates/`):

```
templates/
├── AGENT.template.md      # New agent template
├── SKILL.template.md      # New skill template
├── RULES.template.md      # Domain rules template
└── MEMORY.template.md     # Project memory template
```

**Deployment**:

After creating new agents/skills:
```bash
cd ~/Projects/marvin
./install.sh  # Deploy to ~/.claude/
```

**Suggestion trigger**:

If Marvin directly handles a task that would be complex/recurring:
```
Marvin: [Executes Kafka task]

Note: Detected multiple Kafka requests. Consider creating an agent:
  /new-agent kafka-expert "Kafka streaming patterns and optimization"
```

---

## 12. Source of Truth Pattern

### What it is

A deployment pattern where `global/` is the source of truth and `install.sh` deploys to `~/.claude/`. Edits ALWAYS in `global/`, NEVER in `~/.claude/`.

### Why it exists

Without source of truth:
- ❌ Edit `~/.claude/CLAUDE.md` → changes lost on next install
- ❌ Drift: version in ~/.claude different from global/
- ❌ Not versioned: changes in ~/.claude not in git

With source of truth:
- ✅ Everything versioned: `global/` is in git
- ✅ Consistent deployment: `install.sh` guarantees parity
- ✅ Rollback: `git checkout` + `install.sh` restores version

### How it works in Marvin

**Structure**:

```
~/Projects/marvin/           # Git repository
├── global/                  # SOURCE OF TRUTH
│   ├── CLAUDE.md
│   ├── agents/
│   ├── skills/
│   └── rules/
├── install.sh               # Deployment script
└── .git/

~/.claude/                   # DEPLOYED (don't edit)
├── CLAUDE.md                # Copy of global/CLAUDE.md
├── agents/
├── skills/
└── rules/
```

**Golden rule**: **NEVER edit `~/.claude/` directly.**

**Workflow**:

```bash
# 1. Edit source of truth
cd ~/Projects/marvin
vim global/agents/dbt-expert/rules.md

# 2. Test (optional)
./install.sh --dry-run

# 3. Deploy
./install.sh

# 4. Verify
claude
> Test change...

# 5. Commit
git add global/agents/dbt-expert/rules.md
git commit -m "feat(dbt): add incremental materialization guidance"
```

**Script install.sh**:

```bash
#!/bin/bash
MARVIN_HOME="$HOME/.claude"
GLOBAL_DIR="$(pwd)/global"

# Backup existing (if not ours)
backup_if_needed "$MARVIN_HOME/CLAUDE.md"

# Copy complete structure
cp -r "$GLOBAL_DIR/CLAUDE.md" "$MARVIN_HOME/"
cp -r "$GLOBAL_DIR/agents" "$MARVIN_HOME/"
cp -r "$GLOBAL_DIR/skills" "$MARVIN_HOME/"
cp -r "$GLOBAL_DIR/rules" "$MARVIN_HOME/"
cp -r "$GLOBAL_DIR/registry" "$MARVIN_HOME/"
cp -r "$GLOBAL_DIR/templates" "$MARVIN_HOME/"

# Memory.md: NEVER overwrite (preserves user data)
if [ ! -f "$MARVIN_HOME/memory.md" ]; then
  cp "$GLOBAL_DIR/memory.md" "$MARVIN_HOME/"
fi

echo "Marvin installed to ~/.claude/"
```

**Flags**:
- `./install.sh`: Installs with backup
- `./install.sh --force`: Installs without prompts
- `./install.sh --dry-run`: Shows what would be copied (without executing)

**Project override** (`.claude/`):

Projects can have local overrides:

```
project/
├── .claude/                 # Project-specific
│   ├── CLAUDE.md            # Adds project context
│   ├── memory.md
│   └── rules/
│       └── project-specific.md
└── src/
```

**Loading order**:
1. `~/.claude/CLAUDE.md` (global)
2. `.claude/CLAUDE.md` (project, if exists)
3. Global memory
4. Project memory

**When to edit where**:

| What to edit | Where to edit | Don't edit |
|--------------|-------------|------------|
| Orchestrator logic | `global/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Agent definition | `global/agents/<name>/AGENT.md` | `~/.claude/agents/` |
| Domain rules | `global/agents/<domain>/rules.md` | `~/.claude/agents/` |
| Skills | `global/skills/<name>/SKILL.md` | `~/.claude/skills/` |
| Global memory | `~/.claude/memory.md` | ✅ OK to edit (user data) |
| Project context | `.claude/CLAUDE.md` | ✅ OK (project-specific) |

---

## 13. Project Initialization

### What it is

The `/init` skill that detects project type and creates `.claude/` structure with appropriate configurations.

### Why it exists

Different projects have different needs:
- Data pipeline: needs SQL, dbt, Airflow rules
- AI/ML: needs notebook, experiment, MLOps rules
- Generic: needs only basics

`/init` automates appropriate configuration.

### How it works in Marvin

**Invocation**:

```bash
# Explicit
> /init data-pipeline

# Auto-detection
> /init
Marvin: [Analyzes files]
        Detected: dbt_project.yml, airflow/
        Type: data-pipeline
```

**Type detection**:

```python
def detect_project_type():
    if exists("dbt_project.yml") or exists("airflow/") or exists("dagster.py"):
        return "data-pipeline"

    if has_requirement("torch", "tensorflow", "transformers") or exists("*.ipynb"):
        return "ai-ml"

    return "generic"
```

**Structure created** (`.claude/`):

```
project/
└── .claude/
    ├── CLAUDE.md              # Project context
    ├── memory.md              # Project memory
    ├── registry/
    │   ├── agents.md          # Project-specific agents (initially empty)
    │   └── skills.md          # Project-specific skills (initially empty)
    ├── rules/                 # Domain rules for this project
    │   └── data-engineering.md  # If data-pipeline
    └── settings.json          # Permissions
```

**CLAUDE.md created** (data-pipeline):

```markdown
# Project Context

This is a data pipeline project.

## Tech Stack
- Python 3.11
- dbt 1.5
- Airflow 2.7
- Snowflake
- AWS S3

## Architecture
- Source: S3 raw buckets
- Transformation: dbt models (staging → intermediate → marts)
- Orchestration: Airflow DAGs (daily schedule)
- Target: Snowflake warehouse

## Conventions
- Staging models: stg_<source>__<entity>
- SQL: lowercase keywords, snake_case identifiers
- Tests: every model has unique + not_null on PK

## Memory
@.claude/memory.md

## Project-Specific Agents
@.claude/registry/agents.md

## Project-Specific Skills
@.claude/registry/skills.md

## Domain Rules
@.claude/rules/data-engineering.md
```

**memory.md created**:

```markdown
# Project Memory

## Architecture Decisions
- [2026-02-13] Detected stack: dbt 1.5, Airflow 2.7, Snowflake

## Tech Stack & Conventions
- [2026-02-13] Using stg_<source>__<entity> naming for staging

## Patterns Discovered

## Lessons Learned
```

**settings.json created** (data-pipeline):

```json
{
  "permissions": {
    "allow": [
      "dbt *",
      "airflow *",
      "psql *",
      "snowsql *"
    ],
    "deny": []
  }
}
```

**Domain rules** (`.claude/rules/data-engineering.md`):

```markdown
# Data Engineering Rules

## SQL Standards
- Lowercase keywords
- Explicit JOINs
- CTEs over subqueries

## dbt Conventions
- Staging: 1:1 with source, no business logic
- Marts: denormalized for analytics

## Data Quality
- Primary keys: unique + not_null
- Foreign keys: relationships tested
```

**Project types**:

| Type | Detects | Creates rules/ |
|------|---------|-------------|
| `data-pipeline` | dbt_project.yml, airflow/, dagster | data-engineering.md |
| `ai-ml` | torch/transformers in requirements, notebooks | ai-ml.md |
| `generic` | Any other | (none - uses only global) |

**Post-initialization**:

```bash
Marvin: ✅ Project initialized as: data-pipeline

Created:
  .claude/CLAUDE.md
  .claude/memory.md
  .claude/registry/agents.md
  .claude/registry/skills.md
  .claude/rules/data-engineering.md
  .claude/settings.json

Next steps:
- Customize .claude/CLAUDE.md with project specifics
- Use /remember to document decisions as they arise
- Global agents (dbt-expert, airflow-expert, etc.) are available
```

---

## 14. Humanized Commits

### What it is

A convention from the `git-expert` agent to create commits that look human-written, with **zero AI attribution**.

### Why it exists

Commits with AI attribution:
- ❌ Create noise in history
- ❌ Reduce accountability (who approved?)
- ❌ May violate corporate policies
- ❌ Don't add technical value

Humanized commits:
- ✅ Clean, professional history
- ✅ Indistinguishable from manual commits
- ✅ Compliance with standard policies

### How it works in Marvin

**CRITICAL rules** (git-expert):

**NEVER include**:
- "Generated with Claude Code"
- "Generated by AI"
- "Co-Authored-By: Claude" or any AI co-author
- Any mention of "Claude", "Anthropic", "AI"
- Robot emojis or AI-related symbols

**Conventional Commits format**:

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

**Types**:

| Type | When to use |
|------|-------------|
| feat | New feature or capability |
| fix | Bug fix |
| docs | Documentation only |
| refactor | Code change without fix/feature |
| perf | Performance improvement |
| test | Add/fix tests |
| chore | Maintenance, config, tooling |

**GOOD example**:

```
feat(etl): add incremental load for orders table

Implement watermark-based extraction using updated_at timestamp.
Only processes records modified since last successful run.

- Add checkpoint tracking in metadata table
- Implement recovery logic for failed runs
- Reduce processing time from 4h to 15min

Closes #234
```

**BAD example** (FORBIDDEN):

```
feat(etl): add incremental load for orders table

Implement watermark-based extraction.

Generated with Claude Code
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Atomic Commits**:

Git-expert groups changes logically:

```bash
# Changes detected:
# - models/staging/stg_orders.sql (new)
# - models/staging/_sources.yml (updated)
# - tests/test_stg_orders.sql (new)
# - README.md (updated)

# Logical groups:
# Group 1: staging model + its tests (tightly coupled)
# Group 2: documentation (independent)

# Result: 2 atomic commits

Commit 1:
feat(dbt): add staging model for orders

Create stg_orders with unique + not_null tests.
Maps raw orders table to analytics-ready format.

Commit 2:
docs: update README with staging layer conventions
```

**Grouping strategy**:

| Scenario | Commits |
|---------|---------|
| Feature + feature tests | 1 commit (tests are part of feature) |
| Feature + refactor existing code | 2 commits (refactor first) |
| Bug fix + formatting | 2 commits (fix first, style after) |
| 3 unrelated bugs | 3 commits (each independent) |
| Migration + code depending on it | 2 commits (migration → code) |

**Git-expert process**:

```bash
1. git status (list changes)
2. git diff --staged (see what will commit)
3. git log --oneline -20 (learn project style)

4. Analyze changes:
   - What was added/removed/modified?
   - What's the purpose?
   - Multiple purposes? → multiple commits

5. Write message:
   - Correct type and scope
   - First line: imperative, < 72 chars
   - Body: explain WHY, not just WHAT
   - Footer: issue refs, breaking changes

6. Execute commit:
   git commit -m "$(cat <<'EOF'
   feat(dbt): add orders staging model

   Create stg_orders.sql with standard conventions.
   Includes unique + not_null tests on order_id.
   EOF
   )"

7. Verify: git log -1
```

**Principles**:

- **Human, always**: Zero AI fingerprint
- **Atomic**: One logical purpose per commit
- **Why over what**: Diff shows what, message explains why
- **Match the project**: Follow existing history patterns
- **Imperative**: "add" not "added", "fix" not "fixed"

---

## 15. Stop and Think Pattern

### What it is

A mandatory reflection process that Marvin MUST execute before any action. Prevents premature execution and guarantees correct routing.

### Why it exists

Without stop-and-think:
- ❌ Executes directly when should delegate
- ❌ Delegates to wrong agent
- ❌ Loses important context
- ❌ Complex tasks treated superficially

With stop-and-think:
- ✅ Always correct routing
- ✅ Complete handoff constructed
- ✅ Relevant context identified
- ✅ Appropriate strategy chosen

### How it works in Marvin

**Mandatory process** (BEFORE every action):

```
┌─────────────────────────────────────────────┐
│  1. Identify Domain                         │
│     "create dbt model" → domain: dbt        │
└──────────────┬──────────────────────────────┘
               ▼
┌─────────────────────────────────────────────┐
│  2. Check Agent Registry                    │
│     Query: registry/agents.md               │
│     Match: "dbt" → dbt-expert               │
└──────────────┬──────────────────────────────┘
               ▼
┌─────────────────────────────────────────────┐
│  3. Specialist Exists?                      │
│     YES → Construct Handoff                 │
│     NO → Handle Direct or Suggest           │
└──────────────┬──────────────────────────────┘
               ▼
┌─────────────────────────────────────────────┐
│  4. Delegate via Task Tool                  │
│     with structured handoff                 │
└─────────────────────────────────────────────┘
```

**Implementation**:

```markdown
## How You Work (in CLAUDE.md)

### Stop and Think (MANDATORY — Before Every Action)

For ANY request:
1. Identify the domain
2. Check the agent registry
3. If specialist exists → construct structured handoff (@rules/handoff-protocol.md)
4. Delegate via Task tool with the structured handoff

Handle directly ONLY for: greetings, capability questions, clarifications,
concept explanations, or single-file edits with no specialist.

**CRITICAL**: Skipping delegation when a specialist exists violates your core protocol.
```

**Handling decision**:

```python
def should_handle_directly(request):
    # Only these categories:
    return (
        is_greeting(request) or           # "Hello Marvin"
        is_capability_question(request) or # "What can you do?"
        is_clarification(request) or       # "Could you clarify X?"
        is_concept_explanation(request) or # "Explain what is X"
        is_single_file_no_specialist(request) # "Fix typo in README" (if no docs-expert)
    )

# EVERYTHING ELSE: delegate if specialist exists
```

**Examples**:

#### Case 1: Delegation (majority)

```
User: "Create a dbt model for orders"

Stop and Think:
1. Domain: dbt
2. Registry: dbt-expert exists
3. Specialist exists → construct handoff
4. Delegate

[Constructs structured handoff]
[Calls Task tool with dbt-expert]
```

#### Case 2: Handle direct (greeting)

```
User: "Hello Marvin!"

Stop and Think:
1. Domain: greeting
2. Registry: (not applicable)
3. Greeting exception → handle direct
4. Responds directly

Marvin: "Hello! I'm Marvin, your Data Engineering and AI/ML assistant.
        How can I help you today?"
```

#### Case 3: Handle direct (clarification)

```
User: "What did you mean by 'watermark strategy'?"

Stop and Think:
1. Domain: clarification
2. Registry: (not applicable)
3. Clarification exception → handle direct
4. Explains concept

Marvin: "A watermark strategy tracks the last successfully processed..."
```

#### Case 4: Delegate even for "simple"

```
User: "Commit these changes"

Stop and Think:
1. Domain: git
2. Registry: git-expert exists
3. Specialist exists → MUST delegate (even "simple")
4. Delegate

[Constructs minimal handoff for git-expert]
```

**CRITICAL**: Even apparently simple tasks MUST be delegated if specialist exists. No exception for "it's quick" or "it's just a commit".

**Protocol violation**:

```
# WRONG (violation)
User: "Create dbt model"
Marvin: [Writes model directly]

# CORRECT
User: "Create dbt model"
Marvin: [Stop and Think]
        [Identifies dbt domain]
        [Finds dbt-expert]
        [Constructs handoff]
        [Delegates via Task]
```

---

## 16. Model Selection by Complexity

### What it is

Each agent declares which LLM model to use (haiku, sonnet, opus) based on the typical complexity of its tasks.

### Why it exists

Always using the strongest model:
- ❌ Wastes cost on simple tasks
- ❌ Unnecessary latency

Always using the fastest model:
- ❌ Poor quality on complex tasks
- ❌ More retries (ends up slower)

Selection by complexity:
- ✅ Optimized cost
- ✅ Appropriate latency
- ✅ Guaranteed quality

### How it works in Marvin

**Available models**:

| Model | When to use | Capabilities |
|--------|-------------|-------------|
| haiku | Simple, executive tasks | Fast, low cost, direct commands |
| sonnet | Most tasks | Balanced cost/quality, implementation |
| opus | Complex reasoning | Maximum capability, design, deep debugging |

**Declaration in AGENT.md**:

```yaml
---
name: git-expert
model: haiku
---
```

**Selection rules by agent**:

| Agent | Model | Justification |
|--------|--------|---------------|
| git-expert | haiku | Executive: run git commands, format messages |
| verifier | haiku | Executive: run pytest/mypy/ruff, report results |
| coder | sonnet | Implementation: write code, tests, refactoring |
| researcher | sonnet | Synthesis: search, read, synthesize information |
| dbt-expert | sonnet | Implementation: models, tests, docs |
| spark-expert | sonnet | Implementation: transformations, optimization |
| airflow-expert | sonnet | Implementation: DAGs, operators |
| architect | opus | Design: complex architectural decisions (if exists) |
| debugger | opus | Deep debugging: root cause analysis (if exists) |

**Decision criteria**:

```python
def choose_model(task_type):
    if task_type in ["execute_command", "format_text", "run_tests"]:
        return "haiku"  # Executive, no ambiguity

    elif task_type in ["implement", "refactor", "research", "synthesize"]:
        return "sonnet"  # Standard for technical work

    elif task_type in ["architecture", "complex_debugging", "system_design"]:
        return "opus"  # Maximum cognitive capability
```

**Practical examples**:

```
Task: "Commit these changes"
Domain: git
Agent: git-expert
Model: haiku
Why: Executive (git diff, git commit, format message)

Task: "Implement incremental dbt model"
Domain: dbt
Agent: dbt-expert
Model: sonnet
Why: Implementation (write SQL, tests, docs)

Task: "Research modern data lake architectures"
Domain: research
Agent: researcher
Model: sonnet
Why: Synthesis (search, read, cross sources, recommend)

Task: "Debug distributed race condition in Spark"
Domain: spark + debugging
Agent: spark-expert → opus override
Model: opus
Why: Complex debugging (requires deep reasoning)
```

**Override by complexity**:

Marvin can override agent's model if it detects exceptional complexity:

```markdown
## Handoff: dbt-expert

[Exceptionally complex task:
 migration of 100 models with schema changes]

**Model Override**: opus (exceptional complexity)
```

**Complete frontmatter**:

```yaml
---
name: coder
color: green
description: >
  Code implementation specialist.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet                    # ← Explicit declaration
memory: user
permissionMode: acceptEdits
---
```

---

## 17. Hooks and Extensions

### What it is

Shell scripts executed automatically at specific points in the Claude Code lifecycle. Enable validation, notification, and automation.

### Why they exist

Claude Code alone cannot:
- ❌ Block commits with secrets before executing
- ❌ Validate SQL syntax before running pipeline
- ❌ Notify when long tasks finish

Hooks solve:
- ✅ Pre-execution validation
- ✅ Post-execution notifications
- ✅ Workflow automation

### How they work in Marvin

**Location**: `~/.claude/hooks/`

**Hook types**:

#### 1. `block-secrets.sh`

Executes before git operations, blocks commits with secrets:

```bash
#!/bin/bash
# block-secrets.sh

# Search for secret patterns in staged files
git diff --cached | grep -E '(password|api_key|secret|token)\s*=\s*['\''"]'

if [ $? -eq 0 ]; then
  echo "ERROR: Detected hardcoded secrets in staged files"
  echo "Remove secrets before committing"
  exit 1
fi

exit 0
```

Integration:
```bash
# Before git commit
~/.claude/hooks/block-secrets.sh || {
  echo "Commit blocked by security hook"
  exit 1
}
```

#### 2. `validate-python.sh`

Validates Python syntax before executing:

```bash
#!/bin/bash
# validate-python.sh FILE

python -m py_compile "$1" 2>&1

if [ $? -ne 0 ]; then
  echo "Python syntax error in $1"
  exit 1
fi
```

#### 3. `validate-sql.sh`

Validates SQL syntax (if sqlfluff available):

```bash
#!/bin/bash
# validate-sql.sh FILE

if command -v sqlfluff >/dev/null 2>&1; then
  sqlfluff lint "$1" --dialect snowflake
else
  echo "sqlfluff not available, skipping validation"
fi
```

#### 4. `notify.sh`

Notifies when tasks finish (useful with Ralph Loop):

```bash
#!/bin/bash
# notify.sh MESSAGE

# macOS
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$1\" with title \"Marvin\""
fi

# Linux (notify-send)
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Marvin" "$1"
fi
```

Usage:
```bash
# At end of Ralph Loop
~/.claude/hooks/notify.sh "Task completed successfully"
```

#### 5. `greeting.sh`

Executes on Claude Code initialization:

```bash
#!/bin/bash
# greeting.sh

echo "================================================"
echo "  Marvin — Data Engineering & AI Assistant"
echo "================================================"
echo ""
echo "Available skills: /init /research /spec /ralph"
echo "Type '/help' for full list"
echo ""
```

**Settings integration** (`~/.claude/settings.json`):

```json
{
  "permissions": {
    "allow": ["dbt *", "pytest *"],
    "deny": ["rm -rf *"]
  },
  "hooks": {
    "pre-commit": "~/.claude/hooks/block-secrets.sh",
    "pre-run": "~/.claude/hooks/validate-python.sh",
    "post-task": "~/.claude/hooks/notify.sh"
  }
}
```

**Hook implementation**:

```bash
# Make executable
chmod +x ~/.claude/hooks/*.sh

# Claude Code calls hooks automatically
# (or manually via bash commands in agents)
```

**Example usage in agent**:

```markdown
# verifier agent

Before running tests:
1. Run pre-validation hook:
   bash ~/.claude/hooks/validate-python.sh src/pipeline.py

2. If exit code 0: proceed with tests
3. If exit code 1: report validation error
```

**Custom hooks**:

Projects can add specific hooks in `.claude/hooks/`:

```
project/
└── .claude/
    └── hooks/
        ├── pre-dbt-run.sh      # Validates models before dbt run
        └── post-pipeline.sh    # Updates dashboard after pipeline
```

**Execution order**:

```bash
1. ~/.claude/hooks/<hook>.sh    # Global
2. .claude/hooks/<hook>.sh       # Project (if exists, overrides global)
```

---

## Conclusion

These 17 concepts form the complete architecture of Marvin:

1. **Orchestration Layer** — The brain that routes requests
2. **Specialized Agents** — Domain specialists with deep knowledge
3. **Mandatory Delegation** — Zero exceptions for consistency
4. **Handoff Protocol** — Structured context transfer
5. **Ralph Loop** — Autonomous long-running execution
6. **Spec-Driven Development** — Design before implementation
7. **Skills System** — On-demand functionality via slash commands
8. **Persistent Memory** — Learning between sessions
9. **Deterministic Verification** — Facts before opinions
10. **Universal vs Domain Rules** — Appropriately scoped knowledge
11. **Auto-Extension** — Organic system growth
12. **Source of Truth** — Controlled and versioned deployment
13. **Project Initialization** — Appropriate setup by type
14. **Humanized Commits** — Zero AI fingerprint
15. **Stop and Think** — Mandatory reflection before action
16. **Model Selection** — Optimized cost/quality
17. **Hooks** — Automation and validation in lifecycle events

Together, these concepts transform Claude Code from a generic assistant into a specialized and extensible system for Data Engineering and AI/ML.
