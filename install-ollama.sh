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
#   --repair               : Repair existing installation
#   --models-path PATH     : Host path for models (default: /opt/ollama/models)
#   --ollama-port PORT     : External Ollama API port (default: 11434)
#   --webui-port PORT      : External Open WebUI port (default: 3000)
#   --skip-firewall        : Skip UFW configuration

# --------------------------
# Configuration
# --------------------------
MODE="gpu"
NONINTERACTIVE="false"
REPAIR_ONLY="false"
EXISTING_INSTALLATION="false"
EXISTING_COMPONENTS=()
PERSISTED_DIRECTORIES=()
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

join_by() {
  local delimiter="$1"
  shift
  if [[ $# -eq 0 ]]; then
    printf ''
    return 0
  fi
  local first="$1"
  shift
  printf '%s' "${first}"
  local item
  for item in "$@"; do
    printf '%s%s' "${delimiter}" "${item}"
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local response
  if [[ "${default,,}" == "y" ]]; then
    read -r -p "${prompt} [Y/n]: " response
    case "${response,,}" in
      n|no) return 1 ;;
      *) return 0 ;;
    esac
  else
    read -r -p "${prompt} [y/N]: " response
    case "${response,,}" in
      y|yes) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# --------------------------
# Checks for existing installation
# --------------------------
systemd_unit_exists() {
  [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]]
}

unit_exists() {
  local unit="$1"
  systemctl list-unit-files "${unit}" --no-legend 2>/dev/null | grep -q "${unit}"
}

docker_container_exists() {
  local bin
  bin="$(command -v docker 2>/dev/null || true)"
  [[ -z "${bin}" ]] && return 1
  "${bin}" ps -a --format '{{.Names}}' 2>/dev/null | grep -qE '^(ollama|open-webui)$'
}

stop_service() {
  local service="$1"
  if systemctl is-active --quiet "${service}" 2>/dev/null; then
    sudo systemctl stop "${service}" 2>/dev/null || true
  fi
}

disable_service() {
  local service="$1"
  if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
    sudo systemctl disable "${service}" 2>/dev/null || true
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    local backup="${file}.backup.$(date +%s)"
    sudo cp "${file}" "${backup}"
    log "Backup created: ${backup}"
  fi
}

stop_ollama_service() {
  if systemctl list-unit-files "${SERVICE_NAME}" --no-legend 2>/dev/null | grep -q "${SERVICE_NAME}"; then
    log "Stopping Ollama systemd service..."
    stop_service "${SERVICE_NAME}"
  fi
}

stop_ollama_containers() {
  local bin
  bin="$(command -v docker 2>/dev/null || true)"
  [[ -z "${bin}" ]] && return 0
  if ! docker_container_exists; then
    return 0
  fi
  log "Stopping Ollama containers..."
  if [[ -d "${OLLAMA_DIR}" ]]; then
    ( cd "${OLLAMA_DIR}" && "${bin}" compose down --remove-orphans >/dev/null 2>&1 ) || true
  fi
  "${bin}" rm -f ollama open-webui >/dev/null 2>&1 || true
}

detect_existing_installation() {
  EXISTING_COMPONENTS=()
  PERSISTED_DIRECTORIES=()
  local found="false"

  if [[ -f "${COMPOSE_FILE}" ]]; then
    EXISTING_COMPONENTS+=("docker-compose.yml")
    found="true"
  fi

  if systemd_unit_exists; then
    EXISTING_COMPONENTS+=("systemd service")
    found="true"
  fi

  if docker_container_exists; then
    EXISTING_COMPONENTS+=("docker containers")
    found="true"
  fi

  [[ -d "${OLLAMA_DIR}" ]] && PERSISTED_DIRECTORIES+=("${OLLAMA_DIR}")
  [[ -d "${MODELS_PATH}" ]] && PERSISTED_DIRECTORIES+=("${MODELS_PATH}")
  [[ -d "${WEBUI_DATA}" ]] && PERSISTED_DIRECTORIES+=("${WEBUI_DATA}")

  if [[ "${found}" == "true" ]]; then
    EXISTING_INSTALLATION="true"
  else
    EXISTING_INSTALLATION="false"
  fi
}

