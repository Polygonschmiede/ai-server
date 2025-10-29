#!/usr/bin/env bash
# Docker utilities for LocalAI Installer

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
