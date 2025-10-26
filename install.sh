#!/usr/bin/env bash
set -euo pipefail

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
#   --cpu-only         : erzwingt CPU-Image anstelle von GPU
#   --non-interactive  : unterdrückt Pausen/Hinweise
#   --models-path PATH : Host-Pfad für Modelle (default: /opt/localai/models)
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

# --------------------------
# Utils
# --------------------------
log() { echo -e "\033[1;32m[+] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[!] $*\033[0m"; }
err() { echo -e "\033[1;31m[✗] $*\033[0m" >&2; }
die() { err "$*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Benötigtes Kommando fehlt: $1"; }

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
  if [[ ! -t 0 ]]; then
    return 1
  fi
  local response
  read -r -p "${prompt} [y/N]: " response || return 1
  case "${response}" in
    [yY]|[yY][eE][sS]|[jJ]|[jJ][aA]) return 0 ;;
    *) return 1 ;;
  esac
}

systemd_unit_exists() {
  [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]] || systemctl list-unit-files "${SERVICE_NAME}" >/dev/null 2>&1
}

docker_bin() {
  if [[ -n "${DOCKER_CMD}" ]]; then
    printf '%s\n' "${DOCKER_CMD}"
    return
  fi
  command -v docker 2>/dev/null || true
}

docker_container_exists() {
  local bin
  bin="$(docker_bin)"
  [[ -z "${bin}" ]] && return 1
  local containers
  containers="$("${bin}" ps -a --format '{{.Names}}' 2>/dev/null || true)"
  [[ -z "${containers}" ]] && return 1
  if grep -Fxq "localai" <<<"${containers}"; then
    return 0
  fi
  return 1
}

backup_file() {
  local target="$1"
  [[ ! -f "${target}" ]] && return 0
  local stamp
  stamp="$(date +%Y%m%d%H%M%S)"
  local backup="${target}.${stamp}.bak"
  sudo cp "${target}" "${backup}"
  log "Backup erstellt: ${backup}"
}

stop_localai_service() {
  if systemd_unit_exists; then
    log "Stoppe LocalAI systemd Dienst…"
    sudo systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
  fi
}

stop_localai_containers() {
  local bin
  bin="$(docker_bin)"
  [[ -z "${bin}" ]] && return 0
  if ! docker_container_exists; then
    return 0
  fi
  log "Stoppe LocalAI Container…"
  if [[ -d "${LOCALAI_DIR}" ]]; then
    ( cd "${LOCALAI_DIR}" && "${bin}" compose down --remove-orphans >/dev/null 2>&1 ) || true
  fi
  "${bin}" rm -f localai >/dev/null 2>&1 || true
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
    EXISTING_COMPONENTS+=("docker container")
    found="true"
  fi

  [[ -d "${LOCALAI_DIR}" ]] && PERSISTED_DIRECTORIES+=("${LOCALAI_DIR}")
  [[ -d "${MODELS_PATH}" ]] && PERSISTED_DIRECTORIES+=("${MODELS_PATH}")

  if [[ "${found}" == "true" ]]; then
    EXISTING_INSTALLATION="true"
  else
    EXISTING_INSTALLATION="false"
  fi
}

safe_uninstall() {
  log "Führe saubere Deinstallation der bestehenden Installation durch…"
  stop_localai_service
  stop_localai_containers

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
}

handle_existing_installation() {
  detect_existing_installation

  if [[ ${#PERSISTED_DIRECTORIES[@]} -gt 0 ]]; then
    log "Vorhandene Verzeichnisse werden weiterverwendet: $(join_by ', ' "${PERSISTED_DIRECTORIES[@]}")"
  fi

  if [[ "${EXISTING_INSTALLATION}" != "true" ]]; then
    if [[ "${REPAIR_ONLY}" == "true" ]]; then
      warn "Reparaturmodus angefordert, aber keine bestehende Installation gefunden – starte reguläre Installation."
      REPAIR_ONLY="false"
    fi
    return
  fi

  local components
  components="$(join_by ', ' "${EXISTING_COMPONENTS[@]}")"
  warn "Gefundene LocalAI-Artefakte: ${components}"

  if [[ "${REPAIR_ONLY}" == "true" ]]; then
    log "Reparaturmodus aktiv – stoppe Dienst für Neu-Konfiguration."
    stop_localai_service
    stop_localai_containers
    return
  fi

  if [[ "${NONINTERACTIVE}" == "true" ]]; then
    log "Nicht-interaktiver Modus: bestehende Installation wird automatisch ersetzt."
    safe_uninstall
    return
  fi

  if prompt_yes_no "Bestehende Installation gefunden (${components}). Saubere Neuinstallation durchführen?"; then
    safe_uninstall
  else
    log "Überspringe Deinstallation – konfiguriere bestehende Installation neu."
    stop_localai_service
    stop_localai_containers
  fi
}

# --------------------------
# Argumente
# --------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-only) MODE="cpu"; shift ;;
    --non-interactive) NONINTERACTIVE="true"; shift ;;
    --repair) REPAIR_ONLY="true"; shift ;;
    --models-path) MODELS_PATH="${2:?}"; shift 2 ;;
    *) die "Unbekanntes Argument: $1" ;;
  esac
done

handle_existing_installation

