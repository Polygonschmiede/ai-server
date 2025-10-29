"""
System Monitoring Module
Provides real-time system stats (GPU, CPU, Memory, Services)
"""

import psutil
import subprocess
import os
from typing import Dict, Any


class SystemMonitor:
    """Monitor system resources and services"""

    def __init__(self):
        self.has_gpu = self._check_gpu()

    def _check_gpu(self) -> bool:
        """Check if NVIDIA GPU is available"""
        try:
            subprocess.run(['nvidia-smi'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except FileNotFoundError:
            return False

    def _get_gpu_stats(self) -> Dict[str, Any]:
        """Get GPU statistics using nvidia-smi"""
        if not self.has_gpu:
            return {
                'gpu_power': 0.0,
                'gpu_power_limit': 0.0,
                'gpu_temp': 0,
                'gpu_util': 0,
                'gpu_memory_used': 0.0,
                'gpu_memory_total': 0.0,
            }

        try:
            # Query GPU stats
            cmd = [
                'nvidia-smi',
                '--query-gpu=power.draw,power.limit,temperature.gpu,utilization.gpu,memory.used,memory.total',
                '--format=csv,noheader,nounits'
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            values = result.stdout.strip().split(', ')

            return {
                'gpu_power': float(values[0]),
                'gpu_power_limit': float(values[1]),
                'gpu_temp': int(float(values[2])),
                'gpu_util': int(float(values[3])),
                'gpu_memory_used': float(values[4]) / 1024,  # Convert MB to GB
                'gpu_memory_total': float(values[5]) / 1024,  # Convert MB to GB
            }
        except Exception as e:
            print(f"Error getting GPU stats: {e}")
            return {
                'gpu_power': 0.0,
                'gpu_power_limit': 0.0,
                'gpu_temp': 0,
                'gpu_util': 0,
                'gpu_memory_used': 0.0,
                'gpu_memory_total': 0.0,
            }

    def _get_cpu_stats(self) -> Dict[str, Any]:
        """Get CPU statistics"""
        return {
            'cpu_percent': psutil.cpu_percent(interval=1),
            'cpu_count': psutil.cpu_count(),
        }

    def _get_memory_stats(self) -> Dict[str, Any]:
        """Get memory statistics"""
        mem = psutil.virtual_memory()
        return {
            'memory_total': mem.total / (1024 ** 3),  # Convert to GB
            'memory_used': mem.used / (1024 ** 3),
            'memory_free': mem.available / (1024 ** 3),
            'memory_percent': mem.percent,
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

    def _check_container_running(self, container_name: str) -> bool:
        """Check if a Docker container is running"""
        try:
            result = subprocess.run(
                ['docker', 'ps', '--filter', f'name={container_name}', '--format', '{{.Names}}'],
                capture_output=True,
                text=True
            )
            return container_name in result.stdout
        except Exception:
            return False

    def get_stats(self) -> Dict[str, Any]:
        """Get all system statistics"""
        stats = {}

        # GPU stats
        stats.update(self._get_gpu_stats())

        # CPU stats
        stats.update(self._get_cpu_stats())

        # Memory stats
        stats.update(self._get_memory_stats())

        # Service status
        stats['localai_running'] = self._check_service_running('localai.service') or \
                                     self._check_container_running('localai')
        stats['ollama_running'] = self._check_service_running('ollama.service') or \
                                   self._check_container_running('ollama')

        return stats

    def get_total_power(self) -> float:
        """Estimate total system power consumption"""
        stats = self.get_stats()

        # GPU power
        gpu_power = stats['gpu_power']

        # Estimate CPU power (rough estimate based on TDP)
        # Typical desktop CPU: 65-125W TDP
        # Scale by CPU usage
        cpu_power = 100 * (stats['cpu_percent'] / 100.0)

        # Estimate other components (motherboard, RAM, drives, etc.)
        base_power = 50  # Watts

        return gpu_power + cpu_power + base_power
