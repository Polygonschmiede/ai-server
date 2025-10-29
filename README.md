# LocalAI Installer for Ubuntu

Automated installation and configuration script for [LocalAI](https://github.com/go-skynet/LocalAI) on Ubuntu 24.04 with NVIDIA GPU support, Docker Compose orchestration, and intelligent power management.

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
- **Repair Mode**: `--repair` flag to reconfigure services without reinstalling
- **State Persistence**: Configuration survives reboots and updates

## Requirements

- **OS**: Ubuntu 24.04 (Noble) - amd64 architecture
- **Privileges**: Root or sudo access required
- **Hardware**:
  - CPU mode: Any x86_64 system
  - GPU mode: NVIDIA GPU with compatible drivers (optional)

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

## Usage Examples

### Access LocalAI

After installation, LocalAI is available at:
- **API/WebUI**: `http://<server-ip>:8080`
- **Health Check**: `http://<server-ip>:8080/readyz`
- **OpenAI-compatible API**: `http://<server-ip>:8080/v1/`

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
