#!/usr/bin/env python3
"""Marvin Dashboard — live Textual TUI for metrics.jsonl."""

from __future__ import annotations

import json
import time
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from rich.text import Text
from textual import work
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import DataTable, Footer, Header, RichLog, Static


# ---------------------------------------------------------------------------
# MetricsStore — in-memory aggregation
# ---------------------------------------------------------------------------

@dataclass
class MetricsStore:
    """Aggregates metrics events into counters and lists."""

    total: int = 0

    # Sessions: session_id -> {model, tools}
    sessions: dict[str, dict] = field(default_factory=dict)

    # Tools
    tool_counts: Counter = field(default_factory=Counter)
    tool_total: int = 0

    # Failures
    failure_total: int = 0
    mcp_errors: int = 0
    interrupts: int = 0

    # Subagents: list of dicts
    subagents: list[dict] = field(default_factory=list)

    # User prompts: list of dicts
    prompts: list[dict] = field(default_factory=list)

    def ingest(self, event: dict) -> str | None:
        """Process one event, update counters. Returns event type or None."""
        self.total += 1
        ev = event.get("event")
        sid = event.get("session", "")

        if ev == "session_start":
            self.sessions.setdefault(sid, {"model": event.get("model", "?"), "tools": 0})

        elif ev == "tool_use":
            self.tool_counts[event.get("tool", "?")] += 1
            self.tool_total += 1
            if sid in self.sessions:
                self.sessions[sid]["tools"] += 1

        elif ev == "tool_failure":
            self.failure_total += 1
            if event.get("is_interrupt"):
                self.interrupts += 1

        elif ev == "subagent_stop":
            self.subagents.append(event)

        elif ev == "subagent_start":
            pass  # tracked via subagent_stop

        elif ev == "user_prompt":
            self.prompts.append(event)

        elif ev == "notification":
            if event.get("notification_type") == "mcp_error":
                self.mcp_errors += 1

        return ev


# ---------------------------------------------------------------------------
# Color-coded feed formatting
# ---------------------------------------------------------------------------

_EVENT_STYLES: dict[str, tuple[str, str]] = {
    "tool_use": ("TOOL", "cyan"),
    "tool_failure": ("FAIL", "red bold"),
    "subagent_start": ("AGENT+", "magenta"),
    "subagent_stop": ("AGENT", "magenta"),
    "user_prompt": ("PROMPT", "green"),
    "session_start": ("START", "yellow bold"),
    "session_end": ("END", "yellow"),
    "notification": ("NOTE", "dim"),
}


def _format_feed_line(event: dict) -> Text:
    """Build a Rich Text line for the event feed."""
    ev = event.get("event", "?")
    ts = event.get("ts", "")[11:19]  # HH:MM:SS from ISO
    label, style = _EVENT_STYLES.get(ev, (ev.upper()[:6], ""))

    detail = ""
    if ev == "tool_use":
        tool = event.get("tool", "")
        fpath = event.get("file", "")
        if fpath:
            detail = f"{tool}  {Path(fpath).name}"
        elif event.get("cmd"):
            cmd = event["cmd"][:60].strip()
            detail = f"{tool}  {cmd}"
        else:
            detail = tool
    elif ev == "tool_failure":
        tool = event.get("tool", "")
        err = (event.get("error", "") or "")[:50]
        detail = f"{tool}  {err}"
    elif ev == "subagent_stop":
        agent = event.get("agent", "?")
        status = event.get("status", "?")
        detail = f"{agent} {status}"
    elif ev == "subagent_start":
        detail = event.get("agent", "?")
    elif ev == "user_prompt":
        prompt = event.get("prompt", "")[:40]
        detail = f'"{prompt}"'
    elif ev == "session_start":
        detail = event.get("model", "")
    elif ev == "session_end":
        detail = event.get("reason", "")

    line = Text()
    line.append(f"{ts} ", style="dim")
    line.append(f"{label:<7}", style=style)
    line.append(detail)
    return line


