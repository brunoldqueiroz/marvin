#!/usr/bin/env python3
"""Marvin CLI — manage your Claude Code orchestration layer."""

from __future__ import annotations

import importlib.metadata
import importlib.resources
import json
import os
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import urllib.request
from collections import Counter
from pathlib import Path

import click
from loguru import logger
from rich.console import Console
from rich.table import Table

GITHUB_REPO = "brunoldqueiroz/marvin"
INIT_EXCLUDE = {"dev", "settings.local.json"}


# ---------------------------------------------------------------------------
# Data resolution
# ---------------------------------------------------------------------------

def _resolve_data_dir() -> Path:
    """Resolve the bundled .claude/ directory.

    Resolution chain:
    1. MARVIN_DATA env var (testing / override)
    2. Source tree — Path(__file__).parent.parent / ".claude" (dev mode)
    3. Installed package data — importlib.resources
    """
    if "MARVIN_DATA" in os.environ:
        return Path(os.environ["MARVIN_DATA"])
    source_root = Path(__file__).resolve().parent.parent
    if (source_root / ".claude").exists():
        return source_root / ".claude"
    try:
        pkg = importlib.resources.files("cli") / "_data" / ".claude"
        pkg_path = Path(str(pkg))
        if pkg_path.exists():
            return pkg_path
    except (TypeError, FileNotFoundError):
        pass
    return source_root / ".claude"


DATA_DIR = _resolve_data_dir()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_version() -> str:
    """Get version: installed metadata first, then CHANGELOG.md fallback."""
    try:
        return importlib.metadata.version("marvin-cli")
    except importlib.metadata.PackageNotFoundError:
        pass
    changelog = Path(__file__).resolve().parent.parent / "CHANGELOG.md"
    if not changelog.exists():
        return "unknown"
    pattern = re.compile(r"^## \[(\d+\.\d+\.\d+)\]")
    for line in changelog.read_text().splitlines():
        m = pattern.match(line)
        if m:
            return m.group(1)
    return "unknown"


def parse_frontmatter(path: Path) -> dict[str, str]:
    """Extract name and description from YAML frontmatter between --- markers."""
    text = path.read_text()
    if not text.startswith("---"):
        return {}
    end = text.find("---", 3)
    if end == -1:
        return {}
    block = text[3:end]

    result: dict[str, str] = {}
    lines = block.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^(\w[\w-]*):\s*(.*)", line)
        if m:
            key, value = m.group(1), m.group(2).strip()
            if value == ">" or value == "|":
                parts: list[str] = []
                i += 1
                while i < len(lines) and (lines[i].startswith("  ") or lines[i].strip() == ""):
                    parts.append(lines[i].strip())
                    i += 1
                result[key] = " ".join(p for p in parts if p)
                continue
            else:
                result[key] = value
        i += 1
    return result


def _list_entries(kind: str, subdir: str, filename: str) -> None:
    """List agents or skills from DATA_DIR as a rich table."""
    entries_dir = DATA_DIR / subdir
    if not entries_dir.exists():
        logger.error(f"{kind} directory not found: {entries_dir}")
        raise SystemExit(1)
    entries: list[tuple[str, str]] = []
    for entry_dir in sorted(entries_dir.iterdir()):
        md = entry_dir / filename
        if md.exists():
            fm = parse_frontmatter(md)
            name = fm.get("name", entry_dir.name)
            desc = fm.get("description", "")
            # Truncate at first sentence boundary for clean display
            short = desc.split(". Use when:")[0].split(". Use for:")[0]
            if short != desc:
                short += "."
            entries.append((name, short))
    if not entries:
        logger.warning(f"No {kind} found.")
        return

    table = Table(title=f"{kind.capitalize()} ({len(entries)})")
    table.add_column("Name", style="cyan", no_wrap=True)
    table.add_column("Description")
    for name, desc in entries:
        table.add_row(name, desc)

    Console(stderr=True).print(table)


