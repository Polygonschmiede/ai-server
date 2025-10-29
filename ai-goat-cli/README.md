# AI GOAT 🐐 - Greatest Of All Tech

**Interactive Terminal Dashboard for AI Server Management**

A modern, beautiful Terminal User Interface (TUI) for managing and monitoring your AI server. Built with Python and Textual, AI GOAT provides real-time monitoring, power management, and system control - all in your terminal!

```
    ___
   (o o)     AI GOAT - Greatest Of All Tech
   (  V  )    Your AI Server Command Center
  /--m-m-\
```

## Features

### 🎯 Real-Time Monitoring
- **GPU Metrics**: Power consumption (Watts), temperature, utilization, VRAM usage
- **CPU Metrics**: Usage percentage, core count
- **Memory**: Total, used, and free RAM
- **Services**: LocalAI and Ollama status

### ⚡ Power Management
- **Total System Power**: Real-time power consumption estimate
- **Auto-Suspend Timer**: Countdown until automatic suspension
- **Stay-Awake Status**: See remaining time when stay-awake is active
- **Idle Conditions**: Visual indicators for CPU, GPU, SSH, and API activity

### 🌐 Remote Control
- **Wake-on-LAN**: MAC address and interface information
- **Stay-Awake URLs**: Quick commands to prevent auto-suspend
- **Access URLs**: Direct links to all services (LocalAI, Ollama, Open WebUI)

### 🛠️ System Management
- Install LocalAI and Ollama
- Repair existing installations
- Start/stop services
- View logs
- Quick command reference

## Screenshots

### Dashboard
```
╭─ System Status ────────────────╮  ╭─ Power Status ─────────────────╮
│                                │  │                                │
│ GPU:                           │  │ Total System Power:            │
│   Power: 245.2W / 350W         │  │   245.2W                       │
│   Temp:  62°C                  │  │                                │
│   Usage: 85%                   │  │ Auto-Suspend:                  │
│   VRAM:  8.2GB / 24.0GB        │  │   Auto-Suspend in: 25 minutes  │
│                                │  │   Idle threshold: 30 min       │
│ CPU:                           │  │   Current idle: 5 min          │
│   Usage: 45%                   │  │                                │
│   Cores: 16                    │  │ Conditions:                    │
│                                │  │   CPU Idle: ✗ 55.0% (need ≥90%)│
│ Memory:                        │  │   GPU Idle: ✗ 85.0% (need ≤10%)│
│   Used:  16.2GB / 32.0GB       │  │   No SSH:   ✓                  │
│   Free:  15.8GB                │  │   No API:   ✗                  │
│                                │  │                                │
│ Services:                      │  │                                │
│   LocalAI: ● Running           │  │                                │
│   Ollama:  ● Running           │  │                                │
╰────────────────────────────────╯  ╰────────────────────────────────╯
```

## Installation

### Prerequisites
- Python 3.8 or higher
- pip (Python package manager)
- Ubuntu 24.04 (recommended)
- AI server already installed (install.sh and/or install-ollama.sh)

### Install AI GOAT

```bash
# Navigate to the CLI tool directory
cd ~/ai-server/ai-goat-cli

# Run the installer
bash install-cli.sh
```

The installer will:
1. Install Python dependencies
2. Create a virtual environment
3. Make the tool executable
4. Create a system-wide command link

## Usage

### Starting AI GOAT

