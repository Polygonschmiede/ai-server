#!/usr/bin/env bash
# Installation helper functions for LocalAI Installer

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

  # Check for Python scripts in /opt/ai-server/ (new location)
  if [[ -f "/opt/ai-server/auto-suspend-monitor.py" ]]; then
    EXISTING_COMPONENTS+=("auto-suspend script")
    found="true"
  fi

  if [[ -f "/opt/ai-server/stay-awake-server.py" ]]; then
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
  log "Performing clean uninstall of existing installation…"
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

  # Remove Python scripts from new location
  if [[ -f "/opt/ai-server/auto-suspend-monitor.py" ]]; then
    sudo rm -f "/opt/ai-server/auto-suspend-monitor.py"
  fi
  if [[ -f "/opt/ai-server/stay-awake-server.py" ]]; then
    sudo rm -f "/opt/ai-server/stay-awake-server.py"
  fi

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

handle_existing_installation() {
  detect_existing_installation

  if [[ ${#PERSISTED_DIRECTORIES[@]} -gt 0 ]]; then
    log "Existing directories will be preserved: $(join_by ', ' "${PERSISTED_DIRECTORIES[@]}")"
  fi

  if [[ "${EXISTING_INSTALLATION}" != "true" ]]; then
    if [[ "${REPAIR_ONLY}" == "true" ]]; then
      warn "Repair mode requested, but no existing installation found – starting regular installation."
      REPAIR_ONLY="false"
    fi
    return
  fi

  local components
  components="$(join_by ', ' "${EXISTING_COMPONENTS[@]}")"
  warn "Found LocalAI artifacts: ${components}"

  if [[ "${REPAIR_ONLY}" == "true" ]]; then
    log "Repair mode active – stopping services for reconfiguration."
    stop_support_services
    stop_localai_service
    stop_localai_containers
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
    log "Skipping uninstall – reconfiguring existing installation."
    stop_support_services
    stop_localai_service
    stop_localai_containers
  fi
}
