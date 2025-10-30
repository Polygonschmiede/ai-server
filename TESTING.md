# Quick Testing Guide

**For rapid install → test → uninstall cycles**

---

## 🚀 Quick Start (One Command)

### Fresh Install
```bash
# Clone and install in one go
git clone https://github.com/Polygonschmiede/ai-server.git && \
cd ai-server && \
sudo bash install.sh --non-interactive --cpu-only
```

### Uninstall
```bash
# From project directory
sudo bash install.sh --uninstall
```

---

## 📋 Complete Test Cycle

### 1. Clone Repository
```bash
cd ~
git clone https://github.com/Polygonschmiede/ai-server.git
cd ai-server
```

### 2. Install (CPU-only, non-interactive)
```bash
sudo bash install.sh --non-interactive --cpu-only
```

**What this does:**
- ✅ Installs Docker (if needed)
- ✅ Creates LocalAI service
- ✅ Creates Auto-Suspend service (5 min idle)
- ✅ Creates Stay-Awake service
- ✅ Configures firewall
- ✅ Starts all services

**Duration:** ~5-10 minutes (first time, includes Docker install)

### 3. Verify Installation
```bash
./verify-setup.sh
```

**Expected output:**
```
=========================================
  AI Server Setup Verification
=========================================

Docker Installation
---
  ✓ Docker is installed
  ✓ Docker is running
  ✓ User is in docker group

LocalAI Installation
---
  ✓ LocalAI directory exists
  ✓ LocalAI docker-compose.yml exists
  ✓ LocalAI service is installed
  ✓ LocalAI service is running
  ✓ LocalAI container is running
  ✓ LocalAI API is responding

Auto-Suspend Installation
---
  ✓ Auto-suspend service is installed
  ✓ Auto-suspend service is running

Stay-Awake Installation
---
  ✓ Stay-awake HTTP service is installed
  ✓ Stay-awake HTTP service is running
  ✓ Stay-awake HTTP endpoint is responding
```

### 4. Test Services

#### Check Service Status
```bash
./ai-server-manager.sh status
```

#### Check Auto-Suspend Logs
```bash
sudo journalctl -u ai-auto-suspend.service -f
```

**Expected logs:**
```
Starting auto-suspend monitor
Configuration:
  Wait time: 5 minutes
  CPU idle threshold: >=90%
  GPU usage threshold: <=10%
  Check interval: 60 seconds
  Check SSH connections: False

Check: CPU idle=100.0%, GPU usage=0.0%, stay_awake=False
System became idle at ...
System idle for 0.0 minutes (threshold: 5 minutes)
```

#### Test Stay-Awake Endpoint
```bash
# Health check
curl http://localhost:9876/health
# Expected: OK

# Status check
curl http://localhost:9876/status
# Expected: Stay-awake: inactive

# Activate stay-awake for 1 hour
curl "http://localhost:9876/stay?s=3600"
# Expected: Stay-awake activated for 3600 seconds (1h 0m)
```

#### Test LocalAI API
```bash
curl http://localhost:8080/readyz
# Expected: {"status":"ok"}
```

### 5. Test AI GOAT CLI
```bash
cd ai-goat-cli
./ai-goat
```

**Press `q` to quit**

### 6. Uninstall
```bash
# From project directory
cd ~/ai-server
sudo bash install.sh --uninstall
```

**What this does:**
- ✅ Stops all services
- ✅ Disables all services
- ✅ Removes service files
- ✅ Removes Python scripts
- ✅ Removes Docker containers
- ✅ Removes installation state
- ✅ **Preserves model data** (optional removal)

**Expected output:**
```
==================== Uninstalling LocalAI ====================
[INFO] Found components: localai service docker container auto-suspend service stay-awake service
[INFO] Stopping and disabling LocalAI service...
[SUCCESS] Service stopped and disabled
[INFO] Stopping support services...
[SUCCESS] LocalAI uninstalled successfully
[INFO] Model data preserved (if any) at: /opt/localai/models
[INFO] To remove models: sudo rm -rf /opt/localai/models
```

### 7. Verify Clean Uninstall
```bash
./verify-setup.sh
```

**Expected output:**
```
Docker Installation
---
  ✓ Docker is installed
  ✓ Docker is running
  ✓ User is in docker group

LocalAI Installation
---
  ✗ LocalAI directory does not exist
  ...
```

### 8. Remove Repository (optional)
```bash
cd ~
rm -rf ai-server
```

---

## 🔁 Repeat Test Cycle

```bash
# Uninstall
cd ~/ai-server
sudo bash install.sh --uninstall

# Re-install
sudo bash install.sh --non-interactive --cpu-only

# Verify
./verify-setup.sh
```

---

## 🎯 Common Test Scenarios

### Test #1: GPU Mode Installation
```bash
sudo bash install.sh --uninstall
sudo bash install.sh --non-interactive  # GPU mode (default)
./verify-setup.sh
```

### Test #2: Different Wait Time
```bash
sudo bash install.sh --uninstall
sudo bash install.sh --non-interactive --cpu-only --wait-minutes 10
sudo journalctl -u ai-auto-suspend.service | grep "Wait time"
# Expected: Wait time: 10 minutes
```

### Test #3: Repair Mode
```bash
# Change configuration without full reinstall
sudo bash install.sh --repair --wait-minutes 15

# Verify change
sudo systemctl cat ai-auto-suspend.service | grep WAIT_MINUTES
# Expected: Environment="WAIT_MINUTES=15"
```

