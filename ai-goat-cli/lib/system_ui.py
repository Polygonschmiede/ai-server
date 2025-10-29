"""
System Management UI Module
Interactive system management interface
"""

import re
from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical, Grid
from textual.widgets import Button, Static, Label
from textual.reactive import reactive
from textual import work
from system import SystemManager


class SystemManagementUI(Container):
    """Interactive system management interface"""

    status_text = reactive("")
    output_text = reactive("")

    # ANSI escape code pattern
    ANSI_ESCAPE_PATTERN = re.compile(r'\x1b\[[0-9;]*m')

    def __init__(self):
        super().__init__()
        self.system_mgr = SystemManager()

    @staticmethod
    def strip_ansi_codes(text: str) -> str:
        """Remove ANSI escape codes from text"""
        return SystemManagementUI.ANSI_ESCAPE_PATTERN.sub('', text)

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static("[bold cyan]═══ System Management ═══[/bold cyan]", id="system-title")
            yield Static("", id="system-status")

            with Grid(id="action-grid"):
                # Installation buttons
                yield Button("📦 Install LocalAI", id="btn-install-localai", variant="primary")
                yield Button("📦 Install Ollama", id="btn-install-ollama", variant="primary")
                yield Button("📦 Install Auto-Suspend", id="btn-install-autosuspend", variant="primary")

                # Service control
                yield Button("▶️  Start Both Services", id="btn-start-both", variant="success")
                yield Button("▶️  Start LocalAI", id="btn-start-localai", variant="success")
                yield Button("▶️  Start Ollama", id="btn-start-ollama", variant="success")

                yield Button("⏸️  Stop All Services", id="btn-stop-all", variant="warning")
                yield Button("⏸️  Stop LocalAI", id="btn-stop-localai", variant="warning")
                yield Button("⏸️  Stop Ollama", id="btn-stop-ollama", variant="warning")

                # Auto-suspend controls
                yield Button("🔌 Enable Auto-Suspend", id="btn-enable-autosuspend", variant="default")
                yield Button("⏸️  Disable Auto-Suspend", id="btn-disable-autosuspend", variant="default")
                yield Button("⏰ Stay Awake 1h", id="btn-stay-1h", variant="default")

                yield Button("⏰ Stay Awake 2h", id="btn-stay-2h", variant="default")
                yield Button("⏰ Stay Awake 4h", id="btn-stay-4h", variant="default")
                yield Button("📊 Check Status", id="btn-check-status", variant="default")

            yield Static("", id="system-output")

    def on_mount(self) -> None:
        self.update_status()
        # Update status more frequently for better responsiveness
        self.set_interval(2.0, self.update_status)

    def update_status(self) -> None:
        """Update service status display"""
        try:
            localai_status = self.system_mgr.get_service_status('localai')
            ollama_status = self.system_mgr.get_service_status('ollama')
            autosuspend_status = self.system_mgr.get_service_status('ai-auto-suspend')

            # Format service status with installation state
            def format_status(status):
                if not status['exists']:
                    return '[dim]not installed[/dim]'
                state = '[green]●[/green] Running' if status['active'] else '[red]○[/red] Stopped'
                enabled = '[green]enabled[/green]' if status['enabled'] else '[yellow]disabled[/yellow]'
                return f"{state} ({enabled})"

            lines = [
                "[yellow]Current Status:[/yellow]",
                "",
                f"LocalAI:      {format_status(localai_status)}",
                f"Ollama:       {format_status(ollama_status)}",
                f"Auto-Suspend: {format_status(autosuspend_status)}",
            ]

            # Add installation hints
            if not localai_status['exists']:
                lines.append("\n[dim]→ Click 'Install LocalAI' to set up[/dim]")
            if not ollama_status['exists']:
                lines.append("\n[dim]→ Click 'Install Ollama' to set up[/dim]")
            if not autosuspend_status['exists']:
                lines.append("\n[dim]→ Click 'Install Auto-Suspend' to set up[/dim]")

            status_widget = self.query_one("#system-status", Static)
            status_widget.update("\n".join(lines))
        except Exception as e:
            pass

    @work(thread=True)
    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses"""
        button_id = event.button.id

        # Disable button during operation
        event.button.disabled = True

        try:
            output_widget = self.query_one("#system-output", Static)

            if button_id == "btn-install-localai":
                output_widget.update("[yellow]Installing LocalAI... (this may take a while)[/yellow]\n\n[dim]Running: sudo bash install.sh --non-interactive[/dim]")
                success, output = self.system_mgr.install_localai()
                self._show_result(output_widget, success, "LocalAI Installation", output)

            elif button_id == "btn-install-ollama":
                output_widget.update("[yellow]Installing Ollama... (this may take a while)[/yellow]\n\n[dim]Running: sudo bash install-ollama.sh --non-interactive[/dim]")
                success, output = self.system_mgr.install_ollama()
                self._show_result(output_widget, success, "Ollama Installation", output)

            elif button_id == "btn-install-autosuspend":
                output_widget.update("[yellow]Installing Auto-Suspend system...[/yellow]\n\n[dim]Running: sudo bash install-auto-suspend.sh[/dim]")
                success, output = self.system_mgr.install_auto_suspend()
                self._show_result(output_widget, success, "Auto-Suspend Installation", output)

            elif button_id == "btn-start-both":
                output_widget.update("[yellow]Starting both services...[/yellow]\n\n[dim]Running: bash ai-server-manager.sh both[/dim]")
                success, output = self.system_mgr.run_ai_server_command('both')
                self._show_result(output_widget, success, "Start Services", output)

            elif button_id == "btn-start-localai":
                output_widget.update("[yellow]Starting LocalAI...[/yellow]\n\n[dim]Running: bash ai-server-manager.sh localai[/dim]")
                success, output = self.system_mgr.run_ai_server_command('localai')
                self._show_result(output_widget, success, "Start LocalAI", output)

            elif button_id == "btn-start-ollama":
                output_widget.update("[yellow]Starting Ollama...[/yellow]\n\n[dim]Running: bash ai-server-manager.sh ollama[/dim]")
                success, output = self.system_mgr.run_ai_server_command('ollama')
                self._show_result(output_widget, success, "Start Ollama", output)

            elif button_id == "btn-stop-all":
                output_widget.update("[yellow]Stopping all services...[/yellow]")
                success, output = self.system_mgr.run_ai_server_command('stop')
                self._show_result(output_widget, success, "Stop Services", output)

            elif button_id == "btn-stop-localai":
                output_widget.update("[yellow]Stopping LocalAI...[/yellow]")
                success, output = self.system_mgr.stop_service('localai')
                self._show_result(output_widget, success, "Stop LocalAI", output)

            elif button_id == "btn-stop-ollama":
                output_widget.update("[yellow]Stopping Ollama...[/yellow]")
                success, output = self.system_mgr.stop_service('ollama')
                self._show_result(output_widget, success, "Stop Ollama", output)

            elif button_id == "btn-enable-autosuspend":
                output_widget.update("[yellow]Enabling Auto-Suspend...[/yellow]\n\n[dim]Running: systemctl enable ai-auto-suspend && systemctl start ai-auto-suspend[/dim]")
                success1, output1 = self.system_mgr.enable_service('ai-auto-suspend')
                success2, output2 = self.system_mgr.start_service('ai-auto-suspend')
                self._show_result(output_widget, success1 and success2, "Enable Auto-Suspend",
                                output1 + "\n" + output2)

            elif button_id == "btn-disable-autosuspend":
                output_widget.update("[yellow]Disabling Auto-Suspend...[/yellow]\n\n[dim]Running: systemctl stop ai-auto-suspend && systemctl disable ai-auto-suspend[/dim]")
                success1, output1 = self.system_mgr.stop_service('ai-auto-suspend')
                success2, output2 = self.system_mgr.disable_service('ai-auto-suspend')
                self._show_result(output_widget, success1 and success2, "Disable Auto-Suspend",
                                output1 + "\n" + output2)

            elif button_id == "btn-stay-1h":
                output_widget.update("[yellow]Activating stay-awake for 1 hour...[/yellow]\n\n[dim]Sending HTTP request to stay-awake server[/dim]")
                success, output = self.system_mgr.activate_stay_awake(1)
                self._show_result(output_widget, success, "Stay Awake (1 hour)", output)

            elif button_id == "btn-stay-2h":
                output_widget.update("[yellow]Activating stay-awake for 2 hours...[/yellow]\n\n[dim]Sending HTTP request to stay-awake server[/dim]")
                success, output = self.system_mgr.activate_stay_awake(2)
                self._show_result(output_widget, success, "Stay Awake (2 hours)", output)

            elif button_id == "btn-stay-4h":
                output_widget.update("[yellow]Activating stay-awake for 4 hours...[/yellow]\n\n[dim]Sending HTTP request to stay-awake server[/dim]")
                success, output = self.system_mgr.activate_stay_awake(4)
                self._show_result(output_widget, success, "Stay Awake (4 hours)", output)

            elif button_id == "btn-check-status":
                output_widget.update("[yellow]Checking status...[/yellow]")
                success, output = self.system_mgr.run_ai_server_command('status')
                self._show_result(output_widget, success, "System Status", output)

            # Update status after operation
            self.update_status()

        finally:
            # Re-enable button
            event.button.disabled = False

    def _show_result(self, widget: Static, success: bool, title: str, output: str):
        """Show operation result"""
        if success:
            result = f"[bold green]✓ {title} - Success[/bold green]\n\n"
        else:
            result = f"[bold red]✗ {title} - Failed[/bold red]\n\n"

        # Strip ANSI escape codes from output
        clean_output = self.strip_ansi_codes(output)

        # Limit output length
        if len(clean_output) > 1000:
            clean_output = clean_output[:1000] + "\n\n[dim]... (output truncated)[/dim]"

        widget.update(result + clean_output)
