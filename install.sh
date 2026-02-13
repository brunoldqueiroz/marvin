#!/bin/bash
# install.sh — Install Marvin globally or per-project
#
# This copies/links Marvin's global layer or project templates to:
#   - ~/.claude/ (global scope — available in every Claude Code session)
#   - ./.claude/ (project scope — project-specific config)
#
# Usage:
#   ./install.sh                              # Global install (default)
#   ./install.sh --global                     # Explicit global install
#   ./install.sh --project                    # Project install (interactive template menu)
#   ./install.sh --project --template ai-ml   # Project install with specific template
#   ./install.sh --dev                        # Global install in dev mode (symlinks)
#   ./install.sh --project --dev              # Project install in dev mode (symlinks)
#   ./install.sh --force --dry-run            # Preview with no prompts

set -euo pipefail

MARVIN_REPO="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$MARVIN_REPO/global"
TEMPLATE_DIR="$MARVIN_REPO/project-templates"

# Default values
SCOPE="global"
TEMPLATE=""
FORCE=false
DRY_RUN=false
DEV_MODE=false

# Show usage/help
show_usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install Marvin globally or per-project.

SCOPE OPTIONS:
  --global              Install to ~/.claude/ (default)
  --project, --local    Install to ./.claude/ (project-specific)

PROJECT OPTIONS:
  --template <name>     Use specific template (ai-ml, data-pipeline, generic)
                        Without this, shows interactive menu

INSTALLATION OPTIONS:
  --dev                 Dev mode: symlink directories, copy files
  --force               Skip confirmation prompts
  --dry-run             Preview changes without modifying anything

OTHER:
  --help, -h            Show this help message

EXAMPLES:
  # Global install (default)
  ./install.sh

  # Global install with dev mode (for Marvin development)
  ./install.sh --global --dev

  # Project install with interactive menu
  ./install.sh --project

  # Project install with specific template
  ./install.sh --project --template ai-ml

  # Project install in dev mode
  ./install.sh --project --template data-pipeline --dev

  # Preview without making changes
  ./install.sh --project --dry-run

NOTES:
  - Default scope is --global (backward compatible)
  - Dev mode uses symlinks for directories, copies individual files
  - Project install auto-discovers templates from project-templates/
  - Project install handles .mcp.json and updates .gitignore
EOF
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      SCOPE="global"
      shift
      ;;
    --project|--local)
      SCOPE="project"
      shift
      ;;
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
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
    *)
      echo "ERROR: Unknown option: $1"
      echo "Run ./install.sh --help for usage information."
      exit 1
      ;;
  esac
done

# Verify repository structure
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

