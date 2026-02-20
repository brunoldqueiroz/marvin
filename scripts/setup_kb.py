#!/usr/bin/env python3
"""Setup Qdrant Cloud environment variables for Marvin's shared knowledge base."""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def get_shell_rc() -> Path:
    """Detect the user's shell and return the appropriate rc file."""
    shell = os.environ.get("SHELL", "/bin/bash")
    if "zsh" in shell:
        return Path.home() / ".zshrc"
    return Path.home() / ".bashrc"


def validate_url(url: str) -> bool:
    """Check that URL looks like a valid Qdrant Cloud endpoint."""
    return url.startswith("https://") and len(url) > 10


def read_env_var(name: str, flag_value: str | None, prompt_msg: str) -> str:
    """Get value from flag, environment, or interactive prompt."""
    if flag_value:
        return flag_value
    existing = os.environ.get(name)
    if existing:
        # Mask the value regardless of whether it's a URL or key — avoids
        # accidentally printing secrets to the terminal.
        print(f"  Found {name} in environment: {existing[:8]}...")
        use = input("  Use existing value? [Y/n] ").strip().lower()
        if use != "n":
            return existing
    return input(f"  {prompt_msg}: ").strip()


def set_env_vars(url: str, key: str) -> None:
    """Append env var exports to the user's shell rc file."""
    rc_file = get_shell_rc()

    if not rc_file.exists():
        rc_file.touch()

    content = rc_file.read_text()
    lines_to_add = []

    # Replace or append QDRANT_URL
    if "export QDRANT_URL=" in content:
        # Use a callable replacement to avoid re.sub interpreting backslash
        # sequences (e.g. \1) in the replacement string.
        content = re.sub(
            r'export QDRANT_URL="[^"]*"',
            lambda _: f'export QDRANT_URL="{url}"',
            content,
        )
        print(f"  Updated QDRANT_URL in {rc_file}")
    else:
        lines_to_add.append(f'export QDRANT_URL="{url}"')

    # Replace or append QDRANT_API_KEY
    if "export QDRANT_API_KEY=" in content:
        content = re.sub(
            r'export QDRANT_API_KEY="[^"]*"',
            lambda _: f'export QDRANT_API_KEY="{key}"',
            content,
        )
        print(f"  Updated QDRANT_API_KEY in {rc_file}")
    else:
        lines_to_add.append(f'export QDRANT_API_KEY="{key}"')

    if lines_to_add:
        # Ensure there is a blank line before the new block regardless of
        # whether the rc file already ends with a newline.
        separator = "\n" if content.endswith("\n") else "\n\n"
        block = (
            separator
            + "# Marvin Knowledge Base (Qdrant Cloud)\n"
            + "\n".join(lines_to_add)
            + "\n"
        )
        content += block
        print(f"  Added Qdrant env vars to {rc_file}")

    rc_file.write_text(content)
    print(f"\n  Run: source {rc_file}")


def check_setup() -> bool:
    """Verify env vars are set and MCP server is reachable."""
    ok = True

    url = os.environ.get("QDRANT_URL")
    key = os.environ.get("QDRANT_API_KEY")

    if not url:
        print("  QDRANT_URL is not set")
        ok = False
    else:
        print(f"  QDRANT_URL = {url[:30]}...")

    if not key:
        print("  QDRANT_API_KEY is not set")
        ok = False
    else:
        print(f"  QDRANT_API_KEY = {key[:8]}...")

    # Check if mcp-server-qdrant is available via uvx
    try:
        result = subprocess.run(
            ["uvx", "--help"],
            capture_output=True,
            timeout=10,
        )
        if result.returncode == 0:
            print("  uvx is available")
        else:
            print("  uvx not found — install uv first: https://docs.astral.sh/uv/")
            ok = False
    except FileNotFoundError:
        print("  uvx not found — install uv first: https://docs.astral.sh/uv/")
        ok = False
    except subprocess.TimeoutExpired:
        print("  uvx timed out")
        ok = False

    if ok:
        print(
            "\n  Setup looks good. Restart Claude Code to pick up the new MCP server."
        )
    else:
        print("\n  Setup incomplete. Run: python scripts/setup_kb.py")

    return ok


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Set up Qdrant Cloud env vars for Marvin's shared knowledge base.",
    )
    parser.add_argument("--url", help="Qdrant Cloud URL (https://...)")
    parser.add_argument("--key", help="Qdrant Cloud API key")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify env vars are set and MCP server is reachable",
    )
    args = parser.parse_args()

    print("Marvin Knowledge Base Setup\n")

    if args.check:
        sys.exit(0 if check_setup() else 1)

    url = read_env_var("QDRANT_URL", args.url, "Qdrant Cloud URL (https://...)")
    if not validate_url(url):
        print(f"  Invalid URL: {url} (must start with https://)")
        sys.exit(1)

    key = read_env_var("QDRANT_API_KEY", args.key, "Qdrant Cloud API key")
    if not key:
        print("  API key cannot be empty")
        sys.exit(1)

    set_env_vars(url, key)


if __name__ == "__main__":
    main()
