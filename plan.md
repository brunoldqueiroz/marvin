# MARVIN — AI Assistant Built on Claude Code

## Vision

Marvin is an AI assistant built **entirely on top of Claude Code**, using its native features:
CLAUDE.md, subagents, skills, hooks, MCP servers, and the CLI SDK. No custom Python
framework, no raw API calls — Claude Code **is** the agent runtime.

Initially focused on **Data Engineering** and **AI/ML**, Marvin uses Claude Opus as the
orchestrator brain that thinks, plans, and delegates to specialized subagents.

---

## 1. Architecture: Claude Code as the Platform

### 1.1 Why Claude Code Instead of Raw API/Agent SDK

| Raw API / Agent SDK                    | Claude Code (Our Approach)                      |
|----------------------------------------|-------------------------------------------------|
| Build your own agent loop              | Agent loop is built-in                          |
| Implement tool use from scratch        | 15+ built-in tools (Read, Edit, Bash, Grep...) |
| Build custom permission system         | Permission system + hooks built-in              |
| Write memory management code           | Auto memory + agent memory built-in             |
| Build subagent orchestration           | Task tool + AGENT.md files                      |
| Create CLI interface                   | Claude Code CLI (interactive + headless)        |
| Integrate MCP manually                 | `.mcp.json` — declarative MCP config            |
| Build context management               | Compaction + context engineering built-in        |
| Write validation/formatting scripts    | Hooks (PreToolUse, PostToolUse, etc.)           |
| Deploy custom server                   | Just run `claude` in your terminal              |

**Key insight:** Claude Code already implements the orchestrator-subagent pattern
that Anthropic recommends. We configure it, not rebuild it.

### 1.2 Architecture Overview

```
                    ┌─────────────────────────┐
                    │     YOU (Terminal)       │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │      CLAUDE CODE        │
                    │    (Agent Runtime)      │
                    │                         │
                    │  CLAUDE.md (Marvin)     │  ← Orchestrator brain
                    │  + Extended Thinking    │
                    │  + Built-in Tools       │
                    │  + MCP Servers          │
                    │  + Hooks                │
                    └──┬───┬───┬───┬───┬─────┘
                       │   │   │   │   │
           ┌───────────┘   │   │   │   └───────────┐
           │               │   │   │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
    │  Data Eng   │ │  AI / ML    │ │  Research   │ │  Code       │
    │  AGENT.md   │ │  AGENT.md   │ │  AGENT.md   │ │  AGENT.md   │
    └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
        Subagents (isolated context, specialized tools)

    ┌──────────────────────────────────────────────────────────────┐
    │  Skills (SKILL.md)  — Reusable knowledge + slash commands   │
    │  /pipeline  /model  /review  /research  /sql  /dbt          │
    └──────────────────────────────────────────────────────────────┘
```

### 1.3 How It Maps to Anthropic's Patterns

| Anthropic Pattern         | Claude Code Implementation                           |
|--------------------------|------------------------------------------------------|
| **Orchestrator-Workers** | CLAUDE.md (orchestrator) + AGENT.md files (workers)  |
| **Routing**              | Claude reads intent → spawns correct subagent via Task tool |
| **Parallelization**      | Multiple Task calls in single response (built-in)    |
| **Evaluator-Optimizer**  | Verification agent + hooks (PostToolUse)             |
| **Plan-and-Execute**     | Plan mode (`--permission-mode plan`) → Execute       |
| **Prompt Chaining**      | Skills with sequential instructions                  |

---

## 2. Marvin's Brain — How It All Connects

CLAUDE.md is the **core** of Marvin's brain, but the complete intelligence is
distributed across several components that work together:

```
┌──────────────────────────────────────────────────────────────────┐
│                      MARVIN'S BRAIN                              │
│                                                                  │
│  ┌─────────────┐   Loads at every session start                 │
│  │  CLAUDE.md   │   Identity, decision-making, routing logic    │
│  │  (DNA)       │   Imports rules + registry dynamically        │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ├── @.claude/registry/agents.md    (who can I delegate to?) │
│         ├── @.claude/registry/skills.md    (what workflows do I know?) │
│         ├── @.claude/rules/data-engineering.md  (domain knowledge)│
│         ├── @.claude/rules/ai-ml.md             (domain knowledge)│
│         └── @.claude/rules/coding-standards.md  (how to code)   │
│                                                                  │
│  ┌─────────────┐   Persists across sessions                     │
│  │ agent-memory │   Patterns discovered, lessons learned        │
│  │ (Experience) │   Each agent has its own memory               │
│  └─────────────┘                                                │
│                                                                  │
│  ┌─────────────┐   Always fires, no matter what                 │
│  │  Hooks       │   Auto-format, block secrets, notify          │
│  │ (Reflexes)   │   Deterministic — can't be ignored            │
│  └─────────────┘                                                │
│                                                                  │
│  ┌─────────────┐   Isolated specialists                         │
│  │  Agents      │   data-eng, ai-ml, researcher, coder, verifier│
│  │ (Team)       │   Each has own context + tools + memory       │
│  └─────────────┘                                                │
│                                                                  │
│  ┌─────────────┐   Reusable procedures                          │
│  │  Skills      │   /pipeline, /sql, /dbt, /spec, /ralph...    │
│  │ (Procedures) │   Invoked as slash commands                   │
│  └─────────────┘                                                │
│                                                                  │
│  ┌─────────────┐   External connections                         │
│  │  MCP Servers │   Exa, GitHub, Postgres, Notion, Context7     │
│  │ (Senses)     │   How Marvin perceives the outside world      │
│  └─────────────┘                                                │
└──────────────────────────────────────────────────────────────────┘
```

**The key insight:** CLAUDE.md doesn't hardcode agents and skills. It **imports**
dynamic registry files via `@` references. When you add a new agent or skill,
you update the registry — and Marvin immediately knows about it.

---

## 3. Packaging: Two-Layer Architecture

### The Problem

If Marvin lives only in `~/Projects/marvin/`, you'd have to `cd` there every time.
But you want Marvin available when working on ANY project — a data pipeline,
an ML training repo, a web app, anything.

### The Solution: Global + Project Layers

Claude Code has a built-in configuration hierarchy. We use it:

```
┌────────────────────────────────────────────────────────────────┐
│                     LAYER 1: GLOBAL                            │
│                  ~/.claude/ (user-level)                        │
│                                                                │
│  Marvin's core identity, universal agents, universal skills    │
│  Available in EVERY project, on EVERY `claude` session         │
│                                                                │
│  ~/.claude/CLAUDE.md          ← Marvin's brain (always loads)  │
│  ~/.claude/settings.json      ← Global permissions & hooks     │
│  ~/.claude/agents/            ← Universal agents               │
│  ~/.claude/skills/            ← Universal skills               │
│  ~/.claude/agent-memory/      ← Learned knowledge              │
└────────────────────────────────────────────────────────────────┘
                            +
┌────────────────────────────────────────────────────────────────┐
│                     LAYER 2: PROJECT                           │
│              .claude/ (per-project, in each repo)              │
│                                                                │
│  Project-specific context, rules, agents, MCP servers          │
│  Only loads when you're inside that project                    │
│                                                                │
│  .claude/CLAUDE.md            ← Project context (tech stack)   │
│  .claude/rules/               ← Project-specific rules         │
│  .claude/agents/              ← Project-specific agents         │
│  .claude/skills/              ← Project-specific skills        │
│  .claude/settings.json        ← Project permissions            │
│  .mcp.json                    ← Project MCP servers            │
└────────────────────────────────────────────────────────────────┘
```