```bash
# Run from anywhere (if symlink was created)
ai-goat

# Or run directly
cd ~/ai-server/ai-goat-cli
./ai-goat
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **q** | Quit the application |
| **d** | Toggle dark mode |
| **1** | Show Dashboard (default view) |
| **2** | Show System Management |
| **3** | Show Remote Control |
| **Tab** | Switch between tabs |
| **Arrow keys** | Navigate within tabs |

### Navigation

The interface has three main tabs:

1. **Dashboard (Press 1)**: Real-time system monitoring and power status
2. **System Management (Press 2)**: Installation, repair, and service management
3. **Remote Control (Press 3)**: Wake-on-LAN and remote access information

## Architecture

```
ai-goat-cli/
├── ai-goat              # Bash wrapper script (entry point)
├── ai-goat.py           # Main Python TUI application
├── install-cli.sh       # Installation script
├── requirements.txt     # Python dependencies
├── lib/                 # Python modules
│   ├── monitoring.py    # System monitoring (GPU, CPU, Memory)
│   ├── power.py         # Power management and auto-suspend
│   ├── system.py        # System installation and service control
│   └── remote.py        # Remote control (WOL, URLs)
├── assets/
│   └── goat.txt         # ASCII art
└── config/              # Configuration files
```

## Dependencies

### Python Packages
- **textual** (≥0.47.0) - Modern TUI framework
- **rich** (≥13.7.0) - Beautiful terminal formatting
- **psutil** (≥5.9.6) - System and process utilities
- **pynvml** (≥11.5.0) - NVIDIA GPU monitoring
- **requests** (≥2.31.0) - HTTP library
- **pyyaml** (≥6.0.1) - YAML parser

### System Tools
- `nvidia-smi` - GPU monitoring (if NVIDIA GPU present)
- `systemctl` - Service management
- `docker` - Container management
- `ss` - Socket statistics
- `ethtool` - Network interface tools

## How It Works

### Monitoring
- Queries `nvidia-smi` every 2 seconds for GPU stats
- Uses `psutil` for CPU and memory monitoring
- Checks systemd services and Docker containers for service status

### Power Management
- Reads auto-suspend configuration from systemd environment variables
- Monitors `/run/ai-nodectl/stay_awake_until` for stay-awake status
- Checks SSH sessions and API connections via `ss` command
- Estimates total power consumption from GPU + CPU + base load

### Remote Control
- Reads MAC address from `/sys/class/net/<interface>/address`
- Detects WOL interface from systemd `wol@*.service` units
- Determines server IP by connecting to external address
- Provides formatted commands for Wake-on-LAN

## Troubleshooting

### "Virtual environment not found"
```bash
cd ~/ai-server/ai-goat-cli
bash install-cli.sh
```

### GPU stats showing 0
- Ensure NVIDIA drivers are installed: `nvidia-smi`
- Check if you have CUDA/GPU access: `docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi`

### Services not detected
- Make sure services are running: `systemctl status localai.service ollama.service`
- Check Docker containers: `docker ps`

### Permission denied
- Some operations require sudo access
- Run with appropriate permissions or add user to docker group: `sudo usermod -aG docker $USER`

## Tips

### Keep the Dashboard Open
Run AI GOAT in a `tmux` or `screen` session to keep it running in the background:

```bash
# Using tmux
tmux new -s ai-goat
ai-goat
# Press Ctrl+B, then D to detach
# Reattach with: tmux attach -t ai-goat

# Using screen
screen -S ai-goat
ai-goat
# Press Ctrl+A, then D to detach
# Reattach with: screen -r ai-goat
```

### Monitor from SSH
AI GOAT works perfectly over SSH - just connect and run it!

```bash
ssh user@your-server
ai-goat
```

### Quick Power Check
Want a quick glance at power consumption?

```bash
watch -n 2 nvidia-smi  # Traditional way

ai-goat                # AI GOAT way (with context!)
```

## Comparison with Other Tools

| Tool | AI GOAT | htop | nvidia-smi | systemctl |
|------|---------|------|------------|-----------|
| GPU Power (Watts) | ✅ | ❌ | ✅ | ❌ |
| Auto-Suspend Timer | ✅ | ❌ | ❌ | ❌ |
| Service Status | ✅ | ❌ | ❌ | ✅ |
| Remote Control Info | ✅ | ❌ | ❌ | ❌ |
| All-in-One | ✅ | ❌ | ❌ | ❌ |
| Pretty UI | ✅ | ✅ | ❌ | ❌ |

## Roadmap

### Planned Features
- [ ] Interactive service management (buttons to start/stop services)
- [ ] Live log viewer with filtering
- [ ] Model management (pull/list/delete Ollama models)
- [ ] Graph view for GPU/CPU usage over time
- [ ] Configuration editor for auto-suspend settings
- [ ] Notification system for important events
- [ ] Export metrics to files
- [ ] Web dashboard mode (optional HTTP server)

### Future Enhancements
- [ ] Support for multiple GPUs
- [ ] AMD GPU support (via rocm-smi)
- [ ] Container resource limits editing
- [ ] Backup and restore functionality
- [ ] Plugin system for custom monitors

## Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## License

MIT License - See main project LICENSE file

## Credits

- Built with [Textual](https://textual.textualize.io/) by Textualize
- ASCII art inspired by goat emojis 🐐
- Part of the [AI Server](https://github.com/Polygonschmiede/ai-server) project

---

**Made with ❤️ and 🐐 for AI enthusiasts**

Run `ai-goat` and embrace the GOAT! 🚀
