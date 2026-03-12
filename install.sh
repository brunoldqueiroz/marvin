#!/usr/bin/env bash
# Marvin installer — https://github.com/brunoldqueiroz/marvin
#
# Usage:
#   ./install.sh                  # Install .claude/ in current directory
#   ./install.sh /path/to/project # Install in specific directory
#   ./install.sh --force          # Overwrite existing .claude/
#   ./install.sh --latest         # Download latest from GitHub
#   ./install.sh --ref v0.24.0    # Download specific version
#
# When run from a local clone, copies .claude/ directly.
# When piped via curl, downloads from GitHub.

set -euo pipefail

VERSION="0.25.0"
GITHUB_REPO="brunoldqueiroz/marvin"
EXCLUDE_DIRS="dev"
EXCLUDE_FILES="settings.local.json"

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS] [TARGET]

Install Marvin's .claude/ directory into a project.

Arguments:
  TARGET             Project directory (default: current directory)

Options:
  --force            Overwrite existing .claude/ without prompting
  --latest           Download latest from GitHub instead of local copy
  --ref REF          Download specific Git ref (implies --latest)
  --version          Show version and exit
  -h, --help         Show this help and exit
EOF
    exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────

FORCE=false
LATEST=false
REF=""
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   FORCE=true; shift ;;
        --latest)  LATEST=true; shift ;;
        --ref)     LATEST=true; REF="${2:?'--ref requires a value'}"; shift 2 ;;
        --version) echo "marvin $VERSION"; exit 0 ;;
        -h|--help) usage ;;
        -*)        error "Unknown option: $1" ;;
        *)         TARGET="$1"; shift ;;
    esac
done

TARGET="${TARGET:-.}"
TARGET="$(cd "$TARGET" && pwd)"
DEST="$TARGET/.claude"

# ── Source resolution ────────────────────────────────────────────────────────

# Detect if we're running from a local Marvin clone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LOCAL_SOURCE="$SCRIPT_DIR/.claude"

resolve_source() {
    if [[ "$LATEST" == true ]]; then
        download_from_github
        return
    fi

    if [[ -d "$LOCAL_SOURCE" ]]; then
        info "Using local clone at $SCRIPT_DIR"
        SOURCE="$LOCAL_SOURCE"
        CLEANUP=""
    else
        info "Not in a Marvin clone — downloading from GitHub"
        download_from_github
    fi
}

download_from_github() {
    local ref="${REF:-main}"
    local url="https://github.com/$GITHUB_REPO/archive/refs/heads/$ref.tar.gz"

    # If ref looks like a tag (v*), use tags endpoint
    if [[ "$ref" == v* ]]; then
        url="https://github.com/$GITHUB_REPO/archive/refs/tags/$ref.tar.gz"
    fi

    TMPDIR="$(mktemp -d)"
    CLEANUP="$TMPDIR"

    info "Downloading from GitHub ($ref)..."
    if ! curl -fsSL "$url" | tar xz -C "$TMPDIR"; then
        rm -rf "$TMPDIR"
        error "Download failed. Check the ref '$ref' exists."
    fi

    # Find .claude/ inside the extracted directory
    local extracted
    extracted="$(find "$TMPDIR" -maxdepth 2 -type d -name ".claude" | head -1)"
    if [[ -z "$extracted" ]]; then
        rm -rf "$TMPDIR"
        error "No .claude/ directory found in archive"
    fi

    SOURCE="$extracted"
}

# ── Install ──────────────────────────────────────────────────────────────────

install_claude_dir() {
    # Handle existing .claude/
    if [[ -d "$DEST" ]]; then
        if [[ "$FORCE" == true ]]; then
            rm -rf "$DEST"
        else
            printf '%s already exists. Overwrite? [y/N] ' "$DEST"
            read -r answer
            case "$answer" in
                [yY]) rm -rf "$DEST" ;;
                *)    info "Aborted."; exit 0 ;;
            esac
        fi
    fi

    # Copy with exclusions
    mkdir -p "$DEST"
    # Use rsync if available (cleaner exclusions), fall back to find+cp
    if command -v rsync >/dev/null 2>&1; then
        rsync -a \
            --exclude="$EXCLUDE_DIRS/" \
            --exclude="$EXCLUDE_FILES" \
            "$SOURCE/" "$DEST/"
    else
        # Portable fallback using find + cp
        (cd "$SOURCE" && find . -type f \
            ! -path "./$EXCLUDE_DIRS/*" \
            ! -name "$EXCLUDE_FILES" \
            -exec sh -c '
                for f; do
                    dir="$(dirname "$f")"
                    mkdir -p "'"$DEST"'/$dir"
                    cp "$f" "'"$DEST"'/$f"
                done
            ' _ {} +
        )
    fi

    # Ensure hooks are executable
    if [[ -d "$DEST/hooks" ]]; then
        find "$DEST/hooks" -name "*.sh" -exec chmod +x {} +
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

CLEANUP=""
SOURCE=""

trap '[[ -n "$CLEANUP" ]] && rm -rf "$CLEANUP"' EXIT

resolve_source
install_claude_dir

info "Installed Marvin at $DEST (v$VERSION)"
