#!/bin/bash
# install.sh — Install Marvin globally to ~/.claude/
#
# This copies Marvin's global layer (brain, agents, skills, rules, hooks)
# to ~/.claude/ so Marvin is available in every Claude Code session.
#
# Usage:
#   ./install.sh           # Install (with backup of existing files)
#   ./install.sh --force   # Install without prompts
#   ./install.sh --dry-run # Show what would be copied

set -euo pipefail

MARVIN_HOME="$HOME/.claude"
MARVIN_REPO="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$MARVIN_REPO/global"
FORCE=false
DRY_RUN=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: ./install.sh [--force] [--dry-run]"
      echo ""
      echo "Installs Marvin's global layer to ~/.claude/"
      echo ""
      echo "Options:"
      echo "  --force     Install without confirmation prompts"
      echo "  --dry-run   Show what would be copied without doing it"
      exit 0
      ;;
  esac
done

echo "================================================"
echo "  MARVIN — AI Assistant Installer"
echo "================================================"
echo ""
echo "Source:      $GLOBAL_DIR"
echo "Destination: $MARVIN_HOME"
echo ""

# Verify source exists
if [ ! -d "$GLOBAL_DIR" ]; then
  echo "ERROR: global/ directory not found at $GLOBAL_DIR"
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

# Confirmation
if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
  echo "This will install Marvin to $MARVIN_HOME."
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
  mkdir -p "$MARVIN_HOME"
fi

# 1. CLAUDE.md (the brain)
echo "[1/8] CLAUDE.md (Marvin's brain)"
backup_if_needed "$MARVIN_HOME/CLAUDE.md"
install_item "$GLOBAL_DIR/CLAUDE.md" "$MARVIN_HOME/CLAUDE.md"

# 2. Registry
echo "[2/8] Registry (agents + skills)"
install_item "$GLOBAL_DIR/registry" "$MARVIN_HOME/registry"

# 3. Templates
echo "[3/8] Templates (for /new-agent, /new-skill, /new-rule)"
install_item "$GLOBAL_DIR/templates" "$MARVIN_HOME/templates"

# 4. Agents
echo "[4/8] Universal agents (researcher, coder, verifier)"
install_item "$GLOBAL_DIR/agents" "$MARVIN_HOME/agents"

# 5. Skills
echo "[5/8] Universal skills (/init, /new-agent, /research, etc.)"
install_item "$GLOBAL_DIR/skills" "$MARVIN_HOME/skills"

# 6. Rules
echo "[6/8] Universal rules (coding-standards, security)"
install_item "$GLOBAL_DIR/rules" "$MARVIN_HOME/rules"

# 7. Hooks + Settings + Greeting
echo "[7/8] Settings + Hooks + Greeting"
backup_if_needed "$MARVIN_HOME/settings.json"
install_item "$GLOBAL_DIR/settings.json" "$MARVIN_HOME/settings.json"
install_item "$GLOBAL_DIR/hooks" "$MARVIN_HOME/hooks"

# Make hooks and greeting executable
if [ "$DRY_RUN" = false ]; then
  chmod +x "$MARVIN_HOME/hooks/"*.sh 2>/dev/null || true
fi

# 8. Memory (never overwrite existing)
echo "[8/8] Memory (persistent across sessions)"
if [ -f "$MARVIN_HOME/memory.md" ]; then
  echo "  [SKIP] memory.md already exists (preserving your data)"
else
  install_item "$GLOBAL_DIR/memory.md" "$MARVIN_HOME/memory.md"
fi

echo ""
echo "================================================"
if [ "$DRY_RUN" = true ]; then
  echo "  DRY RUN COMPLETE — No files were modified"
else
  echo "  MARVIN INSTALLED SUCCESSFULLY!"
fi
echo "================================================"
echo ""
echo "Marvin is now available in every Claude Code session."
echo ""
echo "Quick start:"
echo "  cd ~/Projects/any-project"
echo "  claude"
echo "  > Hello Marvin!"
echo ""
echo "To initialize project-specific config:"
echo "  > /init data-pipeline    # For data engineering projects"
echo "  > /init ai-ml            # For AI/ML projects"
echo "  > /init                  # For generic projects"
echo ""
echo "To extend Marvin:"
echo "  > /new-agent <name> <description>"
echo "  > /new-skill <name> <description>"
echo "  > /new-rule <domain>"
echo ""
