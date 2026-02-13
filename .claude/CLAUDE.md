# Marvin Project — Development Instructions

## Critical Rule: Edit Source, Not Installed Copy

This repository (`/home/brunoqueiroz/Projects/marvin/`) is the **source of truth** for all Marvin configuration.

**NEVER edit files in `~/.claude/` directly.** Always edit the source files in this project:

| To change... | Edit in... | NOT in... |
|--------------|-----------|-----------|
| CLAUDE.md (brain) | `global/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Agent definitions | `global/agents/<name>/AGENT.md` | `~/.claude/agents/` |
| Skills | `global/skills/<name>/SKILL.md` | `~/.claude/skills/` |
| Rules | `global/rules/<domain>.md` | `~/.claude/rules/` |
| Registry | `global/registry/*.md` | `~/.claude/registry/` |
| Templates | `global/templates/*.md` | `~/.claude/templates/` |
| Settings | `global/settings.json` | `~/.claude/settings.json` |
| Hooks | `global/hooks/*.sh` | `~/.claude/hooks/` |
| Memory | `global/memory.md` | `~/.claude/memory.md` |

After making changes, the user runs `./install.sh` to deploy to `~/.claude/`.

## Project Structure

```
marvin/
├── global/           # Source of truth for ~/.claude/
│   ├── CLAUDE.md     # Marvin's brain (system prompt)
│   ├── agents/       # Specialized agent definitions
│   ├── skills/       # Slash command definitions
│   ├── rules/        # Domain knowledge rules
│   ├── registry/     # Agent and skill registries
│   ├── templates/    # Templates for /new-agent, /new-skill, /new-rule
│   ├── hooks/        # Shell hooks (greeting, validation)
│   ├── settings.json # Claude Code settings
│   └── memory.md     # Persistent memory (template)
├── project-templates/ # Templates for /init command
├── research/          # Research documents
├── scripts/           # Utility scripts
├── specs/             # OpenSpec specifications
├── changes/           # Active proposals and tasks
├── install.sh         # Deploys global/ to ~/.claude/
└── .claude/           # THIS FILE — project-specific dev instructions
```

## Workflow

1. Edit source files in `global/`
2. Test changes (review, validate)
3. Commit to git
4. Run `./install.sh` to deploy
