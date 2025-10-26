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

# --------------------------
# Utils
# --------------------------
log() { echo -e "\033[1;32m[+] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[!] $*\033[0m"; }
err() { echo -e "\033[1;31m[✗] $*\033[0m" >&2; }
die() { err "$*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Benötigtes Kommando fehlt: $1"; }

# --------------------------
# Argumente
# --------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-only) MODE="cpu"; shift ;;
    --non-interactive) NONINTERACTIVE="true"; shift ;;
    --models-path) MODELS_PATH="${2:?}"; shift 2 ;;
    *) die "Unbekanntes Argument: $1" ;;
  esac
done

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
( cd "${LOCALAI_DIR}" && /usr/bin/docker compose config >/dev/null )

log "LocalAI Dienst aktivieren & starten…"
sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}"

# --------------------------
# Post-Checks
# --------------------------
log "Status prüfen…"
systemctl --no-pager --full status "${SERVICE_NAME}" || true

log "Docker-Container:"
/usr/bin/docker ps || true

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