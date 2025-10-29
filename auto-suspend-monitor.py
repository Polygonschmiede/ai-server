#!/usr/bin/env python3
"""
Auto-Suspend Monitor
Monitors system activity and suspends when idle for too long
"""

import os
import time
import subprocess
import logging
from typing import Dict, Any
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
WAIT_MINUTES = int(os.getenv('WAIT_MINUTES', '30'))
CPU_IDLE_THRESHOLD = int(os.getenv('CPU_IDLE_THRESHOLD', '90'))  # CPU must be >90% idle
GPU_USAGE_MAX = int(os.getenv('GPU_USAGE_MAX', '10'))  # GPU usage must be <10%
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', '60'))  # Check every 60 seconds

STAY_AWAKE_FILE = "/run/ai-nodectl/stay_awake_until"
STATE_FILE = "/var/lib/ai-auto-suspend/idle_since"


class AutoSuspendMonitor:
    """Monitor system activity and trigger suspend when appropriate"""

    def __init__(self):
        self.idle_since = None
        self._ensure_state_dir()
        self._load_state()

    def _ensure_state_dir(self):
        """Ensure state directory exists"""
        state_dir = os.path.dirname(STATE_FILE)
        os.makedirs(state_dir, exist_ok=True)

    def _load_state(self):
        """Load idle state from file"""
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, 'r') as f:
                    timestamp = float(f.read().strip())
                    self.idle_since = timestamp
                    logger.info(f"Loaded idle state: since {datetime.fromtimestamp(timestamp)}")
            except Exception as e:
                logger.warning(f"Error loading state: {e}")
                self.idle_since = None

    def _save_state(self):
        """Save idle state to file"""
        try:
            with open(STATE_FILE, 'w') as f:
                if self.idle_since:
                    f.write(str(self.idle_since))
                else:
                    f.write('')
        except Exception as e:
            logger.error(f"Error saving state: {e}")

    def _check_stay_awake(self) -> bool:
        """Check if stay-awake is active"""
        if not os.path.exists(STAY_AWAKE_FILE):
            return False

        try:
            with open(STAY_AWAKE_FILE, 'r') as f:
                until_timestamp = int(f.read().strip())

            now = int(time.time())
            if until_timestamp > now:
                remaining = until_timestamp - now
                logger.info(f"Stay-awake active: {remaining}s remaining")
                return True
            else:
                # Clean up expired file
                os.remove(STAY_AWAKE_FILE)
                return False
        except Exception as e:
            logger.warning(f"Error checking stay-awake: {e}")
            return False

    def _get_cpu_idle(self) -> float:
        """Get CPU idle percentage"""
        try:
            # Use top to get CPU idle
            result = subprocess.run(
                ['top', '-bn1'],
                capture_output=True,
                text=True,
                timeout=5
            )

            for line in result.stdout.splitlines():
                if 'Cpu(s)' in line or '%Cpu' in line:
                    # Parse line like: "%Cpu(s):  0.3 us,  0.2 sy,  0.0 ni, 99.5 id,  0.0 wa"
                    parts = line.split(',')
                    for part in parts:
                        if 'id' in part:
                            idle_str = part.strip().split()[0]
                            return float(idle_str)

            return 0.0
        except Exception as e:
            logger.error(f"Error getting CPU idle: {e}")
            return 0.0

    def _get_gpu_usage(self) -> float:
        """Get GPU usage percentage"""
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                usage = float(result.stdout.strip().split('\n')[0])
                return usage
            else:
                return 0.0
        except FileNotFoundError:
            # No NVIDIA GPU
            return 0.0
        except Exception as e:
            logger.error(f"Error getting GPU usage: {e}")
            return 0.0

    def _check_ssh_active(self) -> bool:
        """Check if SSH sessions are active"""
        try:
            result = subprocess.run(
                ['ss', '-tna'],
                capture_output=True,
                text=True,
                timeout=5
            )

            for line in result.stdout.splitlines():
                if 'ESTAB' in line and ':22' in line:
                    return True
            return False
        except Exception as e:
            logger.error(f"Error checking SSH: {e}")
            return False

    def _check_api_active(self) -> bool:
        """Check if API ports have active connections"""
        api_ports = ['8080', '11434', '3000']

        try:
            result = subprocess.run(
                ['ss', '-tna'],
                capture_output=True,
                text=True,
                timeout=5
            )

            for line in result.stdout.splitlines():
                if 'ESTAB' in line:
                    for port in api_ports:
                        if f':{port}' in line:
                            return True
            return False
        except Exception as e:
            logger.error(f"Error checking API connections: {e}")
            return False

    def check_conditions(self) -> Dict[str, Any]:
        """Check all suspend conditions"""
        cpu_idle = self._get_cpu_idle()
        gpu_usage = self._get_gpu_usage()
        ssh_active = self._check_ssh_active()
        api_active = self._check_api_active()
        stay_awake = self._check_stay_awake()

        cpu_idle_ok = cpu_idle >= CPU_IDLE_THRESHOLD
        gpu_idle_ok = gpu_usage <= GPU_USAGE_MAX
        no_ssh = not ssh_active
        no_api = not api_active
        no_stay_awake = not stay_awake

        all_conditions_met = (
            cpu_idle_ok and
            gpu_idle_ok and
            no_ssh and
            no_api and
            no_stay_awake
        )

        return {
            'cpu_idle': cpu_idle,
            'cpu_idle_ok': cpu_idle_ok,
            'gpu_usage': gpu_usage,
            'gpu_idle_ok': gpu_idle_ok,
            'ssh_active': ssh_active,
            'no_ssh': no_ssh,
            'api_active': api_active,
            'no_api': no_api,
            'stay_awake': stay_awake,
            'no_stay_awake': no_stay_awake,
            'all_conditions_met': all_conditions_met,
        }

    def trigger_suspend(self):
        """Trigger system suspend"""
        logger.info("Triggering system suspend...")

        try:
            subprocess.run(
                ['systemctl', 'suspend'],
                check=True,
                timeout=10
            )
        except Exception as e:
            logger.error(f"Error triggering suspend: {e}")

    def run_check(self):
        """Run a single check cycle"""
        conditions = self.check_conditions()

        logger.info(
            f"Check: CPU idle={conditions['cpu_idle']:.1f}% (need >={CPU_IDLE_THRESHOLD}%), "
            f"GPU usage={conditions['gpu_usage']:.1f}% (need <={GPU_USAGE_MAX}%), "
            f"SSH={conditions['ssh_active']}, API={conditions['api_active']}, "
            f"stay_awake={conditions['stay_awake']}"
        )

        if conditions['all_conditions_met']:
            # System is idle
            now = time.time()

            if self.idle_since is None:
                # Start idle timer
                self.idle_since = now
                self._save_state()
                logger.info(f"System became idle at {datetime.fromtimestamp(now)}")
            else:
                # Check if idle long enough
                idle_duration = now - self.idle_since
                idle_minutes = idle_duration / 60

                logger.info(
                    f"System idle for {idle_minutes:.1f} minutes "
                    f"(threshold: {WAIT_MINUTES} minutes)"
                )

                if idle_minutes >= WAIT_MINUTES:
                    logger.info("Idle threshold reached - suspending system")
                    self.trigger_suspend()
                    # Reset state after suspend
                    self.idle_since = None
                    self._save_state()
        else:
            # System is active
            if self.idle_since is not None:
                idle_duration = time.time() - self.idle_since
                logger.info(
                    f"System became active after {idle_duration / 60:.1f} minutes of idle"
                )
                self.idle_since = None
                self._save_state()

    def run(self):
        """Main monitoring loop"""
        logger.info("Starting auto-suspend monitor")
        logger.info(f"Configuration:")
        logger.info(f"  Wait time: {WAIT_MINUTES} minutes")
        logger.info(f"  CPU idle threshold: >={CPU_IDLE_THRESHOLD}%")
        logger.info(f"  GPU usage threshold: <={GPU_USAGE_MAX}%")
        logger.info(f"  Check interval: {CHECK_INTERVAL} seconds")

        while True:
            try:
                self.run_check()
            except Exception as e:
                logger.error(f"Error in check cycle: {e}")

            time.sleep(CHECK_INTERVAL)


def main():
    """Main entry point"""
    monitor = AutoSuspendMonitor()
    monitor.run()


if __name__ == '__main__':
    main()
