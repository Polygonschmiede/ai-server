#!/usr/bin/env bash
set -euo pipefail

# AI GOAT CLI Installer
# Installs Python dependencies and sets up the CLI tool

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

log() { echo -e "${COLOR_GREEN}[+]${COLOR_RESET} $*"; }
info() { echo -e "${COLOR_BLUE}[i]${COLOR_RESET} $*"; }
warn() { echo -e "${COLOR_YELLOW}[!]${COLOR_RESET} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Installing AI GOAT CLI"
echo ""

# Check Python
if ! command -v python3 >/dev/null 2>&1; then
    warn "Python 3 not found. Installing..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
fi

info "Python version: $(python3 --version)"
echo ""

# Check if python3-venv is available
if ! python3 -m venv --help >/dev/null 2>&1; then
    warn "python3-venv not found. Installing required packages..."
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    echo ""
    info "Please run the following command with sudo:"
    echo "  ${COLOR_GREEN}sudo apt update && sudo apt install -y python3-venv python3-pip python${PYTHON_VERSION}-venv${COLOR_RESET}"
    echo ""
    warn "After installation, run this script again."
    exit 1
fi

# Check pip
if ! command -v pip3 >/dev/null 2>&1; then
    warn "pip3 not found. Installing..."
    sudo apt install -y python3-pip
fi

# Remove failed venv if it exists but is broken
if [ -d "${SCRIPT_DIR}/venv" ] && [ ! -f "${SCRIPT_DIR}/venv/bin/activate" ]; then
    warn "Cleaning up broken virtual environment..."
    rm -rf "${SCRIPT_DIR}/venv"
fi

# Create virtual environment
if [ ! -d "${SCRIPT_DIR}/venv" ]; then
    log "Creating Python virtual environment..."
    if ! python3 -m venv "${SCRIPT_DIR}/venv"; then
        warn "Failed to create virtual environment!"
        rm -rf "${SCRIPT_DIR}/venv"
        exit 1
    fi
fi

# Activate venv and install dependencies
log "Installing Python dependencies..."
source "${SCRIPT_DIR}/venv/bin/activate"
pip install --upgrade pip
pip install -r "${SCRIPT_DIR}/requirements.txt"

# Make main script executable
log "Making AI GOAT executable..."
chmod +x "${SCRIPT_DIR}/ai-goat"

# Create symlink in /usr/local/bin
if [ ! -L "/usr/local/bin/ai-goat" ]; then
    log "Creating system-wide command..."
    sudo ln -sf "${SCRIPT_DIR}/ai-goat" /usr/local/bin/ai-goat
fi

echo ""
log "======================================"
log "  AI GOAT CLI Installation Complete!"
log "======================================"
echo ""
info "Run the tool with:"
echo "  ${COLOR_GREEN}ai-goat${COLOR_RESET}"
echo ""
info "Or directly:"
echo "  ${COLOR_GREEN}cd ${SCRIPT_DIR} && ./ai-goat${COLOR_RESET}"
echo ""
info "Features:"
echo "  • Real-time GPU/CPU monitoring"
echo "  • Power consumption tracking"
echo "  • Auto-suspend countdown timer"
echo "  • Wake-on-LAN information"
echo "  • Service management"
echo ""
info "Keyboard shortcuts:"
echo "  • Press 'q' to quit"
echo "  • Press '1' for Dashboard"
echo "  • Press '2' for System Management"
echo "  • Press '3' for Remote Control"
echo "  • Press 'd' to toggle dark mode"
echo ""