def _download_claude_dir(ref: str = "main") -> Path:
    """Download .claude/ from GitHub tarball. Returns path to tempdir containing .claude/."""
    url = f"https://github.com/{GITHUB_REPO}/archive/refs/heads/{ref}.tar.gz"
    tmpdir = Path(tempfile.mkdtemp(prefix="marvin-"))
    tarpath = tmpdir / "archive.tar.gz"
    try:
        logger.info("Downloading from GitHub ({})...", ref)
        urllib.request.urlretrieve(url, tarpath)  # noqa: S310
    except Exception as exc:
        shutil.rmtree(tmpdir, ignore_errors=True)
        logger.error("Download failed: {}", exc)
        raise SystemExit(1)

    try:
        with tarfile.open(tarpath) as tf:
            # Safety: reject absolute paths and path traversal
            for member in tf.getmembers():
                if member.name.startswith("/") or ".." in member.name:
                    shutil.rmtree(tmpdir, ignore_errors=True)
                    logger.error("Refusing to extract tarball with unsafe paths")
                    raise SystemExit(1)
            tf.extractall(tmpdir)  # noqa: S202
    except tarfile.TarError as exc:
        shutil.rmtree(tmpdir, ignore_errors=True)
        logger.error("Failed to extract archive: {}", exc)
        raise SystemExit(1)

    tarpath.unlink()

    # Find the extracted .claude/ — it's inside marvin-{ref}/
    for child in tmpdir.iterdir():
        candidate = child / ".claude"
        if candidate.is_dir():
            return tmpdir
    shutil.rmtree(tmpdir, ignore_errors=True)
    logger.error("No .claude/ directory found in archive")
    raise SystemExit(1)


def _find_claude_in_download(tmpdir: Path) -> Path:
    """Find the .claude/ directory inside the extracted tarball."""
    for child in tmpdir.iterdir():
        candidate = child / ".claude"
        if candidate.is_dir():
            return candidate
    logger.error("No .claude/ directory found in download")
    raise SystemExit(1)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

@click.group()
@click.version_option(version=get_version(), prog_name="marvin")
def cli():
    """Marvin — Claude Code orchestration layer CLI."""


@cli.command()
@click.argument("path", default=".", type=click.Path())
@click.option("--force", is_flag=True, help="Overwrite existing .claude/ without prompting")
@click.option("--latest", is_flag=True, help="Download latest from GitHub instead of bundled data")
@click.option("--ref", default=None, help="Download specific Git ref (implies --latest)")
def init(path: str, force: bool, latest: bool, ref: str | None) -> None:
    """Initialize Marvin in a project directory."""
    target = Path(path).resolve()
    dest = target / ".claude"

    # Determine source
    tmpdir = None
    if ref:
        latest = True
    if latest:
        tmpdir = _download_claude_dir(ref=ref or "main")
        source = _find_claude_in_download(tmpdir)
    else:
        source = DATA_DIR
        if not source.exists():
            logger.error("Bundled data not found: {}", source)
            logger.error("Try: marvin init --latest")
            raise SystemExit(1)

    try:
        if dest.exists() and not force:
            answer = input(f"{dest} already exists. Overwrite? [y/N] ").strip().lower()
            if answer != "y":
                logger.info("Aborted.")
                return
            shutil.rmtree(dest)

        def ignore(directory: str, contents: list[str]) -> set[str]:
            rel = os.path.relpath(directory, source)
            if rel == ".":
                return {c for c in contents if c in INIT_EXCLUDE}
            return set()

        shutil.copytree(source, dest, ignore=ignore, dirs_exist_ok=force)

        # Ensure hooks are executable
        hooks_dir = dest / "hooks"
        if hooks_dir.exists():
            for hook in hooks_dir.iterdir():
                if hook.is_file() and hook.suffix == ".sh":
                    hook.chmod(hook.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

        logger.info("Initialized Marvin at {}", dest)
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)


@cli.command()
def agents() -> None:
    """List available agents."""
    _list_entries("agents", "agents", "AGENT.md")


@cli.command()
def skills() -> None:
    """List available skills."""
    _list_entries("skills", "skills", "SKILL.md")


