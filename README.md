# AI Server Installer for Ubuntu

Automated installation and configuration scripts for AI model servers on Ubuntu 24.04 with NVIDIA GPU support, Docker Compose orchestration, and intelligent power management.

## 📚 Documentation

- **[USAGE.md](USAGE.md)** - 🎯 **Start here!** Complete usage guide with:
  - How to use the Web UI
  - Download and switch models
  - Monitor GPU/CPU status
  - Auto-suspend and Wake-on-LAN
  - Daily usage commands
- **[ai-goat-cli/](ai-goat-cli/)** - 🐐 **AI GOAT CLI** - Interactive terminal dashboard:
  - Real-time GPU/CPU monitoring with power consumption (Watts)
  - Auto-suspend countdown timer
  - Wake-on-LAN and remote control info
  - Beautiful TUI (Terminal User Interface)
  - See [ai-goat-cli/README.md](ai-goat-cli/README.md)
- **[OLLAMA.md](OLLAMA.md)** - Ollama-specific installation and features
- **[AGENTS.md](AGENTS.md)** - Development guidelines

## Available AI Servers

This repository provides installers for two AI server options:

1. **LocalAI** - Advanced, self-hosted AI inference engine with wide model format support
2. **Ollama** - Simple, user-friendly LLM server with beautiful web UI (see [OLLAMA.md](OLLAMA.md))

Both servers:
- Run in Docker containers
- Support NVIDIA GPU acceleration
- Provide OpenAI-compatible APIs
- Work with n8n and other tools
- **Can run in parallel** on the same system sharing GPU resources

**New to this?** Start with Ollama for the easiest experience. See [OLLAMA.md](OLLAMA.md) for installation and usage.

**Want both?** Install LocalAI first (see below), then run `sudo bash install-ollama.sh`. Use `./ai-server-manager.sh` to manage them:
- Run them **separately** (exclusive mode - one at a time)
- Run them **together** (parallel mode - both sharing GPU)

## Features

### Core Functionality
- **Docker Setup**: Automated installation of Docker CE, Docker Compose, and all required dependencies
- **LocalAI Deployment**: Containerized LocalAI with GPU (CUDA 12) or CPU-only modes
- **NVIDIA Support**: Automatic NVIDIA Container Toolkit installation and configuration
- **SystemD Integration**: Service management with automatic restart and health monitoring

### Power Management
- **Auto-Suspend**: Monitors CPU/GPU utilization; suspends system after 30 minutes idle (configurable)
- **Smart Idle Detection**: API connections ignored - only CPU/GPU activity prevents suspend
- **Optional SSH Check**: SSH connections can optionally prevent suspend (disabled by default)
- **Stay-Awake HTTP Service**: Simple HTTP endpoint to prevent auto-suspend during active workloads
- **Wake-on-LAN**: Automatic WOL configuration for remote system wake-up

### Security & Hardening
- **UFW Firewall**: Automated firewall configuration with sensible defaults
- **SSH Hardening**: Optional password authentication disabling and root login prevention
- **Safe Uninstall**: Clean removal of all managed components while preserving model data

### Operations
- **Idempotent**: Safe to run multiple times without breaking existing installations
- **Repair Mode**: `--repair` flag to reconfigure services without reinstalling (both installers)
- **Safe Uninstall**: Both installers detect existing installations and offer clean removal
- **State Persistence**: Configuration survives reboots and updates
- **Verification Script**: `verify-setup.sh` checks all components and provides detailed status

### User Experience
- **Detailed Feedback**: Real-time progress updates for every installation step
- **Color-Coded Output**: Visual feedback with success (green), info (blue), warning (yellow), and error (red) messages
- **Progress Indicators**: Clear status messages showing what's happening at each stage
- **Comprehensive Summary**: Detailed installation report at the end with all relevant information
- **Error Handling**: Clear error messages with suggested actions when issues occur

### Service Management
- **Unified Control**: Single `ai-server-manager.sh` script to manage both services
- **Parallel Operation**: Run both LocalAI and Ollama simultaneously
- **Exclusive Mode**: Run only one service at a time (automatic stop of the other)
- **Easy Model Management**: Pull and list Ollama models through the manager script

## Requirements

- **OS**: Ubuntu 24.04 (Noble) - amd64 architecture
- **Privileges**: Root or sudo access required
- **Hardware**:
  - CPU mode: Any x86_64 system
  - GPU mode: NVIDIA GPU with compatible drivers (optional)

## Getting the Repository

Before you can run the installation scripts, you need to get this repository onto your Linux machine.

