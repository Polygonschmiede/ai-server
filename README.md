# AI Server Installer for Ubuntu

Automated installation and configuration scripts for AI model servers on Ubuntu 24.04 with NVIDIA GPU support, Docker Compose orchestration, and intelligent power management.

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
- **Auto-Suspend**: Monitors CPU/GPU utilization and SSH sessions; suspends system after configurable idle time
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

## Getting Started

This guide will take you from a fresh Ubuntu installation to a running AI server in just a few steps.

### Complete Workflow (Start to Finish)

If you're starting with a fresh Ubuntu 24.04 installation, follow these steps:

```bash
# 1. Update system and install Git
sudo apt update
sudo apt install -y git

# 2. Clone this repository
git clone https://github.com/Polygonschmiede/ai-server.git
cd ai-server

# 3. Make scripts executable
chmod +x install.sh install-ollama.sh ai-server-manager.sh verify-setup.sh

# 4. Install LocalAI (includes Docker, NVIDIA toolkit, etc.)
sudo bash install.sh

# 5. Install Ollama (optional, but recommended)
sudo bash install-ollama.sh

# 6. Verify installation
./verify-setup.sh

# 7. Start both services in parallel
./ai-server-manager.sh both

# 8. Pull some models for Ollama
./ai-server-manager.sh pull llama3.2
./ai-server-manager.sh pull mistral

# Done! Access your services:
# - LocalAI:  http://localhost:8080
# - Ollama:   http://localhost:11434
# - WebUI:    http://localhost:3000
```

### Step-by-Step Guide

#### Step 1: Install Git (if not already installed)

On a fresh Ubuntu installation, you may need to install Git first:

```bash
sudo apt update
sudo apt install -y git
```

#### Step 2: Clone the Repository

Download the installation scripts to your Linux machine:

```bash
# Clone the repository
git clone https://github.com/Polygonschmiede/ai-server.git

# Navigate into the directory
cd ai-server
```

#### Step 3: Make Scripts Executable

Ensure all scripts have execute permissions:

```bash
chmod +x install.sh install-ollama.sh ai-server-manager.sh verify-setup.sh
```

#### Step 4: Run the Installation

Now you're ready to install! Choose one of the options below based on your needs.

### What Happens During Installation?

The installation scripts will automatically:

**LocalAI (install.sh):**
1. Install Docker CE and Docker Compose
2. Set up NVIDIA Container Toolkit (if GPU detected)
3. Configure Docker to use NVIDIA runtime
4. Create systemd services for LocalAI
5. Set up auto-suspend and stay-awake services
6. Configure UFW firewall rules
7. Optional: Harden SSH security
8. Create directory structure in `/opt/localai`
9. Download and start LocalAI container

**Ollama (install-ollama.sh):**
1. Check for existing Docker installation
2. Detect NVIDIA GPU (if available)
3. Create systemd service for Ollama
4. Set up Open WebUI container
5. Configure firewall rules for ports 11434 and 3000
6. Create directory structure in `/opt/ollama`
7. Download and start Ollama and WebUI containers

**Total Installation Time:**
- LocalAI: ~5-10 minutes (depending on internet speed)
- Ollama: ~3-5 minutes
- First model download: ~2-5 minutes (depends on model size)

### First-Time Setup Tips

**If you have an NVIDIA GPU:**
- Make sure NVIDIA drivers are installed: `nvidia-smi` should work
- The installer will automatically set up GPU acceleration
- No manual configuration needed

**If you don't have a GPU:**
- Use `--cpu-only` flag for both installers
- Performance will be slower but still functional
- Great for testing and small models

**SSH Access:**
- The installer can harden SSH security (disable password auth)
- Only do this if you have SSH keys set up
- If unsure, skip SSH hardening during installation

## Quick Start

### Option A: LocalAI Only

Install LocalAI with GPU support (default):

```bash
sudo bash install.sh
```

Or with CPU-only mode:

```bash
sudo bash install.sh --cpu-only --non-interactive
```

### Option B: Ollama Only

Install Ollama with Open WebUI:

```bash
# Make sure Docker is installed (run Option A first, or install Docker manually)
sudo bash install-ollama.sh
```

