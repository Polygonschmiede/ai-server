#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# Source Helper Libraries
# --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all helper libraries
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/scripts/lib/system.sh"
source "${SCRIPT_DIR}/scripts/lib/service.sh"
source "${SCRIPT_DIR}/scripts/lib/docker.sh"
source "${SCRIPT_DIR}/scripts/lib/power.sh"
source "${SCRIPT_DIR}/scripts/lib/install_helpers.sh"

# --------------------------
# LocalAI Installer (Ubuntu 24.04 + NVIDIA)
# --------------------------
# Features:
# - Offizielles Docker APT-Repo hinzufügen
# - docker-ce, docker-compose-plugin, buildx, containerd installieren
# - docker/socket aktivieren, User in docker-Gruppe
# - NVIDIA Container Toolkit installieren & als Default-Runtime setzen
# - /opt/localai mit docker-compose.yml (GPU-Image CUDA 12)
# - systemd Unit: pull vor up, down beim Stop
# - Idempotent; sicher mehrmals ausführbar
#
# Flags:
#   --cpu-only             : erzwingt CPU-Image anstelle von GPU
#   --non-interactive      : unterdrückt Pausen/Hinweise (überschreibt Prompts)
#   --models-path PATH     : Host-Pfad für Modelle (default: /opt/localai/models)
#   --timezone ZONE        : Zeitzone setzen (default: Europe/Berlin)
#   --localai-port PORT    : Externer LocalAI-Port (default: 8080)
#   --stay-awake-port PORT : HTTP Keep-Alive Port (default: 9876)
#   --stay-awake-bind IP   : Bind-Adresse für Stay-Awake (default: 0.0.0.0)
#   --server-ip IP         : Server-IP für Statushinweise (default: 192.168.178.50)
#   --skip-firewall        : Skips UFW configuration
#   --harden-ssh           : Passwort-SSH deaktivieren & Root-Login verbieten
#   --skip-ssh-hardening   : Erzwingt, dass SSH unverändert bleibt
#   --skip-auto-suspend    : Skips Auto-Suspend watcher
#   --skip-stay-awake      : Skips Stay-Awake HTTP service
#   --skip-wol             : Skips Wake-on-LAN
#   --wol-interface IFACE  : WOL-Interface explizit setzen (default: automatisch)
#   --wait-minutes MIN     : Idle-Min bis Suspend (default: 30)
#   --cpu-idle-threshold % : CPU Idle-Schwelle (default: 90)
#   --gpu-max %            : max. GPU-Utilisation für Idle (default: 10)
#   --check-interval SEC   : Auto-Suspend check interval (default: 60)
#
# Nach dem Run: WebUI/HTTP: http://<server>:8080, Health: /health /readyz

# --------------------------
# Konfiguration
# --------------------------
MODE="gpu"                # "gpu" (Default) oder "cpu"
NONINTERACTIVE="false"
MODELS_PATH_DEFAULT="/opt/localai/models"
MODELS_PATH="${MODELS_PATH_DEFAULT}"
LOCALAI_DIR="/opt/localai"
COMPOSE_FILE="${LOCALAI_DIR}/docker-compose.yml"
SERVICE_NAME="localai.service"
REPAIR_ONLY="false"
EXISTING_INSTALLATION="false"
EXISTING_COMPONENTS=()
PERSISTED_DIRECTORIES=()
DOCKER_CMD=""
TIMEZONE="Europe/Berlin"
LOCALAI_PORT="8080"
STAY_AWAKE_PORT="9876"
STAY_AWAKE_BIND="0.0.0.0"
SERVER_IP="192.168.178.50"
CONFIGURE_FIREWALL="true"
SSH_HARDEN="auto"
ENABLE_AUTO_SUSPEND="true"
ENABLE_STAY_AWAKE="true"
ENABLE_WOL="true"
WOL_INTERFACE=""
WAIT_MINUTES="5"
CPU_IDLE_THRESHOLD="90"
GPU_USAGE_MAX="10"
GPU_PROC_FORBID="1"
CHECK_INTERVAL="60"
MANAGED_SERVICE_AUTO_SUSPEND="ai-auto-suspend.service"
MANAGED_SERVICE_STAY_AWAKE="stay-awake.service"
MANAGED_SERVICE_WOL_TEMPLATE="/etc/systemd/system/wol@.service"
MANAGED_ENV_DIR="/etc/localai-installer"
PORTS_DEFAULT_STRING="8080 11434 8000 8081 7860 9600 5000 3000"


