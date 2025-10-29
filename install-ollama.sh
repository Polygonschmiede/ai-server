#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# Ollama + Open WebUI Installer (Ubuntu 24.04 + NVIDIA)
# --------------------------
# Features:
# - Installs Ollama server in Docker
# - Installs Open WebUI for model management
# - GPU support with NVIDIA Container Toolkit
# - Systemd service integration
# - Works alongside LocalAI installation
#
# Flags:
#   --cpu-only             : Run without GPU support
#   --non-interactive      : No prompts or pauses
#   --models-path PATH     : Host path for models (default: /opt/ollama/models)
#   --ollama-port PORT     : External Ollama API port (default: 11434)
#   --webui-port PORT      : External Open WebUI port (default: 3000)
#   --skip-firewall        : Skip UFW configuration

# --------------------------
# Configuration
# --------------------------
MODE="gpu"
NONINTERACTIVE="false"
OLLAMA_DIR="/opt/ollama"
MODELS_PATH="/opt/ollama/models"
WEBUI_DATA="/opt/ollama/webui"
COMPOSE_FILE="${OLLAMA_DIR}/docker-compose.yml"
SERVICE_NAME="ollama.service"
OLLAMA_PORT="11434"
WEBUI_PORT="3000"
CONFIGURE_FIREWALL="true"
DOCKER_CMD=""

# --------------------------
# Utils
# --------------------------
log() { echo -e "\033[1;32m[+] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[!] $*\033[0m"; }
err() { echo -e "\033[1;31m[✗] $*\033[0m" >&2; }
die() { err "$*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command missing: $1"; }

# --------------------------
# Argument parsing
# --------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-only) MODE="cpu"; shift ;;
    --non-interactive) NONINTERACTIVE="true"; shift ;;
    --models-path) MODELS_PATH="${2:?}"; shift 2 ;;
    --ollama-port) OLLAMA_PORT="${2:?}"; shift 2 ;;
    --webui-port) WEBUI_PORT="${2:?}"; shift 2 ;;
    --skip-firewall) CONFIGURE_FIREWALL="false"; shift ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# --------------------------
# Checks
# --------------------------
[[ "$(id -u)" -ne 0 ]] && warn "Script not running as root - will use sudo for system changes."

require_cmd lsb_release
DISTRO="$(lsb_release -is || true)"
CODENAME="$(lsb_release -cs || true)"
ARCH="$(dpkg --print-architecture)"

[[ "${DISTRO}" != "Ubuntu" ]] && die "Only Ubuntu is supported (found: ${DISTRO})."
[[ "${ARCH}" != "amd64" ]] && die "This script is for x86_64/amd64 (found: ${ARCH})."

# --------------------------
# Check for Docker
# --------------------------
if ! command -v docker >/dev/null 2>&1; then
  die "Docker not found. Please run install.sh first to install Docker, or install Docker manually."
fi

DOCKER_CMD="$(command -v docker)"

# --------------------------
# GPU Detection
# --------------------------
GPU_AVAILABLE="false"
if [[ "${MODE}" == "gpu" ]]; then
  log "Checking for NVIDIA GPU..."
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    GPU_AVAILABLE="true"
    log "NVIDIA GPU detected."
  else
    warn "No NVIDIA GPU detected. Will use CPU mode."
    warn "If you have a GPU, ensure NVIDIA drivers and Container Toolkit are installed."
    MODE="cpu"
  fi
fi

# --------------------------
# Check for LocalAI conflict
# --------------------------
if systemctl is-active --quiet localai.service 2>/dev/null; then
  warn "LocalAI service is currently running."
  warn "Both services can run simultaneously, but will use more resources."
  if [[ "${NONINTERACTIVE}" != "true" ]]; then
    read -r -p "Continue? [y/N]: " response
    case "${response}" in
      [yY]|[yY][eE][sS]) ;;
      *) die "Installation cancelled." ;;
    esac
  fi
fi

