#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# AI Server Setup Verification Script
# --------------------------
# This script verifies that LocalAI and/or Ollama are properly installed
# and running on the system.

# --------------------------
# Colors
# --------------------------
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_BOLD='\033[1m'

# --------------------------
# Counters
# --------------------------
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# --------------------------
# Helper functions
# --------------------------
print_header() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_BLUE}=========================================${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_BLUE}  AI Server Setup Verification${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_BLUE}=========================================${COLOR_RESET}"
  echo ""
}

check_pass() {
  echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $*"
  ((CHECKS_PASSED++))
}

check_fail() {
  echo -e "  ${COLOR_RED}✗${COLOR_RESET} $*"
  ((CHECKS_FAILED++))
}

check_warn() {
  echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $*"
  ((CHECKS_WARNING++))
}

section() {
  echo ""
  echo -e "${COLOR_BOLD}$*${COLOR_RESET}"
  echo "---"
}

# --------------------------
# Check functions
# --------------------------
check_docker() {
  section "Docker Installation"

  if command -v docker >/dev/null 2>&1; then
    check_pass "Docker is installed"
    local version
    version="$(docker --version 2>/dev/null || echo 'unknown')"
    echo "    Version: ${version}"
  else
    check_fail "Docker is not installed"
    return 1
  fi

  if systemctl is-active --quiet docker 2>/dev/null; then
    check_pass "Docker service is running"
  else
    check_fail "Docker service is not running"
    return 1
  fi

  # Check if user is in docker group
  if groups | grep -q docker 2>/dev/null || [[ "$(id -u)" -eq 0 ]]; then
    check_pass "User has Docker permissions"
  else
    check_warn "Current user not in docker group (may need sudo)"
  fi

  return 0
}

check_nvidia() {
  section "NVIDIA GPU Support"

  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
      check_pass "NVIDIA GPU detected"
      local gpu_info
      gpu_info="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
      echo "    GPU: ${gpu_info}"

      # Check VRAM
      local vram
      vram="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)"
      echo "    VRAM: ${vram}"
    else
      check_fail "NVIDIA driver not working"
      return 1
    fi
  else
    check_warn "No NVIDIA GPU detected (CPU mode)"
    return 0
  fi

  # Check nvidia-container-toolkit
  if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
    check_pass "NVIDIA Container Toolkit is working"
  else
    check_fail "NVIDIA Container Toolkit not configured"
    return 1
  fi

  return 0
}

check_localai() {
  section "LocalAI Installation"

  # Check service
  if systemctl list-unit-files localai.service --no-legend 2>/dev/null | grep -q localai.service; then
    check_pass "LocalAI service is installed"

    if systemctl is-active --quiet localai.service 2>/dev/null; then
      check_pass "LocalAI service is running"
    else
      check_warn "LocalAI service is stopped"
    fi

    if systemctl is-enabled --quiet localai.service 2>/dev/null; then
      check_pass "LocalAI service is enabled (auto-start)"
    else
      check_warn "LocalAI service is not enabled"
    fi
  else
    check_warn "LocalAI service not installed"
    return 0
  fi

  # Check directory
  if [[ -d "/opt/localai" ]]; then
    check_pass "LocalAI directory exists"
  else
    check_fail "LocalAI directory not found"
    return 1
  fi

  # Check docker-compose file
  if [[ -f "/opt/localai/docker-compose.yml" ]]; then
    check_pass "LocalAI docker-compose.yml exists"
  else
    check_fail "LocalAI docker-compose.yml not found"
    return 1
  fi

  # Check container
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^localai$'; then
    check_pass "LocalAI container is running"

    # Check API endpoint
    if curl -fsS "http://127.0.0.1:8080/readyz" >/dev/null 2>&1; then
      check_pass "LocalAI API is responding"
      echo "    URL: http://localhost:8080"
    else
      check_warn "LocalAI API not responding yet (may still be starting)"
    fi
  else
    check_warn "LocalAI container not running"
  fi

  return 0
}

check_ollama() {
  section "Ollama Installation"

  # Check service
  if systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q ollama.service; then
    check_pass "Ollama service is installed"

    if systemctl is-active --quiet ollama.service 2>/dev/null; then
      check_pass "Ollama service is running"
    else
      check_warn "Ollama service is stopped"
    fi

    if systemctl is-enabled --quiet ollama.service 2>/dev/null; then
      check_pass "Ollama service is enabled (auto-start)"
    else
      check_warn "Ollama service is not enabled"
    fi
  else
    check_warn "Ollama service not installed"
    return 0
  fi

  # Check directory
  if [[ -d "/opt/ollama" ]]; then
    check_pass "Ollama directory exists"
  else
    check_fail "Ollama directory not found"
    return 1
  fi

  # Check docker-compose file
  if [[ -f "/opt/ollama/docker-compose.yml" ]]; then
    check_pass "Ollama docker-compose.yml exists"
  else
    check_fail "Ollama docker-compose.yml not found"
    return 1
  fi

  # Check containers
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^ollama$'; then
    check_pass "Ollama container is running"

    # Check API endpoint
    if curl -fsS "http://127.0.0.1:11434/" >/dev/null 2>&1; then
      check_pass "Ollama API is responding"
      echo "    URL: http://localhost:11434"
    else
      check_warn "Ollama API not responding yet (may still be starting)"
    fi
  else
    check_warn "Ollama container not running"
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^open-webui$'; then
    check_pass "Open WebUI container is running"

    # Check WebUI endpoint
    if curl -fsS "http://127.0.0.1:3000/" >/dev/null 2>&1; then
      check_pass "Open WebUI is responding"
      echo "    URL: http://localhost:3000"
    else
      check_warn "Open WebUI not responding yet (may still be starting)"
    fi
  else
    check_warn "Open WebUI container not running"
  fi

  # Check for models
  if docker exec ollama ollama list >/dev/null 2>&1; then
    local model_count
    model_count="$(docker exec ollama ollama list 2>/dev/null | tail -n +2 | wc -l)"
    if [[ ${model_count} -gt 0 ]]; then
      check_pass "Ollama has ${model_count} model(s) installed"
    else
      check_warn "No Ollama models installed yet"
      echo "    Tip: ./ai-server-manager.sh pull llama3.2"
    fi
  fi

  return 0
}