# --------------------------
# Argumente
# --------------------------
load_previous_state
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-only) MODE="cpu"; shift ;;
    --non-interactive) NONINTERACTIVE="true"; shift ;;
    --repair) REPAIR_ONLY="true"; shift ;;
    --models-path) MODELS_PATH="${2:?}"; shift 2 ;;
    --timezone) TIMEZONE="${2:?}"; shift 2 ;;
    --localai-port) LOCALAI_PORT="${2:?}"; shift 2 ;;
    --stay-awake-port) STAY_AWAKE_PORT="${2:?}"; shift 2 ;;
    --stay-awake-bind) STAY_AWAKE_BIND="${2:?}"; shift 2 ;;
    --server-ip) SERVER_IP="${2:?}"; shift 2 ;;
    --skip-firewall) CONFIGURE_FIREWALL="false"; shift ;;
    --harden-ssh) SSH_HARDEN="true"; shift ;;
    --skip-ssh-hardening) SSH_HARDEN="false"; shift ;;
    --skip-auto-suspend) ENABLE_AUTO_SUSPEND="false"; shift ;;
    --skip-stay-awake) ENABLE_STAY_AWAKE="false"; shift ;;
    --skip-wol) ENABLE_WOL="false"; shift ;;
    --wol-interface) WOL_INTERFACE="${2:?}"; shift 2 ;;
    --wait-minutes) WAIT_MINUTES="${2:?}"; shift 2 ;;
    --cpu-idle-threshold) CPU_IDLE_THRESHOLD="${2:?}"; shift 2 ;;
    --gpu-max) GPU_USAGE_MAX="${2:?}"; shift 2 ;;
    --gpu-proc-forbid) GPU_PROC_FORBID="${2:?}"; shift 2 ;;
    --check-interval) CHECK_INTERVAL="${2:?}"; shift 2 ;;
    *) die "Unbekanntes Argument: $1" ;;
  esac
done

handle_existing_installation

# --------------------------
# Start-Banner
# --------------------------
clear
echo "=========================================================================="
echo "              LocalAI Installer for Ubuntu 24.04 + NVIDIA"
echo "=========================================================================="
echo ""
info "Configuration:"
echo "  • Modus: ${MODE}"
echo "  • LocalAI Port: ${LOCALAI_PORT}"
echo "  • Modelle-Pfad: ${MODELS_PATH}"
echo "  • Auto-Suspend: ${ENABLE_AUTO_SUSPEND} (${WAIT_MINUTES} Min Idle)"
echo "  • Stay-Awake: ${ENABLE_STAY_AWAKE} (Port ${STAY_AWAKE_PORT})"
echo "  • Wake-on-LAN: ${ENABLE_WOL}"
echo "  • Firewall: ${CONFIGURE_FIREWALL}"
echo ""
info "The installation will now begin. This may take 5-15 minutes."
info "You will receive detailed feedback on each step."
echo ""
sleep 2

# --------------------------
# Checks
# --------------------------
log "==================== System-Checks ===================="
[[ "$(id -u)" -ne 0 ]] && warn "Script not running as root – using sudo for system changes."

info "Checking system requirements..."
require_cmd lsb_release
DISTRO="$(lsb_release -is || true)"
CODENAME="$(lsb_release -cs || true)"
ARCH="$(dpkg --print-architecture)"

info "Erkanntes System:"
echo "  • Distribution: ${DISTRO}"
echo "  • Codename: ${CODENAME}"
echo "  • Architektur: ${ARCH}"
echo ""

if [[ "${DISTRO}" != "Ubuntu" ]]; then
  die "Only Ubuntu is supported (found: ${DISTRO})."