### Step 1: Install Git (if not already installed)

On Ubuntu, install Git with:
```bash
sudo apt update
sudo apt install -y git
```

Verify Git is installed:
```bash
git --version
```

### Step 2: Clone the Repository

Clone this repository to your Linux machine:
```bash
git clone https://github.com/Polygonschmiede/ai-server.git
```

This will create a directory called `ai-server` in your current location.

### Step 3: Navigate to the Repository

Change into the repository directory:
```bash
cd ai-server
```

### Step 4: Make Scripts Executable (optional)

The scripts should already be executable, but if needed:
```bash
chmod +x install.sh install-ollama.sh ai-server-manager.sh verify-setup.sh
```

Now you're ready to proceed with the installation!

## Quick Start

### Basic Installation (GPU Mode)

```bash
sudo bash install.sh
```

### CPU-Only Installation

```bash
sudo bash install.sh --cpu-only --non-interactive
```

### Custom Configuration

```bash
sudo bash install.sh \
  --models-path /data/models \
  --localai-port 8080 \
  --wait-minutes 30 \
  --harden-ssh
```

## Configuration Options

### Core Options
| Flag | Description | Default |
|------|-------------|---------|
| `--cpu-only` | Force CPU-only mode (no GPU acceleration) | GPU mode |
| `--non-interactive` | Skip all prompts and confirmations | Interactive |
| `--repair` | Reconfigure services without full reinstall | Normal install |
| `--models-path PATH` | Host directory for AI models | `/opt/localai/models` |
| `--localai-port PORT` | External LocalAI HTTP port | `8080` |

### Power Management
| Flag | Description | Default |
|------|-------------|---------|
| `--skip-auto-suspend` | Disable auto-suspend watcher | Enabled |
| `--skip-stay-awake` | Disable stay-awake HTTP service | Enabled |
| `--skip-wol` | Disable Wake-on-LAN configuration | Enabled |
| `--wait-minutes MIN` | Idle minutes before suspend | `30` |
| `--cpu-idle-threshold %` | CPU idle threshold for suspend | `90` |
| `--gpu-max %` | Max GPU utilization for idle | `10` |
| `--check-interval SEC` | Auto-suspend check interval | `60` |
| `--check-ssh` | SSH connections prevent suspend | `false` |
| `--stay-awake-port PORT` | HTTP port for stay-awake service | `9876` |
| `--stay-awake-bind IP` | Bind address for stay-awake | `0.0.0.0` |
| `--wol-interface IFACE` | Network interface for WOL | Auto-detect |

### Security Options
| Flag | Description | Default |
|------|-------------|---------|
| `--skip-firewall` | Skip UFW firewall configuration | Enabled |
| `--harden-ssh` | Force SSH hardening (disable password auth) | Ask user |
| `--skip-ssh-hardening` | Force skip SSH hardening | Ask user |

### Miscellaneous
| Flag | Description | Default |
|------|-------------|---------|
| `--timezone ZONE` | System timezone | `Europe/Berlin` |
| `--server-ip IP` | Server IP for status messages | `192.168.178.50` |

## Managing AI Services

After installation, use the unified management script to control your AI servers:

### Parallel Mode (Both Services Running)

Run both LocalAI and Ollama simultaneously:
```bash
./ai-server-manager.sh both
```

Both services will share GPU memory. This works well for:
- Testing different models
- Comparing responses
- Having multiple API endpoints available

**Note**: Monitor GPU memory usage with `nvidia-smi`. If you experience OOM errors, run services in exclusive mode.

### Exclusive Mode (One Service at a Time)

Switch to LocalAI (stops Ollama if running):
```bash
./ai-server-manager.sh localai
```

Switch to Ollama (stops LocalAI if running):
```bash
./ai-server-manager.sh ollama
```

### Check Status

View all services:
```bash
./ai-server-manager.sh status
```

### Stop All Services

```bash
./ai-server-manager.sh stop
```

### Verify Installation

Run the verification script to check all components:
```bash
./verify-setup.sh
```

This will check:
- Docker installation and status
- NVIDIA GPU and drivers
- LocalAI installation and API
- Ollama installation and API
- Support services (auto-suspend, stay-awake)
- Firewall configuration

## Usage Examples

### Access LocalAI

After installation, LocalAI is available at:
- **API/WebUI**: `http://<server-ip>:8080`
- **Health Check**: `http://<server-ip>:8080/readyz`
- **OpenAI-compatible API**: `http://<server-ip>:8080/v1/`

### Access Ollama

