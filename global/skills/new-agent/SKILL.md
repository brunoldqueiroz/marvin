---
name: new-agent
description: Create a new specialized subagent for Marvin
disable-model-invocation: true
argument-hint: "[agent-name] [domain description]"
---

# Create New Agent

Create a new agent: $ARGUMENTS

## Steps

### 1. Parse Arguments

Extract from `$ARGUMENTS`:
- **First word** = agent name (kebab-case, e.g. "devops", "analytics", "frontend")
- **Remaining words** = domain description (what this agent specializes in)

If no arguments provided, ask the user for:
- Agent name
- What domain/tasks this agent should handle

### 2. Determine Scope

Check where to create the agent:
- If inside a project with `.claude/` → create in `.claude/agents/<name>/` (project-level)
- If no project `.claude/` exists → create in `~/.claude/agents/<name>/` (global)

Tell the user which scope was chosen and why.

### 3. Read Template

Read the agent template from the templates directory:
- Check `~/.claude/templates/AGENT.template.md`
- If not found, use the built-in template structure below

### 4. Generate AGENT.md

Create `agents/<name>/AGENT.md` with these decisions:

**Model selection** (based on domain complexity):
- `haiku` — for fast, simple tasks (linting, formatting, validation, simple lookups)
- `sonnet` — for most agents (coding, research, analysis, general tasks)
- `opus` — for complex reasoning (architecture, AI/ML, system design)

**Tool selection** (based on domain needs):
- Code agents → `Read, Edit, Write, Bash, Grep, Glob`
- Research agents → `Read, Write, Grep, Glob, Bash, WebSearch, WebFetch`
- Review/validation agents → `Read, Bash, Grep, Glob` (no write access)
- Full agents → `Read, Edit, Write, Bash, Grep, Glob`

**Memory setting:**
- `project` — for project-specific agents (most common)
- `user` — for universal agents that learn across projects

**Permission mode:**
- `acceptEdits` — for agents that write code
- (omit) — for read-only agents

Fill in the template:
- `{{NAME}}` → agent name (kebab-case)
- `{{DISPLAY_NAME}}` → Human-friendly name (e.g. "DevOps" from "devops")
- `{{DOMAIN}}` → domain description from arguments
- `{{DESCRIPTION}}` → detailed description of what this agent does
- `{{COMPETENCY_1..3}}` → 3-5 core competencies based on the domain

Write a thorough "How You Work" section with domain-specific methodology.
Add a "Conventions" section with domain-relevant standards.

### 5. Update Registry

Determine which registry to update:
- Project-level agent → append to `.claude/registry/agents.md`
- Global agent → append to `~/.claude/registry/agents.md`

Append a new row to the agents table:
```
| **<name>** | <domain> | <when to use this agent> |
```

### 6. Create Memory Directory

Create the agent memory directory:
- Project-level → `.claude/agent-memory/<name>/`
- Global → `~/.claude/agent-memory/<name>/`

### 7. Confirm

Show the user:
- Path to the created AGENT.md
- Model and tools chosen (and why)
- The registry entry that was added
- How to use the new agent: "Marvin will now automatically route <domain> tasks to this agent"
- How to customize: "Edit the AGENT.md to refine the agent's behavior"

## Example

```
/new-agent devops infrastructure, CI/CD, Docker, Kubernetes, deployment
```

Creates:
- `.claude/agents/devops/AGENT.md` — DevOps specialist agent (sonnet, full tools)
- Updated `.claude/registry/agents.md` — new row for devops
- `.claude/agent-memory/devops/` — ready for persistent learning
