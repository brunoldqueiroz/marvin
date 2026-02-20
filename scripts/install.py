#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "typer>=0.12",
#     "python-dotenv>=1.0",
#     "rich>=13.0",
# ]
# ///
"""install.py — Install Marvin to a project's .claude/ directory.

Copies/links Marvin's core layer to <project-path>/.claude/ and resolves
MCP server API keys from a .env file.

Usage:
  uv run scripts/install.py <project-path>
  uv run scripts/install.py <project-path> --dev
  uv run scripts/install.py <project-path> --force
  uv run scripts/install.py <project-path> --dry-run
"""

from __future__ import annotations

import json
import re
import shutil
import stat
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Annotated

import typer
from dotenv import dotenv_values
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


@dataclass
class Config:
    project_path: Path
    core_dir: Path
    repo_dir: Path
    dev_mode: bool = False
    force: bool = False
    dry_run: bool = False


@dataclass
class InstallRecord:
    """Tracks what happened to each file/directory during installation."""

    name: str
    action: str  # COPY, LINK, SKIP, BACKUP, UPDATE, CLEANUP
    status: str  # ok, warn, skip
    detail: str = ""


@dataclass
class StepResult:
    records: list[InstallRecord] = field(default_factory=list)

    def add(self, name: str, action: str, status: str, detail: str = "") -> None:
        self.records.append(InstallRecord(name, action, status, detail))


# ---------------------------------------------------------------------------
# Key utilities
# ---------------------------------------------------------------------------


def mask_key(value: str) -> str:
    """Mask an API key for display, showing first 3 and last 5 chars."""
    if len(value) <= 8:
        return "****"
    return f"{value[:3]}****{value[-5:]}"


def is_placeholder(value: str) -> bool:
    """Return True if value looks like a template placeholder rather than a real key."""
    markers = {"your-", "placeholder", "xxx", "change-me", "insert-", "todo"}
    lower = value.lower()
    return any(m in lower for m in markers)


def resolve_template(template: str, env_vars: dict[str, str]) -> str:
    """Replace ${VAR} patterns in template with values from env_vars.

    Variables not present in env_vars are left as-is.
    """

    def replacer(match: re.Match) -> str:  # type: ignore[type-arg]
        var_name = match.group(1)
        return env_vars.get(var_name, match.group(0))

    return re.sub(r"\$\{(\w+)\}", replacer, template)


# ---------------------------------------------------------------------------
# File operations
# ---------------------------------------------------------------------------


def backup_if_needed(path: Path, dry_run: bool) -> str | None:
    """Back up a file if it exists and wasn't installed by Marvin.

    Returns the backup filename if a backup was made, None otherwise.
    """
    if not path.is_file():
        return None
    content = path.read_text(encoding="utf-8", errors="replace")
    if "MARVIN" in content:
        return None  # Already ours — no backup needed
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = path.with_name(f"{path.name}.backup.{timestamp}")
    if not dry_run:
        shutil.copy2(path, backup)
    return backup.name


def install_file(src: Path, dst: Path, dry_run: bool) -> None:
    """Copy a single file to dst, creating parent directories as needed."""
    if dry_run:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def install_dir(src: Path, dst: Path, dry_run: bool) -> None:
    """Copy a directory to dst (non-dev mode)."""
    if dry_run:
        return
    dst.mkdir(parents=True, exist_ok=True)
    for item in src.iterdir():
        dest_item = dst / item.name
        if item.is_dir():
            shutil.copytree(item, dest_item, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dest_item)


def link_dir(src: Path, dst: Path, dry_run: bool) -> None:
    """Symlink src directory at dst (dev mode)."""
    if dry_run:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        if dst.is_symlink() or dst.is_file():
            dst.unlink()
        else:
            shutil.rmtree(dst)
    dst.symlink_to(src)


def deploy_dir(src: Path, dst: Path, dev_mode: bool, dry_run: bool) -> None:
    """Deploy a directory: symlink in dev mode, copy otherwise."""
    if dev_mode:
        link_dir(src, dst, dry_run)
    else:
        install_dir(src, dst, dry_run)