Or with CPU-only mode:

```bash
sudo bash install-ollama.sh --cpu-only --non-interactive
```

### Option C: Both LocalAI and Ollama (Recommended)

Install both services for maximum flexibility:

```bash
# 1. Install LocalAI first (includes Docker setup)
sudo bash install.sh

# 2. Then install Ollama
sudo bash install-ollama.sh

# 3. Verify everything is working
./verify-setup.sh

# 4. Start both in parallel mode
./ai-server-manager.sh both
```

### Custom Configuration Example

LocalAI with custom settings:

```bash
sudo bash install.sh \
  --models-path /data/models \
  --localai-port 8080 \
  --wait-minutes 30 \
  --harden-ssh
```

Ollama with custom ports:

```bash
sudo bash install-ollama.sh \
  --ollama-port 11434 \
  --webui-port 3000 \
  --models-path /data/ollama-models
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
   - Monitors SSH sessions and LLM API ports
   - Suspends after configured idle time

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

## FAQ - First Installation

### How do I get these scripts on my Linux machine?

```bash
# Install Git first
sudo apt update && sudo apt install -y git

# Clone the repository
git clone https://github.com/Polygonschmiede/ai-server.git
cd ai-server

# Make scripts executable
chmod +x *.sh

# Run installation
sudo bash install.sh
```

### Do I need to download anything else manually?

No! The scripts will automatically download everything needed:
- Docker and Docker Compose
- NVIDIA Container Toolkit (if GPU detected)
- LocalAI container image
- Ollama container image
- Open WebUI container image

Just run the scripts and wait for completion.

### Which installation order should I use?

**Recommended order:**
1. First: `sudo bash install.sh` (installs Docker + LocalAI)
2. Then: `sudo bash install-ollama.sh` (adds Ollama)
3. Verify: `./verify-setup.sh`

**Why this order?**
- `install.sh` sets up Docker and NVIDIA toolkit
- `install-ollama.sh` reuses the existing Docker installation
- This avoids duplicate work and potential conflicts

### Can I run this on a fresh Ubuntu install?

Yes! That's exactly what it's designed for. Just make sure you have:
- Ubuntu 24.04 (recommended) or similar version
- Internet connection
- Sudo/root access

The scripts will handle everything else.

### What if I already have Docker installed?

No problem! The scripts detect existing installations:
- Existing Docker: Will be reused (not reinstalled)
- Existing LocalAI/Ollama: You'll be asked if you want to reinstall or keep
- Use `--repair` flag to fix broken installations without reinstalling

### Do I need an NVIDIA GPU?

No, but it's recommended for better performance:
- **With GPU**: Use default installation (GPU mode)
- **Without GPU**: Add `--cpu-only` flag to both installers
- CPU mode works fine for testing and smaller models

### How much disk space do I need?

**Minimum requirements:**
- System/Docker: ~5 GB
- LocalAI image: ~2 GB
- Ollama image: ~1 GB
- Models: 1-10 GB each (depends on model size)

**Recommended:** At least 50 GB free space for comfortable use with multiple models.

### Can I change ports after installation?

Yes, use the `--repair` flag with new port settings:

```bash
# Change LocalAI port
sudo bash install.sh --repair --localai-port 8090

# Change Ollama ports
sudo bash install-ollama.sh --repair --ollama-port 11435 --webui-port 3001
```

### How do I update to the latest version?

```bash
# Navigate to repository directory
cd ai-server

# Pull latest changes
git pull

# Re-run installation in repair mode
sudo bash install.sh --repair
sudo bash install-ollama.sh --repair
```

### Where are my models stored?

**LocalAI models:** `/opt/localai/models`
**Ollama models:** `/opt/ollama/models`

These directories are preserved during reinstallation and uninstallation.

### How do I completely remove everything?

```bash
# Run installers without --non-interactive
# They will detect existing installations and offer removal
sudo bash install.sh
sudo bash install-ollama.sh

# Or use --non-interactive for automatic removal
sudo bash install.sh --non-interactive
sudo bash install-ollama.sh --non-interactive
```

Models are preserved by default. To remove models too:
```bash
sudo rm -rf /opt/localai
sudo rm -rf /opt/ollama
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
