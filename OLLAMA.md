# Ollama Server Installation & Management

This guide explains how to install and use Ollama as an alternative to LocalAI. Both servers can be installed on the same system, and you can easily switch between them.

## What is Ollama?

Ollama is a lightweight, easy-to-use AI model server that makes it simple to run large language models locally. It includes:
- Simple API for running LLMs
- Easy model management (pull, run, remove)
- OpenAI-compatible API for n8n integration
- Open WebUI for a beautiful chat interface

## Features

- **Docker-based deployment**: Ollama runs in a container for easy management
- **Open WebUI**: Beautiful web interface for chatting and managing models
- **GPU Support**: Automatic NVIDIA GPU detection and support
- **n8n Integration**: OpenAI-compatible API endpoint
- **Easy Switching**: Simple command to switch between LocalAI and Ollama
- **Model Management**: Pull and manage models through CLI or web interface

## Installation

### Prerequisites

You must have Docker installed. If you haven't already, run the LocalAI installer first:

```bash
sudo bash install.sh
```

### Install Ollama

```bash
# GPU mode (default)
sudo bash install-ollama.sh

# CPU-only mode
sudo bash install-ollama.sh --cpu-only

# Non-interactive installation
sudo bash install-ollama.sh --non-interactive

# Repair existing installation
sudo bash install-ollama.sh --repair

# Custom ports and paths
sudo bash install-ollama.sh \
  --ollama-port 11434 \
  --webui-port 3000 \
  --models-path /data/ollama-models
```

**Note**: The installer will automatically detect existing installations and offer to:
- Perform a clean reinstallation
- Reconfigure the existing installation
- Repair mode with `--repair` flag

## Configuration Options

| Flag | Description | Default |
|------|-------------|---------|
| `--cpu-only` | Run without GPU support | GPU mode |
| `--non-interactive` | Skip all prompts | Interactive |
| `--repair` | Repair existing installation | Normal install |
| `--models-path PATH` | Host directory for models | `/opt/ollama/models` |
| `--ollama-port PORT` | Ollama API port | `11434` |
| `--webui-port PORT` | Open WebUI port | `3000` |
| `--skip-firewall` | Skip UFW configuration | Enabled |

## Using the Management Script

The `ai-server-manager.sh` script makes it easy to manage both LocalAI and Ollama:

### Check Status

```bash
./ai-server-manager.sh status
```

Output:
```
================================
   AI Server Manager
================================

Current Status:

  LocalAI:  RUNNING
    API:    http://localhost:8080
    WebUI:  http://localhost:8080

  Ollama:   STOPPED
```

### Switch to Ollama (Exclusive Mode)

```bash
./ai-server-manager.sh ollama
```

This will:
1. Stop LocalAI if it's running
2. Start Ollama and Open WebUI
3. Display connection info

### Switch to LocalAI (Exclusive Mode)

```bash
./ai-server-manager.sh localai
```

### Run Both Services in Parallel

```bash
./ai-server-manager.sh both
```

This starts both LocalAI and Ollama simultaneously. Both services will share GPU memory.

**Note**: If you experience GPU memory issues, use exclusive mode (run only one service at a time).

### Stop All Services

```bash
./ai-server-manager.sh stop
```

### Verify Installation

Check that everything is working correctly:

```bash
./verify-setup.sh
```

This comprehensive check will verify:
- Docker installation
- NVIDIA GPU and drivers (if applicable)
- Ollama service and container status
- Open WebUI status
- API endpoints responding
- Installed models

## Model Management

### Pull Models Using the Manager Script

```bash
# Pull Llama 3.2 (recommended for general use)
./ai-server-manager.sh pull llama3.2

# Pull Mistral (good balance of speed and quality)
./ai-server-manager.sh pull mistral

# Pull other models
./ai-server-manager.sh pull codellama
./ai-server-manager.sh pull phi3
```

### List Installed Models

```bash
./ai-server-manager.sh models
```

### Pull Models Directly with Docker

```bash
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull mistral
docker exec ollama ollama pull codellama
docker exec ollama ollama pull gemma2
```

### List Models Directly

```bash
docker exec ollama ollama list
```

### Remove Models

```bash
docker exec ollama ollama rm llama3.2
```

## Popular Models

| Model | Size | Description | Best For |
|-------|------|-------------|----------|
| `llama3.2` | 2-3GB | Latest Llama model | General purpose, fast |
| `llama3.2:1b` | 1.3GB | Smallest Llama | Low-resource systems |
| `mistral` | 4.1GB | Efficient and capable | Balanced performance |
| `codellama` | 3.8GB | Code specialist | Programming tasks |
| `phi3` | 2.3GB | Microsoft's small model | Quick responses |
| `gemma2` | 5.4GB | Google's latest | High quality |

See all models at: https://ollama.com/library

## Accessing Services

### Ollama API

**Endpoint**: `http://localhost:11434`

Test the API:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

### Open WebUI

**URL**: `http://localhost:3000`

Open WebUI provides:
- Beautiful chat interface
- Model management UI
- Conversation history
- Settings and customization
- No authentication required (in this setup)

## n8n Integration

Both LocalAI and Ollama expose OpenAI-compatible APIs that work with n8n.

### Configure n8n for Ollama