fi

if [[ "${CODENAME}" != "noble" ]]; then
  warn "Empfohlen: Ubuntu 24.04 (Noble). Gefunden: ${CODENAME}. Ich versuche es trotzdem."
else
  success "Ubuntu 24.04 (Noble) erkannt - perfekt!"
fi

if [[ "${ARCH}" != "amd64" ]]; then
  die "Dieses Skript ist für x86_64/amd64 gebaut (gefunden: ${ARCH})."
else
  success "Architektur amd64 - kompatibel!"
fi

# --------------------------
# Pakete & Tools
# --------------------------
echo ""
log "==================== APT-Repository aktualisieren ===================="
info "Aktualisiere Paketlisten..."
if sudo apt-get update -y; then
  success "Paketlisten aktualisiert"
else
  err "Error updating package lists"
  exit 1
fi

echo ""
log "==================== Installing Base Packages ===================="
install_base_packages

echo ""
log "==================== System Configuration ===================="
ensure_timezone
maybe_harden_ssh
configure_firewall

# --------------------------
# Docker-Repository einrichten
# --------------------------
echo ""
log "==================== Docker-Repository einrichten ===================="
info "Creating keyring directory..."
sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  info "Downloading Docker GPG key..."
  if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    success "Docker GPG key installed"
  else
    die "Error downloading Docker GPG key"
  fi
else
  success "Docker GPG key already present"
fi

info "Füge Docker APT-Repository hinzu..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
success "Docker-Repository hinzugefügt"

info "Updating package lists for Docker..."
if sudo apt-get update -y; then
  success "Paketlisten aktualisiert"
else
  err "Error updating package lists"
  exit 1
fi

echo ""
log "==================== Installing Docker CE + Compose ===================="
info "Installing: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin"
info "Dies kann mehrere Minuten dauern..."
if sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
  success "Docker successfully installed"
else
  err "Error during Docker installation"
  exit 1
fi

info "Checking Docker installation..."
DOCKER_CMD="$(docker_bin)"
if [[ -z "${DOCKER_CMD}" ]]; then
  die "docker could not be found after installation."
else
  success "Docker-Binary gefunden: ${DOCKER_CMD}"
fi

# --------------------------
# Docker-Dienste & Gruppe
# --------------------------
echo ""
log "==================== Enabling Docker Services ===================="
info "Reloading systemd configuration..."
sudo systemctl daemon-reload

info "Enabling Docker socket..."
sudo systemctl unmask docker.socket || true
if sudo systemctl enable --now docker.socket; then
  success "Docker socket enabled"
else
  warn "Error enabling Docker socket"
fi

info "Enabling Docker service..."
if sudo systemctl enable --now docker; then
  success "Docker service enabled and started"
else
  err "Error enabling Docker service"
  exit 1
fi

# Nutzer in docker-Gruppe (falls vorhanden)
if [[ -n "${SUDO_USER:-}" ]]; then
  info "Füge User ${SUDO_USER} zur docker-Gruppe hinzu..."
  if sudo usermod -aG docker "${SUDO_USER}"; then
    success "User ${SUDO_USER} zur docker-Gruppe hinzugefügt"
    warn "IMPORTANT: ${SUDO_USER} must log out and back in for group changes to take effect!"
  else
    warn "Could not add user to docker group"
  fi
else
  warn "No SUDO_USER set – skipping group change."
fi

