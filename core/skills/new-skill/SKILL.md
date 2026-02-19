---
name: new-skill
description: Create a new skill (slash command) for Marvin
disable-model-invocation: true
argument-hint: "[skill-name] [description of what the skill does]"
---

# Create New Skill

Create a new skill: $ARGUMENTS

## Steps

### 1. Parse Arguments

Extract from `$ARGUMENTS`:
- **First word** = skill name (kebab-case, e.g. "airflow", "docker", "deploy")
- **Remaining words** = what this skill does

If no arguments provided, ask the user for:
- Skill name (will become the `/command`)
- What the skill should do

### 2. Determine Scope

Check where to create the skill:
- If inside a project with `.claude/` → create in `.claude/skills/<name>/` (project-level)
- If no project `.claude/` exists → create in `~/.claude/skills/<name>/` (global)

Tell the user which scope was chosen.

### 3. Read Template

Read the skill template:
- Check `~/.claude/templates/SKILL.template.md`
- If not found, use the built-in template structure below

### 4. Generate SKILL.md

Create `skills/<name>/SKILL.md` with:

**Frontmatter:**
- `name` → skill name (kebab-case)
- `description` → clear one-line description
- `disable-model-invocation: true` — always set this so the skill content is injected as instructions
- `argument-hint` → describe expected arguments (e.g. "[source] [destination]")

**Body — design the process steps:**

Think about what this skill needs to do, then write clear step-by-step instructions:

1. **Understand** — What input does the skill need? Parse `$ARGUMENTS`.
2. **Plan** — What's the approach? Any decisions to make?
3. **Execute** — Step-by-step implementation instructions
4. **Verify** — How to validate the result?
5. **Document** — What should be recorded?

**Agent delegation:**
- If the skill involves complex code → instruct to delegate to the **python-expert** agent
- If the skill involves research → instruct to delegate to the **researcher** agent
- If the skill involves domain work → reference the appropriate domain agent
- Simple skills can execute directly without delegation

### 5. Update Registry

Determine which registry to update:
- Project-level skill → append to `.claude/registry/skills.md`
- Global skill → append to `~/.claude/registry/skills.md`

Append a new row to the skills table:
```
| /<name> | <what this skill does> |
```

### 6. Confirm

Show the user:
- Path to the created SKILL.md
- How to invoke: `/<name> [arguments]`
- The registry entry that was added
- How to customize: "Edit the SKILL.md to refine the workflow"

## Example

```
/new-skill airflow create and manage Airflow DAGs for data orchestration
```

Creates:
- `.claude/skills/airflow/SKILL.md` — Airflow DAG workflow
- Updated `.claude/registry/skills.md` — `/airflow` now available
