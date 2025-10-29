"""
System Management Module
Provides installation, repair, and service management
"""

import subprocess
import os
from typing import Dict, List, Any


class SystemManager:
    """Manage AI server installation and services"""

    def __init__(self):
        self.base_dir = self._find_base_dir()

    def _find_base_dir(self) -> str:
        """Find the ai-server base directory"""
        # Try to find from current location
        current = os.path.dirname(os.path.abspath(__file__))

        # Go up directories until we find install.sh
        for _ in range(5):  # Max 5 levels up
            if os.path.exists(os.path.join(current, 'install.sh')):
                return current
            current = os.path.dirname(current)

        # Default to home directory
        return os.path.expanduser('~/ai-server')

    def run_installer(self, script: str, args: List[str] = None) -> tuple[bool, str]:
        """Run an installation script"""
        script_path = os.path.join(self.base_dir, script)

        if not os.path.exists(script_path):
            return False, f"Script not found: {script_path}"

        cmd = ['sudo', 'bash', script_path]
        if args:
            cmd.extend(args)

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=600  # 10 minute timeout
            )
            return result.returncode == 0, result.stdout + result.stderr
        except subprocess.TimeoutExpired:
            return False, "Installation timed out after 10 minutes"
        except Exception as e:
            return False, f"Error running installer: {e}"

    def install_localai(self, cpu_only: bool = False, non_interactive: bool = True) -> tuple[bool, str]:
        """Install LocalAI"""
        args = []
        if cpu_only:
            args.append('--cpu-only')
        if non_interactive:
            args.append('--non-interactive')

        return self.run_installer('install.sh', args)

    def install_ollama(self, cpu_only: bool = False, non_interactive: bool = True) -> tuple[bool, str]:
        """Install Ollama"""
        args = []
        if cpu_only:
            args.append('--cpu-only')
        if non_interactive:
            args.append('--non-interactive')

        return self.run_installer('install-ollama.sh', args)

    def repair_installation(self, service: str = 'localai') -> tuple[bool, str]:
        """Repair an installation"""
        if service == 'localai':
            return self.run_installer('install.sh', ['--repair', '--non-interactive'])
        elif service == 'ollama':
            return self.run_installer('install-ollama.sh', ['--repair', '--non-interactive'])
        else:
            return False, f"Unknown service: {service}"

    def start_service(self, service: str) -> tuple[bool, str]:
        """Start a systemd service"""
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'start', f'{service}.service'],
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stdout + result.stderr
        except Exception as e:
            return False, f"Error starting service: {e}"

    def stop_service(self, service: str) -> tuple[bool, str]:
        """Stop a systemd service"""
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'stop', f'{service}.service'],
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stdout + result.stderr
        except Exception as e:
            return False, f"Error stopping service: {e}"

    def restart_service(self, service: str) -> tuple[bool, str]:
        """Restart a systemd service"""
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'restart', f'{service}.service'],
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stdout + result.stderr
        except Exception as e:
            return False, f"Error restarting service: {e}"

    def get_service_logs(self, service: str, lines: int = 50) -> str:
        """Get service logs"""
        try:
            result = subprocess.run(
                ['sudo', 'journalctl', '-u', f'{service}.service', '-n', str(lines), '--no-pager'],
                capture_output=True,
                text=True
            )
            return result.stdout
        except Exception as e:
            return f"Error getting logs: {e}"

    def get_container_logs(self, container: str, lines: int = 50) -> str:
        """Get Docker container logs"""
        try:
            result = subprocess.run(
                ['docker', 'logs', '--tail', str(lines), container],
                capture_output=True,
                text=True
            )
            return result.stdout + result.stderr
        except Exception as e:
            return f"Error getting container logs: {e}"

    def enable_service(self, service: str) -> tuple[bool, str]:
        """Enable a systemd service"""
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'enable', f'{service}.service'],
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stdout + result.stderr
        except Exception as e:
            return False, f"Error enabling service: {e}"

    def disable_service(self, service: str) -> tuple[bool, str]:
        """Disable a systemd service"""
        try:
            result = subprocess.run(
                ['sudo', 'systemctl', 'disable', f'{service}.service'],
                capture_output=True,
                text=True
            )
            return result.returncode == 0, result.stdout + result.stderr
        except Exception as e:
            return False, f"Error disabling service: {e}"

    def get_service_status(self, service: str) -> Dict[str, Any]:
        """Get detailed service status"""
        try:
            # Check if service is active
            result = subprocess.run(
                ['systemctl', 'is-active', f'{service}.service'],
                capture_output=True,
                text=True
            )
            is_active = result.stdout.strip() == 'active'

            # Check if service is enabled
            result = subprocess.run(
                ['systemctl', 'is-enabled', f'{service}.service'],
                capture_output=True,
                text=True
            )
            is_enabled = result.stdout.strip() == 'enabled'

            return {
                'active': is_active,
                'enabled': is_enabled,
                'exists': True
            }
        except Exception:
            return {
                'active': False,
                'enabled': False,
                'exists': False
            }

    def install_auto_suspend(self) -> tuple[bool, str]:
        """Install auto-suspend system"""
        return self.run_installer('install-auto-suspend.sh')

    def activate_stay_awake(self, hours: int = 1) -> tuple[bool, str]:
        """Activate stay-awake via HTTP request"""
        try:
            import urllib.request
            seconds = hours * 3600
            url = f"http://localhost:9876/stay?s={seconds}"

            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=5) as response:
                result = response.read().decode('utf-8')
                return True, result
        except Exception as e:
            return False, f"Error activating stay-awake: {e}"

    def run_ai_server_command(self, command: str) -> tuple[bool, str]:
        """Run ai-server-manager.sh command"""
        script_path = os.path.join(self.base_dir, 'ai-server-manager.sh')

        if not os.path.exists(script_path):
            return False, f"Script not found: {script_path}"

        try:
            result = subprocess.run(
                ['bash', script_path, command],
                capture_output=True,
                text=True,
                timeout=300
            )
            return result.returncode == 0, result.stdout + result.stderr
        except Exception as e:
            return False, f"Error running command: {e}"
