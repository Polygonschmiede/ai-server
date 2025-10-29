#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
INSTALL_DIR="/opt/ai-server"
SYSTEMD_DIR="/etc/systemd/system"
STATE_DIR="/var/lib/ai-auto-suspend"
RUN_DIR="/run/ai-nodectl"

echo -e "${BLUE}[+] AI Server Auto-Suspend Installation${NC}"
echo -e "${BLUE}[+]${NC} This will install the auto-suspend system"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Please run as root (use sudo)${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${GREEN}[+] Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$STATE_DIR"
mkdir -p "$RUN_DIR"

echo -e "${GREEN}[+] Copying scripts...${NC}"
cp "$SCRIPT_DIR/stay-awake-server.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/auto-suspend-monitor.py" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/stay-awake-server.py"
chmod +x "$INSTALL_DIR/auto-suspend-monitor.py"

echo -e "${GREEN}[+] Installing systemd services...${NC}"
cp "$SCRIPT_DIR/stay-awake.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/ai-auto-suspend.service" "$SYSTEMD_DIR/"

echo -e "${GREEN}[+] Reloading systemd...${NC}"
systemctl daemon-reload

echo -e "${GREEN}[+] Enabling services...${NC}"
systemctl enable stay-awake.service
systemctl enable ai-auto-suspend.service

echo -e "${GREEN}[+] Starting services...${NC}"
systemctl start stay-awake.service
systemctl start ai-auto-suspend.service

echo -e "${GREEN}[+] Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 9876/tcp comment "Stay-Awake HTTP Server"
fi

echo ""
echo -e "${GREEN}[+] ==========================================${NC}"
echo -e "${GREEN}[+] ✓ Installation complete!${NC}"
echo -e "${GREEN}[+] ==========================================${NC}"
echo ""

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${YELLOW}Service Status:${NC}"
systemctl status stay-awake.service --no-pager | head -n 5
echo ""
systemctl status ai-auto-suspend.service --no-pager | head -n 5
echo ""

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Wait time:         30 minutes"
echo -e "  CPU idle needed:   ≥90%"
echo -e "  GPU usage max:     ≤10%"
echo ""

echo -e "${YELLOW}Stay-Awake URL:${NC}"
echo -e "  ${GREEN}http://${SERVER_IP}:9876/stay?s=SECONDS${NC}"
echo ""

echo -e "${YELLOW}Examples:${NC}"
echo -e "  # Keep awake for 1 hour:"
echo -e "  ${BLUE}curl \"http://${SERVER_IP}:9876/stay?s=3600\"${NC}"
echo ""
echo -e "  # Keep awake for 2 hours:"
echo -e "  ${BLUE}curl \"http://${SERVER_IP}:9876/stay?s=7200\"${NC}"
echo ""
echo -e "  # Check status:"
echo -e "  ${BLUE}curl \"http://${SERVER_IP}:9876/status\"${NC}"
echo ""

echo -e "${YELLOW}Management:${NC}"
echo -e "  # View logs:"
echo -e "  ${BLUE}journalctl -u ai-auto-suspend.service -f${NC}"
echo -e "  ${BLUE}journalctl -u stay-awake.service -f${NC}"
echo ""
echo -e "  # Stop/start services:"
echo -e "  ${BLUE}systemctl stop ai-auto-suspend.service${NC}"
echo -e "  ${BLUE}systemctl start ai-auto-suspend.service${NC}"
echo ""
echo -e "  # Disable auto-suspend:"
echo -e "  ${BLUE}systemctl disable ai-auto-suspend.service${NC}"
echo -e "  ${BLUE}systemctl stop ai-auto-suspend.service${NC}"
echo ""

echo -e "${YELLOW}Configuration File:${NC}"
echo -e "  Edit ${BLUE}/etc/systemd/system/ai-auto-suspend.service${NC}"
echo -e "  to change wait time and thresholds"
echo ""
