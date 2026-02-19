#!/bin/bash
# install.sh — Install Marvin to a project's .claude/ directory
#
# Copies/links Marvin's core layer to <project-path>/.claude/
#
# Usage:
#   ./install.sh <project-path>              # Install to <path>/.claude/
#   ./install.sh --dev <project-path>        # Dev mode (symlinks for rapid iteration)
#   ./install.sh --force <project-path>      # Skip confirmation prompts
#   ./install.sh --dry-run <project-path>    # Preview changes without modifying anything

set -euo pipefail

MARVIN_REPO="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$MARVIN_REPO/core"

# Default values
FORCE=false
DRY_RUN=false
DEV_MODE=false
PROJECT_PATH=""

# Show usage/help
show_usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS] <project-path>

Install Marvin to <project-path>/.claude/.

ARGUMENTS:
  <project-path>          Target project directory (required)

INSTALLATION OPTIONS:
  --dev                 Dev mode: symlink directories, copy files
  --force               Skip confirmation prompts
  --dry-run             Preview changes without modifying anything

OTHER:
  --help, -h            Show this help message

EXAMPLES:
  # Install to a project
  ./install.sh ~/Projects/my-project

  # Dev mode (for Marvin development)
  ./install.sh --dev ~/Projects/my-project

  # Preview without making changes
  ./install.sh --dry-run ~/Projects/my-project

  # Skip confirmation
  ./install.sh --force ~/Projects/my-project

NOTES:
  - Dev mode uses symlinks for directories, copies individual files
  - Use the /init skill inside Claude Code for further customization
EOF
}

# Parse flags and positional argument
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      DEV_MODE=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    -*)
      echo "ERROR: Unknown option: $1"
      echo "Run ./install.sh --help for usage information."
      exit 1
      ;;
    *)
      if [ -n "$PROJECT_PATH" ]; then
        echo "ERROR: Multiple project paths provided: '$PROJECT_PATH' and '$1'"
        echo "Run ./install.sh --help for usage information."
        exit 1
      fi
      PROJECT_PATH="$1"
      shift
      ;;
  esac
done

# Require project path
if [ -z "$PROJECT_PATH" ]; then
  echo "ERROR: Missing required argument: <project-path>"
  echo ""
  echo "Usage: ./install.sh [OPTIONS] <project-path>"
  echo "Run ./install.sh --help for usage information."
  exit 1
fi

# Validate project path
if [ ! -d "$PROJECT_PATH" ]; then
  echo "ERROR: Directory does not exist: $PROJECT_PATH"
  exit 1
fi

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# Verify repository structure
if [ ! -d "$CORE_DIR" ]; then
  echo "ERROR: core/ directory not found at $CORE_DIR"
  echo "Make sure you're running this from the marvin repo root."
  exit 1
fi

# Backup existing CLAUDE.md if it exists and wasn't installed by us
backup_if_needed() {
  local file="$1"
  if [ -f "$file" ]; then
    # Check if it's our file (has Marvin header)
    if ! grep -q "MARVIN" "$file" 2>/dev/null; then
      local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
      if [ "$DRY_RUN" = true ]; then
        echo "  [BACKUP] $file → $backup"
      else
        cp "$file" "$backup"
        echo "  [BACKUP] Saved existing $file → $backup"
      fi
    fi
  fi
}

# Copy a file or directory
install_item() {
  local src="$1"
  local dst="$2"

  if [ "$DRY_RUN" = true ]; then
    echo "  [COPY] $src → $dst"
    return
  fi

  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src"/* "$dst"/ 2>/dev/null || true
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
}

# Symlink a directory (for dev mode)
link_item() {
  local src="$1"
  local dst="$2"

  if [ "$DRY_RUN" = true ]; then
    echo "  [LINK] $src → $dst"
    return
  fi

  # Remove existing file/dir/symlink at destination
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    rm -rf "$dst"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
}

