#!/usr/bin/env bash
# Logging utilities for LocalAI Installer

log() {
  echo -e "\033[1;32m[+] $*\033[0m"
}

warn() {
  echo -e "\033[1;33m[!] $*\033[0m"
}

err() {
  echo -e "\033[1;31m[✗] $*\033[0m" >&2
}

die() {
  err "$*"
  exit 1
}

info() {
  echo -e "\033[1;34m[INFO] $*\033[0m"
}

success() {
  echo -e "\033[1;32m[✓] $*\033[0m"
}

# Spinner for long-running operations
spinner() {
  local pid=$1
  local msg="${2:-Working}"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) %10 ))
    printf "\r\033[1;36m[${spin:$i:1}] %s...\033[0m" "$msg"
    sleep 0.1
  done
  wait "$pid"
  local status=$?
  printf "\r\033[K"
  return $status
}
