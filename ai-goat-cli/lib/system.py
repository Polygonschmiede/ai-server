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
