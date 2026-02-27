#!/usr/bin/env bash
# Marvin installer — https://github.com/brunoldqueiroz/marvin
# Usage: curl -fsSL https://raw.githubusercontent.com/brunoldqueiroz/marvin/main/install.sh | bash
set -euo pipefail

REPO="git+https://github.com/brunoldqueiroz/marvin"

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

if command -v uv >/dev/null 2>&1; then
    info "Installing marvin-cli with uv..."
    uv tool install "$REPO" || error "uv tool install failed"
elif command -v pipx >/dev/null 2>&1; then
    info "Installing marvin-cli with pipx..."
    pipx install "$REPO" || error "pipx install failed"
else
    error "uv or pipx is required. Install uv: https://docs.astral.sh/uv/"
fi

info "Installed successfully!"
marvin --version
echo ""
echo "Get started:"
echo "  marvin init        # initialize Marvin in current project"
echo "  marvin agents      # list available agents"
echo "  marvin skills      # list available skills"
echo "  marvin --help      # show all commands"
