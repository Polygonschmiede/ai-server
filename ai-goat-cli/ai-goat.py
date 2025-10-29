#!/usr/bin/env python3
"""
AI GOAT - Greatest Of All Tech
Interactive CLI for AI Server Management
"""

import sys
import os

# Add lib directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Header, Footer, Static, Button, Label, DataTable, TabbedContent, TabPane
from textual.reactive import reactive
from textual import work
from rich.text import Text
from rich.console import RenderableType
import asyncio
from datetime import datetime, timedelta

# Import our modules
from monitoring import SystemMonitor
from power import PowerManager
from system import SystemManager
from remote import RemoteManager
from system_ui import SystemManagementUI


class GoatHeader(Static):
    """Custom header with ASCII goat"""

    def compose(self) -> ComposeResult:
        goat_art = """[bold cyan]
    ___
   (o o)     AI GOAT - Greatest Of All Tech
   (  V  )    Your AI Server Command Center
  /--m-m-\\
[/bold cyan]"""
        yield Static(goat_art, id="goat-logo")


class SystemStatus(Static):
    """Real-time system status display"""

    status_text = reactive("")

    def __init__(self):
        super().__init__()
        self.monitor = SystemMonitor()

    def on_mount(self) -> None:
        self.update_status()
        self.set_interval(2.0, self.update_status)

    def update_status(self) -> None:
        stats = self.monitor.get_stats()

        # Build status text with colors
        lines = [
            f"[bold cyan]═══ System Status ═══[/bold cyan]",
            "",
            f"[yellow]GPU:[/yellow]",
            f"  Power: [bold green]{stats['gpu_power']:.1f}W[/bold green] / {stats['gpu_power_limit']:.0f}W",
            f"  Temp:  [bold cyan]{stats['gpu_temp']}°C[/bold cyan]",
            f"  Usage: [bold magenta]{stats['gpu_util']}%[/bold magenta]",
            f"  VRAM:  {stats['gpu_memory_used']:.1f}GB / {stats['gpu_memory_total']:.1f}GB",
            "",
            f"[yellow]CPU:[/yellow]",
            f"  Usage: [bold magenta]{stats['cpu_percent']}%[/bold magenta]",
            f"  Cores: {stats['cpu_count']}",
            "",
            f"[yellow]Memory:[/yellow]",
            f"  Used:  {stats['memory_used']:.1f}GB / {stats['memory_total']:.1f}GB",
            f"  Free:  {stats['memory_free']:.1f}GB",
            "",
            f"[yellow]Services:[/yellow]",
            f"  LocalAI: {'[green]●[/green] Running' if stats['localai_running'] else '[red]○[/red] Stopped'}",
            f"  Ollama:  {'[green]●[/green] Running' if stats['ollama_running'] else '[red]○[/red] Stopped'}",
        ]

        self.status_text = "\n".join(lines)

    def render(self) -> RenderableType:
        return self.status_text


class PowerStatus(Static):
    """Power management status display"""

    power_text = reactive("")

    def __init__(self):
        super().__init__()
        self.power_mgr = PowerManager()

    def on_mount(self) -> None:
        self.update_power()
        self.set_interval(5.0, self.update_power)

    def update_power(self) -> None:
        status = self.power_mgr.get_status()

        # Calculate time remaining
        if status['stay_awake_active']:
            remaining = status['stay_awake_remaining']
            time_str = f"{remaining // 60}m {remaining % 60}s"
            suspend_line = f"  [bold green]Stay Awake:[/bold green] {time_str} remaining"
        elif status['auto_suspend_enabled']:
            idle_minutes = status['idle_minutes']
            wait_minutes = status['wait_minutes']
            remaining = wait_minutes - idle_minutes

            if remaining > 0:
                time_str = f"{remaining} minutes"
                suspend_line = f"  [yellow]Auto-Suspend in:[/yellow] {time_str}"
            else:
                suspend_line = f"  [bold yellow]System will suspend soon...[/bold yellow]"
        else:
            suspend_line = f"  [dim]Auto-suspend disabled[/dim]"

        # Build power status
        lines = [
            f"[bold cyan]═══ Power Status ═══[/bold cyan]",
            "",
            f"[yellow]Total System Power:[/yellow]",
            f"  [bold green]{status['total_power']:.1f}W[/bold green]",
            "",
            f"[yellow]Auto-Suspend:[/yellow]",
            suspend_line,
            f"  Idle threshold: {status['wait_minutes']} min",
            f"  Current idle: {status['idle_minutes']} min",
            "",
            f"[yellow]Conditions:[/yellow]",
            f"  CPU Idle: {'[green]✓[/green]' if status['cpu_idle'] else '[red]✗[/red]'} {status['cpu_idle_percent']:.1f}% (need ≥{status['cpu_threshold']}%)",
            f"  GPU Idle: {'[green]✓[/green]' if status['gpu_idle'] else '[red]✗[/red]'} {status['gpu_util']:.1f}% (need ≤{status['gpu_threshold']}%)",
            f"  No SSH:   {'[green]✓[/green]' if not status['ssh_active'] else '[red]✗[/red]'}",
            f"  No API:   {'[green]✓[/green]' if not status['api_active'] else '[red]✗[/red]'}",
        ]

        self.power_text = "\n".join(lines)

    def render(self) -> RenderableType:
        return self.power_text