# Discover available templates
discover_templates() {
  local templates=()
  if [ -d "$TEMPLATE_DIR" ]; then
    for template in "$TEMPLATE_DIR"/*; do
      if [ -d "$template" ]; then
        templates+=("$(basename "$template")")
      fi
    done
  fi
  echo "${templates[@]}"
}

# Show interactive template menu
select_template() {
  local templates=($(discover_templates))

  if [ ${#templates[@]} -eq 0 ]; then
    echo "ERROR: No templates found in $TEMPLATE_DIR"
    exit 1
  fi

  echo ""
  echo "Available templates:"
  echo ""

  local i=1
  for template in "${templates[@]}"; do
    echo "  $i) $template"
    ((i++))
  done

  echo ""
  read -p "Select template [1-${#templates[@]}]: " -r selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#templates[@]} ]; then
    echo "ERROR: Invalid selection"
    exit 1
  fi

  echo "${templates[$((selection-1))]}"
}

# Install globally to ~/.claude/
install_global() {
  local marvin_home="$HOME/.claude"
  local use_item="install_item"

  if [ "$DEV_MODE" = true ]; then
    use_item="link_item"
  fi

  echo "================================================"
  echo "  MARVIN — Global Installation"
  echo "================================================"
  echo ""
  echo "Source:      $GLOBAL_DIR"
  echo "Destination: $marvin_home"
  if [ "$DEV_MODE" = true ]; then
    echo "Mode:        DEV (symlinks)"
  fi
  echo ""

  # Confirmation
  if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    echo "This will install Marvin to $marvin_home."
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
    mkdir -p "$marvin_home"
  fi

  # 1. CLAUDE.md (the brain) — always copy, even in dev mode
  echo "[1/8] CLAUDE.md (Marvin's brain)"
  backup_if_needed "$marvin_home/CLAUDE.md"
  install_item "$GLOBAL_DIR/CLAUDE.md" "$marvin_home/CLAUDE.md"

  # 2. Registry
  echo "[2/8] Registry (agents + skills)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$GLOBAL_DIR/registry" "$marvin_home/registry"
  else
    install_item "$GLOBAL_DIR/registry" "$marvin_home/registry"
  fi

  # 3. Templates
  echo "[3/8] Templates (for /new-agent, /new-skill, /new-rule)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$GLOBAL_DIR/templates" "$marvin_home/templates"
  else
    install_item "$GLOBAL_DIR/templates" "$marvin_home/templates"
  fi

  # 4. Agents (includes domain-specific rules)
  echo "[4/8] Agents + domain rules (researcher, coder, dbt-expert, etc.)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$GLOBAL_DIR/agents" "$marvin_home/agents"
  else
    install_item "$GLOBAL_DIR/agents" "$marvin_home/agents"
  fi

  # 5. Skills
  echo "[5/8] Universal skills (/init, /new-agent, /research, etc.)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$GLOBAL_DIR/skills" "$marvin_home/skills"
  else
    install_item "$GLOBAL_DIR/skills" "$marvin_home/skills"
  fi

  # 6. Rules (universal only — domain rules live with agents)
  echo "[6/8] Universal rules (coding-standards, security, handoff-protocol)"
  if [ "$DEV_MODE" = true ]; then
    link_item "$GLOBAL_DIR/rules" "$marvin_home/rules"
  else
    install_item "$GLOBAL_DIR/rules" "$marvin_home/rules"
  fi

  # Clean up migrated domain rules (moved to agent directories)
  for old_rule in aws.md dbt.md spark.md snowflake.md airflow.md; do
    if [ -f "$marvin_home/rules/$old_rule" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "  [CLEANUP] Would remove migrated rule: $old_rule"
      else
        rm "$marvin_home/rules/$old_rule"
        echo "  [CLEANUP] Removed migrated rule: $old_rule"
      fi
    fi
  done

  # 7. Hooks + Settings
  echo "[7/8] Settings + Hooks"
  backup_if_needed "$marvin_home/settings.json"
  install_item "$GLOBAL_DIR/settings.json" "$marvin_home/settings.json"

  if [ "$DEV_MODE" = true ]; then
    link_item "$GLOBAL_DIR/hooks" "$marvin_home/hooks"
  else
    install_item "$GLOBAL_DIR/hooks" "$marvin_home/hooks"
  fi

  # Make hooks executable
  if [ "$DRY_RUN" = false ]; then
    chmod +x "$marvin_home/hooks/"*.sh 2>/dev/null || true
  fi

  # 8. Memory (never overwrite existing)
  echo "[8/8] Memory (persistent across sessions)"
  if [ -f "$marvin_home/memory.md" ]; then
    echo "  [SKIP] memory.md already exists (preserving your data)"
  else
    install_item "$GLOBAL_DIR/memory.md" "$marvin_home/memory.md"
  fi

  echo ""
  echo "================================================"
  if [ "$DRY_RUN" = true ]; then
    echo "  DRY RUN COMPLETE — No files were modified"
  else
    echo "  MARVIN INSTALLED GLOBALLY!"
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
}

# Install project-specific config to ./.claude/
install_project() {
  local project_home=".claude"
  local selected_template="$TEMPLATE"

  # If no template specified, show interactive menu
  if [ -z "$selected_template" ]; then
    if [ "$FORCE" = true ] || [ "$DRY_RUN" = true ]; then
      echo "ERROR: --template required when using --force or --dry-run with --project"
      exit 1
    fi
    selected_template=$(select_template)
  fi

  # Validate template exists
  local template_path="$TEMPLATE_DIR/$selected_template"
  if [ ! -d "$template_path" ]; then
    echo "ERROR: Template '$selected_template' not found at $template_path"
    echo ""
    echo "Available templates:"
    for t in $(discover_templates); do
      echo "  - $t"
    done
    exit 1
  fi

  echo ""
  echo "================================================"
  echo "  MARVIN — Project Installation"
  echo "================================================"
  echo ""
  echo "Template:    $selected_template"
  echo "Source:      $template_path"
  echo "Destination: $project_home"
  if [ "$DEV_MODE" = true ]; then
    echo "Mode:        DEV (symlinks)"
  fi
  echo ""

  # Confirmation
  if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    echo "This will install project-specific Marvin config to ./.claude/."
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
  echo "Installing project config..."
  echo ""

  # Create project .claude directory
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$project_home"
  fi

  local step=1
  local total=0

  # Count items to install
  [ -f "$template_path/CLAUDE.md" ] && total=$((total + 1))
  [ -d "$template_path/registry" ] && total=$((total + 1))
  [ -d "$template_path/agents" ] && total=$((total + 1))
  [ -d "$template_path/skills" ] && total=$((total + 1))
  [ -d "$template_path/rules" ] && total=$((total + 1))
  [ -f "$template_path/settings.json" ] && total=$((total + 1))
  [ -f "$template_path/mcp.json" ] && total=$((total + 1))

  # 1. CLAUDE.md
  if [ -f "$template_path/CLAUDE.md" ]; then
    echo "[$step/$total] CLAUDE.md (project context)"
    backup_if_needed "$project_home/CLAUDE.md"
    install_item "$template_path/CLAUDE.md" "$project_home/CLAUDE.md"
    step=$((step + 1))
  fi

  # 2. Registry
  if [ -d "$template_path/registry" ]; then
    echo "[$step/$total] Registry (agents + skills)"
    if [ "$DEV_MODE" = true ]; then
      link_item "$template_path/registry" "$project_home/registry"
    else
      install_item "$template_path/registry" "$project_home/registry"
    fi
    step=$((step + 1))
  fi

  # 3. Agents
  if [ -d "$template_path/agents" ]; then
    echo "[$step/$total] Project-specific agents"
    if [ "$DEV_MODE" = true ]; then
      link_item "$template_path/agents" "$project_home/agents"
    else
      install_item "$template_path/agents" "$project_home/agents"
    fi
    step=$((step + 1))
  fi

  # 4. Skills
  if [ -d "$template_path/skills" ]; then
    echo "[$step/$total] Project-specific skills"
    if [ "$DEV_MODE" = true ]; then
      link_item "$template_path/skills" "$project_home/skills"
    else
      install_item "$template_path/skills" "$project_home/skills"
    fi
    step=$((step + 1))
  fi

  # 5. Rules
  if [ -d "$template_path/rules" ]; then
    echo "[$step/$total] Domain rules"
    if [ "$DEV_MODE" = true ]; then
      link_item "$template_path/rules" "$project_home/rules"
    else
      install_item "$template_path/rules" "$project_home/rules"
    fi
    step=$((step + 1))
  fi

  # 6. Settings
  if [ -f "$template_path/settings.json" ]; then
    echo "[$step/$total] Settings (project-specific)"
    backup_if_needed "$project_home/settings.json"
    install_item "$template_path/settings.json" "$project_home/settings.json"
    step=$((step + 1))
  fi

  # 7. MCP config (copy to project root, not .claude/)
  if [ -f "$template_path/mcp.json" ]; then
    echo "[$step/$total] MCP config (.mcp.json)"
    backup_if_needed ".mcp.json"
    if [ "$DRY_RUN" = true ]; then
      echo "  [COPY] $template_path/mcp.json → .mcp.json"
    else
      install_item "$template_path/mcp.json" ".mcp.json"
    fi
    step=$((step + 1))
  fi

  # Update .gitignore
  echo ""
  echo "Updating .gitignore..."
  if [ -f ".gitignore" ]; then
    if grep -q "^\.claude/settings\.local\.json$" .gitignore 2>/dev/null; then
      echo "  [SKIP] .gitignore already contains .claude/settings.local.json"
    else
      if [ "$DRY_RUN" = true ]; then
        echo "  [ADD] .claude/settings.local.json to .gitignore"
      else
        echo ".claude/settings.local.json" >> .gitignore
        echo "  [ADD] Added .claude/settings.local.json to .gitignore"
      fi
    fi
  else
    if [ "$DRY_RUN" = true ]; then
      echo "  [CREATE] .gitignore with .claude/settings.local.json"
    else
      echo ".claude/settings.local.json" > .gitignore
      echo "  [CREATE] Created .gitignore with .claude/settings.local.json"
    fi
  fi

  echo ""
  echo "================================================"
  if [ "$DRY_RUN" = true ]; then
    echo "  DRY RUN COMPLETE — No files were modified"
  else
    echo "  PROJECT CONFIG INSTALLED!"
  fi
  echo "================================================"
  echo ""
  echo "Project-specific Marvin config is now active in ./.claude/"
  echo ""
  echo "Template: $selected_template"
  echo ""
  echo "Next steps:"
  echo "  1. Review .claude/CLAUDE.md and customize for your project"
  echo "  2. Update tech stack and architecture sections"
  echo "  3. Add project-specific conventions"
  echo ""
  echo "To start Claude Code with this config:"
  echo "  claude"
  echo ""
}

# Main execution
if [ "$SCOPE" = "global" ]; then
  install_global
elif [ "$SCOPE" = "project" ]; then
  install_project
else
  echo "ERROR: Invalid scope: $SCOPE"
  exit 1
fi