# --------------------------
# NVIDIA Toolkit (falls GPU)
# --------------------------
echo ""
log "==================== Checking NVIDIA GPU Support ===================="
GPU_AVAILABLE="false"
if [[ "${MODE}" == "gpu" ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    success "nvidia-smi gefunden - GPU-Unterstützung verfügbar"
    GPU_AVAILABLE="true"
    info "GPU-Informationen:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || true
  else
    warn "nvidia-smi not found – attempting to install NVIDIA Container Toolkit."

    # Repo einrichten
    if [[ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]]; then
      info "Loading NVIDIA Container Toolkit GPG key..."
      if curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg; then
        success "NVIDIA GPG key installed"
      else
        warn "Error downloading NVIDIA GPG key"
      fi
    fi

    info "Füge NVIDIA Container Toolkit Repository hinzu..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    success "NVIDIA Repository hinzugefügt"

    info "Aktualisiere Paketlisten..."
    sudo apt-get update -y

    info "Installing NVIDIA Container Toolkit..."
    if sudo apt-get install -y nvidia-container-toolkit; then
      success "NVIDIA Container Toolkit installed"
    else
      warn "Error installing NVIDIA Container Toolkit"
    fi

    # Docker-Runtime konfigurieren
    info "Configuring Docker for NVIDIA Runtime..."
    if sudo nvidia-ctk runtime configure --runtime=docker --set-as-default=true; then
      success "Docker configured for NVIDIA"
    else
      warn "Error configuring NVIDIA Runtime"
    fi

    info "Restarting Docker..."
    if sudo systemctl restart docker; then
      success "Docker restarted"
    else
      warn "Error restarting Docker"
    fi

    # Finaler Check
    if command -v nvidia-smi >/dev/null 2>&1; then
      success "nvidia-smi now available - GPU support enabled"
      GPU_AVAILABLE="true"
      nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || true
    else
      warn "nvidia-smi still not available. GPU mode will NOT be enforced."
      warn "Installation will continue in CPU-only mode."
      GPU_AVAILABLE="false"
    fi
  fi
else
  info "CPU-only mode selected - skipping GPU configuration"
fi

# --------------------------
# LocalAI Verzeichnisse
# --------------------------
echo ""
log "==================== LocalAI Verzeichnisse anlegen ===================="
info "Creating directories: ${LOCALAI_DIR} & ${MODELS_PATH}"
if sudo mkdir -p "${LOCALAI_DIR}" "${MODELS_PATH}"; then
  success "Verzeichnisse erfolgreich angelegt"
  info "  - LocalAI-Configuration: ${LOCALAI_DIR}"
  info "  - Modelle: ${MODELS_PATH}"
else
  die "Error creating directories"
fi

# --------------------------
# docker-compose.yml schreiben
# --------------------------
echo ""
log "==================== Creating docker-compose.yml ===================="
if [[ "${MODE}" == "gpu" && "${GPU_AVAILABLE}" == "true" ]]; then
  IMAGE="localai/localai:latest-gpu-nvidia-cuda-12"
  GPU_YAML='
    # NVIDIA GPU verwenden
    gpus: "all"
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
'
  info "Verwende GPU-Image: ${IMAGE}"
else
  IMAGE="localai/localai:latest"
  GPU_YAML=''
  info "Verwende CPU-Image: ${IMAGE}"
fi

info "Schreibe ${COMPOSE_FILE}..."
sudo tee "${COMPOSE_FILE}" >/dev/null <<YAML
services:
  localai:
    image: ${IMAGE}
    container_name: localai
    restart: unless-stopped
${GPU_YAML}    ports:
      - "${LOCALAI_PORT}:8080"
    environment:
      - DEBUG=false
      - THREADS=4
      - MODELS_PATH=/models
    volumes:
      - ${MODELS_PATH}:/models
YAML
success "docker-compose.yml successfully created"

# --------------------------
# systemd Unit schreiben
# --------------------------
echo ""
log "==================== systemd Service einrichten ===================="
info "Creating systemd unit: ${SERVICE_NAME}"
sudo tee "/etc/systemd/system/${SERVICE_NAME}" >/dev/null <<'UNIT'
[Unit]
Description=LocalAI via Docker Compose
Requires=docker.service
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/opt/localai
Environment=COMPOSE_PROJECT_NAME=localai
# Vor dem Start: Images ziehen (leise)
ExecStartPre=/usr/bin/docker compose pull --quiet
# Start im Hintergrund; Container haben restart: unless-stopped
ExecStart=/usr/bin/docker compose up -d
# Beim Stop Container herunterfahren
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT
success "systemd Unit erstellt"

echo ""
log "==================== Support-Services konfigurieren ===================="
info "Configuring Auto-Suspend service..."
configure_auto_suspend_service
info "Configuring Stay-Awake service..."
configure_stay_awake_service
info "Configuring Wake-on-LAN..."
configure_wol
info "Saving configuration status..."
persist_state
success "Support-Services konfiguriert"

# --------------------------
# Start
# --------------------------
echo ""
log "==================== LocalAI Service starten ===================="
info "Validiere docker-compose.yml..."
if ( cd "${LOCALAI_DIR}" && "${DOCKER_CMD}" compose config >/dev/null ); then
  success "docker-compose.yml ist valide"
else
  err "docker-compose.yml ist ungültig!"
  exit 1
fi

info "Reloading systemd configuration..."
sudo systemctl daemon-reload

info "Enabling LocalAI service..."
sudo systemctl enable "${SERVICE_NAME}"
success "Service aktiviert"

echo ""
info "Starting LocalAI service..."
warn "Docker lädt jetzt das Image herunter - dies kann 5-15 Minuten dauern!"
info "Bitte warten Sie, während der Download is running..."
echo ""

# Start service in background and monitor progress
sudo systemctl start "${SERVICE_NAME}" &
START_PID=$!

# Show progress while service starts
log "Service starting (PID: $START_PID)..."
DOTS=0
SECONDS_WAITED=0
while kill -0 $START_PID 2>/dev/null; do
  printf "\r\033[1;36m[⏳] Starting LocalAI service... %ds vergangen\033[0m" $SECONDS_WAITED
  sleep 2
  SECONDS_WAITED=$((SECONDS_WAITED + 2))

  # Show intermediate status every 15 seconds
  if [ $((SECONDS_WAITED % 15)) -eq 0 ] && [ $SECONDS_WAITED -gt 0 ]; then
    echo ""
    info "Status-Update nach ${SECONDS_WAITED}s:"
    if "${DOCKER_CMD}" ps -a --filter "name=localai" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -q "localai"; then
      "${DOCKER_CMD}" ps -a --filter "name=localai" --format "  Container: {{.Names}} - {{.Status}}" 2>/dev/null || true
    else
      info "  Container being prepared..."
    fi
  fi
done
wait $START_PID
START_STATUS=$?
echo ""

if [ $START_STATUS -ne 0 ]; then
  err "Service startup failed!"
  echo ""
  warn "Showing service status for error analysis:"
  sudo systemctl status "${SERVICE_NAME}" --no-pager || true
  echo ""
  warn "Showing container logs for error analysis:"
  "${DOCKER_CMD}" logs localai 2>&1 | tail -n 30 || true
  exit 1
fi

success "systemctl start Befehl abgeschlossen (nach ${SECONDS_WAITED}s)"

# Wait for container to actually start
echo ""
info "Waiting for container to start..."
WAIT_COUNT=0
MAX_WAIT=60
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if "${DOCKER_CMD}" ps --format '{{.Names}}' | grep -q '^localai$'; then
    success "LocalAI Container läuft!"
    break
  fi
  printf "."
  sleep 2
  WAIT_COUNT=$((WAIT_COUNT + 2))
done
echo ""

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  warn "Container startete nicht innerhalb von ${MAX_WAIT} Sekunden"
  info "Container-Status:"
  "${DOCKER_CMD}" ps -a --filter "name=localai" || true
  info "Service-Status:"
  sudo systemctl status "${SERVICE_NAME}" --no-pager || true
fi

# --------------------------
# Post-Checks
# --------------------------
echo ""
log "==================== Verifying Installation ===================="

info "Service-Status:"
systemctl --no-pager --full status "${SERVICE_NAME}" || true

echo ""
info "Docker-Container:"
"${DOCKER_CMD}" ps || true

# Health-Check (kann anfangs noch 'starting' sein)
echo ""
info "Warte auf LocalAI Health-Endpoint (kann bis zu 30 Sekunden dauern)..."
HEALTH_CHECK_ATTEMPTS=10
HEALTH_CHECK_DELAY=3
for i in $(seq 1 ${HEALTH_CHECK_ATTEMPTS}); do
  if curl -fsS "http://127.0.0.1:${LOCALAI_PORT}/readyz" >/dev/null 2>&1; then
    success "LocalAI ist bereit und antwortet auf Health-Checks!"
    break
  else
    if [[ $i -eq ${HEALTH_CHECK_ATTEMPTS} ]]; then
      warn "Health-Endpoint noch nicht bereit nach ${HEALTH_CHECK_ATTEMPTS} Versuchen."
      warn "This is normal on first installation (image download + startup can take a while)."
      warn "Logs ansehen mit: ${DOCKER_CMD} logs -f localai"
    else
      printf "."
      sleep ${HEALTH_CHECK_DELAY}
    fi
  fi
done
echo ""

# --------------------------
# Zusammenfassung
# --------------------------
echo ""
echo "=========================================================================="
log "                    INSTALLATION ABGESCHLOSSEN!                    "
echo "=========================================================================="
echo ""
success "LocalAI wurde erfolgreich installiert und gestartet!"
echo ""
info "📍 Zugriffs-URLs:"
echo "   • LocalAI WebUI/API: http://${SERVER_IP}:${LOCALAI_PORT}"
echo "   • Health Check:      http://${SERVER_IP}:${LOCALAI_PORT}/readyz"
echo "   • Metrics:           http://${SERVER_IP}:${LOCALAI_PORT}/metrics"
echo ""

if [[ "${ENABLE_STAY_AWAKE}" == "true" ]]; then
  info "⏰ Stay-Awake Service:"
  echo "   • Keep-Alive Endpoint: http://${SERVER_IP}:${STAY_AWAKE_PORT}/stay?s=3600"
  echo "   • Beispiel: curl http://${SERVER_IP}:${STAY_AWAKE_PORT}/stay?s=7200"
  echo ""
fi

if [[ "${ENABLE_AUTO_SUSPEND}" == "true" ]]; then
  info "💤 Auto-Suspend:"
  echo "   • Status: Aktiviert"
  echo "   • Idle-Timeout: ${WAIT_MINUTES} Minuten"
  echo "   • CPU Idle-Schwelle: ${CPU_IDLE_THRESHOLD}%"
  echo "   • GPU Max-Auslastung: ${GPU_USAGE_MAX}%"
  echo ""
fi

if [[ "${ENABLE_WOL}" == "true" && -n "${WOL_INTERFACE}" ]]; then
  info "🌐 Wake-on-LAN:"
  echo "   • Status: Aktiviert"
  echo "   • Interface: ${WOL_INTERFACE}"
  echo ""
fi

if [[ "${GPU_AVAILABLE}" == "true" ]]; then
  info "🎮 GPU-Unterstützung:"
  echo "   • Status: Aktiviert (NVIDIA CUDA)"
  echo "   • Image: ${IMAGE}"
  echo ""
else
  info "💻 CPU-Modus:"
  echo "   • Status: Aktiv"
  echo "   • Image: ${IMAGE}"
  echo ""
fi

info "📂 Verzeichnisse:"
echo "   • LocalAI-Config: ${LOCALAI_DIR}"
echo "   • Modelle:        ${MODELS_PATH}"
echo ""

info "🔧 Nützliche Befehle:"
echo "   • Status anzeigen:     sudo systemctl status ${SERVICE_NAME}"
echo "   • Logs anzeigen:       ${DOCKER_CMD} logs -f localai"
echo "   • Service neustarten:  sudo systemctl restart ${SERVICE_NAME}"
echo "   • Service stoppen:     sudo systemctl stop ${SERVICE_NAME}"
echo ""

if [[ -n "${SUDO_USER:-}" ]]; then
  warn "⚠️  WICHTIG: User '${SUDO_USER}' wurde zur docker-Gruppe hinzugefügt."
  warn "   Bitte neu anmelden (logout/login), damit 'docker' ohne sudo funktioniert!"
  echo ""
fi

echo "=========================================================================="
success "🚀 LocalAI ist jetzt einsatzbereit! Viel Erfolg!"
echo "=========================================================================="