check_support_services() {
  section "Support Services"

  # Check auto-suspend
  if systemctl list-unit-files ai-auto-suspend.service --no-legend 2>/dev/null | grep -q ai-auto-suspend.service; then
    check_pass "Auto-suspend service is installed"

    if systemctl is-active --quiet ai-auto-suspend.service 2>/dev/null; then
      check_pass "Auto-suspend service is running"
    else
      check_warn "Auto-suspend service is stopped"
    fi
  else
    check_warn "Auto-suspend service not installed"
  fi

  # Check stay-awake
  if systemctl list-unit-files stay-awake.service --no-legend 2>/dev/null | grep -q stay-awake.service; then
    check_pass "Stay-awake HTTP service is installed"

    if systemctl is-active --quiet stay-awake.service 2>/dev/null; then
      check_pass "Stay-awake HTTP service is running"

      if curl -fsS "http://127.0.0.1:9876/" >/dev/null 2>&1; then
        check_pass "Stay-awake HTTP endpoint is responding"
        echo "    URL: http://localhost:9876"
      fi
    else
      check_warn "Stay-awake HTTP service is stopped"
    fi
  else
    check_warn "Stay-awake HTTP service not installed"
  fi

  return 0
}

check_firewall() {
  section "Firewall Configuration"

  if command -v ufw >/dev/null 2>&1; then
    check_pass "UFW is installed"

    if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
      check_pass "UFW is active"

      # Check important ports
      if sudo ufw status 2>/dev/null | grep -q "8080"; then
        check_pass "Port 8080 (LocalAI) is allowed"
      else
        check_warn "Port 8080 (LocalAI) may be blocked"
      fi

      if sudo ufw status 2>/dev/null | grep -q "11434"; then
        check_pass "Port 11434 (Ollama) is allowed"
      else
        check_warn "Port 11434 (Ollama) may be blocked"
      fi

      if sudo ufw status 2>/dev/null | grep -q "3000"; then
        check_pass "Port 3000 (Open WebUI) is allowed"
      else
        check_warn "Port 3000 (Open WebUI) may be blocked"
      fi
    else
      check_warn "UFW is not active"
    fi
  else
    check_warn "UFW not installed (firewall may not be configured)"
  fi

  return 0
}

print_summary() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_BLUE}=========================================${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_BLUE}  Summary${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_BLUE}=========================================${COLOR_RESET}"
  echo ""

  echo -e "  ${COLOR_GREEN}Passed:${COLOR_RESET}   ${CHECKS_PASSED}"
  echo -e "  ${COLOR_YELLOW}Warnings:${COLOR_RESET} ${CHECKS_WARNING}"
  echo -e "  ${COLOR_RED}Failed:${COLOR_RESET}   ${CHECKS_FAILED}"
  echo ""

  if [[ ${CHECKS_FAILED} -eq 0 ]]; then
    echo -e "${COLOR_GREEN}✓ Setup verification completed successfully!${COLOR_RESET}"
    echo ""

    if [[ ${CHECKS_WARNING} -gt 0 ]]; then
      echo -e "${COLOR_YELLOW}Note: There are ${CHECKS_WARNING} warning(s) that may need attention.${COLOR_RESET}"
      echo ""
    fi

    echo "Quick commands:"
    echo "  ./ai-server-manager.sh status     # Check running services"
    echo "  ./ai-server-manager.sh both       # Start both services"
    echo "  ./ai-server-manager.sh pull llama3.2  # Download a model"
    echo ""
    return 0
  else
    echo -e "${COLOR_RED}✗ Setup verification found ${CHECKS_FAILED} issue(s)!${COLOR_RESET}"
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Run installation: sudo bash install.sh"
    echo "  - Check logs: sudo journalctl -u localai.service"
    echo "  - Check containers: docker ps -a"
    echo "  - Verify Docker: sudo systemctl status docker"
    echo ""
    return 1
  fi
}

# --------------------------
# Main
# --------------------------
main() {
  print_header

  check_docker
  check_nvidia
  check_localai
  check_ollama
  check_support_services
  check_firewall

  print_summary
}

main "$@"
