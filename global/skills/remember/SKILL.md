---
name: remember
description: Save something to Marvin's persistent memory
disable-model-invocation: true
argument-hint: "<what to remember>"
---

# Remember

Save information to persistent memory: `$ARGUMENTS`

## Process

### 1. Parse What to Save

Extract the key information from `$ARGUMENTS`. Identify:
- **What** is being remembered (the fact, preference, decision, or lesson)
- **Why** it matters (context, if provided)

### 2. Determine Scope

Choose where to save based on context:

- **Project memory** (`.claude/memory.md`) — if inside a project with `.claude/` directory AND the information is specific to this project (architecture decisions, tech stack choices, project-specific conventions)
- **Global memory** (`~/.claude/memory.md`) — if the information is about user preferences, cross-project patterns, or general lessons that apply everywhere

**Heuristic:** If in doubt, ask: "Would this be useful in a different project?" If yes → global. If no → project.

### 3. Classify Category

Place the entry under the correct section:

**Global memory sections:**
- **User Preferences** — language, style, tools, workflow preferences
- **Architecture Decisions** — cross-project architectural choices
- **Patterns & Conventions** — coding patterns, naming conventions, preferred approaches
- **Lessons Learned** — mistakes to avoid, insights, best practices discovered

**Project memory sections:**
- **Architecture Decisions** — project-specific design choices
- **Tech Stack & Conventions** — frameworks, versions, project standards
- **Patterns Discovered** — project-specific patterns and idioms
- **Lessons Learned** — project-specific gotchas and insights

### 4. Write to Memory File

Use the Edit tool to append the entry under the correct section.

**Format:**
```
- [YYYY-MM-DD] <concise description of what was learned>
```

**Rules:**
- One line per entry (keep it concise)
- Use today's date
- Don't duplicate existing entries — if a similar entry exists, update it instead
- If the memory file doesn't exist, create it using the appropriate template

### 5. Confirm

Tell the user:
- What was saved
- Where it was saved (global or project)
- Under which category