# ---------------------------------------------------------------------------
# MarvinDashboard — Textual App
# ---------------------------------------------------------------------------

DASHBOARD_CSS = """
Screen {
    layout: horizontal;
}

#sidebar {
    width: 44;
    dock: left;
    border-right: solid $accent;
    padding: 0 1;
}

#main {
    width: 1fr;
    padding: 0 1;
}

.panel-title {
    text-style: bold;
    color: $accent;
    margin: 1 0 0 0;
}

DataTable {
    height: auto;
    max-height: 14;
    margin-bottom: 1;
}

#errors-panel {
    margin: 1 0;
    height: auto;
}

#feed {
    height: 1fr;
    min-height: 10;
    border: solid $accent;
    margin-bottom: 1;
}

#prompts-table {
    max-height: 10;
}

#subagents-table {
    max-height: 10;
}
"""


class MarvinDashboard(App):
    """Live TUI dashboard for Marvin metrics."""

    CSS = DASHBOARD_CSS
    TITLE = "Marvin Dashboard"
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("c", "clear_feed", "Clear"),
        ("p", "toggle_pause", "Pause"),
        ("r", "refresh_all", "Refresh"),
    ]

    def __init__(self, metrics_path: Path) -> None:
        super().__init__()
        self.metrics_path = metrics_path
        self.store = MetricsStore()
        self._paused = False
        self._live = True

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(id="sidebar"):
                yield Static("Sessions", classes="panel-title")
                yield DataTable(id="sessions-table")
                yield Static("Tool Usage (top 15)", classes="panel-title")
                yield DataTable(id="tools-table")
                yield Static("", id="errors-panel")
            with Vertical(id="main"):
                yield Static("Event Feed", classes="panel-title")
                yield RichLog(id="feed", max_lines=1000, wrap=True, markup=True)
                yield Static("Subagents", classes="panel-title")
                yield DataTable(id="subagents-table")
                yield Static("User Prompts", classes="panel-title")
                yield DataTable(id="prompts-table")
        yield Footer()

    def on_mount(self) -> None:
        # Sessions table
        st = self.query_one("#sessions-table", DataTable)
        st.add_columns("Session", "Model", "Tools")
        st.cursor_type = "none"

        # Tools table
        tt = self.query_one("#tools-table", DataTable)
        tt.add_columns("Tool", "Cnt", "Bar")
        tt.cursor_type = "none"

        # Subagents table
        at = self.query_one("#subagents-table", DataTable)
        at.add_columns("Agent", "Status", "Output", "Artifact")
        at.cursor_type = "none"

        # Prompts table
        pt = self.query_one("#prompts-table", DataTable)
        pt.add_columns("Time", "Len", "Prompt")
        pt.cursor_type = "none"

        self._tail_metrics()

    # -- Worker: 2-phase loading -------------------------------------------

    @work(thread=True)
    def _tail_metrics(self) -> None:
        """Phase 1: read history. Phase 2: tail for new events."""
        path = self.metrics_path
        if not path.exists():
            self.call_from_thread(self._show_error, f"File not found: {path}")
            return

        # Phase 1: History
        batch_count = 0
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ev_type = self.store.ingest(event)
                batch_count += 1

                # Feed: batch every 50 lines
                if batch_count % 50 == 0:
                    self.call_from_thread(self._write_to_feed, event)
                # Tables: rebuild every 100 events
                if batch_count % 100 == 0:
                    self.call_from_thread(self._rebuild_all)

            offset = f.tell()

        # Final rebuild after history load
        self.call_from_thread(self._rebuild_all)
        self.call_from_thread(self._update_subtitle)

        # Phase 2: Tail with polling
        while self._live:
            time.sleep(0.5)
            if self._paused:
                continue
            try:
                with open(path) as f:
                    f.seek(offset)
                    new_data = f.read()
                    if not new_data:
                        continue
                    offset = f.tell()
            except OSError:
                continue

            for line in new_data.splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                self.store.ingest(event)
                self.call_from_thread(self._dispatch_event, event)

    # -- Dispatch + Rebuild ------------------------------------------------

    def _dispatch_event(self, event: dict) -> None:
        """Route a single new event to the appropriate panels."""
        self._write_to_feed(event)
        self._rebuild_all()
        self._update_subtitle()

    def _rebuild_all(self) -> None:
        """Rebuild all data tables from current store state."""
        self._rebuild_sessions()
        self._rebuild_tools()
        self._rebuild_errors()
        self._rebuild_subagents()
        self._rebuild_prompts()

    def _update_subtitle(self) -> None:
        status = "PAUSED" if self._paused else "LIVE"
        self.sub_title = f"{self.store.total} events | {status}"

    def _show_error(self, msg: str) -> None:
        feed = self.query_one("#feed", RichLog)
        feed.write(Text(msg, style="red bold"))

    # -- Panel rebuilders --------------------------------------------------

    def _rebuild_sessions(self) -> None:
        table = self.query_one("#sessions-table", DataTable)
        table.clear()
        for sid, info in list(self.store.sessions.items())[-20:]:
            short_id = sid[:8] if len(sid) > 8 else sid
            table.add_row(short_id, info["model"], str(info["tools"]))

    def _rebuild_tools(self) -> None:
        table = self.query_one("#tools-table", DataTable)
        table.clear()
        top = self.store.tool_counts.most_common(15)
        if not top:
            return
        max_val = top[0][1]
        for tool, count in top:
            bar_len = int(count / max_val * 12) if max_val else 0
            bar = "\u2588" * bar_len
            table.add_row(tool, str(count), bar)

    def _rebuild_errors(self) -> None:
        s = self.store
        total = s.tool_total + s.failure_total
        rate = (s.failure_total / total * 100) if total else 0
        panel = self.query_one("#errors-panel", Static)
        lines = [
            "[bold $accent]Errors[/]",
            f"  Failures: {s.failure_total} ({rate:.1f}%)",
            f"  MCP errors: {s.mcp_errors}",
            f"  Interrupts: {s.interrupts}",
        ]
        panel.update("\n".join(lines))

    def _rebuild_subagents(self) -> None:
        table = self.query_one("#subagents-table", DataTable)
        table.clear()
        for sa in self.store.subagents[-15:]:
            agent = sa.get("agent", "?")
            status = sa.get("status", "?")
            output = str(sa.get("output_len", 0))
            artifact = "Yes" if sa.get("has_artifact") else "No"
            table.add_row(agent, status, output, artifact)

    def _rebuild_prompts(self) -> None:
        table = self.query_one("#prompts-table", DataTable)
        table.clear()
        for p in self.store.prompts[-15:]:
            ts = p.get("ts", "")[11:16]  # HH:MM
            plen = str(p.get("prompt_len", 0))
            text = p.get("prompt", "")[:40]
            table.add_row(ts, plen, f'"{text}"')

    # -- Feed writer -------------------------------------------------------

    def _write_to_feed(self, event: dict) -> None:
        feed = self.query_one("#feed", RichLog)
        feed.write(_format_feed_line(event))

    # -- Actions -----------------------------------------------------------

    def action_clear_feed(self) -> None:
        feed = self.query_one("#feed", RichLog)
        feed.clear()

    def action_toggle_pause(self) -> None:
        self._paused = not self._paused
        self._update_subtitle()

    def action_refresh_all(self) -> None:
        self._rebuild_all()

    def on_unmount(self) -> None:
        self._live = False


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def run_dashboard(path: Path) -> None:
    """Launch the Marvin Dashboard TUI."""
    app = MarvinDashboard(path)
    app.run()


if __name__ == "__main__":
    import sys

    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    metrics_file = target.resolve() / ".claude" / "dev" / "metrics.jsonl"
    run_dashboard(metrics_file)