@cli.command()
@click.argument("path", default=".", type=click.Path(exists=True))
@click.option("--json", "as_json", is_flag=True, help="Output as JSON")
def metrics(path: str, as_json: bool) -> None:
    """Analyze .claude/dev/metrics.jsonl and print insights."""
    target = Path(path).resolve()
    metrics_file = target / ".claude" / "dev" / "metrics.jsonl"
    if not metrics_file.exists():
        logger.error("metrics file not found: {}", metrics_file)
        raise SystemExit(1)

    events: list[dict] = []
    for line in metrics_file.read_text().splitlines():
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    if not events:
        logger.error("no events found in metrics file")
        raise SystemExit(1)

    # Categorize events
    sessions_start = [e for e in events if e.get("event") == "session_start"]
    tool_uses = [e for e in events if e.get("event") == "tool_use"]
    tool_failures = [e for e in events if e.get("event") == "tool_failure"]
    subagent_stops = [e for e in events if e.get("event") == "subagent_stop"]

    # Session stats
    session_ids = {e.get("session") for e in events if e.get("session")}
    model_counts = Counter(e.get("model", "unknown") for e in sessions_start)

    # Tool stats
    tool_counts = Counter(e.get("tool", "unknown") for e in tool_uses)
    total_tools = len(tool_uses)

    # Failure stats
    failure_counts = Counter(e.get("tool", "unknown") for e in tool_failures)
    total_failures = len(tool_failures)
    failure_rate = (total_failures / total_tools * 100) if total_tools else 0

    # Agent stats
    agent_counts = Counter(e.get("agent", "unknown") for e in subagent_stops)
    agent_pass = Counter(
        e.get("agent", "unknown") for e in subagent_stops if e.get("status") == "pass"
    )
    agent_fail = Counter(
        e.get("agent", "unknown") for e in subagent_stops if e.get("status") != "pass"
    )
    output_lens = [e.get("output_len", 0) for e in subagent_stops if e.get("output_len")]
    avg_output = int(sum(output_lens) / len(output_lens)) if output_lens else 0
    artifact_count = sum(1 for e in subagent_stops if e.get("has_artifact"))
    artifact_rate = (artifact_count / len(subagent_stops) * 100) if subagent_stops else 0

    if as_json:
        stats = {
            "path": str(target),
            "sessions": {
                "total": len(session_ids),
                "models": dict(model_counts),
            },
            "tools": {
                "total": total_tools,
                "counts": dict(tool_counts.most_common()),
            },
            "failures": {
                "total": total_failures,
                "rate": round(failure_rate, 1),
                "counts": dict(failure_counts),
            },
            "agents": {
                "total": len(subagent_stops),
                "counts": dict(agent_counts),
                "pass": dict(agent_pass),
                "fail": dict(agent_fail),
                "avg_output_len": avg_output,
                "artifact_rate": round(artifact_rate),
            },
        }
        logger.info(json.dumps(stats, indent=2))
        return

    # Pretty print
    def bar(count: int, max_count: int, width: int = 20) -> str:
        if max_count == 0:
            return ""
        length = int(count / max_count * width)
        return "\u2588" * length

    logger.info("")
    logger.info("Marvin Metrics \u2014 {}", target)
    logger.info("\u2550" * 40)

    # Sessions
    logger.info("")
    logger.info("Sessions: {} total", len(session_ids))
    if model_counts:
        models_str = ", ".join(f"{m} ({c})" for m, c in model_counts.most_common())
        logger.info("  Models: {}", models_str)

    # Tools
    logger.info("")
    logger.info("Tools: {} calls across {} sessions", f"{total_tools:,}", len(session_ids))
    if tool_counts:
        top = tool_counts.most_common(10)
        max_val = top[0][1] if top else 1
        name_w = max(len(t) for t, _ in top)
        logger.info("  Top 10:")
        for tool, count in top:
            logger.info("    {}  {:4d}  {}", tool.ljust(name_w), count, bar(count, max_val))

    # Failures
    logger.info("")
    logger.info("Tool Failures: {} total ({:.1f}% failure rate)", total_failures, failure_rate)
    if failure_counts:
        for tool, count in failure_counts.most_common():
            logger.info("  {}: {}", tool, count)

    # Agents
    if subagent_stops:
        logger.info("")
        logger.info("Agents: {} invocations", len(subagent_stops))
        for agent, count in agent_counts.most_common():
            p = agent_pass.get(agent, 0)
            f = agent_fail.get(agent, 0)
            logger.info("  {} {:3d}  (pass: {}, fail: {})", agent.ljust(18), count, p, f)
        logger.info("  Avg output: {} chars", f"{avg_output:,}")
        logger.info("  Artifact rate: {:.0f}%", artifact_rate)

    logger.info("")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    logger.remove()
    logger.add(sys.stderr, format="{message}", level="INFO")
    cli()


if __name__ == "__main__":
    main()
