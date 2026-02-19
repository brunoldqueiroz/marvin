---
name: init
description: "Bootstrap a .claude/ directory with CLAUDE.md, memory, registry, rules, and settings for a new project. Use when starting to use Marvin on an existing codebase."
disable-model-invocation: true
argument-hint: "[project-type: data-pipeline | ai-ml | generic]"
---

# Initialize Project for Marvin

Project type: $ARGUMENTS

## Steps

### 1. Detect Project Type

If `$ARGUMENTS` is empty or not specified, analyze the codebase to detect project type:
- Look for `dbt_project.yml`, `airflow/`, `dagster`, `prefect` → **data-pipeline**
- Look for `requirements.txt` with torch/tensorflow/transformers, `*.ipynb`, `experiments/` → **ai-ml**
- Otherwise → **generic**

If `$ARGUMENTS` is provided, use it directly.

### 2. Create `.claude/` Directory Structure

```
.claude/
├── CLAUDE.md              ← Project context
├── memory.md              ← Project memory (persistent across sessions)
├── rules/                 ← Domain rules for this project
├── registry/
│   ├── agents.md          ← Project-specific agent registry
│   └── skills.md          ← Project-specific skill registry
└── settings.json          ← Project permissions
```

### 3. Create Project Memory

Create `.claude/memory.md` using the project memory template (`~/.claude/templates/MEMORY.template.md`).

Pre-populate the **Tech Stack & Conventions** section with what was detected:
```markdown
## Tech Stack & Conventions

- [YYYY-MM-DD] Detected stack: <list of detected technologies>
```

### 4. Write Project CLAUDE.md

Based on detected/specified project type:

**For `data-pipeline` projects:**
```markdown
# Project Context

This is a data pipeline project.

## Tech Stack
- [Detect from files: Python version, dbt, Airflow/Prefect/Dagster, database engines, etc.]

## Architecture
- [Detect: Source systems, transformation layer, target warehouse]

## Conventions
- [Infer from existing code: naming, structure, patterns]

## Memory
@.claude/memory.md

## Project-Specific Agents
@.claude/registry/agents.md

## Project-Specific Skills
@.claude/registry/skills.md

## Domain Rules
@.claude/rules/data-engineering.md
```

**For `ai-ml` projects:**
```markdown
# Project Context

This is an AI/ML project.

## Tech Stack
- [Detect: PyTorch/TensorFlow, Hugging Face, scikit-learn, experiment tracking, etc.]

## Architecture
- [Detect: Model type, training pipeline, inference setup]

## Conventions
- [Infer from existing code]

## Memory
@.claude/memory.md

## Project-Specific Agents
@.claude/registry/agents.md

## Project-Specific Skills
@.claude/registry/skills.md

## Domain Rules
@.claude/rules/ai-ml.md
```

**For `generic` projects:**
```markdown
# Project Context

## Tech Stack
- [Detect from files: language, framework, build system]

## Architecture
- [Describe the project structure]

## Conventions
- [Infer from existing code]

## Memory
@.claude/memory.md

## Project-Specific Agents
@.claude/registry/agents.md

## Project-Specific Skills
@.claude/registry/skills.md
```

### 5. Write Project Registry Files

**`.claude/registry/agents.md`:**
```markdown
# Project Agent Registry

Project-specific agents (in addition to global agents):

| Agent | Domain | Use When |
|-------|--------|----------|
```

**`.claude/registry/skills.md`:**
```markdown
# Project Skills Registry

Project-specific skills (in addition to global skills):

| Skill | Purpose |
|-------|---------|
```

### 6. Write Project Settings

**`.claude/settings.json`:**
```json
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

Add project-relevant permissions based on type:
- **data-pipeline**: allow `dbt *`, `airflow *`, `psql *`
- **ai-ml**: allow `python *`, `jupyter *`, `tensorboard *`
- **generic**: minimal defaults

### 7. Copy Relevant Domain Rules

Based on project type, create domain rule files:
- **data-pipeline** → create `.claude/rules/data-engineering.md` with SQL conventions, pipeline patterns, dbt standards, data quality rules
- **ai-ml** → create `.claude/rules/ai-ml.md` with prompt engineering, model development, RAG, LLM application rules
- **generic** → no extra rules (global coding-standards and security are sufficient)

### 8. Create `.mcp.json` (if needed)

Based on project type, suggest MCP server configuration:
- **data-pipeline** → suggest Postgres/BigQuery/Snowflake based on detected stack
- **ai-ml** → suggest vector DB, experiment tracking
- **generic** → no project-specific MCPs needed

Only create `.mcp.json` if the project would benefit from it. Ask the user before adding database connections.

### 9. Update `.gitignore`

Add these lines if not already present:
```
.claude/settings.local.json
.claude/agent-memory/
```

### 10. Confirm

Show the user:
- What project type was detected/used
- What files were created
- What domain rules were applied
- What MCP servers were suggested
- Next steps for customization