def chmod_executable(path: Path) -> None:
    """Add executable bit to a file (equivalent to chmod +x)."""
    current = path.stat().st_mode
    path.chmod(current | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


# ---------------------------------------------------------------------------
# Installation steps
# ---------------------------------------------------------------------------


def step_1_claude_md(cfg: Config, target: Path) -> StepResult:
    """[1/8] CLAUDE.md — always copied, even in dev mode."""
    result = StepResult()
    src = cfg.core_dir / "CLAUDE.md"
    dst = target / "CLAUDE.md"
    backup_name = backup_if_needed(dst, cfg.dry_run)
    if backup_name:
        result.add(backup_name, "BACKUP", "warn", "previous version saved")
    action = "COPY"
    install_file(src, dst, cfg.dry_run)
    result.add("CLAUDE.md", action, "ok")
    return result


def step_2_registry(cfg: Config, target: Path) -> StepResult:
    """[2/8] Registry."""
    result = StepResult()
    action = "LINK" if cfg.dev_mode else "COPY"
    deploy_dir(
        cfg.core_dir / "registry", target / "registry", cfg.dev_mode, cfg.dry_run
    )
    result.add("registry/", action, "ok")
    return result


def step_3_templates(cfg: Config, target: Path) -> StepResult:
    """[3/8] Templates."""
    result = StepResult()
    action = "LINK" if cfg.dev_mode else "COPY"
    deploy_dir(
        cfg.core_dir / "templates", target / "templates", cfg.dev_mode, cfg.dry_run
    )
    result.add("templates/", action, "ok")
    return result


def step_4_agents(cfg: Config, target: Path) -> StepResult:
    """[4/8] Agents."""
    result = StepResult()
    action = "LINK" if cfg.dev_mode else "COPY"
    deploy_dir(cfg.core_dir / "agents", target / "agents", cfg.dev_mode, cfg.dry_run)
    result.add("agents/", action, "ok")
    return result


def step_5_skills(cfg: Config, target: Path) -> StepResult:
    """[5/8] Skills."""
    result = StepResult()
    action = "LINK" if cfg.dev_mode else "COPY"
    deploy_dir(cfg.core_dir / "skills", target / "skills", cfg.dev_mode, cfg.dry_run)
    result.add("skills/", action, "ok")
    return result


def step_6_rules(cfg: Config, target: Path) -> StepResult:
    """[6/8] Rules + cleanup of migrated domain rules."""
    result = StepResult()
    action = "LINK" if cfg.dev_mode else "COPY"
    deploy_dir(cfg.core_dir / "rules", target / "rules", cfg.dev_mode, cfg.dry_run)
    result.add("rules/", action, "ok")

    migrated = ["aws.md", "dbt.md", "spark.md", "snowflake.md", "airflow.md"]
    for name in migrated:
        old_rule = target / "rules" / name
        if old_rule.is_file():
            if not cfg.dry_run:
                old_rule.unlink()
            result.add(f"rules/{name}", "CLEANUP", "warn", "migrated rule removed")

    return result


def step_7_settings_hooks_memory(cfg: Config, target: Path) -> StepResult:
    """[7/8] Settings, Hooks, Memory."""
    result = StepResult()

    # settings.json — always copy (with backup)
    settings_dst = target / "settings.json"
    backup_name = backup_if_needed(settings_dst, cfg.dry_run)
    if backup_name:
        result.add(backup_name, "BACKUP", "warn", "previous version saved")
    install_file(cfg.core_dir / "settings.json", settings_dst, cfg.dry_run)
    result.add("settings.json", "COPY", "ok")

    # hooks — copy or symlink
    hooks_action = "LINK" if cfg.dev_mode else "COPY"
    deploy_dir(cfg.core_dir / "hooks", target / "hooks", cfg.dev_mode, cfg.dry_run)
    result.add("hooks/", hooks_action, "ok")

    # Make hooks executable
    if not cfg.dry_run:
        hooks_dir = target / "hooks"
        if hooks_dir.is_dir():
            for hook in hooks_dir.glob("*.sh"):
                try:
                    chmod_executable(hook)
                except OSError:
                    pass  # Best-effort — matches bash's `|| true`

    # memory.md — never overwrite
    memory_dst = target / "memory.md"
    if memory_dst.exists():
        result.add("memory.md", "SKIP", "skip", "already exists (preserved)")
    else:
        install_file(cfg.core_dir / "memory.md", memory_dst, cfg.dry_run)
        result.add("memory.md", "COPY", "ok")

    return result


@dataclass
class McpKeyStatus:
    name: str
    status: str  # ok, placeholder, missing
    masked_value: str = ""


def step_8_mcp(cfg: Config) -> tuple[StepResult, list[McpKeyStatus]]:
    """[8/8] MCP servers — resolve .env vars in template and deploy."""
    result = StepResult()
    key_statuses: list[McpKeyStatus] = []

    env_path = cfg.project_path / ".env"
    mcp_template_path = cfg.core_dir / ".mcp.json"
    mcp_dst = cfg.project_path / ".mcp.json"

    # Load template text (needed for both branches)
    template_text = mcp_template_path.read_text(encoding="utf-8")
    needed = set(re.findall(r"\$\{(\w+)\}", template_text))

    # Parse .env
    env_vars: dict[str, str] = {}
    if env_path.is_file():
        raw = dotenv_values(env_path)
        env_vars = {k: v for k, v in raw.items() if v is not None}
        for var in sorted(needed):
            if var not in env_vars:
                key_statuses.append(McpKeyStatus(name=var, status="missing"))
                result.add(f".env:{var}", "MISS", "warn", "not found in .env")
            elif is_placeholder(env_vars[var]):
                key_statuses.append(McpKeyStatus(name=var, status="placeholder"))
                result.add(f".env:{var}", "WARN", "warn", "placeholder value detected")
            else:
                key_statuses.append(
                    McpKeyStatus(
                        name=var, status="ok", masked_value=mask_key(env_vars[var])
                    )
                )
    else:
        result.add(".env", "MISS", "warn", "not found — deploying unresolved template")
        for var in sorted(needed):
            key_statuses.append(McpKeyStatus(name=var, status="missing"))

    # Resolve and write .mcp.json
    backup_name = backup_if_needed(mcp_dst, cfg.dry_run)
    if backup_name:
        result.add(backup_name, "BACKUP", "warn", "previous version saved")
    resolved = resolve_template(template_text, env_vars)

    if not cfg.dry_run:
        try:
            json.loads(resolved)
        except json.JSONDecodeError as exc:
            console.print(
                f"[red]ERROR[/red] Resolved .mcp.json is not valid JSON: {exc}"
            )
            raise typer.Exit(code=1)
        mcp_dst.write_text(resolved, encoding="utf-8")

    result.add(".mcp.json", "COPY", "ok", "env vars resolved")

    # .env.example — deploy only if .env doesn't exist
    env_example_src = cfg.repo_dir / ".env.example"
    env_example_dst = cfg.project_path / ".env.example"
    if env_path.is_file():
        result.add(
            ".env.example", "SKIP", "skip", ".env already exists (keys preserved)"
        )
    else:
        if not cfg.dry_run and env_example_src.is_file():
            shutil.copy2(env_example_src, env_example_dst)
        result.add(".env.example", "COPY", "ok", "copy to .env and add your API keys")

    # .gitignore — add .env entries if absent
    gitignore_path = cfg.project_path / ".gitignore"
    if gitignore_path.is_file():
        content = gitignore_path.read_text(encoding="utf-8")
        if not re.search(r"^\.env$", content, re.MULTILINE):
            if not cfg.dry_run:
                with gitignore_path.open("a", encoding="utf-8") as fh:
                    fh.write("\n# Secrets\n.env\n.env.local\n")
            result.add(".gitignore", "UPDATE", "ok", "added .env entries")

    return result, key_statuses


# ---------------------------------------------------------------------------
# Rich output helpers
# ---------------------------------------------------------------------------

STEP_LABELS = [
    "CLAUDE.md (Marvin's brain)",
    "Registry (agents + skills)",
    "Templates (for /new-agent, /new-skill, /new-rule)",
    "Agents + domain rules",
    "Universal skills (/init, /new-agent, /research, etc.)",
    "Universal rules (coding-standards, security, handoff-protocol)",
    "Settings, Hooks, Memory",
    "MCP servers (Context7, Exa)",
]


def print_step(n: int, label: str) -> None:
    console.print(f"[bold blue][{n}/8][/bold blue] {label}")


def print_record(rec: InstallRecord) -> None:
    if rec.status == "ok":
        detail = f"  [dim]{rec.detail}[/dim]" if rec.detail else ""
        console.print(f"  [green]v[/green] {rec.action:<8} {rec.name}{detail}")
    elif rec.status == "warn":
        detail = f"  [dim]{rec.detail}[/dim]" if rec.detail else ""
        console.print(f"  [yellow]![/yellow] {rec.action:<8} {rec.name}{detail}")
    else:
        detail = f"  [dim]{rec.detail}[/dim]" if rec.detail else ""
        console.print(f"  [dim]-        {rec.name}{detail}[/dim]")


def build_summary_table(all_records: list[InstallRecord]) -> Table:
    table = Table(title="Installation Summary", show_header=True, header_style="bold")
    table.add_column("File / Directory", style="cyan", no_wrap=True)
    table.add_column("Action", justify="center")
    table.add_column("Detail", style="dim")

    action_styles = {
        "COPY": "green",
        "LINK": "blue",
        "BACKUP": "yellow",
        "SKIP": "dim",
        "UPDATE": "green",
        "CLEANUP": "yellow",
        "MISS": "red",
        "WARN": "yellow",
    }

    for rec in all_records:
        style = action_styles.get(rec.action, "")
        action_cell = f"[{style}]{rec.action}[/{style}]" if style else rec.action
        table.add_row(rec.name, action_cell, rec.detail)

    return table


def build_mcp_table(key_statuses: list[McpKeyStatus]) -> Table:
    table = Table(title="MCP API Keys", show_header=True, header_style="bold")
    table.add_column("Key", style="cyan", no_wrap=True)
    table.add_column("Status", justify="center")
    table.add_column("Value", style="dim")

    for ks in key_statuses:
        if ks.status == "ok":
            status_cell = "[green]READY[/green]"
            value_cell = ks.masked_value
        elif ks.status == "placeholder":
            status_cell = "[yellow]PLACEHOLDER[/yellow]"
            value_cell = "edit .env with a real key"
        else:
            status_cell = "[red]MISSING[/red]"
            value_cell = "not found in .env"
        table.add_row(ks.name, status_cell, value_cell)

    return table


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


def install_project(cfg: Config) -> None:
    """Run all 8 installation steps."""
    target = cfg.project_path / ".claude"
    mode_label = "DEV (symlinks)" if cfg.dev_mode else "COPY"
    dry_label = (
        "  [yellow][DRY RUN — no files will be modified][/yellow]"
        if cfg.dry_run
        else ""
    )

    # Banner
    banner_text = (
        "[bold]MARVIN[/bold] — Project Installation\n\n"
        f"[dim]Source:[/dim]      {cfg.core_dir}\n"
        f"[dim]Destination:[/dim] {target}\n"
        f"[dim]Mode:[/dim]        {mode_label}"
        + (f"\n{dry_label}" if dry_label else "")
    )
    console.print(Panel(banner_text, style="bold blue", expand=False))
    console.print()

    # Confirmation prompt
    if not cfg.force and not cfg.dry_run:
        console.print(f"This will install Marvin to [cyan]{target}[/cyan].")
        console.print("Existing files will be backed up before overwriting.")
        console.print()
        try:
            confirmed = typer.confirm("Continue?", default=True)
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]Aborted.[/dim]")
            raise typer.Exit(code=0)
        if not confirmed:
            console.print("[dim]Aborted.[/dim]")
            raise typer.Exit(code=0)
        console.print()

    # Create base .claude/ directory
    if not cfg.dry_run:
        target.mkdir(parents=True, exist_ok=True)

    all_records: list[InstallRecord] = []
    key_statuses: list[McpKeyStatus] = []

    steps = [
        (1, STEP_LABELS[0], lambda: step_1_claude_md(cfg, target)),
        (2, STEP_LABELS[1], lambda: step_2_registry(cfg, target)),
        (3, STEP_LABELS[2], lambda: step_3_templates(cfg, target)),
        (4, STEP_LABELS[3], lambda: step_4_agents(cfg, target)),
        (5, STEP_LABELS[4], lambda: step_5_skills(cfg, target)),
        (6, STEP_LABELS[5], lambda: step_6_rules(cfg, target)),
        (7, STEP_LABELS[6], lambda: step_7_settings_hooks_memory(cfg, target)),
    ]

    for n, label, fn in steps:
        print_step(n, label)
        step_result: StepResult = fn()
        for rec in step_result.records:
            print_record(rec)
        all_records.extend(step_result.records)
        console.print()

    # Step 8 returns key statuses too
    print_step(8, STEP_LABELS[7])
    mcp_result, key_statuses = step_8_mcp(cfg)
    for rec in mcp_result.records:
        print_record(rec)
    all_records.extend(mcp_result.records)
    console.print()

    # MCP key summary table
    if key_statuses:
        console.print(build_mcp_table(key_statuses))
        console.print()

    # Installation summary table
    console.print(build_summary_table(all_records))
    console.print()

    # Footer
    if cfg.dry_run:
        footer_text = "[yellow]DRY RUN COMPLETE — No files were modified[/yellow]"
    else:
        footer_text = "[green]MARVIN INSTALLED![/green]"

    env_path = cfg.project_path / ".env"
    env_hint = ""
    if not env_path.is_file():
        env_hint = (
            "\n[dim]  cp .env.example .env   # Add your API keys[/dim]"
            "\n[dim]  source .env            # Or add to ~/.zshrc[/dim]"
        )

    quickstart = (
        f"{footer_text}\n\n"
        "[bold]Quick start:[/bold]\n"
        f"[dim]  cd {cfg.project_path}[/dim]"
        + env_hint
        + "\n[dim]  claude[/dim]"
        + "\n[dim]  > Hello Marvin![/dim]"
        + "\n\n[bold]To customize:[/bold]\n"
        "[dim]  > /init data-pipeline    # For data engineering projects[/dim]\n"
        "[dim]  > /init ai-ml            # For AI/ML projects[/dim]\n"
        "[dim]  > /init                  # For generic projects[/dim]\n"
        "\n[bold]To extend Marvin:[/bold]\n"
        "[dim]  > /new-agent <name> <description>[/dim]\n"
        "[dim]  > /new-skill <name> <description>[/dim]\n"
        "[dim]  > /new-rule <domain>[/dim]"
    )
    console.print(Panel(quickstart, style="bold blue", expand=False))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