class RemoteControl(Static):
    """Remote control options"""

    def __init__(self):
        super().__init__()
        self.remote_mgr = RemoteManager()

    def compose(self) -> ComposeResult:
        info = self.remote_mgr.get_info()

        yield Static(f"""[bold cyan]═══ Remote Control ═══[/bold cyan]

[yellow]Wake-on-LAN:[/yellow]
  MAC Address: [bold]{info['mac_address']}[/bold]
  Interface:   {info['wol_interface']}

[yellow]Stay-Awake Service:[/yellow]
  URL: [bold]http://{info['server_ip']}:{info['stay_awake_port']}/stay?s=SECONDS[/bold]

  Examples:
    [dim]# Keep awake for 1 hour[/dim]
    curl "http://{info['server_ip']}:{info['stay_awake_port']}/stay?s=3600"

    [dim]# Keep awake for 2 hours[/dim]
    curl "http://{info['server_ip']}:{info['stay_awake_port']}/stay?s=7200"

[yellow]Access URLs:[/yellow]
  LocalAI:  http://{info['server_ip']}:8080
  Ollama:   http://{info['server_ip']}:11434
  Open WebUI: http://{info['server_ip']}:3000
""")


class AIGoatApp(App):
    """Main AI GOAT application"""

    CSS = """
    #goat-logo {
        dock: top;
        height: 5;
        content-align: center middle;
        background: $panel;
    }

    SystemStatus {
        width: 1fr;
        height: 100%;
        border: solid cyan;
        padding: 1;
    }

    PowerStatus {
        width: 1fr;
        height: 100%;
        border: solid yellow;
        padding: 1;
    }

    RemoteControl {
        width: 100%;
        height: 100%;
        border: solid green;
        padding: 1;
    }

    #main-container {
        height: 100%;
    }

    TabPane {
        padding: 1;
    }

    #action-grid {
        grid-size: 3;
        grid-gutter: 1;
        height: auto;
        margin: 1 0;
    }

    #action-grid Button {
        width: 100%;
        height: 3;
    }

    #system-title {
        text-align: center;
        margin-bottom: 1;
    }

    #system-status {
        background: $panel;
        border: solid cyan;
        padding: 1;
        margin-bottom: 1;
        height: auto;
    }

    #system-output {
        background: $panel;
        border: solid green;
        padding: 1;
        margin-top: 1;
        height: auto;
        min-height: 10;
    }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("d", "toggle_dark", "Toggle Dark Mode"),
        ("1", "show_dashboard", "Dashboard"),
        ("2", "show_system", "System"),
        ("3", "show_remote", "Remote"),
    ]

    def compose(self) -> ComposeResult:
        yield GoatHeader()
        yield Header(show_clock=True)

        with TabbedContent(id="main-container"):
            with TabPane("Dashboard", id="tab-dashboard"):
                with Horizontal():
                    yield SystemStatus()
                    yield PowerStatus()

            with TabPane("System Management", id="tab-system"):
                yield SystemManagementUI()

            with TabPane("Remote Control", id="tab-remote"):
                yield RemoteControl()

        yield Footer()

    def action_toggle_dark(self) -> None:
        """Toggle dark mode"""
        self.dark = not self.dark

    def action_show_dashboard(self) -> None:
        """Show dashboard tab"""
        self.query_one(TabbedContent).active = "tab-dashboard"

    def action_show_system(self) -> None:
        """Show system management tab"""
        self.query_one(TabbedContent).active = "tab-system"

    def action_show_remote(self) -> None:
        """Show remote control tab"""
        self.query_one(TabbedContent).active = "tab-remote"


def main():
    """Main entry point"""
    app = AIGoatApp()
    app.run()


if __name__ == "__main__":
    main()