### Test #4: Disable Auto-Suspend
```bash
sudo bash install.sh --uninstall
sudo bash install.sh --non-interactive --cpu-only --skip-auto-suspend
systemctl is-active ai-auto-suspend.service
# Expected: inactive
```

### Test #5: Test Both LocalAI and Ollama
```bash
# Install LocalAI first
sudo bash install.sh --non-interactive --cpu-only

# Install Ollama
sudo bash install-ollama.sh --non-interactive

# Check both running
./ai-server-manager.sh status

# Uninstall both
sudo bash install.sh --uninstall
sudo bash install-ollama.sh --uninstall  # TODO: Add this
```

---

## ⚡ Quick Commands Reference

| Command | Description |
|---------|-------------|
| `sudo bash install.sh --uninstall` | Uninstall everything |
| `sudo bash install.sh --non-interactive --cpu-only` | Fresh install (CPU mode) |
| `sudo bash install.sh --repair` | Reconfigure without reinstall |
| `./verify-setup.sh` | Verify installation |
| `./ai-server-manager.sh status` | Check service status |
| `sudo journalctl -u ai-auto-suspend.service -f` | Watch auto-suspend logs |
| `curl http://localhost:9876/health` | Test stay-awake endpoint |
| `curl http://localhost:8080/readyz` | Test LocalAI API |

---

## 🐛 Troubleshooting

### Install fails

**Check logs:**
```bash
sudo bash install.sh --non-interactive --cpu-only 2>&1 | tee install.log
cat install.log
```

### Services won't start

**Check status:**
```bash
sudo systemctl status ai-auto-suspend.service
sudo systemctl status stay-awake.service
sudo systemctl status localai.service
```

**Check logs:**
```bash
sudo journalctl -u ai-auto-suspend.service -n 50
sudo journalctl -u stay-awake.service -n 50
sudo journalctl -u localai.service -n 50
```

### Uninstall incomplete

**Manual cleanup:**
```bash
# Stop services
sudo systemctl stop localai.service ai-auto-suspend.service stay-awake.service
sudo systemctl disable localai.service ai-auto-suspend.service stay-awake.service

# Remove containers
docker compose -f /opt/localai/docker-compose.yml down 2>/dev/null || true

# Remove service files
sudo rm -f /etc/systemd/system/localai.service
sudo rm -f /etc/systemd/system/ai-auto-suspend.service
sudo rm -f /etc/systemd/system/stay-awake.service
sudo rm -f /etc/systemd/system/wol@*.service

# Remove Python scripts
sudo rm -rf /opt/ai-server

# Remove state
sudo rm -rf /etc/localai-installer
sudo rm -rf /var/lib/ai-auto-suspend

# Reload systemd
sudo systemctl daemon-reload
```

### Docker conflicts

**Check existing containers:**
```bash
docker ps -a | grep -E "localai|ollama"

# Remove conflicting containers
docker stop localai ollama 2>/dev/null || true
docker rm localai ollama 2>/dev/null || true
```

---

## 📊 Performance Testing

### Test Auto-Suspend Timing
```bash
# Install with 2-minute wait time for faster testing
sudo bash install.sh --non-interactive --cpu-only --wait-minutes 2

# Watch logs and verify it suspends after 2 minutes
sudo journalctl -u ai-auto-suspend.service -f

# You should see:
# System idle for 0.0 minutes (threshold: 2 minutes)
# System idle for 1.0 minutes (threshold: 2 minutes)
# System idle for 2.0 minutes (threshold: 2 minutes)
# Idle threshold reached - suspending system
```

### Test Stay-Awake Override
```bash
# Activate stay-awake for 5 minutes
curl "http://localhost:9876/stay?s=300"

# Monitor auto-suspend logs - should show:
# stay_awake=True
# (System won't suspend while stay-awake is active)

# After 5 minutes, stay-awake expires and suspend resumes
```

---

## 📝 Notes

- **First install takes longer** (~10 min) due to Docker installation and image pulls
- **Subsequent installs are faster** (~2-3 min) with Docker already installed
- **Uninstall preserves model data** by default (save bandwidth on reinstall)
- **Model data location:** `/opt/localai/models` (change with `--models-path`)
- **CPU-only mode recommended for testing** (no GPU required)
- **Auto-suspend wait time:** Default 5 minutes (change with `--wait-minutes`)

---

## ✅ Verification Checklist

After installation, verify:

```bash
# 1. Services running
systemctl is-active localai.service          # → active
systemctl is-active ai-auto-suspend.service  # → active
systemctl is-active stay-awake.service       # → active

# 2. Python scripts installed
ls -la /opt/ai-server/
# → auto-suspend-monitor.py, stay-awake-server.py

# 3. Docker container running
docker ps | grep localai
# → localai container

# 4. API responding
curl -s http://localhost:8080/readyz | jq
# → {"status":"ok"}

# 5. Stay-awake responding
curl -s http://localhost:9876/health
# → OK

# 6. Auto-suspend logging
sudo journalctl -u ai-auto-suspend.service --since "1 min ago" | tail -5
# → Recent "Check:" entries
```

**If all 6 pass:** ✅ Installation successful!

---

**Last Updated:** 2025-10-30
**Tested On:** Ubuntu 24.04
