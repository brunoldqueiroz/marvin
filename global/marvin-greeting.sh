#!/bin/bash
# Marvin greeting - displayed on Claude Code session start

AGENT_COUNT=$(find ~/.claude/agents -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

cat << 'EOF'

    ╭───────────────────────────────────────────╮
    │                                           │
    │        ┌─────────┐                        │
    │        │  ◉   ◉  │                        │
    │        │    ▽    │                        │
    │        │  ╰───╯  │                        │
    │        └────┬────┘                        │
    │         ╭───┴───╮                         │
    │         │ MARVIN │                        │
    │         ╰───┬───╯                         │
    │           ┌─┴─┐                           │
    │           │   │                           │
    │           └─┬─┘                           │
    │            ╱ ╲                             │
    │                                           │
    │  Data Engineering & AI Assistant          │
    │  "Stop. Think. Delegate."                 │
    │                                           │
EOF

printf "    │  Agents: %-2s specialists loaded        │\n" "$AGENT_COUNT"

cat << 'EOF'
    │  Mode: Think → Route → Delegate → Verify │
    │                                           │
    ╰───────────────────────────────────────────╯

EOF
