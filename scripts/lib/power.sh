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
  warn "Could not automatically detect network interface for WOL."
}

configure_wol() {
  if [[ "${ENABLE_WOL}" != "true" ]]; then
    return
  fi
  if ! command -v ethtool >/dev/null 2>&1; then
    warn "ethtool not available – skipping WOL configuration."
    return
  fi
  detect_wol_interface
  if [[ -z "${WOL_INTERFACE}" ]]; then
    warn "No interface specified for WOL – skipping."
    return
  fi
  log "Enabling Wake-on-LAN for interface ${WOL_INTERFACE}…"
  sudo ethtool -s "${WOL_INTERFACE}" wol g || warn "Could not enable WOL for ${WOL_INTERFACE}."
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
  sudo systemctl enable --now "wol@${WOL_INTERFACE}.service" || warn "Could not enable wol@${WOL_INTERFACE}.service."
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

configure_auto_suspend_service() {
  if [[ "${ENABLE_AUTO_SUSPEND}" != "true" ]]; then
    info "Auto-Suspend disabled - skipping"
    disable_service "${MANAGED_SERVICE_AUTO_SUSPEND}"
    remove_managed_unit "/etc/systemd/system/${MANAGED_SERVICE_AUTO_SUSPEND}" "Managed by LocalAI Installer"
    return
  fi

  info "Installing auto-suspend monitor Python script..."

  # Create installation directory
  sudo mkdir -p /opt/ai-server

  # Copy Python script to installation directory
  local script_source="${SCRIPT_DIR}/auto-suspend-monitor.py"
  if [[ ! -f "${script_source}" ]]; then
    err "Auto-suspend monitor script not found at ${script_source}"
    return 1
  fi

  sudo cp "${script_source}" /opt/ai-server/auto-suspend-monitor.py
  sudo chmod +x /opt/ai-server/auto-suspend-monitor.py

  info "Creating systemd service ${MANAGED_SERVICE_AUTO_SUSPEND}..."
  sudo tee "/etc/systemd/system/${MANAGED_SERVICE_AUTO_SUSPEND}" >/dev/null <<SERVICE
[Unit]
Description=AI Server Auto-Suspend Monitor
Documentation=https://github.com/Polygonschmiede/ai-server
After=network.target ${MANAGED_SERVICE_STAY_AWAKE}
Wants=${MANAGED_SERVICE_STAY_AWAKE}
# Managed by LocalAI Installer

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ai-server

# Configuration via environment variables
Environment="WAIT_MINUTES=${WAIT_MINUTES}"
Environment="CPU_IDLE_THRESHOLD=${CPU_IDLE_THRESHOLD}"
Environment="GPU_USAGE_MAX=${GPU_USAGE_MAX}"
Environment="CHECK_INTERVAL=${CHECK_INTERVAL}"
Environment="CHECK_SSH=false"

ExecStart=/usr/bin/python3 /opt/ai-server/auto-suspend-monitor.py
Restart=always
RestartSec=10

# Security settings
PrivateTmp=yes
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/run/ai-nodectl /var/lib/ai-auto-suspend

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ai-auto-suspend

[Install]
WantedBy=multi-user.target
SERVICE

  info "Enabling Auto-Suspend service..."
  sudo systemctl daemon-reload
  if sudo systemctl enable --now "${MANAGED_SERVICE_AUTO_SUSPEND}"; then
    success "Auto-Suspend service enabled and started"
  else
    warn "Error enabling Auto-Suspend service"
  fi
}

configure_stay_awake_service() {
  if [[ "${ENABLE_STAY_AWAKE}" != "true" ]]; then
    info "Stay-Awake disabled - skipping"
    disable_service "${MANAGED_SERVICE_STAY_AWAKE}"
    remove_managed_unit "/etc/systemd/system/${MANAGED_SERVICE_STAY_AWAKE}" "Managed by LocalAI Installer"
    return
  fi

  info "Installing stay-awake server Python script..."

  # Create installation directory
  sudo mkdir -p /opt/ai-server

  # Copy Python script to installation directory
  local script_source="${SCRIPT_DIR}/stay-awake-server.py"
  if [[ ! -f "${script_source}" ]]; then
    err "Stay-awake server script not found at ${script_source}"
    return 1
  fi

  sudo cp "${script_source}" /opt/ai-server/stay-awake-server.py
  sudo chmod +x /opt/ai-server/stay-awake-server.py

  info "Creating systemd service ${MANAGED_SERVICE_STAY_AWAKE}..."
  sudo tee "/etc/systemd/system/${MANAGED_SERVICE_STAY_AWAKE}" >/dev/null <<SERVICE
[Unit]
Description=Stay-Awake HTTP Server
Documentation=https://github.com/Polygonschmiede/ai-server
After=network.target
# Managed by LocalAI Installer

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ai-server

# Configuration via environment variables
Environment="PORT=${STAY_AWAKE_PORT}"

ExecStart=/usr/bin/python3 /opt/ai-server/stay-awake-server.py
Restart=always
RestartSec=10

# Security settings
PrivateTmp=yes
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/run/ai-nodectl

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=stay-awake

[Install]
WantedBy=multi-user.target
SERVICE

  info "Enabling Stay-Awake service..."
  sudo systemctl daemon-reload
  if sudo systemctl enable --now "${MANAGED_SERVICE_STAY_AWAKE}"; then
    success "Stay-Awake service enabled and started"
  else
    warn "Error enabling Stay-Awake service"
  fi
}
