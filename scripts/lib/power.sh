#!/usr/bin/env bash
# Power management utilities for LocalAI Installer

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