# --------------------------
# Create directories
# --------------------------
log "Creating directories: ${OLLAMA_DIR}, ${MODELS_PATH}, ${WEBUI_DATA}"
sudo mkdir -p "${OLLAMA_DIR}" "${MODELS_PATH}" "${WEBUI_DATA}"

# --------------------------
# Generate docker-compose.yml
# --------------------------
if [[ "${MODE}" == "gpu" && "${GPU_AVAILABLE}" == "true" ]]; then
  log "Creating docker-compose.yml with GPU support..."
  sudo cp config/docker-compose.ollama-gpu.yml.example "${COMPOSE_FILE}"
else
  log "Creating docker-compose.yml (CPU mode)..."
  sudo cp config/docker-compose.ollama-cpu.yml.example "${COMPOSE_FILE}"
fi

# Update ports in compose file
sudo sed -i "s/11434:11434/${OLLAMA_PORT}:11434/" "${COMPOSE_FILE}"
sudo sed -i "s/3000:8080/${WEBUI_PORT}:8080/" "${COMPOSE_FILE}"

# Update paths
sudo sed -i "s|/opt/ollama/models|${MODELS_PATH}|" "${COMPOSE_FILE}"
sudo sed -i "s|/opt/ollama/webui|${WEBUI_DATA}|" "${COMPOSE_FILE}"

# --------------------------
# Create systemd service
# --------------------------
log "Creating systemd service: ${SERVICE_NAME}"
sudo tee "/etc/systemd/system/${SERVICE_NAME}" >/dev/null <<'UNIT'
[Unit]
Description=Ollama AI Server with Open WebUI via Docker Compose
Requires=docker.service
After=network-online.target docker.service
Wants=network-online.target
Conflicts=localai.service

[Service]
Type=oneshot
WorkingDirectory=/opt/ollama
Environment=COMPOSE_PROJECT_NAME=ollama
ExecStartPre=/usr/bin/docker compose pull --quiet
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT

# --------------------------
# Configure firewall
# --------------------------
if [[ "${CONFIGURE_FIREWALL}" == "true" ]]; then
  if command -v ufw >/dev/null 2>&1; then
    log "Configuring UFW firewall..."
    sudo ufw allow "${OLLAMA_PORT}/tcp" comment "Ollama API" || true
    sudo ufw allow "${WEBUI_PORT}/tcp" comment "Open WebUI" || true
  fi
fi

# --------------------------
# Start service
# --------------------------
log "Validating docker-compose.yml..."
( cd "${OLLAMA_DIR}" && "${DOCKER_CMD}" compose config >/dev/null )

log "Enabling and starting Ollama service..."
sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}"

# --------------------------
# Post-checks
# --------------------------
log "Checking status..."
sleep 5

if curl -fsS "http://127.0.0.1:${OLLAMA_PORT}/" >/dev/null 2>&1; then
  log "✓ Ollama is ready!"
  echo ""
  log "Ollama API: http://localhost:${OLLAMA_PORT}"
  log "Open WebUI: http://localhost:${WEBUI_PORT}"
  echo ""
  log "To pull models:"
  echo "  docker exec ollama ollama pull llama3.2"
  echo "  docker exec ollama ollama pull mistral"
  echo ""
  log "Or use the management script:"
  echo "  ./ai-server-manager.sh pull llama3.2"
  echo ""
else
  warn "Ollama endpoint not ready yet. Check logs with: docker logs -f ollama"
fi

log "Installation complete! 🚀"
log ""
log "Quick start:"
log "  1. Pull a model: ./ai-server-manager.sh pull llama3.2"
log "  2. Open WebUI: http://localhost:${WEBUI_PORT}"
log "  3. Use with n8n: Point to http://localhost:${OLLAMA_PORT}"
log ""
log "Switch between LocalAI and Ollama:"
log "  ./ai-server-manager.sh localai    # Switch to LocalAI"
log "  ./ai-server-manager.sh ollama     # Switch to Ollama"
log "  ./ai-server-manager.sh status     # Check status"
