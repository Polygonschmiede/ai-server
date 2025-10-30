# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Server Installer - Automated installation and management of LocalAI and Ollama AI model servers on Ubuntu 24.04 with NVIDIA GPU support, Docker orchestration, and intelligent power management.

**Key Components:**
- **LocalAI & Ollama**: Two AI inference servers that can run in parallel or exclusively
- **Power Management**: Auto-suspend monitoring with configurable idle detection
- **AI GOAT CLI**: Interactive TUI dashboard for system monitoring and management
- **SystemD Integration**: All services managed through systemd units

## Common Commands

### Installation & Setup
```bash
# Install LocalAI (GPU mode, interactive)
sudo bash install.sh

# Install LocalAI (CPU-only, non-interactive)
sudo bash install.sh --cpu-only --non-interactive

# Install Ollama (requires Docker from LocalAI install)
sudo bash install-ollama.sh

# Repair/reconfigure existing installation
sudo bash install.sh --repair

# Verify installation
./verify-setup.sh
```

### Service Management
```bash
# Check status of all services
./ai-server-manager.sh status

# Start Ollama (stops LocalAI if running)
./ai-server-manager.sh ollama

# Start LocalAI (stops Ollama if running)
./ai-server-manager.sh localai

# Run both services in parallel
./ai-server-manager.sh both

# Stop all AI services
./ai-server-manager.sh stop

# Manage Ollama models
./ai-server-manager.sh models
./ai-server-manager.sh pull llama3.2
```

### Development & Testing
```bash
# Lint all shell scripts
shellcheck install.sh install-ollama.sh ai-server-manager.sh scripts/**/*.sh

# Format scripts with consistent indentation
shfmt -w install.sh install-ollama.sh scripts/**/*.sh

# Run all Bats integration tests
bats tests

# Run specific test suite
bats tests/install.bats

# Test AI GOAT CLI
cd ai-goat-cli && ./ai-goat
```

### Monitoring & Debugging
```bash
# View LocalAI logs
docker logs -f localai

# View Ollama logs
docker logs -f ollama

# Check auto-suspend status
sudo systemctl status ai-auto-suspend.service
sudo journalctl -u ai-auto-suspend.service -f

# Monitor GPU in real-time
watch -n 2 nvidia-smi

# Check all container stats
docker stats
```

## Architecture

### Directory Structure
```
/opt/localai/           # LocalAI installation
├── docker-compose.yml  # Container definition (GPU/CPU variants)
└── models/             # AI model storage (configurable path)

/opt/ollama/            # Ollama installation
├── docker-compose.yml  # Container definition
└── models/             # Ollama model storage

/etc/localai-installer/ # Persistent installer state
└── state.env           # Installation configuration

/etc/systemd/system/    # SystemD service units
├── localai.service     # LocalAI orchestration
├── ollama.service      # Ollama orchestration
├── ai-auto-suspend.service      # Auto-suspend monitor
├── ai-stayawake-http.service    # Stay-awake HTTP service
└── wol@.service                 # Wake-on-LAN template

scripts/lib/            # Reusable bash helpers
├── docker.sh           # Docker installation/setup
├── install_helpers.sh  # Installation utilities
├── logging.sh          # Logging functions (log, warn, err, die)
├── power.sh            # Power management helpers
├── service.sh          # SystemD service management
└── system.sh           # System utilities

ai-goat-cli/            # Interactive TUI dashboard
├── ai-goat             # Bash wrapper (entry point)
├── ai-goat.py          # Main Textual TUI application
└── lib/                # Python modules
    ├── monitoring.py   # GPU/CPU/Memory monitoring
    ├── power.py        # Auto-suspend status & power metrics
    ├── system.py       # Service control & installation
    └── remote.py       # WOL & remote access info
```

### Service Dependencies
1. **localai.service / ollama.service**: Docker Compose orchestration
   - Pulls images before starting (`docker compose pull`)
   - Uses `restart: unless-stopped` policy
   - Automatic cleanup on stop (`docker compose down`)

2. **ai-auto-suspend.service**: Python-based idle monitoring
   - Checks CPU idle % (default: must be >90% idle)
   - Checks GPU utilization (default: must be <10%)
   - Ignores API connection count (focuses on real hardware usage)
   - Optionally monitors SSH sessions (CHECK_SSH environment variable, disabled by default)
   - Respects stay-awake flag from HTTP service
   - Suspends system after configurable idle time (default: 30 minutes)
   - Reads config from environment variables in service unit

3. **ai-stayawake-http.service**: Python HTTP service
   - Endpoint: `GET /stay?s=<seconds>`
   - Writes timestamp to `/run/ai-nodectl/stay_awake_until`
   - Prevents auto-suspend during active workloads

4. **wol@<interface>.service**: Wake-on-LAN enabler
   - Runs `ethtool -s <interface> wol g` on boot
   - Persists WOL configuration across reboots

