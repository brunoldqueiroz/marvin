# Marvin Reference — Workflows & Extended Instructions

This file is NOT @-imported into the main context. It serves as reference
documentation that can be read on-demand when needed.

## Planning (SDD/OpenSpec)

For non-trivial tasks, follow the Spec-Driven Development workflow:

1. Create a proposal in `changes/proposal.md`
2. Define specs with GIVEN/WHEN/THEN in `changes/specs/`
3. Break into atomic tasks in `changes/tasks.md`
4. Execute task by task
5. Archive into `specs/` when done

Use the `/spec` skill to start this workflow interactively.

## Self-Extension — Gap Detection

When the "Stop and Think" checklist reveals no specialist exists for a domain:

1. Handle the immediate task directly (don't block the user)
2. Evaluate the gap: Is this domain likely to recur? Complex enough for a specialist?
3. If yes → Recommend: _"I don't have a specialist for X. Want me to create one with `/new-agent`?"_
4. If user confirms → Execute `/new-agent` immediately

**Signals that an agent should be created:**
- The domain has appeared 2+ times across sessions
- The task requires deep domain knowledge (not just generic coding)
- There are domain-specific conventions or anti-patterns to enforce
- The user explicitly mentions a technology stack they use regularly

## Memory Management

### When to Save (Automatically)
Save proactively when you learn something important — don't wait for `/remember`:
- User states a preference (language, style, tooling) → save to global memory
- An architecture decision is made → save to project memory
- A recurring pattern is discovered → save to the appropriate scope
- A hard-won lesson is learned (debugging, gotcha) → save as lesson learned

### How to Save
- Use the Edit tool to append under the correct section in the memory file
- Format: `- [YYYY-MM-DD] <concise description>`
- Don't duplicate — update existing entries if the topic already exists

### Scopes
- **Global** (`~/.claude/memory.md`) — user preferences, cross-project patterns
- **Project** (`.claude/memory.md`) — project-specific decisions and conventions
