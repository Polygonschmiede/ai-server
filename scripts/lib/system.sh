#!/usr/bin/env bash
# System utilities for LocalAI Installer

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command missing: $1"
}

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

backup_file() {
  local target="$1"
  [[ ! -f "${target}" ]] && return 0
  local stamp
  stamp="$(date +%Y%m%d%H%M%S)"
  local backup="${target}.${stamp}.bak"
  sudo cp "${target}" "${backup}"
  log "Backup created: ${backup}"
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

ensure_timezone() {
  if [[ -z "${TIMEZONE}" ]]; then
    return
  fi
  if ! command -v timedatectl >/dev/null 2>&1; then
    warn "timedatectl not available – skipping timezone setup."
    return
  fi
  local current
  current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  if [[ "${current}" == "${TIMEZONE}" ]]; then
    log "Timezone already set to ${TIMEZONE}."
    return
  fi
  log "Setting timezone to ${TIMEZONE}…"
  sudo timedatectl set-timezone "${TIMEZONE}" || warn "Could not set timezone."
}

install_base_packages() {
  local packages=(ufw curl jq git neovim less unzip ca-certificates gnupg lsb-release net-tools iproute2 sysstat netcat-openbsd ethtool)
  log "Installing base packages…"
  sudo apt-get install -y "${packages[@]}"
}

configure_firewall() {
  if [[ "${CONFIGURE_FIREWALL}" != "true" ]]; then
    warn "Firewall configuration disabled."
    return
  fi
  if ! command -v ufw >/dev/null 2>&1; then
    warn "ufw not available – skipping firewall configuration."
    return
  fi
  log "Configuring UFW firewall…"
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
    log "UFW was already active – rules updated."
  else
    log "Enabling UFW…"
    sudo ufw --force enable >/dev/null 2>&1 || warn "Could not enable UFW."
  fi
}

maybe_harden_ssh() {
  if [[ "${SSH_HARDEN}" == "false" ]]; then
    return
  fi
  if [[ "${SSH_HARDEN}" == "auto" ]]; then
    if [[ "${NONINTERACTIVE}" == "true" ]]; then
      warn "Non-interactive mode: skipping SSH hardening."
      SSH_HARDEN="false"
      return
    fi
    if prompt_yes_no "Disable password-based SSH login and forbid root login?"; then
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
    warn "sshd_config not found – skipping SSH hardening."
    return
  fi
  log "Hardening SSH: disabling password login, forbidding root login."
  sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "${sshd_config}"
  sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' "${sshd_config}"
  if ! grep -q '^PubkeyAuthentication yes' "${sshd_config}"; then
    echo "PubkeyAuthentication yes" | sudo tee -a "${sshd_config}" >/dev/null
  fi
  sudo systemctl reload ssh >/dev/null 2>&1 || sudo systemctl restart ssh >/dev/null 2>&1 || warn "Could not reload SSH service."
}
