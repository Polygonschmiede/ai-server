#!/usr/bin/env bash
set -euo pipefail

# AI Server Manager - Switch between LocalAI and Ollama
# Simple interface to manage AI servers

COLOR_RESET='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'

print_header() {
  echo -e "${COLOR_BLUE}================================${COLOR_RESET}"
  echo -e "${COLOR_BLUE}   AI Server Manager${COLOR_RESET}"
  echo -e "${COLOR_BLUE}================================${COLOR_RESET}"
  echo ""
}

print_status() {
  echo -e "${COLOR_YELLOW}Current Status:${COLOR_RESET}"
  echo ""

  # Check if LocalAI service exists
  if systemctl list-unit-files localai.service --no-legend 2>/dev/null | grep -q localai.service; then
    # Check LocalAI status
    if systemctl is-active --quiet localai.service 2>/dev/null; then
      echo -e "  LocalAI:  ${COLOR_GREEN}RUNNING${COLOR_RESET}"
      echo "    API:    http://localhost:8080"
      echo "    WebUI:  http://localhost:8080"
    else
      echo -e "  LocalAI:  ${COLOR_RED}STOPPED${COLOR_RESET}"
    fi
  else
    echo -e "  LocalAI:  ${COLOR_YELLOW}NOT INSTALLED${COLOR_RESET}"
    echo "    Install: sudo bash install.sh"
  fi

  echo ""

  # Check if Ollama service exists
  if systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q ollama.service; then
    # Check Ollama status
    if systemctl is-active --quiet ollama.service 2>/dev/null; then
      echo -e "  Ollama:   ${COLOR_GREEN}RUNNING${COLOR_RESET}"
      echo "    API:    http://localhost:11434"
      echo "    WebUI:  http://localhost:3000"
    else
      echo -e "  Ollama:   ${COLOR_RED}STOPPED${COLOR_RESET}"
    fi
  else
    echo -e "  Ollama:   ${COLOR_YELLOW}NOT INSTALLED${COLOR_RESET}"
    echo "    Install: sudo bash install-ollama.sh"
  fi

  echo ""
}

start_localai() {
  echo -e "${COLOR_YELLOW}Switching to LocalAI (exclusive mode)...${COLOR_RESET}"

  # Check if LocalAI service exists
  if ! systemctl list-unit-files localai.service --no-legend 2>/dev/null | grep -q localai.service; then
    echo ""
    echo -e "${COLOR_RED}Error: LocalAI service not found!${COLOR_RESET}"
    echo ""
    echo "LocalAI is not installed yet. To install, run:"
    echo "  sudo bash install.sh"
    echo ""
    echo "Or use the AI GOAT CLI:"
    echo "  ai-goat  (then click 'Install LocalAI' button)"
    echo ""
    return 1
  fi

  if systemctl is-active --quiet ollama.service 2>/dev/null; then
    echo "  Stopping Ollama..."
    sudo systemctl stop ollama.service
  fi

  echo "  Starting LocalAI..."
  sudo systemctl start localai.service

  echo ""
  echo -e "${COLOR_GREEN}LocalAI is now active!${COLOR_RESET}"
  echo "  API endpoint: http://localhost:8080"
  echo "  WebUI: http://localhost:8080"
  echo ""
}

start_ollama() {
  echo -e "${COLOR_YELLOW}Switching to Ollama (exclusive mode)...${COLOR_RESET}"

  # Check if Ollama service exists
  if ! systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q ollama.service; then
    echo ""
    echo -e "${COLOR_RED}Error: Ollama service not found!${COLOR_RESET}"
    echo ""
    echo "Ollama is not installed yet. To install, run:"
    echo "  sudo bash install-ollama.sh"
    echo ""
    echo "Or use the AI GOAT CLI:"
    echo "  ai-goat  (then click 'Install Ollama' button)"
    echo ""
    return 1
  fi

  if systemctl is-active --quiet localai.service 2>/dev/null; then
    echo "  Stopping LocalAI..."
    sudo systemctl stop localai.service
  fi

  echo "  Starting Ollama..."
  sudo systemctl start ollama.service

  echo ""
  echo -e "${COLOR_GREEN}Ollama is now active!${COLOR_RESET}"
  echo "  API endpoint: http://localhost:11434"
  echo "  WebUI (Open WebUI): http://localhost:3000"
  echo ""
  echo "To pull models, use:"
  echo "  docker exec ollama ollama pull llama3.2"
  echo ""
}

start_both() {
  echo -e "${COLOR_YELLOW}Starting both LocalAI and Ollama (parallel mode)...${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_BLUE}Note: Both services will share GPU memory.${COLOR_RESET}"
  echo "  If you experience OOM errors, run one service at a time."
  echo ""

  # Check which services are installed
  local localai_exists=false
  local ollama_exists=false

  if systemctl list-unit-files localai.service --no-legend 2>/dev/null | grep -q localai.service; then
    localai_exists=true
  fi

  if systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q ollama.service; then
    ollama_exists=true
  fi

  # Start available services
  if $localai_exists; then
    echo "  Starting LocalAI..."
    sudo systemctl start localai.service 2>/dev/null || echo -e "  ${COLOR_RED}Failed to start LocalAI${COLOR_RESET}"
  else
    echo -e "  ${COLOR_YELLOW}LocalAI not installed (run: sudo bash install.sh)${COLOR_RESET}"
  fi

  if $ollama_exists; then
    echo "  Starting Ollama..."
    sudo systemctl start ollama.service 2>/dev/null || echo -e "  ${COLOR_RED}Failed to start Ollama${COLOR_RESET}"
  else
    echo -e "  ${COLOR_YELLOW}Ollama not installed (run: sudo bash install-ollama.sh)${COLOR_RESET}"
  fi

  echo ""

  if $localai_exists || $ollama_exists; then
    echo -e "${COLOR_GREEN}Available services started!${COLOR_RESET}"
    echo ""

    if $localai_exists; then
      echo "LocalAI:"
      echo "  API:    http://localhost:8080"
      echo "  WebUI:  http://localhost:8080"
      echo ""
    fi

    if $ollama_exists; then
      echo "Ollama:"
      echo "  API:    http://localhost:11434"
      echo "  WebUI:  http://localhost:3000"
      echo ""
    fi
  else
    echo -e "${COLOR_RED}No services installed yet!${COLOR_RESET}"
    echo ""
    echo "Install services first:"
    echo "  sudo bash install.sh           # Install LocalAI"
    echo "  sudo bash install-ollama.sh    # Install Ollama"
    echo ""
  fi
}