### State Files
- `/etc/localai-installer/state.env` - Installation parameters persisted across runs
- `/run/ai-nodectl/stay_awake_until` - Unix timestamp; stay-awake active until this time
- `/var/lib/ai-auto-suspend/idle_since` - Unix timestamp tracking idle start time

## Code Architecture & Patterns

### Main Installation Scripts
**install.sh** and **install-ollama.sh** follow the same structure:
1. Parse command-line flags (see `.env.example` for all options)
2. Source helper libraries from `scripts/lib/`
3. Detect existing installations and offer removal
4. Install dependencies (Docker, NVIDIA toolkit)
5. Generate systemd service files and docker-compose.yml
6. Configure power management (auto-suspend, stay-awake, WOL)
7. Configure firewall (UFW) and optional SSH hardening
8. Start services and display status summary

### Bash Coding Standards (from AGENTS.md)
- Start all scripts with `#!/usr/bin/env bash` and `set -euo pipefail`
- Use uppercase snake_case for globals (`LOCALAI_DIR`, `WAIT_MINUTES`)
- Use lowercase snake_case for functions (`require_cmd`, `install_docker`)
- Two-space indentation (enforced by `shfmt`)
- Use explicit long flags in commands (`--models-path`, not `-m`)
- Co-locate logging helpers (`log`, `warn`, `err`, `die`) near top

### Power Management Design
The auto-suspend system has two components:
1. **auto-suspend-monitor.py**: Main monitoring script
   - Checks CPU idle percentage via `mpstat` or `psutil`
   - Checks GPU utilization via `nvidia-smi` (if GPU present)
   - Checks SSH sessions via `who` (optional, disabled by default)
   - **Ignores** API connections - only CPU/GPU activity matters
   - Suspends via `systemctl suspend` when idle conditions met

2. **stay-awake-server.py**: HTTP flag service
   - Simple Flask/HTTP server on port 9876 (configurable)
   - Sets temporary stay-awake flag to prevent suspension
   - Used before long-running jobs or model downloads

**Important**: The system defaults to **NOT** checking SSH connections (set CHECK_SSH=false in service environment). API connections (ports 8080, 11434, 3000) are explicitly ignored - only actual hardware usage (CPU/GPU) prevents suspend. Default wait time is 30 minutes, not 10.

### AI GOAT CLI Architecture
Python TUI application using Textual framework:
- **ai-goat.py**: Main application with tab-based navigation
- **lib/monitoring.py**: Queries `nvidia-smi`, `psutil`, systemd for metrics
- **lib/power.py**: Parses auto-suspend state and estimates power consumption
- **lib/system.py**: Service start/stop, installation triggers
- **lib/remote.py**: Reads WOL config, formats remote access commands

Entry point is bash wrapper `ai-goat` that activates venv and runs Python script.

## Testing

