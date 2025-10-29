"""
Remote Control Module
Provides WOL and remote management information
"""

import subprocess
import socket
import os
from typing import Dict, Any


class RemoteManager:
    """Manage remote control features"""

    def __init__(self):
        pass

    def get_mac_address(self, interface: str = None) -> str:
        """Get MAC address of network interface"""
        if interface is None:
            interface = self._get_default_interface()

        try:
            # Read from /sys/class/net
            mac_file = f"/sys/class/net/{interface}/address"
            if os.path.exists(mac_file):
                with open(mac_file, 'r') as f:
                    return f.read().strip()
        except Exception:
            pass

        # Fallback: parse ip link show
        try:
            result = subprocess.run(
                ['ip', 'link', 'show', interface],
                capture_output=True,
                text=True
            )
            for line in result.stdout.splitlines():
                if 'link/ether' in line:
                    return line.split()[1]
        except Exception:
            pass

        return "unknown"

    def _get_default_interface(self) -> str:
        """Get default network interface"""
        try:
            result = subprocess.run(
                ['ip', 'route', 'get', '1.1.1.1'],
                capture_output=True,
                text=True
            )
            for line in result.stdout.splitlines():
                parts = line.split()
                if 'dev' in parts:
                    idx = parts.index('dev')
                    if idx + 1 < len(parts):
                        return parts[idx + 1]
        except Exception:
            pass

        return "eth0"

    def _get_wol_interface(self) -> str:
        """Get WOL interface from systemd service"""
        try:
            result = subprocess.run(
                ['systemctl', 'list-units', 'wol@*.service', '--no-legend'],
                capture_output=True,
                text=True
            )
            for line in result.stdout.splitlines():
                if 'wol@' in line:
                    # Extract interface from wol@<interface>.service
                    service_name = line.split()[0]
                    interface = service_name.replace('wol@', '').replace('.service', '')
                    return interface
        except Exception:
            pass

        return self._get_default_interface()

    def _get_server_ip(self) -> str:
        """Get server's IP address"""
        try:
            # Connect to external IP to determine our outgoing IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "localhost"

    def _get_stay_awake_port(self) -> int:
        """Get stay-awake service port from systemd"""
        try:
            result = subprocess.run(
                ['systemctl', 'show', 'ai-stayawake-http.service', '--property=ExecStart'],
                capture_output=True,
                text=True
            )
            # Parse ExecStart line to extract port
            # Example: ExecStart={ path=/usr/local/bin/ai-stayawake-http.sh ; argv[]=/usr/local/bin/ai-stayawake-http.sh 9876 0.0.0.0 ; ... }
            exec_start = result.stdout.strip()
            if 'argv[]=' in exec_start:
                argv_part = exec_start.split('argv[]=')[1].split(';')[0]
                parts = argv_part.split()
                if len(parts) >= 2:
                    return int(parts[1])
        except Exception:
            pass

        return 9876  # Default

    def get_info(self) -> Dict[str, Any]:
        """Get remote control information"""
        interface = self._get_wol_interface()
        mac_address = self.get_mac_address(interface)
        server_ip = self._get_server_ip()
        stay_awake_port = self._get_stay_awake_port()

        return {
            'wol_interface': interface,
            'mac_address': mac_address,
            'server_ip': server_ip,
            'stay_awake_port': stay_awake_port,
        }

    def check_wol_enabled(self, interface: str = None) -> bool:
        """Check if WOL is enabled on interface"""
        if interface is None:
            interface = self._get_wol_interface()

        try:
            result = subprocess.run(
                ['ethtool', interface],
                capture_output=True,
                text=True
            )
            # Look for "Wake-on: g"
            for line in result.stdout.splitlines():
                if 'Wake-on:' in line and ' g' in line:
                    return True
            return False
        except Exception:
            return False

    def send_wol_packet(self, mac_address: str, broadcast: str = "255.255.255.255") -> bool:
        """Send WOL magic packet"""
        try:
            # Create magic packet
            mac_bytes = bytes.fromhex(mac_address.replace(':', '').replace('-', ''))
            magic_packet = b'\xff' * 6 + mac_bytes * 16

            # Send packet
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            sock.sendto(magic_packet, (broadcast, 9))
            sock.close()

            return True
        except Exception as e:
            print(f"Error sending WOL packet: {e}")
            return False