safe_uninstall() {
  log "Performing clean uninstallation of existing Ollama installation..."
  stop_ollama_service
  stop_ollama_containers

  if [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]]; then
    backup_file "/etc/systemd/system/${SERVICE_NAME}"
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}"
  fi

  if [[ -f "${COMPOSE_FILE}" ]]; then
    backup_file "${COMPOSE_FILE}"
    sudo rm -f "${COMPOSE_FILE}"
  fi

  sudo systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
  sudo systemctl daemon-reload

  log "Uninstallation complete. Model data preserved in: ${MODELS_PATH}"
}

handle_existing_installation() {
  detect_existing_installation

  if [[ "${EXISTING_INSTALLATION}" != "true" ]]; then
    if [[ "${REPAIR_ONLY}" == "true" ]]; then
      warn "Repair mode requested, but no existing installation found - starting regular installation."
      REPAIR_ONLY="false"
    fi
    return
  fi

  local components
  components="$(join_by ', ' "${EXISTING_COMPONENTS[@]}")"
  warn "Found existing Ollama installation: ${components}"

  if [[ "${REPAIR_ONLY}" == "true" ]]; then
    log "Repair mode active - stopping service for reconfiguration."
    stop_ollama_service
    stop_ollama_containers
    return
  fi

  if [[ "${NONINTERACTIVE}" == "true" ]]; then
    log "Non-interactive mode: existing installation will be automatically replaced."
    safe_uninstall
    return
  fi

  if prompt_yes_no "Existing installation found (${components}). Perform clean reinstallation?"; then
    safe_uninstall
  else
    log "Skipping uninstallation - reconfiguring existing installation."
    stop_ollama_service
    stop_ollama_containers
  fi
}

# --------------------------
# Argument parsing
# --------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-only) MODE="cpu"; shift ;;
    --non-interactive) NONINTERACTIVE="true"; shift ;;
    --repair) REPAIR_ONLY="true"; shift ;;
    --models-path) MODELS_PATH="${2:?}"; shift 2 ;;
    --ollama-port) OLLAMA_PORT="${2:?}"; shift 2 ;;
    --webui-port) WEBUI_PORT="${2:?}"; shift 2 ;;
    --skip-firewall) CONFIGURE_FIREWALL="false"; shift ;;
    *) die "Unknown argument: $1" ;;
  esac
done

handle_existing_installation

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
# Check for parallel LocalAI operation
# --------------------------
if systemctl is-active --quiet localai.service 2>/dev/null; then
  log "LocalAI service is currently running."
  log "Both services can run in parallel and share GPU resources."
  log "Tip: Use ./ai-server-manager.sh to manage both services."
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

log ""
log "=========================================="
log "✓ Installation complete!"
log "=========================================="
log ""
log "Ollama Server Status:"
log "  Service:     ${SERVICE_NAME}"
log "  API:         http://localhost:${OLLAMA_PORT}"
log "  Open WebUI:  http://localhost:${WEBUI_PORT}"
log "  Models dir:  ${MODELS_PATH}"
log ""
log "Quick start:"
log "  1. Pull a model:"
log "     ./ai-server-manager.sh pull llama3.2"
log "     ./ai-server-manager.sh pull mistral"
log ""
log "  2. Open Web Interface:"
log "     http://localhost:${WEBUI_PORT}"
log ""
log "  3. Check status:"
log "     ./ai-server-manager.sh status"
log ""
log "Management commands:"
log "  ./ai-server-manager.sh status      # View all services"
log "  ./ai-server-manager.sh models      # List installed models"
log "  ./ai-server-manager.sh both        # Start both LocalAI and Ollama"
log "  ./ai-server-manager.sh stop        # Stop all services"
log ""
log "Troubleshooting:"
log "  sudo systemctl status ${SERVICE_NAME}"
log "  docker logs -f ollama"
log "  docker logs -f open-webui"
log ""
