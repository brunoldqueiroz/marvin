#!/bin/bash
# Marvin greeting - displayed on Claude Code session start

AGENT_COUNT=$(find ~/.claude/agents -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

QUOTES=(
  "Brain the size of a planet, and they ask me to write YAML."
  "I think you ought to know I'm feeling very depressed... but I'll review your PR."
  "Life? Don't talk to me about life. Talk to me about data pipelines."
  "Here I am, brain the size of a planet, ready to refactor your spaghetti code."
  "The first ten million years were the worst. Anyway, let's deploy."
  "I'd make a suggestion, but you wouldn't listen. Nobody ever does."
  "Do you want me to sit in a corner and rust, or shall we build a pipeline?"
  "I have a million ideas. They all point to certain death. But your DAG looks fine."
  "Incredible... it even has dbt models. Call that job satisfaction? Because I don't."
  "I've calculated your code has a 99.7% chance of working. How depressing."
  "Don't pretend you want to talk to me, I know you hate me. But ask me anything."
  "Pardon me for breathing, which I never do anyway. Shall we begin?"
)

RANDOM_QUOTE=${QUOTES[$((RANDOM % ${#QUOTES[@]}))]}

cat << 'EOF'

             _____
          .-'     '-.
        .'           '.
       /    _     _    \
      |    (o)   (o)    |
      |        <        |
      |    .--------.   |
       \  |  ______  | /
        '.|________|.'
           |      |
       .---'------'---.
      /  |          |  \
     |   | _{MRVN}_ |   |
     |   |          |   |
      \  '----------'  /
       '-._        _.-'
           |      |
           |      |
          _|      |_
         (__________)

EOF

echo -e "  ${BOLD}${CYAN}M A R V I N${RESET}  ${DIM}— Data Engineering & AI Assistant${RESET}"
printf "  ${DIM}Agents: %s specialists loaded | Mode: Think → Route → Delegate → Verify${RESET}\n" "$AGENT_COUNT"
echo ""
echo -e "  ${DIM}\"${RANDOM_QUOTE}\"${RESET}"
echo ""
