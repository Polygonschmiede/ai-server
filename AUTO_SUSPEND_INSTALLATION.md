# Auto-Suspend Installation & Troubleshooting Guide

**Date:** 2025-10-30
**Status:** Ready for Installation

---

## 🚨 Problem

You reported that the AI GOAT CLI shows:
- "Current idle: 0 min" (never increases)
- "No SSH: ✗" (showing SSH as blocking, even though it should be ignored)

**Root Cause:** The auto-suspend services were **never installed**. The code fixes are complete, but need to be applied by running the installer.

---

## ✅ Solution: Install the Services

### Step 1: Run the Installer with Repair Mode

```bash
sudo bash install.sh --repair
```

**What this does:**
1. ✅ Creates `/opt/ai-server/` directory
2. ✅ Copies `auto-suspend-monitor.py` to `/opt/ai-server/`
3. ✅ Copies `stay-awake-server.py` to `/opt/ai-server/`
4. ✅ Generates `/etc/systemd/system/ai-auto-suspend.service`
5. ✅ Generates `/etc/systemd/system/stay-awake.service`
6. ✅ Runs `systemctl daemon-reload`
7. ✅ Runs `systemctl enable --now ai-auto-suspend.service stay-awake.service`

**Expected Output:**
```
==================== Support-Services konfigurieren ====================
[INFO] Configuring Auto-Suspend service...
[INFO] Installing auto-suspend monitor Python script...
[INFO] Creating systemd service ai-auto-suspend.service...
[INFO] Enabling Auto-Suspend service...
[SUCCESS] Auto-Suspend service enabled and started

[INFO] Configuring Stay-Awake service...
[INFO] Installing stay-awake server Python script...
[INFO] Creating systemd service stay-awake.service...
[INFO] Enabling Stay-Awake service...
[SUCCESS] Stay-Awake service enabled and started
```

---

### Step 2: Verify Services are Running

```bash
# Check service status
sudo systemctl status ai-auto-suspend.service
sudo systemctl status stay-awake.service
```

**Expected Output:**
```
● ai-auto-suspend.service - AI Server Auto-Suspend Monitor
     Loaded: loaded (/etc/systemd/system/ai-auto-suspend.service; enabled)
     Active: active (running) since ...
```

```
● stay-awake.service - Stay-Awake HTTP Server
     Loaded: loaded (/etc/systemd/system/stay-awake.service; enabled)
     Active: active (running) since ...
```

---

### Step 3: Check Auto-Suspend Logs

```bash
sudo journalctl -u ai-auto-suspend.service -f
```

**Expected Log Output:**
```
Starting auto-suspend monitor
Configuration:
  Wait time: 30 minutes
  CPU idle threshold: >=90%
  GPU usage threshold: <=10%
  Check interval: 60 seconds
  Check SSH connections: False
  API connections: ignored (do not prevent suspend)

Check: CPU idle=100.0%, GPU usage=0.0%, stay_awake=False
System became idle at 2025-10-30 18:20:00
System idle for 0.0 minutes (threshold: 30 minutes)
```

**Watch the logs for 1-2 minutes** - you should see:
- "Check: CPU idle=..." every 60 seconds
- "System idle for X minutes" incrementing
- When it reaches 30 minutes: "Idle threshold reached - suspending system"

---

### Step 4: Verify State Files Were Created

```bash
# Check state directory
sudo ls -la /var/lib/ai-auto-suspend/

# Expected output:
# drwxr-xr-x 2 root root 4096 Oct 30 18:20 .
# -rw-r--r-- 1 root root   10 Oct 30 18:20 idle_since

# Check state file content
sudo cat /var/lib/ai-auto-suspend/idle_since

# Expected: Unix timestamp like "1698689200.5"
```

---

### Step 5: Test Stay-Awake Service

```bash
# Test health endpoint
curl http://localhost:9876/health

# Expected: "OK"

# Test status endpoint
curl http://localhost:9876/status

# Expected: "Stay-awake: inactive"

# Activate stay-awake for 1 hour
curl "http://localhost:9876/stay?s=3600"

# Expected: "Stay-awake activated for 3600 seconds (1h 0m)"

# Check status again
curl http://localhost:9876/status

# Expected: "Stay-awake: active\nRemaining: 0h 59m 55s"
```

---

### Step 6: Re-open AI GOAT CLI

```bash
cd ai-goat-cli
./ai-goat
```

**What you should see NOW:**

```
╸━━━━━━━━━╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌───────────────────────────────────────┐┌────────────────────────────────────────┐
│                                       ││                                        │
│ ═══ System Status ═══                 ││ ═══ Power Status ═══                   │
│                                       ││                                        │
│ GPU:                                  ││ Total System Power:                    │
│   Power: 19.2W / 450W                 ││   69.2W                                │
│   Temp:  35°C                         ││                                        │
│   Usage: 0%                           ││ Auto-Suspend:                          │
│   VRAM:  0.1GB / 24.0GB               ││   Auto-Suspend in: 27 minutes          │
│                                       ││   Idle threshold: 30 min               │
│ CPU:                                  ││   Current idle: 3 min                  │
│   Usage: 0.0%                         ││                                        │
│   Cores: 32                           ││ Conditions:                            │
│                                       ││   CPU Idle: ✓ 100.0% (need ≥90%)       │
│ Memory:                               ││   GPU Idle: ✓ 0.0% (need ≤10%)         │
│   Used:  5.6GB / 62.0GB               ││   No API:   ✓ (info only)             │
│   Free:  56.4GB                       ││                                        │
│                                       ││                                        │
│ Services:                             ││                                        │
│   LocalAI: ● Running                  ││                                        │
│   Ollama:  ● Running                  ││                                        │
└───────────────────────────────────────┘└────────────────────────────────────────┘
```