# --------------------------
# Checks
# --------------------------
[[ "$(id -u)" -ne 0 ]] && warn "Skript läuft nicht als root – verwende sudo für Systemänderungen."
require_cmd lsb_release
DISTRO="$(lsb_release -is || true)"
CODENAME="$(lsb_release -cs || true)"
ARCH="$(dpkg --print-architecture)"

[[ "${DISTRO}" != "Ubuntu" ]] && die "Nur Ubuntu wird unterstützt (gefunden: ${DISTRO})."
[[ "${CODENAME}" != "noble" ]] && warn "Empfohlen: Ubuntu 24.04 (Noble). Gefunden: ${CODENAME}. Ich versuche es trotzdem."
[[ "${ARCH}" != "amd64" ]] && die "Dieses Skript ist für x86_64/amd64 gebaut (gefunden: ${ARCH})."

# --------------------------
# Pakete & Tools
# --------------------------
log "APT-Grundpakete installieren…"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg jq lsb-release

# --------------------------
# Docker-Repository einrichten
# --------------------------
log "Docker APT-Repository einrichten…"
sudo install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update -y
log "Docker CE + Compose installieren…"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

DOCKER_CMD="$(docker_bin)"
[[ -z "${DOCKER_CMD}" ]] && die "docker konnte nach der Installation nicht gefunden werden."

# --------------------------
# Docker-Dienste & Gruppe
# --------------------------
log "Docker-Dienste aktivieren…"
sudo systemctl daemon-reload
# Socket aktivieren (fd://)
sudo systemctl unmask docker.socket || true
sudo systemctl enable --now docker.socket
sudo systemctl enable --now docker

# Nutzer in docker-Gruppe (falls vorhanden)
if [[ -n "${SUDO_USER:-}" ]]; then
  log "User ${SUDO_USER} zur docker-Gruppe hinzufügen (für spätere Logins)…"
  sudo usermod -aG docker "${SUDO_USER}" || true
else
  warn "Kein SUDO_USER gesetzt – Überspringe Gruppenänderung."
fi

# --------------------------
# NVIDIA Toolkit (falls GPU)
# --------------------------
GPU_AVAILABLE="false"
if [[ "${MODE}" == "gpu" ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_AVAILABLE="true"
  else
    warn "nvidia-smi nicht gefunden – versuche NVIDIA Container Toolkit zu installieren."
    # Repo einrichten
    if [[ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]]; then
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    fi
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y nvidia-container-toolkit

    # Docker-Runtime konfigurieren
    sudo nvidia-ctk runtime configure --runtime=docker --set-as-default=true
    sudo systemctl restart docker

    # Finaler Check
    if command -v nvidia-smi >/dev/null 2>&1; then
      GPU_AVAILABLE="true"
    else
      warn "nvidia-smi weiterhin nicht verfügbar. GPU-Modus wird NICHT erzwungen."
      GPU_AVAILABLE="false"
    fi
  fi
fi

# --------------------------
# LocalAI Verzeichnisse
# --------------------------
log "Verzeichnisse anlegen: ${LOCALAI_DIR} & ${MODELS_PATH}"
sudo mkdir -p "${LOCALAI_DIR}" "${MODELS_PATH}"

# --------------------------
# docker-compose.yml schreiben
# --------------------------
if [[ "${MODE}" == "gpu" && "${GPU_AVAILABLE}" == "true" ]]; then
  IMAGE="localai/localai:latest-gpu-nvidia-cuda-12"
  GPU_YAML='
    # NVIDIA GPU verwenden
    gpus: "all"
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
'
  log "Schreibe docker-compose.yml (GPU: ${IMAGE})…"
else
  IMAGE="localai/localai:latest"
  GPU_YAML=''
  warn "Schreibe docker-compose.yml (CPU: ${IMAGE}) – GPU nicht verfügbar/erzwungen."
fi

sudo tee "${COMPOSE_FILE}" >/dev/null <<YAML
services:
  localai:
    image: ${IMAGE}
    container_name: localai
    restart: unless-stopped
${GPU_YAML}    ports:
      - "8080:8080"
    environment:
      - DEBUG=false
      - THREADS=4
      - MODELS_PATH=/models
    volumes:
      - ${MODELS_PATH}:/models
YAML

# --------------------------
# systemd Unit schreiben
# --------------------------
log "systemd Unit erstellen: ${SERVICE_NAME}"
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

# --------------------------
# Start
# --------------------------
log "Compose validieren…"
( cd "${LOCALAI_DIR}" && "${DOCKER_CMD}" compose config >/dev/null )

log "LocalAI Dienst aktivieren & starten…"
sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}"

# --------------------------
# Post-Checks
# --------------------------
log "Status prüfen…"
systemctl --no-pager --full status "${SERVICE_NAME}" || true

log "Docker-Container:"
"${DOCKER_CMD}" ps || true

# Health-Check (kann anfangs noch 'starting' sein)
log "Warte kurz auf Health-Endpoint…"
sleep 3 || true
if curl -fsS http://localhost:8080/readyz >/dev/null 2>&1; then
  log "LocalAI ist bereit: http://localhost:8080"
else
  warn "Health-Endpoint noch nicht bereit. Logs ansehen mit:  docker logs -f localai"
fi

# Hinweis zur Gruppe
if [[ -n "${SUDO_USER:-}" ]]; then
  warn "Falls '${SUDO_USER}' neu zur docker-Gruppe hinzugefügt wurde, ist ein Re-Login nötig, damit 'docker' ohne sudo funktioniert."
fi

log "Fertig. Viel Spaß mit LocalAI! 🚀"
