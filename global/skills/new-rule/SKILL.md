---
name: new-rule
description: Create a new domain knowledge rule for Marvin
disable-model-invocation: true
argument-hint: "[domain-name]"
---

# Create New Rule

Create a new domain knowledge rule: $ARGUMENTS

## Steps

### 1. Parse Arguments

Extract from `$ARGUMENTS`:
- **Domain name** = the knowledge domain (e.g. "kubernetes", "terraform", "react", "dbt")

If no arguments provided, ask the user what domain they want to add rules for.

### 2. Determine Scope

Check where to create the rule:
- If inside a project with `.claude/` → create in `.claude/rules/<domain>.md` (project-level)
- If no project `.claude/` exists → create in `~/.claude/rules/<domain>.md` (global)

Tell the user which scope was chosen.

### 3. Read Template

Read the rule template:
- Check `~/.claude/templates/RULE.template.md`
- If not found, use the built-in template structure

### 4. Research Best Practices

Before writing the rule, gather domain knowledge:
- Use the **researcher** agent to find current best practices for this domain
- Focus on: conventions, naming standards, common patterns, anti-patterns
- Prefer official documentation and widely-accepted community standards
- If web search is not available, use your built-in knowledge

### 5. Generate Rule File

Create `rules/<domain>.md` with these sections:

```markdown
# <Domain> Rules

## Conventions
- Naming conventions for this domain
- File/directory structure standards
- Configuration patterns

## Patterns (Do This)
- Recommended approaches
- Best practices with brief explanations
- Common patterns with examples

## Anti-patterns (Avoid This)
- Common mistakes to avoid
- Why each anti-pattern is problematic
- What to do instead

## Tools & Commands
- Key CLI commands for this domain
- Common flags and options
- Useful combinations
```

Fill in with domain-specific knowledge. Be concrete — include actual naming
patterns, real conventions, specific examples. Avoid generic advice.

### 6. Update CLAUDE.md Imports

Determine which CLAUDE.md to update:
- Project-level rule → update `.claude/CLAUDE.md`
- Global rule → update `~/.claude/CLAUDE.md`

Add a new `@` import line under the "## Domain Knowledge" section:
```
@rules/<domain>.md
```

If there's no "## Domain Knowledge" section, add one.

### 7. Confirm

Show the user:
- Path to the created rule file
- Summary of what rules were included
- The CLAUDE.md import that was added
- How it works: "Marvin will now apply these rules automatically when working in this domain"
- How to customize: "Edit the rule file to refine conventions"

## Example

```
/new-rule kubernetes
```

Creates:
- `.claude/rules/kubernetes.md` — K8s conventions, patterns, anti-patterns
- Updated CLAUDE.md with `@rules/kubernetes.md` import
