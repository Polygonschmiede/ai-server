"""
System Management UI Module
Interactive system management interface
"""

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

    def __init__(self):
        super().__init__()
        self.system_mgr = SystemManager()

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
        self.set_interval(5.0, self.update_status)

    def update_status(self) -> None:
        """Update service status display"""
        try:
            localai_status = self.system_mgr.get_service_status('localai')
            ollama_status = self.system_mgr.get_service_status('ollama')
            autosuspend_status = self.system_mgr.get_service_status('ai-auto-suspend')

            lines = [
                "[yellow]Current Status:[/yellow]",
                "",
                f"LocalAI:      {'[green]●[/green] Running' if localai_status['active'] else '[red]○[/red] Stopped'} "
                f"({'enabled' if localai_status['enabled'] else 'disabled'})",
                f"Ollama:       {'[green]●[/green] Running' if ollama_status['active'] else '[red]○[/red] Stopped'} "
                f"({'enabled' if ollama_status['enabled'] else 'disabled'})",
                f"Auto-Suspend: {'[green]●[/green] Running' if autosuspend_status['active'] else '[red]○[/red] Stopped'} "
                f"({'enabled' if autosuspend_status['enabled'] else 'disabled' if autosuspend_status['exists'] else 'not installed'})",
            ]

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
                output_widget.update("[yellow]Installing LocalAI... (this may take a while)[/yellow]")
                success, output = self.system_mgr.install_localai()
                self._show_result(output_widget, success, "LocalAI Installation", output)

            elif button_id == "btn-install-ollama":
                output_widget.update("[yellow]Installing Ollama... (this may take a while)[/yellow]")
                success, output = self.system_mgr.install_ollama()
                self._show_result(output_widget, success, "Ollama Installation", output)

            elif button_id == "btn-install-autosuspend":
                output_widget.update("[yellow]Installing Auto-Suspend system...[/yellow]")
                success, output = self.system_mgr.install_auto_suspend()
                self._show_result(output_widget, success, "Auto-Suspend Installation", output)

            elif button_id == "btn-start-both":
                output_widget.update("[yellow]Starting both services...[/yellow]")
                success, output = self.system_mgr.run_ai_server_command('both')
                self._show_result(output_widget, success, "Start Services", output)

            elif button_id == "btn-start-localai":
                output_widget.update("[yellow]Starting LocalAI...[/yellow]")
                success, output = self.system_mgr.run_ai_server_command('localai')
                self._show_result(output_widget, success, "Start LocalAI", output)

            elif button_id == "btn-start-ollama":
                output_widget.update("[yellow]Starting Ollama...[/yellow]")
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
                output_widget.update("[yellow]Enabling Auto-Suspend...[/yellow]")
                success1, output1 = self.system_mgr.enable_service('ai-auto-suspend')
                success2, output2 = self.system_mgr.start_service('ai-auto-suspend')
                self._show_result(output_widget, success1 and success2, "Enable Auto-Suspend",
                                output1 + "\n" + output2)

            elif button_id == "btn-disable-autosuspend":
                output_widget.update("[yellow]Disabling Auto-Suspend...[/yellow]")
                success1, output1 = self.system_mgr.stop_service('ai-auto-suspend')
                success2, output2 = self.system_mgr.disable_service('ai-auto-suspend')
                self._show_result(output_widget, success1 and success2, "Disable Auto-Suspend",
                                output1 + "\n" + output2)

            elif button_id == "btn-stay-1h":
                output_widget.update("[yellow]Activating stay-awake for 1 hour...[/yellow]")
                success, output = self.system_mgr.activate_stay_awake(1)
                self._show_result(output_widget, success, "Stay Awake", output)

            elif button_id == "btn-stay-2h":
                output_widget.update("[yellow]Activating stay-awake for 2 hours...[/yellow]")
                success, output = self.system_mgr.activate_stay_awake(2)
                self._show_result(output_widget, success, "Stay Awake", output)

            elif button_id == "btn-stay-4h":
                output_widget.update("[yellow]Activating stay-awake for 4 hours...[/yellow]")
                success, output = self.system_mgr.activate_stay_awake(4)
                self._show_result(output_widget, success, "Stay Awake", output)

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

        # Limit output length
        if len(output) > 1000:
            output = output[:1000] + "\n\n[dim]... (output truncated)[/dim]"

        widget.update(result + output)
