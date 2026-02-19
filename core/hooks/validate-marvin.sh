#!/bin/bash
# validate-marvin.sh — Validate Marvin config files (SKILL.md, AGENT.md) on write/edit
# Hook: PostToolUse (matcher: Edit|Write)
#
# Checks:
# - SKILL.md: has YAML frontmatter with name + description
# - AGENT.md: has YAML frontmatter with name + description + tools + model
# Lightweight — only runs on matching file paths.

source "$(dirname "$0")/_lib.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | json_val '.tool_input.file_path')

# Only check Marvin config files
case "$FILE_PATH" in
  */SKILL.md)
    # Validate SKILL.md frontmatter
    if ! head -1 "$FILE_PATH" | grep -q '^---$' 2>/dev/null; then
      echo "SKILL.md missing YAML frontmatter (must start with ---)" >&2
      exit 2
    fi

    # Extract frontmatter (between first and second ---)
    FRONTMATTER=$(sed -n '1,/^---$/{ /^---$/d; p; }' "$FILE_PATH" | sed '1d')

    if ! echo "$FRONTMATTER" | grep -q '^name:'; then
      echo "SKILL.md frontmatter missing 'name' field" >&2
      exit 2
    fi

    if ! echo "$FRONTMATTER" | grep -q '^description:'; then
      echo "SKILL.md frontmatter missing 'description' field" >&2
      exit 2
    fi

    # Check for $ARGUMENTS reference
    if ! grep -q '\$ARGUMENTS' "$FILE_PATH" 2>/dev/null; then
      echo "Note: SKILL.md does not reference \$ARGUMENTS" >&2
    fi
    ;;

  */AGENT.md)
    # Validate AGENT.md frontmatter
    if ! head -1 "$FILE_PATH" | grep -q '^---$' 2>/dev/null; then
      echo "AGENT.md missing YAML frontmatter (must start with ---)" >&2
      exit 2
    fi

    FRONTMATTER=$(sed -n '1,/^---$/{ /^---$/d; p; }' "$FILE_PATH" | sed '1d')

    for FIELD in name description tools model; do
      if ! echo "$FRONTMATTER" | grep -q "^${FIELD}:"; then
        echo "AGENT.md frontmatter missing '${FIELD}' field" >&2
        exit 2
      fi
    done
    ;;
esac

exit 0