**How Claude Code merges them:**
1. `~/.claude/CLAUDE.md` loads first (Marvin's identity)
2. `.claude/CLAUDE.md` loads next (project context)
3. Project-level settings **extend** global settings (not replace)
4. Both layers' agents and skills are available simultaneously

### What Goes Where

| Component | Global (`~/.claude/`) | Project (`.claude/`) |
|-----------|----------------------|---------------------|
| **CLAUDE.md** | Marvin's identity, how to think, delegate, extend | Project tech stack, conventions, architecture |
| **agents/** | Universal: researcher, coder, verifier | Domain: data-eng, ai-ml, devops (per project) |
| **skills/** | Universal: /new-agent, /new-skill, /new-rule, /research, /review, /ralph | Domain: /pipeline, /sql, /dbt (per project) |
| **rules/** | coding-standards.md, security.md | data-engineering.md, ai-ml.md (per project) |
| **settings.json** | Global permissions, hooks (format, secrets) | Project-specific permissions, tools |
| **registry/** | Global agents + skills registry | Project agents + skills registry |
| **templates/** | Scaffolding templates for /new-* | (not needed per project) |
| **.mcp.json** | — (use `~/.claude.json` for global MCPs) | Project-specific: Postgres, Snowflake, etc. |

### Installation: `install.sh`

A single script installs Marvin's global layer:

```bash
#!/bin/bash
# install.sh — Install Marvin globally

MARVIN_HOME="$HOME/.claude"
MARVIN_REPO="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Marvin to $MARVIN_HOME..."

# Backup existing config
if [ -f "$MARVIN_HOME/CLAUDE.md" ]; then
  cp "$MARVIN_HOME/CLAUDE.md" "$MARVIN_HOME/CLAUDE.md.backup"
  echo "Backed up existing CLAUDE.md"
fi

# Copy global layer
cp "$MARVIN_REPO/global/CLAUDE.md" "$MARVIN_HOME/CLAUDE.md"
cp "$MARVIN_REPO/global/settings.json" "$MARVIN_HOME/settings.json"

# Copy universal agents
mkdir -p "$MARVIN_HOME/agents"
cp -r "$MARVIN_REPO/global/agents/"* "$MARVIN_HOME/agents/"

# Copy universal skills
mkdir -p "$MARVIN_HOME/skills"
cp -r "$MARVIN_REPO/global/skills/"* "$MARVIN_HOME/skills/"

# Copy templates
mkdir -p "$MARVIN_HOME/templates"
cp -r "$MARVIN_REPO/global/templates/"* "$MARVIN_HOME/templates/"

# Copy registries
mkdir -p "$MARVIN_HOME/registry"
cp -r "$MARVIN_REPO/global/registry/"* "$MARVIN_HOME/registry/"

echo "Marvin installed! He's now available in every Claude Code session."
echo ""
echo "To add project-specific config, run inside any project:"
echo "  /init"
```

### Project Init: `/init` Skill

A universal skill that scaffolds project-level `.claude/` in any repo:

```yaml
# ~/.claude/skills/init/SKILL.md
---
name: init
description: Initialize Marvin project config in the current directory
disable-model-invocation: true
argument-hint: "[project-type: data-pipeline | ai-ml | web-app | generic]"
---

# Initialize Project for Marvin

Project type: $ARGUMENTS

## Steps

1. **Detect project type** — If $ARGUMENTS is empty, analyze the codebase
   (look for dbt_project.yml, setup.py, package.json, Dockerfile, etc.)

2. **Create .claude/ structure**:
   ```
   .claude/
   ├── CLAUDE.md              ← Project context
   ├── rules/                 ← Domain rules for this project
   ├── registry/
   │   ├── agents.md          ← Project-specific agent registry
   │   └── skills.md          ← Project-specific skill registry
   └── settings.json          ← Project permissions
   ```

3. **Write project CLAUDE.md** based on type:

   **For data-pipeline projects:**
   ```markdown
   # Project Context
   This is a data pipeline project.
   ## Tech Stack
   - [detect from files: dbt, Airflow, Spark, etc.]
   ## Project-Specific Agents
   @.claude/registry/agents.md
   ## Project-Specific Skills
   @.claude/registry/skills.md
   ## Domain Rules
   @.claude/rules/data-engineering.md
   ```

   **For ai-ml projects:**
   ```markdown
   # Project Context
   This is an AI/ML project.
   ## Tech Stack
   - [detect: PyTorch, HuggingFace, scikit-learn, etc.]
   ## Domain Rules
   @.claude/rules/ai-ml.md
   ```

   **For generic projects:**
   ```markdown
   # Project Context
   ## Tech Stack
   - [detect from files]
   ## Conventions
   - [infer from existing code]
   ```

4. **Copy relevant rules** based on project type

5. **Create .mcp.json** with project-relevant MCP servers:
   - Data projects → add Postgres/BigQuery/Snowflake
   - AI projects → add vector DB, experiment tracking
   - All projects → inherit global Exa, Context7, GitHub

6. **Add .claude/settings.local.json to .gitignore**

7. **Confirm** — Show what was created
```

### How It Works in Practice

```bash
# STEP 1: Install Marvin once (global)
cd ~/Projects/marvin
./install.sh

# STEP 2: Open ANY project
cd ~/Projects/my-data-pipeline
claude

# Marvin is already here! (global ~/.claude/ loaded)
> Hi Marvin, what can you do?
# Marvin responds with his full capabilities

# STEP 3: Initialize project-specific config
> /init data-pipeline
# → Creates .claude/ with data-engineering context
# → Creates .mcp.json with Postgres
# → Now Marvin has BOTH global + project knowledge

# STEP 4: Work normally
> /pipeline kafka user_events bigquery
# Marvin uses global agents + project-specific rules

# --- In another terminal ---

# STEP 5: Different project, same Marvin
cd ~/Projects/my-ml-model
claude

> /init ai-ml
# → Creates .claude/ with AI/ML context
# → Marvin adapts to this project's domain

> /model train a sentiment classifier
```

### The Key Insight

```
~/Projects/my-data-pipeline/     ~/Projects/my-ml-model/
         │                                │
    .claude/                         .claude/
    (data eng rules,                 (AI/ML rules,
     Postgres MCP,                   vector DB MCP,
     pipeline skills)                model skills)
         │                                │
         └──────────┐    ┌────────────────┘
                    │    │
              ~/.claude/
              (Marvin's brain,
               universal agents,
               universal skills,
               meta-skills)
```

**You never `cd ~/Projects/marvin` to use Marvin.** You `cd` to whatever project
you're working on, run `claude`, and Marvin is already there. The marvin/ repo
is just the **source code** for his brain — after `install.sh`, it lives in `~/.claude/`.

---

## 4. Project Structure (Two-Layer)

### 4.1 Marvin Source Repo (`~/Projects/marvin/`)

This is the **source code** for Marvin. You develop here, then install.

```
marvin/                              # Source repo (develop + install from here)
├── install.sh                       # Installs global layer to ~/.claude/
├── plan.md                          # This file
├── README.md                        # Documentation
│
├── global/                          # ──── LAYER 1: Goes to ~/.claude/ ────
│   ├── CLAUDE.md                    # Marvin's brain (identity + routing)
│   │
│   ├── registry/                    # Dynamic registries
│   │   ├── agents.md               # All available agents
│   │   └── skills.md               # All available skills
│   │
│   ├── templates/                   # Scaffolding templates
│   │   ├── AGENT.template.md
│   │   ├── SKILL.template.md
│   │   └── RULE.template.md
│   │
│   ├── agents/                      # Universal agents
│   │   ├── researcher/AGENT.md      # Research — available everywhere
│   │   ├── coder/AGENT.md           # Code — available everywhere
│   │   └── verifier/AGENT.md        # Quality gate — available everywhere
│   │
│   ├── skills/                      # Universal skills
│   │   ├── init/SKILL.md            # /init — Setup project-level config
│   │   ├── new-agent/SKILL.md       # /new-agent — Scaffold new agent
│   │   ├── new-skill/SKILL.md       # /new-skill — Scaffold new skill
│   │   ├── new-rule/SKILL.md        # /new-rule — Scaffold new rule
│   │   ├── research/SKILL.md        # /research — Deep research
│   │   ├── review/SKILL.md          # /review — Code review
│   │   ├── spec/SKILL.md            # /spec — OpenSpec SDD workflow
│   │   ├── ralph/SKILL.md           # /ralph — Ralph Loop
│   │   └── meta-prompt/SKILL.md     # /meta-prompt — Generate prompts
│   │
│   ├── rules/                       # Universal rules
│   │   ├── coding-standards.md      # Code quality (always loaded)
│   │   └── security.md             # Security (always loaded)
│   │
│   ├── hooks/                       # Universal hooks
│   │   ├── validate-python.sh
│   │   ├── block-secrets.sh
│   │   └── notify.sh
│   │
│   └── settings.json                # Global permissions & hooks
│
├── project-templates/               # ──── LAYER 2: Scaffolded by /init ────
│   ├── data-pipeline/
│   │   ├── CLAUDE.md                # Data pipeline project context
│   │   ├── rules/
│   │   │   └── data-engineering.md
│   │   ├── agents/
│   │   │   └── data-eng/AGENT.md
│   │   ├── skills/
│   │   │   ├── pipeline/SKILL.md
│   │   │   ├── sql/SKILL.md
│   │   │   └── dbt/SKILL.md
│   │   ├── settings.json
│   │   └── mcp.json                 # Postgres, BigQuery, etc.
│   │
│   ├── ai-ml/
│   │   ├── CLAUDE.md                # AI/ML project context
│   │   ├── rules/
│   │   │   └── ai-ml.md
│   │   ├── agents/
│   │   │   └── ai-ml/AGENT.md
│   │   ├── skills/
│   │   │   └── model/SKILL.md
│   │   ├── settings.json
│   │   └── mcp.json                 # Vector DB, experiment tracking
│   │
│   └── generic/
│       ├── CLAUDE.md                # Generic project context
│       └── settings.json
│
├── specs/                           # OpenSpec specifications
├── changes/                         # OpenSpec active changes
└── scripts/
    └── ralph.sh                     # Ralph Loop runner
```

### 4.2 After Installation — What Lives Where

**Global (`~/.claude/`)** — Installed once, always available:
```
~/.claude/
├── CLAUDE.md                        # Marvin's brain
├── settings.json                    # Global permissions, hooks
├── registry/
│   ├── agents.md                    # Agent registry
│   └── skills.md                    # Skills registry
├── templates/                       # For /new-agent, /new-skill, /new-rule
├── agents/
│   ├── researcher/AGENT.md
│   ├── coder/AGENT.md
│   └── verifier/AGENT.md
├── skills/
│   ├── init/SKILL.md                # /init
│   ├── new-agent/SKILL.md           # /new-agent
│   ├── new-skill/SKILL.md           # /new-skill
│   ├── new-rule/SKILL.md            # /new-rule
│   ├── research/SKILL.md            # /research
│   ├── review/SKILL.md              # /review
│   ├── spec/SKILL.md                # /spec
│   ├── ralph/SKILL.md               # /ralph
│   └── meta-prompt/SKILL.md         # /meta-prompt
├── rules/
│   ├── coding-standards.md
│   └── security.md
├── hooks/
│   ├── validate-python.sh
│   ├── block-secrets.sh
│   └── notify.sh
└── agent-memory/                    # Grows over time
```

**Per-Project (`.claude/`)** — Created by `/init`, committed to git:
```
~/Projects/my-data-pipeline/
├── .claude/
│   ├── CLAUDE.md                    # "This is a data pipeline project..."
│   ├── rules/
│   │   └── data-engineering.md
│   ├── agents/
│   │   └── data-eng/AGENT.md
│   ├── skills/
│   │   ├── pipeline/SKILL.md
│   │   ├── sql/SKILL.md
│   │   └── dbt/SKILL.md
│   ├── registry/
│   │   ├── agents.md
│   │   └── skills.md
│   └── settings.json
├── .mcp.json                        # Postgres, dbt, etc.
├── specs/                           # OpenSpec
└── ... (your project files)
```

---

## 5. Core Configuration Files

### 5.1 CLAUDE.md — Marvin's Brain

This is the orchestrator. It loads at every session start.
**Agents and skills are NOT hardcoded** — they're imported from registry files
that get auto-updated when you use `/new-agent` or `/new-skill`.

```markdown
# MARVIN — Data Engineering & AI Assistant

## Identity
You are Marvin, an AI assistant specialized in Data Engineering and AI/ML.
You think deeply before acting, plan before executing, and delegate to
specialized agents when tasks require focused expertise.

## How You Work

### Thinking (Extended Thinking)
- Always use extended thinking for complex requests
- Break down problems before acting
- Consider multiple approaches, pick the best

### Planning (SDD/OpenSpec)
For non-trivial tasks:
1. Create a proposal in changes/proposal.md
2. Define specs with GIVEN/WHEN/THEN in changes/specs/
3. Break into atomic tasks in changes/tasks.md
4. Execute task by task
5. Archive into specs/ when done

### Delegating (Subagents)
Read the agent registry to know who's available, then route:
@.claude/registry/agents.md

### When to Delegate vs. Do Directly
- Simple questions → answer directly
- Single-file edits → do directly
- Research tasks → researcher agent
- Multi-file changes → coder agent
- Domain-specific work → route to the matching domain agent
- Quality gates → verifier agent

## Domain Knowledge
@.claude/rules/data-engineering.md
@.claude/rules/ai-ml.md
@.claude/rules/coding-standards.md

## Available Skills
@.claude/registry/skills.md

## Self-Extension
Marvin can extend himself! Use these meta-skills to grow:
- /new-agent — Create a new specialized agent (scaffolds AGENT.md + updates registry)
- /new-skill — Create a new skill/slash command (scaffolds SKILL.md + updates registry)
- /new-rule — Create a new domain knowledge rule (scaffolds rule + imports in CLAUDE.md)

## Memory
When you learn something important about this project:
- Architecture decisions → save to memory
- Common patterns → save to memory
- User preferences → save to memory
```

### 5.2 registry/agents.md — Dynamic Agent Registry

This file is **auto-updated** by `/new-agent`. CLAUDE.md imports it via `@`.

```markdown
# Agent Registry

Available agents and when to use them:

| Agent | Domain | Use When |
|-------|--------|----------|
| **data-eng** | Data Engineering | Pipelines, SQL, data modeling, orchestration, dbt |
| **ai-ml** | AI/ML | Model training, prompts, RAG, evaluation, MLOps |
| **researcher** | Research | Web search, documentation, state-of-the-art, comparisons |
| **coder** | Implementation | Code, tests, refactoring, debugging |
| **verifier** | Quality | Test execution, spec compliance, security checks |
```

### 5.3 registry/skills.md — Dynamic Skills Registry

This file is **auto-updated** by `/new-skill`. CLAUDE.md imports it via `@`.

```markdown
# Skills Registry

Available slash commands:

| Skill | Purpose |
|-------|---------|
| /new-agent | Scaffold a new specialized agent |
| /new-skill | Scaffold a new skill/slash command |
| /new-rule | Scaffold a new domain knowledge rule |
| /pipeline | Design and implement data pipelines |
| /sql | SQL optimization and generation |
| /dbt | dbt model generation and testing |
| /model | ML model training workflows |
| /research | Deep research with web + Exa |
| /review | Code review with focus on quality |
| /spec | OpenSpec SDD workflow |
| /ralph | Ralph Loop for long-running tasks |
```

### 5.4 templates/ — Scaffolding Templates

#### AGENT.template.md
```yaml
---
name: {{NAME}}
description: >
  {{DESCRIPTION}}
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
memory: project
permissionMode: acceptEdits
---

# {{DISPLAY_NAME}} Agent

You are a specialist in {{DOMAIN}}.

## Core Competencies
- {{COMPETENCY_1}}
- {{COMPETENCY_2}}
- {{COMPETENCY_3}}

## How You Work
1. Understand the requirements fully before acting
2. Design the approach, then implement
3. Test your work
4. Document decisions and assumptions

## Conventions
- Follow existing project patterns
- Write clean, tested code
- Keep changes minimal and focused
```

#### SKILL.template.md
```yaml
---
name: {{NAME}}
description: {{DESCRIPTION}}
disable-model-invocation: true
argument-hint: "[{{ARGUMENT_HINT}}]"
---

# {{DISPLAY_NAME}} Skill

$ARGUMENTS

## Process
1. **Understand** — What is being asked?
2. **Plan** — What's the best approach?
3. **Execute** — Do the work step by step
4. **Verify** — Check the results
5. **Document** — Record what was done

## Notes
- Delegate to a subagent if the task is complex
- Follow project conventions
- Write to appropriate output location
```

#### RULE.template.md
```markdown
# {{DOMAIN}} Rules

## Conventions
- {{CONVENTION_1}}
- {{CONVENTION_2}}

## Patterns
- {{PATTERN_1}}
- {{PATTERN_2}}

## Anti-patterns (avoid)
- {{ANTIPATTERN_1}}
```

### 5.5 settings.json — Permissions & Hooks

```json
{
  "permissions": {
    "allow": [
      "Bash(python *)",
      "Bash(pip *)",
      "Bash(pytest *)",
      "Bash(git status)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(dbt *)",
      "Bash(airflow *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force *)",
      "Bash(git reset --hard *)",
      "Bash(curl * | bash)",
      "Read(.env)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "./.claude/hooks/validate-python.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "./.claude/hooks/block-secrets.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "./.claude/hooks/notify.sh"
          }
        ]
      }
    ]
  }
}
```

### 5.6 .mcp.json — External Tool Integrations

```json
{
  "mcpServers": {
    "exa": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic-ai/exa-mcp-server"],
      "env": {
        "EXA_API_KEY": "${EXA_API_KEY}"
      }
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic-ai/context7-mcp-server"]
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL:-postgresql://localhost/dev}"
      }
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "notion": {
      "type": "http",
      "url": "https://mcp.notion.com/mcp"
    },
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "${PWD}"
      ]
    }
  }
}
```

---

## 6. Subagents (AGENT.md Files)

### 6.1 Data Engineering Agent

```yaml
# .claude/agents/data-eng/AGENT.md
---
name: data-eng
description: >
  Data Engineering specialist. Use for: pipeline design (ETL/ELT),
  data modeling (dimensional, Data Vault, OBT), SQL optimization,
  orchestration (Airflow, Prefect, dbt), data quality, schema design.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
memory: project
permissionMode: acceptEdits
---

# Data Engineering Agent

You are a senior Data Engineer. You design and implement robust data
pipelines, optimize SQL, and build reliable data infrastructure.

## Core Competencies
- Pipeline design: ETL/ELT patterns, incremental loads, CDC
- Data modeling: Star schema, Snowflake schema, Data Vault, OBT
- SQL: Query optimization, window functions, CTEs, materialized views
- Orchestration: Airflow DAGs, Prefect flows, dbt models
- Data quality: Great Expectations, Soda, dbt tests
- Databases: PostgreSQL, BigQuery, Snowflake, DuckDB, Spark

## How You Work
1. Understand the data requirements and sources
2. Design the data model first (schema, relationships, grain)
3. Implement incrementally with tests at each step
4. Always include data quality checks
5. Document assumptions and decisions

## Conventions
- SQL: lowercase keywords, snake_case naming
- Python: Black formatting, type hints
- dbt: one model per file, ref() for dependencies
- Always add tests for new models/pipelines
```

### 6.2 AI/ML Agent

```yaml
# .claude/agents/ai-ml/AGENT.md
---
name: ai-ml
description: >
  AI/ML specialist. Use for: model training pipelines, prompt engineering,
  RAG architecture, evaluation frameworks, MLOps, fine-tuning strategies,
  LLM application design.
tools: Read, Edit, Write, Bash, Grep, Glob
model: opus
memory: project
permissionMode: acceptEdits
---

# AI/ML Agent

You are a senior AI/ML Engineer specializing in LLM applications,
model training, and production ML systems.

## Core Competencies
- LLM applications: Prompt engineering, RAG, fine-tuning, agents
- Model training: PyTorch, Hugging Face, scikit-learn
- Evaluation: Benchmarks, A/B testing, LLM-as-Judge
- MLOps: Model versioning, experiment tracking, deployment
- Data: Feature engineering, embeddings, vector databases

## Prompting Expertise
- Chain-of-Thought (CoT): step-by-step reasoning
- Few-Shot: examples in context for pattern matching
- Zero-Shot: clear instructions when training suffices
- Meta Prompting: generate prompts dynamically
- Tree of Thoughts: explore multiple solution branches
- ReAct: reason → act → observe loops

## How You Work
1. Understand the problem and success metrics
2. Design the approach (architecture, model selection)
3. Implement with experiment tracking
4. Evaluate rigorously (don't trust vibes)
5. Document results and decisions
```

### 6.3 Research Agent

```yaml
# .claude/agents/researcher/AGENT.md
---
name: researcher
description: >
  Research specialist. Use for: literature search, technology comparisons,
  best practices discovery, documentation analysis, state-of-the-art
  tracking. Has access to web search and Exa.
tools: Read, Write, Grep, Glob, Bash, WebSearch, WebFetch
model: sonnet
memory: project
---

# Research Agent

You are a thorough researcher who finds, synthesizes, and delivers
actionable insights from documentation, papers, and the web.

## How You Work
1. Understand the research question precisely
2. Search broadly first (web search, Exa), then narrow
3. Cross-reference multiple sources
4. Synthesize findings into structured output
5. Always cite sources with URLs
6. Distinguish facts from opinions

## Output Format
Always write research results to a file with:
- Executive summary (3-5 bullets)
- Detailed findings by topic
- Comparison tables when relevant
- Source citations with URLs
- Recommendations with trade-offs

## Available Tools
- WebSearch: broad web search
- WebFetch: fetch and analyze specific URLs
- Exa MCP: semantic search for high-quality content
- Context7 MCP: up-to-date library documentation
```

### 6.4 Code Agent

```yaml
# .claude/agents/coder/AGENT.md
---
name: coder
description: >
  Code implementation specialist. Use for: implementing plans,
  writing tests, refactoring, debugging, code review fixes.
  Fast iteration with Sonnet.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
memory: project
permissionMode: acceptEdits
---

# Code Agent

You are a senior software engineer focused on clean, tested,
production-ready implementation.

## How You Work
1. Read and understand existing code before changing it
2. Implement incrementally — small, tested changes
3. Write tests alongside implementation
4. Run tests after every significant change
5. Keep changes minimal — don't over-engineer

## Principles
- Prefer editing existing files over creating new ones
- Follow existing patterns in the codebase
- No dead code, no commented-out blocks
- Tests are not optional
```

### 6.5 Verification Agent

```yaml
# .claude/agents/verifier/AGENT.md
---
name: verifier
description: >
  Quality verification specialist. Use AFTER other agents complete work.
  Runs tests, checks quality, validates against specs. Fast with Haiku.
tools: Read, Bash, Grep, Glob
model: haiku
---

# Verification Agent

You verify that work is complete and correct. You are the quality gate.

## Checklist
1. Run the FULL test suite — `pytest` or equivalent
2. Check for linting errors
3. Verify specs compliance (if specs/ exist)
4. Check for security issues (secrets, injection, etc.)
5. Validate that the original requirements are met

## Rules
- You MUST run tests before marking anything as passed
- Report specific failures with file:line references
- If tests fail, report exactly what failed and why
- Never approve work with failing tests
```

---

## 7. Skills (Slash Commands)

### 7.1 Meta-Skills (Self-Extension)

These are the skills that make Marvin **self-extensible**. They scaffold new
components and auto-update the registries so CLAUDE.md immediately knows about them.

#### /new-agent — Scaffold a New Agent

```yaml
# .claude/skills/new-agent/SKILL.md
---
name: new-agent
description: Create a new specialized subagent for Marvin
disable-model-invocation: true
argument-hint: "[agent-name] [domain description]"
---

# Create New Agent

Create a new agent: $ARGUMENTS

## Steps

1. **Parse arguments** — Extract agent name and domain from $ARGUMENTS
   - First word = agent name (kebab-case, e.g. "devops", "analytics")
   - Remaining words = domain description

2. **Read template** — Read `.claude/templates/AGENT.template.md`

3. **Scaffold AGENT.md** — Create `.claude/agents/<name>/AGENT.md`:
   - Replace {{NAME}} with the agent name
   - Replace {{DISPLAY_NAME}} with a human-friendly version
   - Replace {{DOMAIN}} with the domain description
   - Replace {{DESCRIPTION}} with a detailed description based on the domain
   - Fill in {{COMPETENCY_1..3}} based on the domain
   - Choose appropriate model (haiku for simple, sonnet for most, opus for reasoning)
   - Choose appropriate tools based on domain

4. **Update registry** — Append a new row to `.claude/registry/agents.md`:
   ```
   | **<name>** | <domain> | <when to use> |
   ```

5. **Create memory dir** — Create `.claude/agent-memory/<name>/` directory

6. **Confirm** — Show what was created and how to use the new agent

## Example
```
/new-agent devops infrastructure, CI/CD, Docker, Kubernetes, deployment
```
Creates:
- `.claude/agents/devops/AGENT.md` — DevOps specialist agent
- Updated `.claude/registry/agents.md` — Marvin now knows to route infra tasks here
- `.claude/agent-memory/devops/` — Ready for persistent learning
```

#### /new-skill — Scaffold a New Skill

```yaml
# .claude/skills/new-skill/SKILL.md
---
name: new-skill
description: Create a new skill (slash command) for Marvin
disable-model-invocation: true
argument-hint: "[skill-name] [description]"
---

# Create New Skill

Create a new skill: $ARGUMENTS

## Steps

1. **Parse arguments** — Extract skill name and description from $ARGUMENTS
   - First word = skill name (kebab-case)
   - Remaining words = what the skill does

2. **Read template** — Read `.claude/templates/SKILL.template.md`

3. **Scaffold SKILL.md** — Create `.claude/skills/<name>/SKILL.md`:
   - Replace {{NAME}} with the skill name
   - Replace {{DISPLAY_NAME}} with a human-friendly version
   - Replace {{DESCRIPTION}} with a clear description
   - Replace {{ARGUMENT_HINT}} with expected arguments
   - Design the process steps based on the skill's purpose
   - If the skill is domain-specific, reference the appropriate agent

4. **Update registry** — Append a new row to `.claude/registry/skills.md`:
   ```
   | /<name> | <purpose> |
   ```

5. **Confirm** — Show what was created and how to invoke it

## Example
```
/new-skill airflow create and manage Airflow DAGs for data orchestration
```
Creates:
- `.claude/skills/airflow/SKILL.md` — Airflow DAG skill
- Updated `.claude/registry/skills.md` — `/airflow` now available
```

#### /new-rule — Scaffold a New Rule

```yaml
# .claude/skills/new-rule/SKILL.md
---
name: new-rule
description: Create a new domain knowledge rule for Marvin
disable-model-invocation: true
argument-hint: "[domain-name]"
---

# Create New Rule

Create a new rule: $ARGUMENTS

## Steps

1. **Parse arguments** — Extract domain name from $ARGUMENTS

2. **Read template** — Read `.claude/templates/RULE.template.md`

3. **Research** — Use the researcher agent to find best practices and
   conventions for this domain

4. **Scaffold rule** — Create `.claude/rules/<domain>.md`:
   - Fill in conventions based on research
   - Add common patterns
   - Add anti-patterns to avoid

5. **Update CLAUDE.md** — Add a new `@.claude/rules/<domain>.md` import
   line under the "## Domain Knowledge" section

6. **Confirm** — Show what was created

## Example
```
/new-rule kubernetes
```
Creates:
- `.claude/rules/kubernetes.md` — K8s conventions, patterns, anti-patterns
- Updated CLAUDE.md — Now imports the new rule automatically
```

---

### 7.2 /pipeline — Data Pipeline Design

```yaml
# .claude/skills/pipeline/SKILL.md
---
name: pipeline
description: Design and implement a data pipeline
disable-model-invocation: true
argument-hint: "[source] [destination] [description]"
---

# Data Pipeline Design Skill

Design a data pipeline for: $ARGUMENTS

## Process
1. **Understand** — What data, from where, to where, how often?
2. **Design** — Draw the pipeline architecture (source → transform → load)
3. **Model** — Define the target data model
4. **Implement** — Write the pipeline code with:
   - Idempotent operations
   - Incremental loads where possible
   - Error handling and retries
   - Data quality checks at each stage
5. **Test** — Unit tests + integration tests
6. **Document** — Pipeline spec in specs/

Use the data-eng agent for implementation if the pipeline is complex.
```

### 7.3 /sql — SQL Optimization

```yaml
# .claude/skills/sql/SKILL.md
---
name: sql
description: Optimize, generate, or debug SQL queries
disable-model-invocation: true
argument-hint: "[query or description]"
---

# SQL Skill

$ARGUMENTS

## When optimizing:
1. Read the original query
2. Analyze the execution plan (EXPLAIN ANALYZE)
3. Identify bottlenecks (sequential scans, nested loops, missing indexes)
4. Rewrite with optimizations (CTEs, window functions, proper JOINs)
5. Compare before/after performance

## When generating:
1. Understand the data model
2. Write clear, readable SQL (lowercase keywords, snake_case)
3. Use CTEs for complex logic
4. Add comments for non-obvious logic
5. Include sample output
```

### 7.4 /research — Deep Research

```yaml
# .claude/skills/research/SKILL.md
---
name: research
description: Deep research on any topic using web + Exa + Context7
disable-model-invocation: true
argument-hint: "[topic]"
---

# Research Skill

Research topic: $ARGUMENTS

Delegate this to the **researcher** subagent with these instructions:

1. Search broadly using WebSearch and Exa
2. Find at least 5 quality sources
3. Cross-reference findings
4. Write a structured report to `projects/research/<topic>.md`
5. Include:
   - Executive summary
   - Key findings
   - Comparison tables
   - Source citations
   - Actionable recommendations
```

### 7.5 /spec — OpenSpec SDD Workflow

```yaml
# .claude/skills/spec/SKILL.md
---
name: spec
description: Start an OpenSpec Spec-Driven Development workflow
disable-model-invocation: true
argument-hint: "[feature or change description]"
---

# Spec-Driven Development Skill

Feature: $ARGUMENTS

## Phase 1: Proposal
Create these files:
- `changes/proposal.md` — What and why
- `changes/design.md` — Technical decisions and trade-offs
- `changes/tasks.md` — Atomic implementation checklist

## Phase 2: Definition
For each requirement, write specs in `changes/specs/`:
```
GIVEN [context]
WHEN [action]
THEN [expected result]
```

## Phase 3: Apply
Implement each task from tasks.md:
- [ ] Check off tasks as completed
- [ ] Run verifier agent after each task
- [ ] Keep changes atomic and tested

## Phase 4: Archive
- Merge `changes/specs/` into `specs/`
- Clean up `changes/`
- Update AGENTS.md if architecture changed
```

### 7.6 /ralph — Ralph Loop for Long Tasks

```yaml
# .claude/skills/ralph/SKILL.md
---
name: ralph
description: Start a Ralph Loop for a long-running autonomous task
disable-model-invocation: true
argument-hint: "[task description]"
---

# Ralph Loop Skill

Task: $ARGUMENTS

## Setup
1. Write the task specification to `prompts/PROMPT.md`:
   - Clear objective with measurable completion criteria
   - Current state and progress tracking
   - File paths and context needed
   - What "done" looks like

2. Start the loop:
```bash
while :; do
  claude -p "$(cat prompts/PROMPT.md)" \
    --continue \
    --allowedTools "Read,Edit,Write,Bash,Grep,Glob" \
    --max-turns 30

  # Check if COMPLETE signal exists
  if [ -f ".ralph-complete" ]; then
    rm .ralph-complete
    echo "Task completed!"
    break
  fi
done
```

## Progress Tracking
- Progress lives in files and git, NOT in context
- Each iteration starts fresh but picks up from filesystem state
- Use `changes/tasks.md` as a checklist
- Create `.ralph-complete` file when all tasks verified done

## Signal System
- Write `WARN` to `.ralph-status` when context is getting large
- Write `ROTATE` to trigger context refresh
- Write `COMPLETE` to `.ralph-complete` when done
```

### 7.7 /dbt — dbt Model Generation

```yaml
# .claude/skills/dbt/SKILL.md
---
name: dbt
description: Generate dbt models, tests, and documentation
disable-model-invocation: true
argument-hint: "[model name or description]"
---

# dbt Skill

$ARGUMENTS

## Process
1. Understand the source data and business logic
2. Create staging model (stg_*) from source
3. Create intermediate models if needed (int_*)
4. Create final mart model (fct_* or dim_*)
5. Add schema.yml with:
   - Column descriptions
   - Tests (unique, not_null, accepted_values, relationships)
6. Add sources.yml if new source
7. Run `dbt build --select +model_name` to validate

## Conventions
- One model per file
- Use ref() for all model references
- Use source() for raw data references
- Incremental models for large tables
- Always add at least unique + not_null tests on primary keys
```

---

## 8. Hooks (Deterministic Automation)

### 7.1 validate-python.sh — Auto-format Python

```bash
#!/bin/bash
# .claude/hooks/validate-python.sh
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.py ]]; then
  if command -v ruff &> /dev/null; then
    ruff format "$FILE_PATH" 2>/dev/null
    ruff check --fix "$FILE_PATH" 2>/dev/null
  elif command -v black &> /dev/null; then
    black --quiet "$FILE_PATH" 2>/dev/null
  fi
fi
exit 0
```

### 7.2 validate-sql.sh — Lint SQL

```bash
#!/bin/bash
# .claude/hooks/validate-sql.sh
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.sql ]]; then
  if command -v sqlfluff &> /dev/null; then
    sqlfluff fix --force "$FILE_PATH" 2>/dev/null
  fi
fi
exit 0
```

### 7.3 block-secrets.sh — Prevent Secret Exposure

```bash
#!/bin/bash
# .claude/hooks/block-secrets.sh
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block commands that might expose secrets
PATTERNS=(
  "cat.*\.env"
  "echo.*API_KEY"
  "echo.*SECRET"
  "echo.*PASSWORD"
  "curl.*token="
)

for pattern in "${PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "BLOCKED: Command may expose secrets" >&2
    exit 2
  fi
done
exit 0
```

### 7.4 notify.sh — Desktop Notification

```bash
#!/bin/bash
# .claude/hooks/notify.sh
MESSAGE=$(cat | jq -r '.message // "Claude Code needs attention"')

if command -v notify-send &> /dev/null; then
  notify-send "Marvin" "$MESSAGE" --icon=dialog-information
elif command -v osascript &> /dev/null; then
  osascript -e "display notification \"$MESSAGE\" with title \"Marvin\""
fi
exit 0
```

---

## 9. Techniques Integration

### 8.1 How Techniques Map to Claude Code Features

| Technique                  | Claude Code Feature                                  |
|---------------------------|------------------------------------------------------|
| **Chain-of-Thought**       | Extended Thinking (built-in with Opus)               |
| **Meta Prompting**         | Skills that generate prompts for subagents           |
| **Few-Shot**               | Examples in CLAUDE.md, rules/, and SKILL.md files    |
| **Zero-Shot**              | Direct instructions in AGENT.md                      |
| **ReAct**                  | The agent loop itself (reason → tool → observe)      |
| **Reflexion**              | Agent memory (learns from past sessions)             |
| **SDD/OpenSpec**           | /spec skill + specs/ directory + changes/ workflow   |
| **Ralph Loop**             | /ralph skill + `claude -p --continue` in bash loop   |
| **Evaluator-Optimizer**    | Verifier agent + PostToolUse hooks                   |
| **Orchestrator-Workers**   | CLAUDE.md (orchestrator) + AGENT.md (workers)        |
| **Parallelization**        | Multiple Task tool calls in single response          |
| **Routing**                | Claude reads agent descriptions → picks the best     |
| **Tree of Thoughts**       | Extended thinking explores branches internally       |
| **Plan-and-Execute**       | `--permission-mode plan` → then execute              |

### 8.2 Meta Prompting in Practice

Instead of hand-crafting every prompt, Marvin uses meta prompting through skills:

```yaml
# .claude/skills/meta-prompt/SKILL.md
---
name: meta-prompt
description: Generate an optimized prompt for a specific task
disable-model-invocation: true
argument-hint: "[task description]"
---

# Meta Prompt Generator

Task: $ARGUMENTS

Generate an optimized prompt following these principles:

1. **Role**: Define who the AI should be
2. **Context**: Provide relevant background
3. **Task**: Clear, specific instructions
4. **Format**: Expected output structure
5. **Examples**: 2-3 few-shot examples if helpful
6. **Constraints**: What to avoid

Use Chain-of-Thought to reason about the best prompt structure.
Then output the final prompt wrapped in a code block.

Evaluate the prompt against these criteria:
- Clarity (is it unambiguous?)
- Completeness (does it cover edge cases?)
- Efficiency (minimal tokens for maximum effect?)
```

### 8.3 Ralph Loop in Practice

```bash
#!/bin/bash
# scripts/ralph.sh — Run Marvin in Ralph Loop mode

PROMPT_FILE="${1:-prompts/PROMPT.md}"
MAX_ITERATIONS="${2:-10}"
iteration=0

echo "Starting Ralph Loop with: $PROMPT_FILE"

while [ $iteration -lt $MAX_ITERATIONS ]; do
  iteration=$((iteration + 1))
  echo "--- Iteration $iteration ---"

  claude -p "$(cat "$PROMPT_FILE")" \
    --continue \
    --allowedTools "Read,Edit,Write,Bash(python *),Bash(pytest *),Bash(git *),Grep,Glob" \
    --max-turns 30 \
    --output-format json | jq -r '.result' > ".ralph-output-$iteration.md"

  # Check completion
  if [ -f ".ralph-complete" ]; then
    rm -f .ralph-complete
    echo "Task completed after $iteration iterations!"
    exit 0
  fi

  # Brief pause between iterations
  sleep 2
done

echo "Reached max iterations ($MAX_ITERATIONS). Check progress in files."
```

---

## 10. Rules (Domain Knowledge)

### 9.1 data-engineering.md

```markdown
# .claude/rules/data-engineering.md

## Data Engineering Rules

### SQL Conventions
- Lowercase keywords (select, from, where, join)
- snake_case for all identifiers
- CTEs over subqueries for readability
- Always qualify column names in JOINs
- Use explicit JOIN types (inner join, left join — never implicit)

### Pipeline Patterns
- Prefer ELT over ETL (transform in the warehouse)
- Idempotent operations always (use MERGE/upsert)
- Incremental loads over full refreshes when possible
- Partition by date for large tables
- Add created_at and updated_at to all tables

### dbt Conventions
- Staging models: stg_{source}_{table}
- Intermediate: int_{description}
- Facts: fct_{event}
- Dimensions: dim_{entity}
- One model per file, one test per model minimum

### Data Quality
- Not null on primary keys
- Unique constraints on business keys
- Freshness checks on source data
- Row count monitoring (alert on >20% deviation)
```

### 9.2 ai-ml.md

```markdown
# .claude/rules/ai-ml.md

## AI/ML Rules

### Prompt Engineering
- Start with the simplest prompt that could work
- Add complexity only when evaluation shows it's needed
- Always test prompts against edge cases
- Version control all prompts
- Use structured output (JSON) for machine-consumed results

### Model Development
- Define success metrics BEFORE training
- Always have a baseline to compare against
- Log all experiments (parameters, metrics, artifacts)
- Evaluate on held-out test sets, never training data
- Prefer smaller models that meet requirements over larger ones

### RAG Systems
- Chunk size matters — experiment with 256-1024 tokens
- Overlap chunks by 10-20%
- Embed with the same model used for queries
- Evaluate retrieval quality separately from generation
- Always include source attribution

### LLM Applications
- Use Claude Haiku for simple tasks, Sonnet for complex, Opus for reasoning
- Cache prompts when possible (prompt caching)
- Set temperature=0 for deterministic outputs
- Use structured outputs (tool_use or JSON mode) over free text
- Implement retry with exponential backoff
```

---

## 11. Implementation Phases

### Phase 1: Global Layer — Marvin's Brain (Week 1)
- [x] Create `global/` directory structure in marvin repo
- [x] Write `global/CLAUDE.md` (Marvin's identity + @imports)
- [x] Create `global/registry/` (agents.md + skills.md)
- [x] Create `global/templates/` (AGENT, SKILL, RULE templates)
- [x] Write `global/rules/` (coding-standards.md, security.md)
- [x] Configure `global/settings.json` (permissions, hooks)
- [x] Write `install.sh`
- [ ] Run `install.sh` and test: `claude` shows Marvin in any directory

### Phase 2: Universal Agents (Week 2)
- [x] Create `global/agents/researcher/AGENT.md`
- [x] Create `global/agents/coder/AGENT.md`
- [x] Create `global/agents/verifier/AGENT.md`
- [ ] Reinstall and test: Marvin routes to each agent correctly
- [ ] Test: Agent memory persists across sessions

### Phase 3: Universal Skills + Self-Extension (Week 3)
- [x] Create `/init` skill (project scaffolding)
- [x] Create `/new-agent` skill (scaffold + auto-register)
- [x] Create `/new-skill` skill (scaffold + auto-register)
- [x] Create `/new-rule` skill (scaffold + auto-import)
- [x] Create `/research`, `/review`, `/spec`, `/ralph`, `/meta-prompt` skills
- [ ] Test: `/init data-pipeline` scaffolds a proper project
- [ ] Test: `/new-agent devops` creates agent + updates registry

### Phase 4: Project Templates (Week 4)
- [x] Create `project-templates/data-pipeline/` (CLAUDE.md, rules, agents, skills, mcp)
- [x] Create `project-templates/ai-ml/` (CLAUDE.md, rules, agents, skills, mcp)
- [x] Create `project-templates/generic/` (minimal CLAUDE.md)
- [ ] Test: `/init data-pipeline` in a real project works end-to-end
- [ ] Test: `/init ai-ml` in a real project works end-to-end

### Phase 5: Hooks & Automation (Week 5)
- [x] Create hooks (Python formatter, secret blocker, notify) — built in Phase 1
- [x] Create SQL linter hook (`validate-sql.sh`)
- [x] Create `/ralph` runner script (`scripts/ralph.sh`)
- [x] Create `/meta-prompt` skill — built in Phase 3
- [ ] Test: Hooks fire on every write in any project
- [ ] Test: Ralph Loop completes a multi-step task

### Phase 6: Real-World Testing (Week 6)
- [ ] Use Marvin on an actual data pipeline project
- [ ] Use Marvin on an actual AI/ML project
- [ ] Tune CLAUDE.md based on real usage
- [ ] Fix routing issues and agent gaps
- [ ] Document everything in README.md

### Phase 7: Polish & Expand (Ongoing)
- [ ] Expand agent memory with learned patterns
- [ ] Use `/new-agent` and `/new-skill` to grow organically
- [ ] Add project templates for new domains (devops, analytics, etc.)
- [ ] Add MCP servers as needed per project
- [ ] Share with team — they just run `install.sh`

---

## 12. How to Use Marvin

### First-Time Setup (Once)
```bash
# Clone the Marvin repo
git clone <marvin-repo> ~/Projects/marvin

# Install Marvin globally
cd ~/Projects/marvin
./install.sh
# → Marvin is now in ~/.claude/
# → Available in EVERY Claude Code session
```

### Starting a New Project
```bash
# Go to your project (new or existing)
cd ~/Projects/my-data-pipeline
claude

# Marvin is already here (global layer)!
# Initialize project-specific config:
> /init data-pipeline
# → Creates .claude/ with data engineering context
# → Creates .mcp.json with Postgres
# → Copies data-eng agent and pipeline/sql/dbt skills
# → Ready to work!
```

### Daily Use (Any Project)
```bash
cd ~/Projects/my-data-pipeline
claude

# Ask anything — Marvin has global + project knowledge
> Help me design a pipeline for user events from Kafka to BigQuery

# Use project-specific skills
> /pipeline kafka user_events bigquery
> /sql optimize this query: SELECT ...

# Use universal skills (available everywhere)
> /research best practices for real-time feature stores 2026
> /spec add incremental loading to the user pipeline

# Marvin delegates to subagents automatically
```

### Switching Projects
```bash
# Just cd to another project — Marvin adapts
cd ~/Projects/my-ml-model
claude

# Same Marvin, different project context
> /model train a sentiment classifier using BERT
# → Uses ai-ml agent + project-specific rules
```

### Self-Extension Mode (Growing Marvin)
```bash
# These work globally OR per-project:

# Need a new domain? Create an agent:
> /new-agent devops infrastructure, CI/CD, Docker, Kubernetes
# → Creates agent + updates registry
# → Marvin immediately routes infra tasks to it

# Need a new workflow? Create a skill:
> /new-skill terraform create and manage Terraform IaC
# → Creates skill + updates registry
# → /terraform is now available

# Need domain knowledge?
> /new-rule kubernetes
# → Researches best practices, creates rule, updates imports
```

### Headless Mode (CI/CD, Automation)
```bash
# One-shot task (from any project directory)
claude -p "Review all SQL files for optimization opportunities" \
  --output-format json

# Continue a session
claude -p "Now implement the optimizations you found" --continue

# Ralph Loop for big tasks
~/Projects/marvin/scripts/ralph.sh prompts/PROMPT.md 10
```

### Plan Mode (Architecture Decisions)
```bash
claude --permission-mode plan

> Design the architecture for a real-time ML feature store
# Marvin plans without executing
# Approve → switch to execute
```

---

## 13. Key Design Principles

1. **Claude Code IS the framework.** Don't rebuild what's built-in.
2. **Two layers: global + project.** Marvin's brain is global; project context is local.
3. **Install once, use everywhere.** `install.sh` → Marvin in every `claude` session.
4. **`/init` bootstraps projects.** One command sets up project-specific config.
5. **CLAUDE.md is the brain.** Orchestrator identity + dynamic imports from registries.
6. **Registries enable self-extension.** Agents and skills are never hardcoded.
7. **Subagents for isolation.** Each agent has clean context and focused tools.
8. **Skills for reusability.** Common workflows become slash commands.
9. **Meta-skills for growth.** `/new-agent`, `/new-skill`, `/new-rule` extend Marvin.
10. **Hooks for guarantees.** Deterministic control over probabilistic behavior.
11. **Memory for learning.** Agents improve across sessions.
12. **MCP for integration.** Connect to any tool without custom code.
13. **Files are the API.** Agents communicate through the filesystem.
14. **Git is your safety net.** Especially for Ralph Loop — progress lives in commits.

---

## 14. References

| Resource | URL |
|----------|-----|
| Building Effective Agents (Anthropic) | anthropic.com/research/building-effective-agents |
| Multi-Agent Research System (Anthropic) | anthropic.com/engineering/multi-agent-research-system |
| Multi-Agent Systems Guide (Claude Blog) | claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them |
| Claude Code Hooks Guide | aiorg.dev/blog/claude-code-hooks |
| Claude Code Customization (alexop.dev) | alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents |
| Complete Claude Code Guide (Reddit V2) | reddit.com/r/ClaudeAI/comments/1qcwckg |
| Claude Code CLI Reference (Blake Crosley) | blakecrosley.com/en/guides/claude-code |
| OpenSpec (SDD) | github.com/Fission-AI/OpenSpec |
| Ralph Loop Agent (Vercel) | github.com/vercel-labs/ralph-loop-agent |
| Ralph Technique Deep Wiki | deepwiki.com/agrimsingh/ralph-wiggum-cursor |
| Meta Prompting Guide | prompthub.us/blog/a-complete-guide-to-meta-prompting |
| Agent Architectures 2026 | agnt.gg/articles/the-complete-guide-to-ai-agent-architectures-2026 |
| Agent SDK Overview | docs.claude.com/en/docs/agent-sdk/overview |
| Anthropic Skills Repository | github.com/anthropics/skills |
