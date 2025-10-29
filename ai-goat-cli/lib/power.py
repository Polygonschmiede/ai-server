"""
Power Management Module
Monitors auto-suspend status and provides power control
"""

import subprocess
import os
import time
from typing import Dict, Any
from monitoring import SystemMonitor


class PowerManager:
    """Manage power settings and monitor suspend status"""

    def __init__(self):
        self.monitor = SystemMonitor()
        self.stay_awake_file = "/run/ai-nodectl/stay_awake_until"

    def _get_auto_suspend_config(self) -> Dict[str, int]:
        """Get auto-suspend configuration"""
        config = {
            'wait_minutes': 30,
            'cpu_threshold': 90,
            'gpu_threshold': 10,
        }

        try:
            # Try to read from systemd service environment
            result = subprocess.run(
                ['systemctl', 'show', 'ai-auto-suspend.service', '--property=Environment'],
                capture_output=True,
                text=True
            )

            # Parse environment variables
            env_line = result.stdout.strip()
            if env_line.startswith('Environment='):
                env_str = env_line.replace('Environment=', '')
                for item in env_str.split():
                    if '=' in item:
                        key, value = item.split('=', 1)
                        if key == 'WAIT_MINUTES':
                            config['wait_minutes'] = int(value)
                        elif key == 'CPU_IDLE_THRESHOLD':
                            config['cpu_threshold'] = int(value)
                        elif key == 'GPU_USAGE_MAX':
                            config['gpu_threshold'] = int(value)
        except Exception:
            pass

        return config

    def _check_stay_awake(self) -> tuple[bool, int]:
        """Check if stay-awake is active and return remaining seconds"""
        if not os.path.exists(self.stay_awake_file):
            return False, 0

        try:
            with open(self.stay_awake_file, 'r') as f:
                until_timestamp = int(f.read().strip())

            now = int(time.time())
            remaining = until_timestamp - now

            if remaining > 0:
                return True, remaining
            else:
                return False, 0
        except Exception:
            return False, 0

    def _check_ssh_active(self) -> bool:
        """Check if SSH sessions are active"""
        try:
            result = subprocess.run(
                ['ss', '-tna'],
                capture_output=True,
                text=True
            )
            for line in result.stdout.splitlines():
                if 'ESTAB' in line and ':22' in line:
                    return True
            return False
        except Exception:
            return False

    def _check_api_active(self) -> bool:
        """Check if API ports have active connections"""
        api_ports = ['8080', '11434', '3000', '9876']

        try:
            result = subprocess.run(
                ['ss', '-tna'],
                capture_output=True,
                text=True
            )
            for line in result.stdout.splitlines():
                if 'ESTAB' in line:
                    for port in api_ports:
                        if f':{port}' in line:
                            return True
            return False
        except Exception:
            return False

    def _estimate_idle_minutes(self, stats: Dict[str, Any], config: Dict[str, int]) -> int:
        """Estimate how many minutes the system has been idle"""
        # This is an estimate - the actual value is tracked by ai-auto-suspend service
        # We can only determine if conditions are met NOW

        cpu_idle = stats['cpu_percent'] < (100 - config['cpu_threshold'])
        gpu_idle = stats['gpu_util'] <= config['gpu_threshold']
        no_ssh = not self._check_ssh_active()
        no_api = not self._check_api_active()

        # If all conditions are met, we estimate idle time
        # In reality, this would require reading from the service's state
        if cpu_idle and gpu_idle and no_ssh and no_api:
            # System is currently idle
            # We could store the last non-idle time and calculate from there
            return 0  # Placeholder - would need persistent state
        else:
            return 0

    def get_status(self) -> Dict[str, Any]:
        """Get current power management status"""
        stats = self.monitor.get_stats()
        config = self._get_auto_suspend_config()
        stay_awake_active, stay_awake_remaining = self._check_stay_awake()

        # Calculate total system power
        total_power = self.monitor.get_total_power()

        # Check conditions
        cpu_idle_percent = 100 - stats['cpu_percent']
        cpu_idle = cpu_idle_percent >= config['cpu_threshold']
        gpu_idle = stats['gpu_util'] <= config['gpu_threshold']
        ssh_active = self._check_ssh_active()
        api_active = self._check_api_active()

        # Estimate idle minutes
        idle_minutes = self._estimate_idle_minutes(stats, config)

        # Check if auto-suspend is enabled
        auto_suspend_enabled = self._check_service_running('ai-auto-suspend.service')

        return {
            'total_power': total_power,
            'stay_awake_active': stay_awake_active,
            'stay_awake_remaining': stay_awake_remaining,
            'auto_suspend_enabled': auto_suspend_enabled,
            'wait_minutes': config['wait_minutes'],
            'idle_minutes': idle_minutes,
            'cpu_idle': cpu_idle,
            'cpu_idle_percent': cpu_idle_percent,
            'cpu_threshold': config['cpu_threshold'],
            'gpu_idle': gpu_idle,
            'gpu_util': stats['gpu_util'],
            'gpu_threshold': config['gpu_threshold'],
            'ssh_active': ssh_active,
            'api_active': api_active,
        }

    def _check_service_running(self, service_name: str) -> bool:
        """Check if a systemd service is running"""
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', service_name],
                capture_output=True,
                text=True
            )
            return result.stdout.strip() == 'active'
        except Exception:
            return False

    def activate_stay_awake(self, seconds: int) -> bool:
        """Activate stay-awake for specified seconds"""
        try:
            until_timestamp = int(time.time()) + seconds

            os.makedirs(os.path.dirname(self.stay_awake_file), exist_ok=True)

            with open(self.stay_awake_file, 'w') as f:
                f.write(str(until_timestamp))

            return True
        except Exception as e:
            print(f"Error activating stay-awake: {e}")
            return False