### Test Organization (from tests/README.md)
- Use [Bats](https://bats-core.readthedocs.io/) for integration tests
- One suite per feature area: `install.bats`, `lib_docker.bats`, etc.
- Store golden artifacts in `tests/fixtures/` and compare with `diff`
- Keep tests under ~15 setup lines
- Test both GPU and CPU code paths
- Test failure branches (missing sudo, unsupported distro)

### Running Tests
```bash
# All tests
bats tests

# Specific suite
bats tests/lib_docker.bats

# Dry-run installation
bash install.sh --non-interactive --cpu-only
```

## Important Implementation Notes

### Idempotency
Both installers are designed to be run multiple times safely:
- Detect existing installations and offer removal or repair
- `--repair` flag reconfigures services without full reinstall
- Preserve model data by default during uninstall
- State file (`/etc/localai-installer/state.env`) tracks previous configuration

### Parallel Service Operation
LocalAI and Ollama can run simultaneously:
- Both use `restart: unless-stopped` policy
- Share GPU memory (monitor with `nvidia-smi`)
- Use different ports (LocalAI: 8080, Ollama: 11434/3000)
- Managed via `ai-server-manager.sh both`
- If OOM errors occur, run exclusively instead

### Docker Compose Variants
install.sh generates different docker-compose.yml based on mode:
- **GPU mode**: Uses `localai/localai:latest-gpu-nvidia-cuda-12` image
- **CPU mode**: Uses `localai/localai:latest` image
- Both mount `${MODELS_PATH}:/models` for persistent storage

### SSH Hardening
Optional security feature:
- Disables password authentication
- Disables root login
- Only prompts if `--harden-ssh` or `--skip-ssh-hardening` not specified
- Warns users with active password auth to set up keys first

### Firewall Configuration
UFW rules allow:
- SSH (22)
- LocalAI (8080)
- Ollama (11434)
- Open WebUI (3000)
- Stay-awake service (9876)
- All configurable via command-line flags

## ⚠️ Known Code Issues (see ANALYSIS.md)

**Critical Code Duplication:**
- Helper libraries in `scripts/lib/` are NOT sourced by install.sh/install-ollama.sh
- All helper functions are duplicated inline in install.sh (~600 lines)
- The library files exist but are essentially dead code
- This violates DRY principle and complicates maintenance

**Why this matters:**
- Changes to logging, Docker handling, or service management need updates in multiple places
- install.sh is ~600 lines longer than necessary
- Risk of inconsistencies between duplicated code

**Language Issues:**
- install.sh and helper libraries contain German log messages
- All documentation is in English
- Creates inconsistency for international contributors

**Recommendation:** See ANALYSIS.md for comprehensive improvement plan

## Key Files to Understand

### Entry Points
- `install.sh` - Main LocalAI installer with full feature set
- `install-ollama.sh` - Ollama installer (simpler, requires Docker)
- `ai-server-manager.sh` - Service switching and model management
- `verify-setup.sh` - Installation verification and diagnostics

### Core Helpers
- `scripts/lib/install_helpers.sh` - Installation utilities (require_cmd, detect distro, etc.)
- `scripts/lib/docker.sh` - Docker CE installation and configuration
- `scripts/lib/power.sh` - Power management service generation
- `scripts/lib/logging.sh` - Color-coded logging (log, warn, err, die)

### Runtime Services
- `auto-suspend-monitor.py` - Main idle detection logic
- `stay-awake-server.py` - HTTP flag service
- `ai-goat-cli/ai-goat.py` - Interactive monitoring dashboard

### Configuration
- `.env.example` - All available configuration options with defaults
- `config/` - Additional configuration templates (if any)

## Common Modification Patterns

### Adding a New Command-Line Flag
1. Add to flag parsing section in `install.sh` or `install-ollama.sh`
2. Add default value to configuration section at top
3. Document in `.env.example`
4. Persist to state file if needed for repair mode
5. Update README.md configuration table

### Modifying Auto-Suspend Behavior
1. Edit `auto-suspend-monitor.py` for logic changes
2. Update environment variables in service generation (scripts/lib/power.sh)
3. Document new parameters in `.env.example`
4. Test with `sudo systemctl restart ai-auto-suspend.service`

### Adding a New Service
1. Create systemd service template in `scripts/lib/service.sh` or inline
2. Add to installer script's service setup section
3. Add to `ai-server-manager.sh status` output
4. Add firewall rules if needed (scripts/lib/install_helpers.sh)
5. Add to `verify-setup.sh` checks

### Extending AI GOAT CLI
1. Add monitoring functions to appropriate `ai-goat-cli/lib/*.py` module
2. Update TUI in `ai-goat.py` to display new data
3. Follow Textual framework patterns (widgets, reactive properties)
4. Test without breaking existing dashboard layout

## Troubleshooting Common Issues

### Installation Failures
- Check logs in installation output (verbose by default)
- Run `./verify-setup.sh` to diagnose component status
- Use `--repair` to regenerate services without full reinstall
- Check `/etc/localai-installer/state.env` for persisted config

### Service Won't Start
- Check systemd status: `sudo systemctl status localai.service`
- View container logs: `docker logs localai` or `docker logs ollama`
- Verify docker-compose: `cd /opt/localai && docker compose config`
- Ensure GPU available: `nvidia-smi` and `docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi`

### Auto-Suspend Not Working
- Check service status: `sudo systemctl status ai-auto-suspend.service`
- View live logs: `sudo journalctl -u ai-auto-suspend.service -f`
- Check state file: `cat /var/lib/ai-auto-suspend/idle_since`
- Verify thresholds in environment variables: `systemctl cat ai-auto-suspend.service`
- Remember: API connections do NOT prevent suspend (by design)

### GPU Not Detected
- Verify NVIDIA drivers: `nvidia-smi`
- Check Docker GPU access: `docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi`
- Ensure NVIDIA Container Toolkit installed: `dpkg -l | grep nvidia-container-toolkit`
- Check docker daemon config: `/etc/docker/daemon.json` should have nvidia runtime

## URLs and Endpoints

After installation, services are accessible at:
- **LocalAI API**: `http://<server-ip>:8080`
- **LocalAI WebUI**: `http://<server-ip>:8080`
- **LocalAI Health**: `http://<server-ip>:8080/readyz`
- **Ollama API**: `http://<server-ip>:11434`
- **Open WebUI**: `http://<server-ip>:3000` (Ollama's chat interface)
- **Stay-Awake**: `http://<server-ip>:9876/stay?s=<seconds>`

Both LocalAI and Ollama expose OpenAI-compatible APIs at:
- LocalAI: `http://<server-ip>:8080/v1/`
- Ollama: `http://<server-ip>:11434/v1/`
