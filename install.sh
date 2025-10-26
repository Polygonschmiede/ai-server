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
#   --cpu-only             : erzwingt CPU-Image anstelle von GPU
#   --non-interactive      : unterdrückt Pausen/Hinweise (überschreibt Prompts)
#   --models-path PATH     : Host-Pfad für Modelle (default: /opt/localai/models)
#   --timezone ZONE        : Zeitzone setzen (default: Europe/Berlin)
#   --localai-port PORT    : Externer LocalAI-Port (default: 8080)
#   --stay-awake-port PORT : HTTP Keep-Alive Port (default: 9876)
#   --stay-awake-bind IP   : Bind-Adresse für Stay-Awake (default: 0.0.0.0)
#   --server-ip IP         : Server-IP für Statushinweise (default: 192.168.178.50)
#   --skip-firewall        : Überspringt UFW-Konfiguration
#   --harden-ssh           : Passwort-SSH deaktivieren & Root-Login verbieten
#   --skip-ssh-hardening   : Erzwingt, dass SSH unverändert bleibt
#   --skip-auto-suspend    : Überspringt Auto-Suspend-Watcher
#   --skip-stay-awake      : Überspringt Stay-Awake-HTTP-Service
#   --skip-wol             : Überspringt Wake-on-LAN
#   --wol-interface IFACE  : WOL-Interface explizit setzen (default: automatisch)
#   --wait-minutes MIN     : Idle-Min bis Suspend (default: 30)
#   --cpu-idle-threshold % : CPU Idle-Schwelle (default: 90)
#   --gpu-max %            : max. GPU-Utilisation für Idle (default: 10)
#   --check-interval SEC   : Prüfintervall Auto-Suspend (default: 60)
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
WAIT_MINUTES="30"
CPU_IDLE_THRESHOLD="90"
GPU_USAGE_MAX="10"
GPU_PROC_FORBID="1"
CHECK_INTERVAL="60"
MANAGED_SCRIPT_AUTO_SUSPEND="/usr/local/bin/ai-auto-suspend.sh"
MANAGED_SCRIPT_STAY_AWAKE="/usr/local/bin/ai-stayawake-http.sh"
MANAGED_SERVICE_AUTO_SUSPEND="ai-auto-suspend.service"
MANAGED_SERVICE_STAY_AWAKE="ai-stayawake-http.service"
MANAGED_SERVICE_WOL_TEMPLATE="/etc/systemd/system/wol@.service"
MANAGED_ENV_DIR="/etc/localai-installer"
PORTS_DEFAULT_STRING="8080 11434 8000 8081 7860 9600 5000 3000"

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

unit_exists() {
  local unit="$1"
  systemctl list-unit-files "${unit}" --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "${unit}"
}

service_active() {
  local unit="$1"
  systemctl is-active "${unit}" >/dev/null 2>&1
}

stop_service() {
  local unit="$1"
  if unit_exists "${unit}"; then
    sudo systemctl stop "${unit}" >/dev/null 2>&1 || true
  fi
}

disable_service() {
  local unit="$1"
  if unit_exists "${unit}"; then
    sudo systemctl disable --now "${unit}" >/dev/null 2>&1 || true
  fi
}

remove_managed_unit() {
  local unit_file="$1"
  local marker="$2"
  if [[ -f "${unit_file}" ]] && grep -q "${marker}" "${unit_file}"; then
    backup_file "${unit_file}"
    sudo rm -f "${unit_file}"
  fi
}