app = typer.Typer(
    name="install.py",
    help="Install Marvin to <project-path>/.claude/.",
    add_completion=False,
)


@app.command()
def main(
    project_path: Annotated[
        Path,
        typer.Argument(
            help="Target project directory",
            metavar="<project-path>",
        ),
    ],
    dev: Annotated[
        bool,
        typer.Option("--dev", help="Dev mode: symlink directories, copy files"),
    ] = False,
    force: Annotated[
        bool,
        typer.Option("--force", help="Skip confirmation prompts"),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Preview changes without modifying anything"),
    ] = False,
) -> None:
    # Resolve project path
    if not project_path.is_dir():
        console.print(f"[red]ERROR[/red] Directory does not exist: {project_path}")
        raise typer.Exit(code=1)
    project_path = project_path.resolve()

    # Locate repo root (two levels up from this script: scripts/ -> repo root)
    repo_dir = Path(__file__).resolve().parent.parent
    core_dir = repo_dir / "core"

    if not core_dir.is_dir():
        console.print(f"[red]ERROR[/red] core/ directory not found at {core_dir}")
        console.print(
            "[dim]Make sure you're running this from the marvin repo root.[/dim]"
        )
        raise typer.Exit(code=1)

    cfg = Config(
        project_path=project_path,
        core_dir=core_dir,
        repo_dir=repo_dir,
        dev_mode=dev,
        force=force,
        dry_run=dry_run,
    )

    install_project(cfg)


if __name__ == "__main__":
    app()