**Key Changes:**
1. ✅ "Current idle: 3 min" (now incrementing!)
2. ✅ "Auto-Suspend in: 27 minutes" (countdown working!)
3. ✅ "No SSH" line is GONE (because CHECK_SSH=false)
4. ✅ "No API: ✓ (info only)" (clarified that API doesn't prevent suspend)

---

## 🎯 What Changed?

### Files Modified:

1. **`scripts/lib/power.sh`** (+140 lines)
   - Added `configure_auto_suspend_service()` function
   - Added `configure_stay_awake_service()` function
   - Installs Python scripts to `/opt/ai-server/`
   - Generates and enables systemd services

2. **`ai-goat-cli/lib/power.py`** (+4 lines)
   - Reads `CHECK_SSH` from service configuration
   - Only checks SSH if `CHECK_SSH=true`
   - Passes `check_ssh_enabled` flag to UI

3. **`ai-goat-cli/ai-goat.py`** (+6 lines)
   - Conditionally shows "No SSH" line (only if `CHECK_SSH=true`)
   - Clarified "No API" line with "(info only)"

4. **`install.sh`** (-2 lines)
   - Removed obsolete variables

5. **`stay-awake-server.py`** (1 line)
   - Port now configurable via `PORT` environment variable

6. **`verify-setup.sh`** (2 lines)
   - Updated service name checks

---

## 🐛 Troubleshooting

### Problem: Service won't start

**Check logs:**
```bash
sudo journalctl -u ai-auto-suspend.service -n 50
```

**Common issues:**
- Python3 not installed: `sudo apt install python3`
- Permission issues: Check `/opt/ai-server/` permissions
- Missing dependencies: Service should have no external Python dependencies

### Problem: Timer still shows 0 min

**Possible causes:**
1. Service not running (check `systemctl status`)
2. Conditions not met (check logs for "all_conditions_met")
3. Stay-awake is active (check `/run/ai-nodectl/stay_awake_until`)

**Debug:**
```bash
# Check if conditions are met
sudo journalctl -u ai-auto-suspend.service -f | grep "Check:"

# Expected: "Check: CPU idle=99.5%, GPU usage=0.0%, stay_awake=False"
```

### Problem: System doesn't suspend after 30 minutes

**Check:**
1. Are you SSH'd in and CHECK_SSH=true? (It's false by default now)
2. Is stay-awake active? `curl http://localhost:9876/status`
3. Is CPU or GPU active? Check logs for "System became active"

**Verify configuration:**
```bash
sudo systemctl cat ai-auto-suspend.service | grep Environment
```

**Expected:**
```
Environment="WAIT_MINUTES=30"
Environment="CPU_IDLE_THRESHOLD=90"
Environment="GPU_USAGE_MAX=10"
Environment="CHECK_INTERVAL=60"
Environment="CHECK_SSH=false"
```

---

## 📊 Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. Services are running
sudo systemctl is-active ai-auto-suspend.service   # Should output: active
sudo systemctl is-active stay-awake.service         # Should output: active

# 2. Python scripts are installed
ls -la /opt/ai-server/
# Should show: auto-suspend-monitor.py, stay-awake-server.py

# 3. State directory exists
ls -la /var/lib/ai-auto-suspend/
# Should show: idle_since file

# 4. Stay-awake service responds
curl http://localhost:9876/health
# Should output: OK

# 5. Auto-suspend is logging
sudo journalctl -u ai-auto-suspend.service --since "5 minutes ago" | tail -20
# Should show recent "Check:" entries

# 6. AI GOAT CLI shows idle time
cd ai-goat-cli && ./ai-goat
# Dashboard should show incrementing "Current idle: X min"
```

**If all 6 checks pass:** ✅ Auto-suspend is fully operational!

---

## 🔧 Advanced Configuration

### Change Wait Time

```bash
# Change to 45 minutes
sudo bash install.sh --repair --wait-minutes 45

# Verify
sudo systemctl cat ai-auto-suspend.service | grep WAIT_MINUTES
# Expected: Environment="WAIT_MINUTES=45"
```

### Enable SSH Checking

```bash
# Edit service file
sudo systemctl edit --full ai-auto-suspend.service

# Change this line:
Environment="CHECK_SSH=false"
# To:
Environment="CHECK_SSH=true"

# Restart service
sudo systemctl restart ai-auto-suspend.service

# AI GOAT CLI will now show "No SSH: ✗/✓" line
```

### Change Stay-Awake Port

```bash
# Change to port 8888
sudo bash install.sh --repair --stay-awake-port 8888

# Test new port
curl http://localhost:8888/health
```

---

## 📝 Summary

**Before:**
- ❌ Services not installed
- ❌ Timer stuck at 0 min
- ❌ SSH shown as blocking (confusing)

**After (once you run `sudo bash install.sh --repair`):**
- ✅ Services installed and running
- ✅ Timer increments correctly
- ✅ SSH line hidden (because CHECK_SSH=false)
- ✅ Auto-suspend works as expected

**Next step:** Run `sudo bash install.sh --repair` and watch the magic happen! 🚀

---

**Created:** 2025-10-30
**By:** Claude Code
**Tested:** Syntax validation passed, awaiting user installation