remove_managed_file() {
  local file_path="$1"
  if [[ -f "${file_path}" ]]; then
    backup_file "${file_path}"
    sudo rm -f "${file_path}"
  fi
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

stop_support_services() {
  stop_service "${MANAGED_SERVICE_AUTO_SUSPEND}"
  stop_service "${MANAGED_SERVICE_STAY_AWAKE}"
  local wol_units
  wol_units="$(systemctl list-unit-files 'wol@*.service' --no-legend 2>/dev/null | awk '{print $1}')"
  if [[ -n "${wol_units}" ]]; then
    while IFS= read -r unit; do
      [[ -z "${unit}" ]] && continue
      local fragment
      fragment="$(systemctl show -p FragmentPath --value "${unit}" 2>/dev/null || true)"
      if [[ -n "${fragment}" ]] && [[ -f "${fragment}" ]] && grep -q "Managed by LocalAI Installer" "${fragment}"; then
        stop_service "${unit}"
      fi
    done <<<"${wol_units}"
  fi
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

  if [[ -f "${MANAGED_SCRIPT_AUTO_SUSPEND}" ]]; then
    EXISTING_COMPONENTS+=("auto-suspend script")
    found="true"
  fi

  if [[ -f "${MANAGED_SCRIPT_STAY_AWAKE}" ]]; then
    EXISTING_COMPONENTS+=("stay-awake script")
    found="true"
  fi

  if unit_exists "${MANAGED_SERVICE_AUTO_SUSPEND}"; then
    EXISTING_COMPONENTS+=("auto-suspend service")
    found="true"
  fi

  if unit_exists "${MANAGED_SERVICE_STAY_AWAKE}"; then
    EXISTING_COMPONENTS+=("stay-awake service")
    found="true"
  fi

  if [[ -f "${MANAGED_SERVICE_WOL_TEMPLATE}" ]] && grep -q "Managed by LocalAI Installer" "${MANAGED_SERVICE_WOL_TEMPLATE}"; then
    EXISTING_COMPONENTS+=("wol template")
    found="true"
  fi

  local wol_units
  wol_units="$(systemctl list-unit-files 'wol@*.service' --no-legend 2>/dev/null | awk '{print $1}')"
  if [[ -n "${wol_units}" ]]; then
    while IFS= read -r unit; do
      [[ -z "${unit}" ]] && continue
      local fragment
      fragment="$(systemctl show -p FragmentPath --value "${unit}" 2>/dev/null || true)"
      if [[ -n "${fragment}" ]] && [[ -f "${fragment}" ]] && grep -q "Managed by LocalAI Installer" "${fragment}"; then
        EXISTING_COMPONENTS+=("wol unit ${unit}")
        found="true"
        if [[ -z "${WOL_INTERFACE}" ]]; then
          local iface="${unit#wol@}"
          iface="${iface%.service}"
          WOL_INTERFACE="${iface}"
        fi
      fi
    done <<<"${wol_units}"
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
  stop_support_services
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

  disable_service "${MANAGED_SERVICE_AUTO_SUSPEND}"
  disable_service "${MANAGED_SERVICE_STAY_AWAKE}"

  remove_managed_unit "/etc/systemd/system/${MANAGED_SERVICE_AUTO_SUSPEND}" "Managed by LocalAI Installer"
  remove_managed_unit "/etc/systemd/system/${MANAGED_SERVICE_STAY_AWAKE}" "Managed by LocalAI Installer"
  remove_managed_file "${MANAGED_SCRIPT_AUTO_SUSPEND}"
  remove_managed_file "${MANAGED_SCRIPT_STAY_AWAKE}"

  local wol_units
  wol_units="$(systemctl list-unit-files 'wol@*.service' --no-legend 2>/dev/null | awk '{print $1}')"
  if [[ -n "${wol_units}" ]]; then
    while IFS= read -r unit; do
      [[ -z "${unit}" ]] && continue
      local fragment
      fragment="$(systemctl show -p FragmentPath --value "${unit}" 2>/dev/null || true)"
      if [[ -n "${fragment}" ]] && [[ -f "${fragment}" ]] && grep -q "Managed by LocalAI Installer" "${fragment}"; then
        disable_service "${unit}"
      fi
    done <<<"${wol_units}"
  fi

  remove_managed_unit "${MANAGED_SERVICE_WOL_TEMPLATE}" "Managed by LocalAI Installer"
  sudo rm -rf "${MANAGED_ENV_DIR}"

  sudo systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
  sudo systemctl daemon-reload
}

ensure_managed_dir() {
  sudo mkdir -p "${MANAGED_ENV_DIR}"
}

persist_state() {
  ensure_managed_dir
  sudo tee "${MANAGED_ENV_DIR}/state.env" >/dev/null <<EOF
# Managed by LocalAI Installer
LOCALAI_PORT="${LOCALAI_PORT}"
STAY_AWAKE_PORT="${STAY_AWAKE_PORT}"
STAY_AWAKE_BIND="${STAY_AWAKE_BIND}"
WAIT_MINUTES="${WAIT_MINUTES}"
CPU_IDLE_THRESHOLD="${CPU_IDLE_THRESHOLD}"
GPU_USAGE_MAX="${GPU_USAGE_MAX}"
GPU_PROC_FORBID="${GPU_PROC_FORBID}"
CHECK_INTERVAL="${CHECK_INTERVAL}"
WOL_INTERFACE="${WOL_INTERFACE}"
ENABLE_AUTO_SUSPEND="${ENABLE_AUTO_SUSPEND}"
ENABLE_STAY_AWAKE="${ENABLE_STAY_AWAKE}"
ENABLE_WOL="${ENABLE_WOL}"
EOF
}

load_previous_state() {
  local state_file="${MANAGED_ENV_DIR}/state.env"
  if [[ -f "${state_file}" ]]; then
    # shellcheck disable=SC1090
    source "${state_file}"
  fi
}

ensure_timezone() {
  if [[ -z "${TIMEZONE}" ]]; then
    return
  fi
  if ! command -v timedatectl >/dev/null 2>&1; then
    warn "timedatectl nicht verfügbar – überspringe Zeitzonen-Setup."
    return
  fi
  local current
  current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  if [[ "${current}" == "${TIMEZONE}" ]]; then
    log "Zeitzone bereits auf ${TIMEZONE} gesetzt."
    return
  fi
  log "Setze Zeitzone auf ${TIMEZONE}…"
  sudo timedatectl set-timezone "${TIMEZONE}" || warn "Zeitzone konnte nicht gesetzt werden."
}

install_base_packages() {
  local packages=(ufw curl jq git neovim less unzip ca-certificates gnupg lsb-release net-tools iproute2 sysstat netcat-openbsd ethtool)
  log "Installiere Basis-Pakete…"
  sudo apt-get install -y "${packages[@]}"
}

configure_firewall() {
  if [[ "${CONFIGURE_FIREWALL}" != "true" ]]; then
    warn "Firewall-Konfiguration deaktiviert."
    return
  fi
  if ! command -v ufw >/dev/null 2>&1; then
    warn "ufw nicht verfügbar – Firewall-Konfiguration übersprungen."
    return
  fi
  log "Konfiguriere UFW-Firewall…"
  local status
  status="$(sudo ufw status | head -n1 || true)"
  sudo ufw allow 22/tcp >/dev/null 2>&1 || true
  sudo ufw allow "${LOCALAI_PORT}/tcp" >/dev/null 2>&1 || true
  if [[ "${ENABLE_STAY_AWAKE}" == "true" ]]; then
    sudo ufw allow "${STAY_AWAKE_PORT}/tcp" >/dev/null 2>&1 || true
  fi
  sudo ufw default deny incoming >/dev/null 2>&1 || true
  sudo ufw default allow outgoing >/dev/null 2>&1 || true
  if [[ "${status}" == "Status: active" ]]; then
    log "UFW war bereits aktiv – Regeln aktualisiert."
  else
    log "Aktiviere UFW…"
    sudo ufw --force enable >/dev/null 2>&1 || warn "UFW konnte nicht aktiviert werden."
  fi
}

maybe_harden_ssh() {
  if [[ "${SSH_HARDEN}" == "false" ]]; then
    return
  fi
  if [[ "${SSH_HARDEN}" == "auto" ]]; then
    if [[ "${NONINTERACTIVE}" == "true" ]]; then
      warn "Nicht-interaktiv: SSH-Hardening wird übersprungen."
      SSH_HARDEN="false"
      return
    fi
    if prompt_yes_no "Passwort-basierte SSH-Anmeldung deaktivieren und Root-Login verbieten?"; then
      SSH_HARDEN="true"
    else
      SSH_HARDEN="false"
      return
    fi
  fi
  if [[ "${SSH_HARDEN}" != "true" ]]; then
    return
  fi
  local sshd_config="/etc/ssh/sshd_config"
  if [[ ! -f "${sshd_config}" ]]; then
    warn "sshd_config nicht gefunden – überspringe SSH-Hardening."
    return
  fi
  log "Härte SSH: Passwort-Login aus, Root-Login verboten."
  sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "${sshd_config}"
  sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' "${sshd_config}"
  if ! grep -q '^PubkeyAuthentication yes' "${sshd_config}"; then
    echo "PubkeyAuthentication yes" | sudo tee -a "${sshd_config}" >/dev/null
  fi
  sudo systemctl reload ssh >/dev/null 2>&1 || sudo systemctl restart ssh >/dev/null 2>&1 || warn "SSH-Dienst konnte nicht neu geladen werden."
}

build_llm_ports_string() {
  local result="" candidate
  for candidate in "${LOCALAI_PORT}" ${PORTS_DEFAULT_STRING}; do
    [[ -z "${candidate}" ]] && continue
    if [[ " ${result} " == *" ${candidate} "* ]]; then
      continue
    fi
    if [[ -z "${result}" ]]; then
      result="${candidate}"
    else
      result="${result} ${candidate}"
    fi
  done
  printf '%s' "${result}"
}

write_auto_suspend_script() {
  if [[ "${ENABLE_AUTO_SUSPEND}" != "true" ]]; then
    return
  fi
  log "Schreibe Auto-Suspend Skript nach ${MANAGED_SCRIPT_AUTO_SUSPEND}…"
  sudo tee "${MANAGED_SCRIPT_AUTO_SUSPEND}" >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

# Managed by LocalAI Installer

CPU_IDLE_THRESHOLD="${CPU_IDLE_THRESHOLD:-90}"
GPU_USAGE_MAX="${GPU_USAGE_MAX:-10}"
GPU_PROC_FORBID="${GPU_PROC_FORBID:-1}"
WAIT_MINUTES="${WAIT_MINUTES:-30}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
PORTS_LLMS_DEFAULT="8080 11434 8000 8081 7860 9600 5000 3000"
PORTS_LLMS="${PORTS_LLMS:-${PORTS_LLMS_DEFAULT}}"
STATE_DIR="${STATE_DIR:-/run/ai-nodectl}"
STAY_AWAKE_FILE="${STAY_AWAKE_FILE:-${STATE_DIR}/stay_awake_until}"
LOG_TAG="${LOG_TAG:-ai-auto-suspend}"

mkdir -p "${STATE_DIR}"

log() {
  logger -t "${LOG_TAG}" -- "$*"
  printf '[%s] %s\n' "$(date +'%F %T')" "$*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

get_cpu_idle_pct() {
  if have_cmd mpstat; then
    mpstat 1 1 | awk '/all/ {idle=$NF} END{if(idle==""){idle=0}; print idle}'
    return
  fi
  local usr
  usr=$(top -bn1 | awk -F'[, ]+' '/Cpu\(s\)/ {for(i=1;i<=NF;i++){if($i ~ /us/){print $(i-1); exit}}}')
  awk -v u="${usr:-0}" 'BEGIN{idle=100.0 - u; if(idle<0) idle=0; if(idle>100) idle=100; print idle}'
}

get_gpu_usage_pct() {
  if have_cmd nvidia-smi; then
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \
      | awk '{sum+=$1; n+=1} END {if(n==0){print 0}else{print sum/n}}'
    return
  fi
  if have_cmd rocm-smi; then
    rocm-smi --showuse --json 2>/dev/null | jq -r '.card | values | map(.GPU_USE | tonumber) | add / length' 2>/dev/null || echo 0
    return
  fi
  echo 0
}

gpu_compute_proc_count() {
  if have_cmd nvidia-smi; then
    nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | awk 'NF{c+=1} END{print c+0}'
    return
  fi
  if have_cmd rocm-smi; then
    rocm-smi --showpids --json 2>/dev/null | jq -r '.card | values | map(.PIDS | length) | add' 2>/dev/null || echo 0
    return
  fi
  echo 0
}

ssh_sessions_active() {
  ss -tna | awk '$1=="ESTAB" && $4 ~ /:22$/ {found=1} END{exit !found}'
}

stay_awake_active() {
  if [[ -f "${STAY_AWAKE_FILE}" ]]; then
    local until epoch_now
    until=$(cat "${STAY_AWAKE_FILE}" 2>/dev/null || echo 0)
    epoch_now=$(date +%s)
    [[ "${epoch_now}" -lt "${until}" ]] && return 0
  fi
  return 1
}

llm_ports_active() {
  local ports_array=()
  read -r -a ports_array <<<"${PORTS_LLMS}"
  local p
  for p in "${ports_array[@]}"; do
    [[ -z "${p}" ]] && continue
    if ss -tna | awk -v P=":${p}$" '$1=="ESTAB" && ($4 ~ P || $5 ~ P) {found=1} END{exit !found}'; then
      return 0
    fi
  done
  return 1
}

localai_running() {
  if have_cmd docker; then
    docker ps --format '{{.Names}}' | grep -qi '^localai$' && return 0
  fi
  return 1
}

cleanup() {
  log "stoppe auto-suspend watcher"
  exit 0
}
trap cleanup INT TERM

log "auto-suspend gestartet (WAIT_MINUTES=${WAIT_MINUTES}, CPU_IDLE_THRESHOLD=${CPU_IDLE_THRESHOLD}%, GPU_MAX=${GPU_USAGE_MAX}%)"
idle_minutes=0

while true; do
  if stay_awake_active; then
    idle_minutes=0
    sleep "${CHECK_INTERVAL}"
    continue
  fi
  if ssh_sessions_active; then
    idle_minutes=0
    sleep "${CHECK_INTERVAL}"
    continue
  fi
  ports_busy=0
  if llm_ports_active; then
    ports_busy=1
  fi
  container_running=0
  if localai_running; then
    container_running=1
  fi
  if (( ports_busy == 1 || container_running == 1 )); then
    idle_minutes=0
    sleep "${CHECK_INTERVAL}"
    continue
  fi

  cpu_idle=$(get_cpu_idle_pct || echo 0)
  gpu_usage=$(get_gpu_usage_pct || echo 0)
  gpu_procs=$(gpu_compute_proc_count || echo 0)

  is_idle=0
  awk -v ci="${cpu_idle}" -v gu="${gpu_usage}" -v ci_th="${CPU_IDLE_THRESHOLD}" -v gu_th="${GPU_USAGE_MAX}" \
    'BEGIN{exit ! (ci>=ci_th && gu<=gu_th)}' && is_idle=1

  if (( gpu_procs >= GPU_PROC_FORBID )); then
    is_idle=0
  fi

  if (( is_idle )); then
    idle_minutes=$((idle_minutes + CHECK_INTERVAL/60))
  else
    idle_minutes=0
  fi

  if (( idle_minutes >= WAIT_MINUTES )); then
    log "inaktiv für ${WAIT_MINUTES} Minuten → suspend"
    systemctl suspend || log "WARN: systemctl suspend fehlgeschlagen"
    idle_minutes=0
  fi

  sleep "${CHECK_INTERVAL}"
done
BASH
  sudo chmod +x "${MANAGED_SCRIPT_AUTO_SUSPEND}"
}

write_stay_awake_script() {
  if [[ "${ENABLE_STAY_AWAKE}" != "true" ]]; then
    return
  fi
  log "Schreibe Stay-Awake Skript nach ${MANAGED_SCRIPT_STAY_AWAKE}…"
  sudo tee "${MANAGED_SCRIPT_STAY_AWAKE}" >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

# Managed by LocalAI Installer

PORT="${1:-9876}"
BIND="${2:-0.0.0.0}"
STATE_DIR="${STATE_DIR:-/run/ai-nodectl}"
STAY_AWAKE_FILE="${STAY_AWAKE_FILE:-${STATE_DIR}/stay_awake_until}"

mkdir -p "${STATE_DIR}"

log() {
  printf '[%s] %s\n' "$(date +'%F %T')" "$*"
}

serve_connection() {
  local req
  read -r req || return
  if echo "${req}" | grep -qE 'GET /stay\?s='; then
    local secs
    secs=$(echo "${req}" | sed -n 's|.*GET /stay?s=\([0-9]\+\).*|\1|p')
    if [[ -n "${secs}" ]]; then
      local until
      until=$(( $(date +%s) + secs ))
      echo "${until}" > "${STAY_AWAKE_FILE}"
      local body="staying awake for ${secs}s (until ${until})"
      printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\nContent-Type: text/plain\r\n\r\n%s' "${#body}" "${body}"
      return
    fi
  fi
  local body="try /stay?s=SECONDS"
  printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\nContent-Type: text/plain\r\n\r\n%s' "${#body}" "${body}"
}

log "stay-awake HTTP Listener gestartet auf ${BIND}:${PORT}"
while true; do
  { serve_connection; } | nc -l -p "${PORT}" -s "${BIND}" -q 1
done
BASH
  sudo chmod +x "${MANAGED_SCRIPT_STAY_AWAKE}"
}

configure_auto_suspend_service() {
  if [[ "${ENABLE_AUTO_SUSPEND}" != "true" ]]; then
    disable_service "${MANAGED_SERVICE_AUTO_SUSPEND}"
    remove_managed_unit "/etc/systemd/system/${MANAGED_SERVICE_AUTO_SUSPEND}" "Managed by LocalAI Installer"
    remove_managed_file "${MANAGED_SCRIPT_AUTO_SUSPEND}"
    return
  fi
  write_auto_suspend_script
  local ports_string
  ports_string="$(build_llm_ports_string)"
  log "Aktualisiere systemd Service ${MANAGED_SERVICE_AUTO_SUSPEND}…"
  sudo tee "/etc/systemd/system/${MANAGED_SERVICE_AUTO_SUSPEND}" >/dev/null <<SERVICE
[Unit]
Description=AI Node Auto-Suspend Watcher
Documentation=https://github.com/go-skynet/LocalAI
After=network-online.target
Wants=network-online.target
# Managed by LocalAI Installer

[Service]
Type=simple
ExecStart=${MANAGED_SCRIPT_AUTO_SUSPEND}
Restart=always
RestartSec=5
User=root
KillMode=process
Environment="WAIT_MINUTES=${WAIT_MINUTES}"
Environment="CPU_IDLE_THRESHOLD=${CPU_IDLE_THRESHOLD}"
Environment="GPU_USAGE_MAX=${GPU_USAGE_MAX}"
Environment="GPU_PROC_FORBID=${GPU_PROC_FORBID}"
Environment="CHECK_INTERVAL=${CHECK_INTERVAL}"
Environment="PORTS_LLMS=${ports_string}"
Environment="STAY_AWAKE_FILE=/run/ai-nodectl/stay_awake_until"

[Install]
WantedBy=multi-user.target
SERVICE
  sudo systemctl daemon-reload
  sudo systemctl enable --now "${MANAGED_SERVICE_AUTO_SUSPEND}"
}

configure_stay_awake_service() {
  if [[ "${ENABLE_STAY_AWAKE}" != "true" ]]; then
    disable_service "${MANAGED_SERVICE_STAY_AWAKE}"
    remove_managed_unit "/etc/systemd/system/${MANAGED_SERVICE_STAY_AWAKE}" "Managed by LocalAI Installer"
    remove_managed_file "${MANAGED_SCRIPT_STAY_AWAKE}"
    return
  fi
  write_stay_awake_script
  log "Aktualisiere systemd Service ${MANAGED_SERVICE_STAY_AWAKE}…"
  sudo tee "/etc/systemd/system/${MANAGED_SERVICE_STAY_AWAKE}" >/dev/null <<SERVICE
[Unit]
Description=AI Stay-Awake Tiny HTTP
After=network-online.target
Wants=network-online.target
# Managed by LocalAI Installer

[Service]
Type=simple
ExecStart=${MANAGED_SCRIPT_STAY_AWAKE} ${STAY_AWAKE_PORT} ${STAY_AWAKE_BIND}
Restart=always
RestartSec=3
User=root
Environment="STATE_DIR=/run/ai-nodectl"

[Install]
WantedBy=multi-user.target
SERVICE
  sudo systemctl daemon-reload
  sudo systemctl enable --now "${MANAGED_SERVICE_STAY_AWAKE}"
}

detect_wol_interface() {
  if [[ -n "${WOL_INTERFACE}" ]]; then
    return
  fi
  local detected
  detected="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}')"
  if [[ -n "${detected}" ]]; then
    WOL_INTERFACE="${detected}"
    return
  fi
  warn "Konnte Netzwerk-Interface für WOL nicht automatisch bestimmen."
}

configure_wol() {
  if [[ "${ENABLE_WOL}" != "true" ]]; then
    return
  fi
  if ! command -v ethtool >/dev/null 2>&1; then
    warn "ethtool nicht verfügbar – WOL-Konfiguration übersprungen."
    return
  fi
  detect_wol_interface
  if [[ -z "${WOL_INTERFACE}" ]]; then
    warn "Kein Interface für WOL angegeben – überspringe."
    return
  fi
  log "Aktiviere Wake-on-LAN für Interface ${WOL_INTERFACE}…"
  sudo ethtool -s "${WOL_INTERFACE}" wol g || warn "Konnte WOL für ${WOL_INTERFACE} nicht setzen."
  if [[ ! -f "${MANAGED_SERVICE_WOL_TEMPLATE}" ]]; then
    sudo tee "${MANAGED_SERVICE_WOL_TEMPLATE}" >/dev/null <<'UNIT'
[Unit]
Description=Enable Wake-on-LAN on %i
After=network.target
# Managed by LocalAI Installer

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s %i wol g

[Install]
WantedBy=multi-user.target
UNIT
  fi
  sudo systemctl daemon-reload
  sudo systemctl enable --now "wol@${WOL_INTERFACE}.service" || warn "Konnte wol@${WOL_INTERFACE}.service nicht aktivieren."
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
    stop_support_services
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
    stop_support_services
    stop_localai_service
    stop_localai_containers
  fi
}

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
install_base_packages
ensure_timezone
maybe_harden_ssh
configure_firewall

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
      - "${LOCALAI_PORT}:8080"
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

configure_auto_suspend_service
configure_stay_awake_service
configure_wol
persist_state

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
if curl -fsS "http://127.0.0.1:${LOCALAI_PORT}/readyz" >/dev/null 2>&1; then
  log "LocalAI ist bereit: http://${SERVER_IP}:${LOCALAI_PORT}"
else
  warn "Health-Endpoint noch nicht bereit. Logs ansehen mit:  ${DOCKER_CMD} logs -f localai"
fi

# Hinweis zur Gruppe
if [[ -n "${SUDO_USER:-}" ]]; then
  warn "Falls '${SUDO_USER}' neu zur docker-Gruppe hinzugefügt wurde, ist ein Re-Login nötig, damit 'docker' ohne sudo funktioniert."
fi

if [[ "${ENABLE_STAY_AWAKE}" == "true" ]]; then
  log "Stay-Awake Endpoint aktiv: http://${SERVER_IP}:${STAY_AWAKE_PORT}/stay?s=3600"
fi
if [[ "${ENABLE_AUTO_SUSPEND}" == "true" ]]; then
  log "Auto-Suspend Watcher überwacht CPU/GPU-Auslastung (Timeout ${WAIT_MINUTES} Min)."
fi
if [[ "${ENABLE_WOL}" == "true" && -n "${WOL_INTERFACE}" ]]; then
  log "Wake-on-LAN aktiviert für Interface ${WOL_INTERFACE}."
fi

log "Fertig. Viel Spaß mit LocalAI! 🚀"