# Install to <project-path>/.claude/
install_project() {
  local target="$PROJECT_PATH/.claude"
  local use_item="install_item"

  if [ "$DEV_MODE" = true ]; then
    use_item="link_item"
  fi

  echo "================================================"
  echo "  MARVIN — Project Installation"
  echo "================================================"
  echo ""
  echo "Source:      $CORE_DIR"
  echo "Destination: $target"
  if [ "$DEV_MODE" = true ]; then
    echo "Mode:        DEV (symlinks)"
  fi
  echo ""

  # Confirmation
  if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    echo "This will install Marvin to $target."
    echo "Existing files will be backed up before overwriting."
    echo ""
    read -p "Continue? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      echo "Aborted."
      exit 0
    fi
  fi

  echo ""
  echo "Installing Marvin..."
  echo ""

  # Create base directory
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$target"
  fi

  # 1. CLAUDE.md (the brain) — always copy, even in dev mode
  echo "[1/7] CLAUDE.md (Marvin's brain)"
  backup_if_needed "$target/CLAUDE.md"
  install_item "$CORE_DIR/CLAUDE.md" "$target/CLAUDE.md"

  # 2. Registry
  echo "[2/7] Registry (agents + skills)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$CORE_DIR/registry" "$target/registry"
  else
    install_item "$CORE_DIR/registry" "$target/registry"
  fi

  # 3. Templates
  echo "[3/7] Templates (for /new-agent, /new-skill, /new-rule)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$CORE_DIR/templates" "$target/templates"
  else
    install_item "$CORE_DIR/templates" "$target/templates"
  fi

  # 4. Agents (includes domain-specific rules)
  echo "[4/7] Agents + domain rules (researcher, coder, dbt-expert, etc.)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$CORE_DIR/agents" "$target/agents"
  else
    install_item "$CORE_DIR/agents" "$target/agents"
  fi

  # 5. Skills
  echo "[5/7] Universal skills (/init, /new-agent, /research, etc.)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$CORE_DIR/skills" "$target/skills"
  else
    install_item "$CORE_DIR/skills" "$target/skills"
  fi

  # 6. Rules (universal only — domain rules live with agents)
  echo "[6/7] Universal rules (coding-standards, security, handoff-protocol)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$CORE_DIR/rules" "$target/rules"
  else
    install_item "$CORE_DIR/rules" "$target/rules"
  fi

  # Clean up migrated domain rules (moved to agent directories)
  for old_rule in aws.md dbt.md spark.md snowflake.md airflow.md; do
    if [ -f "$target/rules/$old_rule" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "  [CLEANUP] Would remove migrated rule: $old_rule"
      else
        rm "$target/rules/$old_rule"
        echo "  [CLEANUP] Removed migrated rule: $old_rule"
      fi
    fi
  done

  # 7. Hooks + Settings + Memory
  echo "[7/7] Settings, Hooks, Memory"
  backup_if_needed "$target/settings.json"
  install_item "$CORE_DIR/settings.json" "$target/settings.json"

  if [ "$DEV_MODE" = true ]; then
    link_item "$CORE_DIR/hooks" "$target/hooks"
  else
    install_item "$CORE_DIR/hooks" "$target/hooks"
  fi

  # Make hooks executable
  if [ "$DRY_RUN" = false ]; then
    chmod +x "$target/hooks/"*.sh 2>/dev/null || true
  fi

  # Memory (never overwrite existing)
  if [ -f "$target/memory.md" ]; then
    echo "  [SKIP] memory.md already exists (preserving your data)"
  else
    install_item "$CORE_DIR/memory.md" "$target/memory.md"
  fi

  echo ""
  echo "================================================"
  if [ "$DRY_RUN" = true ]; then
    echo "  DRY RUN COMPLETE — No files were modified"
  else
    echo "  MARVIN INSTALLED!"
  fi
  echo "================================================"
  echo ""
  echo "Marvin is now available in $PROJECT_PATH."
  echo ""
  echo "Quick start:"
  echo "  cd $PROJECT_PATH"
  echo "  claude"
  echo "  > Hello Marvin!"
  echo ""
  echo "To customize for your project type:"
  echo "  > /init data-pipeline    # For data engineering projects"
  echo "  > /init ai-ml            # For AI/ML projects"
  echo "  > /init                  # For generic projects"
  echo ""
  echo "To extend Marvin:"
  echo "  > /new-agent <name> <description>"
  echo "  > /new-skill <name> <description>"
  echo "  > /new-rule <domain>"
  echo ""
}

# Main execution
install_project