After installation, Ollama is available at:
- **API**: `http://<server-ip>:11434`
- **Open WebUI**: `http://<server-ip>:3000`
- **OpenAI-compatible API**: `http://<server-ip>:11434/v1/`

### Stay-Awake Service

Prevent auto-suspend for 1 hour:
```bash
curl "http://<server-ip>:9876/stay?s=3600"
```

### Service Management

```bash
# Check LocalAI status
sudo systemctl status localai.service

# Restart LocalAI
sudo systemctl restart localai.service

# View logs
docker logs -f localai

# Check auto-suspend status
sudo systemctl status ai-auto-suspend.service
```

### Repair Installation

If systemd services drift or configuration changes:
```bash
sudo bash install.sh --repair
```

## Architecture

### Directory Structure
```
/opt/localai/
├── docker-compose.yml    # LocalAI container definition
└── models/               # AI model storage (configurable)

/usr/local/bin/
├── ai-auto-suspend.sh    # Auto-suspend watcher script
└── ai-stayawake-http.sh  # Stay-awake HTTP service script

/etc/systemd/system/
├── localai.service              # Main LocalAI service
├── ai-auto-suspend.service      # Auto-suspend watcher
├── ai-stayawake-http.service    # Stay-awake HTTP service
└── wol@.service                 # Wake-on-LAN template

/etc/localai-installer/
└── state.env             # Persisted configuration state
```

### Services

1. **localai.service**: Orchestrates Docker Compose for LocalAI container
   - Pulls images before start
   - Uses `restart: unless-stopped` policy
   - Automatic cleanup on stop

2. **ai-auto-suspend.service**: Monitors system activity
   - Tracks CPU/GPU utilization
   - Ignores API connections (focus on real hardware usage)
   - Optional SSH session monitoring (disabled by default)
   - Suspends after 30 minutes idle (configurable)

3. **ai-stayawake-http.service**: Simple HTTP service
   - Endpoint: `GET /stay?s=<seconds>`
   - Sets temporary stay-awake flag
   - Prevents auto-suspend during active workloads

4. **wol@<interface>.service**: Wake-on-LAN enabler
   - Configures network interface for WOL
   - Persists across reboots

## Development

See [AGENTS.md](AGENTS.md) for detailed development guidelines.

### Linting & Formatting
```bash
# Lint all shell scripts
shellcheck install.sh scripts/**/*.sh

# Format with consistent indentation
shfmt -w install.sh scripts/**/*.sh
```

### Testing
```bash
# Run all Bats tests
bats tests

# Smoke test without GPU
bash install.sh --non-interactive --cpu-only
```

## Troubleshooting

### LocalAI not starting
```bash
# Check service status
sudo systemctl status localai.service

# View container logs
docker logs -f localai

# Validate docker-compose
cd /opt/localai && docker compose config
```

### GPU not detected
```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

### Auto-suspend not working
```bash
# Check service status
sudo systemctl status ai-auto-suspend.service

# View logs
sudo journalctl -u ai-auto-suspend.service -f

# Check state file
cat /run/ai-nodectl/stay_awake_until
```

## Uninstallation

The installer detects existing installations and offers safe removal:
```bash
# Interactive uninstall with prompts
sudo bash install.sh

# Non-interactive clean install (removes existing)
sudo bash install.sh --non-interactive
```

Manual cleanup:
```bash
# Stop all services
sudo systemctl stop localai.service ai-auto-suspend.service ai-stayawake-http.service
sudo systemctl disable localai.service ai-auto-suspend.service ai-stayawake-http.service

# Remove containers
cd /opt/localai && docker compose down

# Remove service files
sudo rm -f /etc/systemd/system/localai.service
sudo rm -f /etc/systemd/system/ai-auto-suspend.service
sudo rm -f /etc/systemd/system/ai-stayawake-http.service
sudo rm -f /etc/systemd/system/wol@*.service

# Remove scripts
sudo rm -f /usr/local/bin/ai-auto-suspend.sh
sudo rm -f /usr/local/bin/ai-stayawake-http.sh

# Remove state
sudo rm -rf /etc/localai-installer

# Reload systemd
sudo systemctl daemon-reload

# Optional: Remove LocalAI directory (preserves models by default)
# sudo rm -rf /opt/localai
```

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please see [AGENTS.md](AGENTS.md) for development guidelines and coding standards.

## Related Projects

- [LocalAI](https://github.com/go-skynet/LocalAI) - The core AI inference engine
- [Docker](https://www.docker.com/) - Container runtime
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker) - GPU support for containers
