# AI Server Usage Guide

Comprehensive guide for daily usage of your AI server with Ollama and LocalAI.

## Table of Contents

- [Web Interfaces](#web-interfaces)
- [Model Management](#model-management)
- [System Monitoring](#system-monitoring)
- [Power Management](#power-management)
- [Service Management](#service-management)

---

## Web Interfaces

### Ollama Open WebUI (Recommended)

Ollama comes with a beautiful web interface called **Open WebUI** - this is your main UI for interacting with AI models.

**Access:** `http://<your-server-ip>:3000`

#### Features:
- 📊 **Model Selection**: Switch between installed models with a dropdown
- 💬 **Chat Interface**: ChatGPT-like conversation interface
- 📁 **Document Upload**: Upload PDFs, text files for RAG
- 🎨 **Image Generation**: If you install image models
- 👥 **Multi-User**: Create accounts for different users
- 📝 **Chat History**: All your conversations are saved
- ⚙️ **Model Parameters**: Adjust temperature, top_p, etc.

#### First Time Setup:
1. Navigate to `http://<your-server-ip>:3000`
2. Create an admin account (first user is automatically admin)
3. Download models from the settings or use the command line (see below)

### LocalAI Web Interface

LocalAI also has a web interface, but it's more technical.

**Access:** `http://<your-server-ip>:8080`

---

## Model Management

### Download Models

#### Using Open WebUI (Easiest):
1. Open `http://<your-server-ip>:3000`
2. Click on your profile → **Settings**
3. Go to **Models** tab
4. Click **Pull a model from Ollama.com**
5. Enter model name (e.g., `llama3.2`, `mistral`, `codellama`)
6. Click **Pull Model**

#### Using Command Line:

```bash
# Pull a model
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull mistral
docker exec ollama ollama pull codellama

# Or use the manager script
./ai-server-manager.sh pull llama3.2
./ai-server-manager.sh pull mistral
```

#### Popular Models:

| Model | Size | Description | Command |
|-------|------|-------------|---------|
| **llama3.2** | 2GB | Fast, good for chat | `docker exec ollama ollama pull llama3.2` |
| **mistral** | 4GB | Excellent quality | `docker exec ollama ollama pull mistral` |
| **codellama** | 4GB | Code generation | `docker exec ollama ollama pull codellama` |
| **phi3** | 2GB | Fast Microsoft model | `docker exec ollama ollama pull phi3` |
| **llama3.1:70b** | 40GB | Most powerful (needs lots of RAM/VRAM) | `docker exec ollama ollama pull llama3.1:70b` |

### List Installed Models

```bash
# List all downloaded models
./ai-server-manager.sh models

# Or directly:
docker exec ollama ollama list
```

### Switch Between Models

In **Open WebUI**:
1. Click on the **model dropdown** at the top of the chat
2. Select the model you want to use
3. Start chatting!

### Delete Models

```bash
# Remove a model to free space
docker exec ollama ollama rm llama3.2
```

### Model Storage Location

Models are stored in `/opt/ollama/models` (or your custom path if you used `--models-path`).

You can check disk usage:
```bash
du -sh /opt/ollama/models
```

---

## System Monitoring

### GPU Status and Usage

#### Real-time GPU monitoring:
```bash
# Watch GPU usage (updates every 2 seconds)
watch -n 2 nvidia-smi

# Or just check once
nvidia-smi
```

**What to look for:**
- **GPU-Util**: GPU utilization percentage (0-100%)
- **Memory-Usage**: VRAM usage (e.g., 8000MB / 24000MB)
- **Temperature**: GPU temperature
- **Power**: Current power draw
- **Processes**: Which containers are using the GPU

#### Detailed GPU monitoring:
```bash
# GPU utilization in detail
nvidia-smi dmon -s puct

# GPU processes
nvidia-smi pmon
```

### CPU Status and Usage

```bash
# Interactive CPU monitoring
htop

# Or simpler
top

# CPU usage summary
mpstat 1 5

# Load average
uptime
```

### Memory Usage

```bash
# Memory usage
free -h

# Detailed memory info
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable'
```

### Docker Container Stats

```bash
# Watch all container resource usage
docker stats

# Only Ollama
docker stats ollama

# Only LocalAI
docker stats localai
```

**Output shows:**
- CPU%: CPU usage per container
- MEM USAGE / LIMIT: Memory usage
- NET I/O: Network traffic
- BLOCK I/O: Disk read/write

### Disk Usage

```bash
# Overall disk usage
df -h

# Model directory size
du -sh /opt/ollama/models
du -sh /opt/localai/models

# Docker image sizes
docker images
```

### Service Status Dashboard

```bash
# Check all AI services
./ai-server-manager.sh status

# Or individual services
sudo systemctl status localai.service
sudo systemctl status ollama.service
sudo systemctl status ai-auto-suspend.service
sudo systemctl status stay-awake.service
```

---

## Power Management

### Auto-Suspend Feature

Your server automatically suspends after **10 minutes** of inactivity by default.

#### Check Auto-Suspend Status:

```bash
# Check if auto-suspend is running
sudo systemctl status ai-auto-suspend.service

# View live logs
sudo journalctl -u ai-auto-suspend.service -f

# See current idle time
cat /var/log/syslog | grep "ai-auto-suspend" | tail -20
```

#### Auto-Suspend Conditions:

The server will **suspend** when ALL of these are true:
- ✅ CPU idle > 90% (configurable)
- ✅ GPU utilization < 10% (configurable)
- ✅ Idle for 10+ minutes (configurable)
- ✅ No stay-awake flag active
- ✅ No SSH sessions active (optional, disabled by default)

**Note:** API connections (ports 8080, 11434, 3000) are **ignored** - they do not prevent suspend. Only CPU/GPU activity matters.

The server will **stay awake** when ANY of these are true:
- 🔴 GPU is busy (> 10% utilization)
- 🔴 CPU is busy (< 90% idle)
- 🔴 Stay-awake service activated (see below)
- 🔴 Active SSH session (only if CHECK_SSH=true)

#### Configure Auto-Suspend:

Edit the configuration:
```bash
sudo systemctl edit ai-auto-suspend.service --full
```

Key environment variables:
- `WAIT_MINUTES=10` - Minutes of idle time before suspend
- `CPU_IDLE_THRESHOLD=90` - CPU idle percentage required
- `GPU_USAGE_MAX=10` - Max GPU utilization for idle
- `CHECK_INTERVAL=60` - Check interval in seconds
- `CHECK_SSH=false` - If true, SSH connections prevent suspend (default: false)

After editing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ai-auto-suspend.service
```

#### Enable SSH Check:

By default, SSH connections do NOT prevent suspend. To make SSH connections keep the server awake:

```bash
sudo systemctl edit ai-auto-suspend.service --full
```

Change `CHECK_SSH=false` to `CHECK_SSH=true`, then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ai-auto-suspend.service
```

#### Disable Auto-Suspend:

```bash
# Stop and disable auto-suspend
sudo systemctl stop ai-auto-suspend.service
sudo systemctl disable ai-auto-suspend.service
```

### Stay-Awake Service

Prevent your server from auto-suspending for a specific time period.

**Endpoint:** `http://<your-server-ip>:9876/stay?s=<seconds>`

#### Examples:

```bash
# Keep server awake for 1 hour (3600 seconds)
curl "http://192.168.178.50:9876/stay?s=3600"

# Keep awake for 2 hours
curl "http://192.168.178.50:9876/stay?s=7200"

# Keep awake for 30 minutes
curl "http://192.168.178.50:9876/stay?s=1800"

# Keep awake for 8 hours (for long training jobs)
curl "http://192.168.178.50:9876/stay?s=28800"
```

#### Use Cases:
- 🏃 Before starting a long AI inference job
- 📥 While downloading large models
- 🔧 During maintenance or debugging
- 🎮 When you know you'll be using the server soon

#### Check Stay-Awake Status:

```bash
# Check if stay-awake is active
if [ -f /run/ai-nodectl/stay_awake_until ]; then
  until=$(cat /run/ai-nodectl/stay_awake_until)
  now=$(date +%s)
  remaining=$((until - now))
  if [ $remaining -gt 0 ]; then
    echo "Server will stay awake for $remaining more seconds"
    echo "Until: $(date -d @$until)"
  else
    echo "Stay-awake has expired"
  fi
else
  echo "Stay-awake is not active"
fi
```

### Wake-on-LAN (WOL)

Wake up your suspended server remotely.

#### Check if WOL is Enabled:

```bash
# Find your network interface
ip addr show

# Check WOL status (look for 'g' in 'Supports Wake-on')
sudo ethtool <interface> | grep -i wake

# Example:
sudo ethtool enp0s31f6 | grep -i wake
```

**Output should show:**
```
Supports Wake-on: pumbg
Wake-on: g
```

The **'g'** means Magic Packet wake is enabled.

#### Get Your Server's MAC Address:

```bash
# Get MAC address of your network interface
ip link show <interface> | grep link/ether

# Example:
ip link show enp0s31f6 | grep link/ether
```

Output: `link/ether aa:bb:cc:dd:ee:ff`

#### Send Wake-on-LAN from Another Computer:

**Linux/Mac:**
```bash
# Install wakeonlan
sudo apt install wakeonlan  # Ubuntu/Debian
brew install wakeonlan      # macOS

# Wake up the server
wakeonlan aa:bb:cc:dd:ee:ff
```

**Windows:**
```powershell
# Use a WOL tool like "WakeMeOnLan" or "Wake On LAN GUI"
# Or use PowerShell:
$mac = "AA-BB-CC-DD-EE-FF"
$broadcast = "192.168.178.255"
$MacByteArray = $mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
$MagicPacket = (,0xFF * 6) + ($MacByteArray  * 16)
$UdpClient = New-Object System.Net.Sockets.UdpClient
$UdpClient.Connect($broadcast,7)
$UdpClient.Send($MagicPacket,$MagicPacket.Length)
$UdpClient.Close()
```

**Android/iOS:**
- Download "Wake On Lan" app
- Add your server with MAC address
- Tap to wake

#### Test Wake-on-LAN:

```bash
# 1. On your server, activate stay-awake to prevent immediate suspend
curl "http://192.168.178.50:9876/stay?s=60"

# 2. Manually suspend
sudo systemctl suspend

# 3. From another computer, send WOL packet
wakeonlan aa:bb:cc:dd:ee:ff

# 4. Wait 10-30 seconds for server to wake up
```

---

## Service Management

### Using the AI Server Manager Script

The `ai-server-manager.sh` script is your main tool for managing services.

```bash
# Show status of all services
./ai-server-manager.sh status

# Start only Ollama (stops LocalAI)
./ai-server-manager.sh ollama

# Start only LocalAI (stops Ollama)
./ai-server-manager.sh localai

# Start both services (parallel mode)
./ai-server-manager.sh both

# Stop all AI services
./ai-server-manager.sh stop

# List Ollama models
./ai-server-manager.sh models

# Pull a new model
./ai-server-manager.sh pull llama3.2
```

### Running Both Services (Parallel Mode)

```bash
./ai-server-manager.sh both
```

**When to use parallel mode:**
- Testing different models
- Comparing LocalAI vs Ollama
- Need multiple API endpoints
- Different tools using different servers

**Note:** Both services share GPU memory. If you have OOM (Out of Memory) errors, run one at a time.

### Service Logs

#### View Live Logs:

```bash
# Ollama logs
docker logs -f ollama

# LocalAI logs
docker logs -f localai

# Auto-suspend logs
sudo journalctl -u ai-auto-suspend.service -f

# Stay-awake logs
sudo journalctl -u stay-awake.service -f
```

#### View Recent Logs:

```bash
# Last 100 lines
docker logs --tail 100 ollama
docker logs --tail 100 localai

# Last 50 lines of auto-suspend
sudo journalctl -u ai-auto-suspend.service -n 50
```

### Restart Services

```bash
# Restart Ollama
sudo systemctl restart ollama.service

# Restart LocalAI
sudo systemctl restart localai.service

# Or use the manager
./ai-server-manager.sh stop
./ai-server-manager.sh ollama
```

---

## Quick Reference Commands

### Daily Use

```bash
# Start Ollama
./ai-server-manager.sh ollama

# Open WebUI in browser
xdg-open http://192.168.178.50:3000

# Download a model
./ai-server-manager.sh pull llama3.2

# Check GPU usage
watch -n 2 nvidia-smi

# Keep server awake for 2 hours
curl "http://192.168.178.50:9876/stay?s=7200"
```

### Troubleshooting

```bash
# Check what's running
./ai-server-manager.sh status
docker ps

# View errors
docker logs ollama
sudo systemctl status ollama.service

# Restart everything
./ai-server-manager.sh stop
./ai-server-manager.sh both

# Check disk space
df -h
du -sh /opt/ollama/models

# Check memory
free -h
docker stats
```

### Performance Monitoring

```bash
# GPU monitoring
nvidia-smi

# Container stats
docker stats

# System resources
htop

# Network connections
sudo netstat -tulpn | grep -E '(8080|11434|3000)'

# Service status
./ai-server-manager.sh status
```

---

## Tips and Best Practices

### Model Selection

- **Small models (2-3GB)**: Fast, good for most tasks
  - `llama3.2`, `phi3`, `gemma2:2b`
- **Medium models (7-13GB)**: Better quality
  - `mistral`, `codellama`, `llama3.1:8b`
- **Large models (30GB+)**: Best quality, needs lots of VRAM
  - `llama3.1:70b`, `mixtral:8x7b`

### GPU Memory Management

Check VRAM usage before loading big models:
```bash
nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv
```

If you run out of VRAM:
- Use smaller models
- Run one service at a time (`./ai-server-manager.sh ollama`)
- Close other GPU applications

### Network Access

To access from other devices on your network:
1. Find your server's IP: `ip addr show`
2. Ensure firewall allows connections (already configured by install script)
3. Access from any device: `http://<server-ip>:3000`

### Backup Models

Your models are stored in `/opt/ollama/models`. To backup:
```bash
# Create backup
sudo tar -czf ollama-models-backup.tar.gz /opt/ollama/models

# Restore backup
sudo tar -xzf ollama-models-backup.tar.gz -C /
```

---

## Support

For issues or questions:
1. Check the logs: `docker logs ollama`
2. Run the verification script: `./verify-setup.sh`
3. See the [main README](README.md) for troubleshooting
4. Open an issue on GitHub

---

**Happy AI chatting! 🤖**