1. In n8n, add an "OpenAI" node
2. Create new credentials:
   - **API Key**: `ollama` (any value works)
   - **Base URL**: `http://ollama:11434/v1` (if n8n is in Docker)
   - **Base URL**: `http://localhost:11434/v1` (if n8n is on host)
3. Select your model in the node (e.g., `llama3.2`)

### Configure n8n for LocalAI

1. In n8n, add an "OpenAI" node
2. Create new credentials:
   - **API Key**: `sk-dummy` (any value works)
   - **Base URL**: `http://localai:8080/v1` (if n8n is in Docker)
   - **Base URL**: `http://localhost:8080/v1` (if n8n is on host)
3. Select your model in the node

### Example n8n Docker Network

If you want to run n8n alongside your AI servers, add this to your docker-compose.yml:

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - WEBHOOK_URL=http://localhost:5678/
    volumes:
      - /opt/n8n:/home/node/.n8n
```

Then use service names in your n8n OpenAI credentials:
- Ollama: `http://ollama:11434/v1`
- LocalAI: `http://localai:8080/v1`

## Comparing LocalAI vs Ollama

| Feature | LocalAI | Ollama |
|---------|---------|--------|
| **Ease of Use** | Moderate | Very Easy |
| **Model Management** | Manual | Built-in CLI |
| **Web UI** | Basic | Beautiful (Open WebUI) |
| **Model Support** | Wide variety | Curated library |
| **GPU Support** | CUDA 12 | CUDA (latest) |
| **API Compatibility** | OpenAI | OpenAI |
| **Memory Usage** | Higher | Lower |
| **Model Format** | GGUF, GGML, etc. | Ollama format |
| **Best For** | Advanced users, custom models | Simplicity, quick start |

## Troubleshooting

### Check Service Status

```bash
# Check if Ollama service is running
sudo systemctl status ollama.service

# Check Docker containers
docker ps
```

### View Logs

```bash
# Ollama logs
docker logs ollama

# Open WebUI logs
docker logs open-webui

# Follow logs in real-time
docker logs -f ollama
```

### Restart Services

```bash
# Restart Ollama service
sudo systemctl restart ollama.service

# Restart just the containers
cd /opt/ollama
docker compose restart
```

### Service Won't Start

1. Check if ports are already in use:
```bash
sudo lsof -i :11434
sudo lsof -i :3000
```

2. Check Docker status:
```bash
sudo systemctl status docker
```

3. Validate docker-compose.yml:
```bash
cd /opt/ollama
docker compose config
```

### GPU Not Detected

```bash
# Check NVIDIA drivers
nvidia-smi

# Check NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

If GPU isn't working, reinstall NVIDIA Container Toolkit:
```bash
# See install.sh for full installation steps
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Uninstalling

### Remove Ollama (Keep Models)

```bash
# Stop and disable service
sudo systemctl stop ollama.service
sudo systemctl disable ollama.service

# Remove service file
sudo rm /etc/systemd/system/ollama.service
sudo systemctl daemon-reload

# Remove docker-compose.yml
sudo rm /opt/ollama/docker-compose.yml

# Optional: Remove containers
docker stop ollama open-webui
docker rm ollama open-webui
```

### Complete Removal (Including Models)

```bash
# Stop and remove everything
sudo systemctl stop ollama.service
sudo systemctl disable ollama.service
sudo rm /etc/systemd/system/ollama.service
sudo systemctl daemon-reload

# Remove all data
sudo rm -rf /opt/ollama

# Remove Docker images
docker rmi ollama/ollama:latest
docker rmi ghcr.io/open-webui/open-webui:main
```

## Advanced Usage

### Custom Model Configuration

You can import custom models by placing GGUF files in the models directory and using `ollama create`:

```bash
# Create a custom model
docker exec -it ollama ollama create mymodel -f /path/to/Modelfile
```

### Resource Limits

Edit `/opt/ollama/docker-compose.yml` to add resource limits:

```yaml
services:
  ollama:
    # ... existing config ...
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '4'
```

Then restart:
```bash
cd /opt/ollama
docker compose up -d
```

### Multiple Models Running

By default, Ollama keeps models in memory after first use. To unload a model:

```bash
docker exec ollama ollama ps      # List running models
docker exec ollama ollama stop <model-name>  # Stop a specific model
```

## Support

- **Ollama Documentation**: https://github.com/ollama/ollama
- **Open WebUI**: https://github.com/open-webui/open-webui
- **Model Library**: https://ollama.com/library
- **Issues**: Report problems in this repository's issue tracker

## Quick Reference Card

```bash
# Management
./ai-server-manager.sh status      # Check what's running
./ai-server-manager.sh ollama      # Switch to Ollama (exclusive)
./ai-server-manager.sh localai     # Switch to LocalAI (exclusive)
./ai-server-manager.sh both        # Run both in parallel
./ai-server-manager.sh stop        # Stop all AI servers

# Models
./ai-server-manager.sh models      # List Ollama models
./ai-server-manager.sh pull llama3.2  # Download a model

# Services
sudo systemctl status ollama.service   # Check service
sudo systemctl restart ollama.service  # Restart service

# Docker
docker logs ollama                 # View logs
docker logs open-webui            # View UI logs
docker exec ollama ollama list    # List models
docker exec ollama ollama ps      # Show running models

# Access
# Ollama API:  http://localhost:11434
# Open WebUI:  http://localhost:3000
```
