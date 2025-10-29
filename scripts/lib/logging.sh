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
