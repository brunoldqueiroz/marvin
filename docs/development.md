# Development

## Project Structure

```
marvin/
├── core/                  # Source of truth — deployed to <project>/.claude/
│   ├── CLAUDE.md          # Marvin orchestrator system prompt
│   ├── .mcp.json          # MCP server configuration template
│   ├── settings.json      # Claude Code settings
│   ├── memory.md          # Persistent memory template
│   ├── agents/            # 12 specialist agents (AGENT.md + rules.md each)
│   ├── skills/            # Slash command implementations (SKILL.md each)
│   ├── rules/             # Universal rules: coding-standards, security, handoff-protocol
│   ├── registry/          # agents.md and skills.md registries
│   ├── reference/         # Workflow and protocol documentation
│   ├── templates/         # Scaffolding templates for /new-agent, /new-skill, /new-rule
│   └── hooks/             # Shell hooks (*.sh)
├── docs/                  # Architecture and concept documentation
├── scripts/               # install.py — the installer
├── research/              # Research artifacts and notes
├── Makefile               # Build targets
├── .env.example           # Template for MCP API keys
└── .claude/               # Dev-mode project instructions for Marvin's own development
```

## Edit in `core/`, Never in `.claude/`

The `core/` directory is the single source of truth. Never edit files in a deployed `<project>/.claude/` directly — those changes will be overwritten on the next install.

| What to change | Edit here | Not here |
|----------------|-----------|----------|
| Orchestrator logic | `core/CLAUDE.md` | `<project>/.claude/CLAUDE.md` |
| Agent definitions | `core/agents/<name>/AGENT.md` | `<project>/.claude/agents/` |
| Domain rules | `core/agents/<domain>-expert/rules.md` | `<project>/.claude/agents/` |
| Skills | `core/skills/<name>/SKILL.md` | `<project>/.claude/skills/` |
| Universal rules | `core/rules/<name>.md` | `<project>/.claude/rules/` |
| Hooks | `core/hooks/<name>.sh` | `<project>/.claude/hooks/` |
| Settings | `core/settings.json` | `<project>/.claude/settings.json` |

## Makefile Targets

All project-targeting commands require `PROJECT=<path>`.

| Target | Description |
|--------|-------------|
| `make install PROJECT=<path>` | Install Marvin to a project (copy mode) |
| `make install-dev PROJECT=<path>` | Install in dev mode (symlinks — live changes) |
| `make dry-run PROJECT=<path>` | Preview installation without modifying anything |
| `make uninstall PROJECT=<path>` | Remove Marvin from a project |
| `make test` | Run all checks (lint + hook tests) |
| `make lint` | Run all linters (JSON validation + shellcheck) |
| `make hooks-chmod` | Ensure all hooks are executable |
| `make list-hooks` | List all hook scripts |
| `make list-agents` | List all specialist agents |
| `make help` | Show all available targets |

## Development Workflow

Use dev mode so changes to `core/` are reflected immediately without reinstalling:

```bash
# Install once in dev mode
make install-dev PROJECT=~/Projects/my-project

# Edit source files in core/
vim core/agents/dbt-expert/rules.md

# Changes are live immediately (symlinks)
# Validate before committing
make test
make lint
```

For non-dev mode (integration testing the full install):

```bash
make dry-run PROJECT=~/Projects/my-project   # Preview
make install PROJECT=~/Projects/my-project   # Apply
```

## Extending Marvin

Add a new specialist agent:

```bash
> /new-agent kafka-expert "Kafka streaming patterns and consumer group optimization"
```

Add a new slash command:

```bash
> /new-skill schema-registry "Generate and validate Avro schemas for Kafka topics"
```

Add domain knowledge rules:

```bash
> /new-rule kafka
```

All three commands scaffold the necessary files in `core/` using the templates in `core/templates/`. After scaffolding, edit the generated files, then redeploy.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Edit files in `core/`
4. Validate with `make dry-run PROJECT=<path>` and `make test`
5. Submit a pull request

Good candidates for contributions: new domain agents, additional slash commands, expanded rule patterns, new hook behaviors.