stop_all() {
  echo -e "${COLOR_YELLOW}Stopping all AI servers...${COLOR_RESET}"

  if systemctl is-active --quiet localai.service 2>/dev/null; then
    echo "  Stopping LocalAI..."
    sudo systemctl stop localai.service
  fi

  if systemctl is-active --quiet ollama.service 2>/dev/null; then
    echo "  Stopping Ollama..."
    sudo systemctl stop ollama.service
  fi

  echo ""
  echo -e "${COLOR_GREEN}All AI servers stopped.${COLOR_RESET}"
  echo ""
}

list_ollama_models() {
  echo -e "${COLOR_YELLOW}Ollama Models:${COLOR_RESET}"
  echo ""

  # Check if Ollama service exists
  if ! systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q ollama.service; then
    echo -e "  ${COLOR_RED}Ollama is not installed${COLOR_RESET}"
    echo ""
    echo "  Install Ollama first:"
    echo "    sudo bash install-ollama.sh"
    echo ""
    return 1
  fi

  if ! systemctl is-active --quiet ollama.service 2>/dev/null; then
    echo -e "  ${COLOR_RED}Ollama is not running${COLOR_RESET}"
    echo "  Start Ollama first: $0 ollama"
    echo ""
    return 1
  fi

  # Wait a moment for the service to be ready
  sleep 2

  if docker exec ollama ollama list 2>/dev/null; then
    echo ""
  else
    echo -e "  ${COLOR_YELLOW}No models installed yet${COLOR_RESET}"
    echo ""
    echo "  Pull a model with:"
    echo "    docker exec ollama ollama pull llama3.2"
    echo "    docker exec ollama ollama pull mistral"
    echo ""
  fi
}

pull_ollama_model() {
  local model_name="$1"

  # Check if Ollama service exists
  if ! systemctl list-unit-files ollama.service --no-legend 2>/dev/null | grep -q ollama.service; then
    echo -e "${COLOR_RED}Error: Ollama is not installed${COLOR_RESET}"
    echo ""
    echo "Install Ollama first:"
    echo "  sudo bash install-ollama.sh"
    return 1
  fi

  if ! systemctl is-active --quiet ollama.service 2>/dev/null; then
    echo -e "${COLOR_RED}Error: Ollama is not running${COLOR_RESET}"
    echo "Start Ollama first: $0 ollama"
    return 1
  fi

  echo -e "${COLOR_YELLOW}Pulling Ollama model: ${model_name}${COLOR_RESET}"
  echo ""

  docker exec -it ollama ollama pull "$model_name"

  echo ""
  echo -e "${COLOR_GREEN}Model pulled successfully!${COLOR_RESET}"
  echo ""
}

show_menu() {
  print_header
  print_status

  echo -e "${COLOR_YELLOW}Available Commands:${COLOR_RESET}"
  echo ""
  echo "  $0 localai           - Switch to LocalAI (exclusive)"
  echo "  $0 ollama            - Switch to Ollama (exclusive)"
  echo "  $0 both              - Start both services (parallel)"
  echo "  $0 stop              - Stop all AI servers"
  echo "  $0 status            - Show current status"
  echo "  $0 models            - List Ollama models"
  echo "  $0 pull <model>      - Pull an Ollama model"
  echo ""
  echo "Examples:"
  echo "  $0 both              # Run both services together"
  echo "  $0 ollama            # Run only Ollama"
  echo "  $0 pull llama3.2     # Download a model"
  echo "  $0 status            # Check what's running"
  echo ""
}

main() {
  if [[ $# -eq 0 ]]; then
    show_menu
    exit 0
  fi

  case "${1:-}" in
    localai)
      print_header
      start_localai
      ;;
    ollama)
      print_header
      start_ollama
      ;;
    both)
      print_header
      start_both
      ;;
    stop)
      print_header
      stop_all
      ;;
    status)
      print_header
      print_status
      ;;
    models)
      print_header
      list_ollama_models
      ;;
    pull)
      if [[ $# -lt 2 ]]; then
        echo -e "${COLOR_RED}Error: Model name required${COLOR_RESET}"
        echo "Usage: $0 pull <model-name>"
        echo "Example: $0 pull llama3.2"
        exit 1
      fi
      print_header
      pull_ollama_model "$2"
      ;;
    help|--help|-h)
      show_menu
      ;;
    *)
      echo -e "${COLOR_RED}Error: Unknown command '${1}'${COLOR_RESET}"
      echo ""
      show_menu
      exit 1
      ;;
  esac
}

main "$@"
