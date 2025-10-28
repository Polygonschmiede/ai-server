#!/usr/bin/env bash
# SystemD service utilities for LocalAI Installer

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

systemd_unit_exists() {
  [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]] || systemctl list-unit-files "${SERVICE_NAME}" >/dev/null 2>&1
}
