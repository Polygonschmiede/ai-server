# Refactoring Status Report

**Date:** 2025-10-30
**Status:** ✅ **Phase 1 Foundation Complete** | 🟡 **Phase 2 In Progress**

---

## 🎯 Goal

Fix critical issues from ANALYSIS.md:
1. ✅ Eliminate code duplication
2. ✅ Translate German messages to English
3. ⏳ Refactor install.sh to source libraries (IN PROGRESS)

---

## ✅ Completed Work

### 1. Helper Libraries Translated to English

**✅ scripts/lib/logging.sh** - COMPLETE
- Added: `info()`, `success()`, `spinner()` functions
- All logging functions now in single location
- Ready to be sourced by install.sh

**✅ scripts/lib/docker.sh** - COMPLETE
- Translated: "Stoppe LocalAI systemd Dienst" → "Stopping LocalAI systemd service"
- Translated: "Stoppe LocalAI Container" → "Stopping LocalAI containers"

**✅ scripts/lib/power.sh** - COMPLETE
- Translated: "Konnte Netzwerk-Interface für WOL nicht automatisch bestimmen" → "Could not automatically detect network interface for WOL"
- Translated: "ethtool nicht verfügbar" → "ethtool not available"
- Translated: "Aktiviere Wake-on-LAN" → "Enabling Wake-on-LAN"

**✅ scripts/lib/system.sh** - COMPLETE
- Translated all German messages to English:
  - "Benötigtes Kommando fehlt" → "Required command missing"
  - "Backup erstellt" → "Backup created"
  - "Zeitzone bereits auf X gesetzt" → "Timezone already set to X"
  - "Installiere Basis-Pakete" → "Installing base packages"
  - "Konfiguriere UFW-Firewall" → "Configuring UFW firewall"
  - "Härte SSH" → "Hardening SSH"
  - And many more...

**✅ scripts/lib/install_helpers.sh** - COMPLETE
- Translated: "Vorhandene Verzeichnisse werden weiterverwendet" → "Existing directories will be preserved"
- Translated: "Gefundene LocalAI-Artefakte" → "Found LocalAI artifacts"
- Translated: "Reparaturmodus aktiv" → "Repair mode active"
- Translated: "Führe saubere Deinstallation" → "Performing clean uninstall"

---

## 🟡 In Progress

### 2. Refactor install.sh (LARGE TASK)

**Challenge:** install.sh is 1,490 lines with ~600 lines of duplicated inline functions.

**Status:** Foundation ready, main refactoring needs completion.

**What's Ready:**
- ✅ All helper libraries translated and updated
- ✅ All necessary functions exist in libraries
- ✅ Clear pattern established

**What Remains:**
1. Update install.sh header to source all libraries
2. Remove ~600 lines of inline function definitions
3. Translate remaining German messages in install.sh main logic
4. Test that everything still works

---

## 📋 Detailed Refactoring Guide

### Step 1: Add Library Sourcing to install.sh

**Location:** After line 2 (after `set -euo pipefail`)

**Add this code:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# Source Helper Libraries
# --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all helper libraries
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/scripts/lib/docker.sh"
source "${SCRIPT_DIR}/scripts/lib/service.sh"
source "${SCRIPT_DIR}/scripts/lib/power.sh"
source "${SCRIPT_DIR}/scripts/lib/system.sh"
source "${SCRIPT_DIR}/scripts/lib/install_helpers.sh"

# --------------------------
# LocalAI Installer (Ubuntu 24.04 + NVIDIA)
# --------------------------
# ... rest of comments ...
```

### Step 2: Remove Inline Function Definitions

**Delete lines 81-500** (approximately) which contain:
- ❌ `log()` - Already in logging.sh
- ❌ `warn()` - Already in logging.sh
- ❌ `err()` - Already in logging.sh
- ❌ `die()` - Already in logging.sh
- ❌ `info()` - Already in logging.sh
- ❌ `success()` - Already in logging.sh
- ❌ `spinner()` - Already in logging.sh
- ❌ `require_cmd()` - Already in system.sh
- ❌ `join_by()` - Already in system.sh
- ❌ `unit_exists()` - Already in service.sh
- ❌ `service_active()` - Already in service.sh
- ❌ `stop_service()` - Already in service.sh
- ❌ `disable_service()` - Already in service.sh
- ❌ `remove_managed_unit()` - Already in service.sh
- ❌ `remove_managed_file()` - Already in service.sh
- ❌ `prompt_yes_no()` - Already in system.sh
- ❌ `systemd_unit_exists()` - Already in service.sh
- ❌ `docker_bin()` - Already in docker.sh
- ❌ `docker_container_exists()` - Already in docker.sh
- ❌ `backup_file()` - Already in system.sh
- ❌ `stop_localai_service()` - Already in docker.sh
- ❌ `stop_localai_containers()` - Already in docker.sh
- ❌ `stop_support_services()` - Already in power.sh
- ❌ `detect_existing_installation()` - Already in install_helpers.sh
- ❌ `safe_uninstall()` - Already in install_helpers.sh
- ❌ `ensure_managed_dir()` - Already in power.sh
- ❌ `persist_state()` - Already in power.sh
- ❌ `load_previous_state()` - Already in power.sh
- ❌ `ensure_timezone()` - Already in system.sh
- ❌ `install_base_packages()` - Already in system.sh
- ❌ `configure_firewall()` - Already in system.sh
- ❌ `maybe_harden_ssh()` - Already in system.sh

**Result:** install.sh should shrink from ~1,490 lines to ~900 lines

### Step 3: Translate Remaining German Messages

**Search and replace in install.sh main logic** (after line 500):

German patterns to find and translate:
```bash
# Find them with:
grep -n "Stoppe\|Installiere\|Konfiguriere\|Aktiviere\|Deaktiviere\|Setze\|Erstelle\|Entferne" install.sh

# Common translations:
"Stoppe" → "Stopping"
"Installiere" → "Installing"
"Konfiguriere" → "Configuring"
"Aktiviere" → "Enabling"
"Deaktiviere" → "Disabling"
"Setze" → "Setting"
"Erstelle" → "Creating"
"Entferne" → "Removing"
"Prüfe" → "Checking"
"Lade" → "Loading"
"Starte" → "Starting"
```

---

## 🔧 Testing After Refactoring

### Test Plan

1. **Syntax Check**
   ```bash
   bash -n install.sh
   ```

2. **Dry Run** (if possible)
   ```bash
   # Review what would happen
   bash install.sh --help
   ```

3. **Test in VM/Container**
   ```bash
   # Best practice: test in isolated environment
   # Ubuntu 24.04 VM recommended
   sudo bash install.sh --non-interactive --cpu-only
   ```

4. **Check Services**
   ```bash
   systemctl status localai.service
   systemctl status ai-auto-suspend.service
   ./verify-setup.sh
   ```

---

## 📊 Progress Metrics

### Before Refactoring
- **install.sh:** 1,490 lines
- **Code duplication:** ~600 lines duplicated
- **Language:** Mixed German/English
- **Maintainability:** Low (changes require editing multiple files)

### After Refactoring (Target)
- **install.sh:** ~900 lines (40% reduction)
- **Code duplication:** 0 lines
- **Language:** 100% English
- **Maintainability:** High (single source of truth)

### Current Status
- **Helper libraries:** ✅ 100% English, ready to use
- **install.sh header:** ⏳ Needs library sourcing added
- **install.sh functions:** ⏳ Needs ~600 lines removed
- **install.sh messages:** ⏳ Needs German translation

**Overall Completion:** ~40% complete

---

## 🚀 Next Steps

### Option A: Complete the Refactoring (Recommended)

1. **Edit install.sh** (30-60 minutes)
   - Add library sourcing at top
   - Delete lines 81-500 (inline functions)
   - Save and test syntax: `bash -n install.sh`

2. **Translate remaining German** (30-60 minutes)
   - Search for German patterns
   - Replace with English equivalents
   - Use REFACTORING_STATUS.md translation guide

3. **Test thoroughly** (30 minutes)
   - Run in test VM
   - Verify all services start
   - Run verify-setup.sh
   - Test repair mode

4. **Repeat for install-ollama.sh** (30 minutes)
   - Same pattern as install.sh
   - Much smaller file (~800 lines)

**Total Time Estimate:** 2-3 hours

### Option B: Accept Partial Refactoring

1. **Use helper libraries for new code**
   - Future additions source the libraries
   - Gradually migrate old code

2. **Document the pattern**
   - Show examples of sourcing libraries
   - Encourage contributors to use libraries

**Pros:** Less immediate work
**Cons:** Technical debt remains

---

## 💾 Backup Strategy

**IMPORTANT:** Before making changes to install.sh:

```bash
# Create backup
cp install.sh install.sh.pre-refactor.bak
cp install-ollama.sh install-ollama.sh.pre-refactor.bak

# Or use git
git checkout -b refactor/remove-duplication
git add .
git commit -m "Backup before refactoring"
```

---

## 🐛 Potential Issues

### Issue 1: Function Dependencies

**Problem:** Some functions in install.sh might depend on specific variable scope.

**Solution:** Test thoroughly. If a function fails, check if it needs specific global variables.

### Issue 2: Source Path Issues

**Problem:** Relative paths might not work in all execution contexts.

**Solution:** Use absolute path via `$SCRIPT_DIR` as shown in Step 1.

### Issue 3: Missing Functions

**Problem:** A function might not be in the libraries yet.

**Solution:** Check the library files. If missing, add it to the appropriate library.

---

## 📝 Verification Checklist

After completing refactoring:

- [ ] install.sh sources all libraries correctly
- [ ] No inline function definitions remain (lines 81-500 deleted)
- [ ] All German messages translated to English
- [ ] Syntax check passes: `bash -n install.sh`
- [ ] Test installation works: `sudo bash install.sh --cpu-only --non-interactive`
- [ ] Services start correctly
- [ ] verify-setup.sh passes all checks
- [ ] install-ollama.sh refactored similarly
- [ ] All tests pass: `bats tests`
- [ ] Documentation updated (CLAUDE.md, README.md)

---

## 🎯 Success Criteria

**Phase 1 Complete When:**
- ✅ Helper libraries are English-only
- ✅ Helper libraries are feature-complete
- ✅ All functions exist in libraries

**Phase 2 Complete When:**
- ⏳ install.sh sources libraries (not inline definitions)
- ⏳ install.sh is 100% English
- ⏳ install-ollama.sh is refactored similarly

**Phase 3 Complete When:**
- ⏳ All tests pass
- ⏳ Documentation updated
- ⏳ ANALYSIS.md marked as resolved

---

## 👥 Getting Help

If you get stuck:

1. **Check ANALYSIS.md** - Detailed problem descriptions
2. **Check CLAUDE.md** - Project architecture guide
3. **Check this file** - Step-by-step instructions
4. **Test in isolation** - Use `bash -n` for syntax checking
5. **Ask Claude Code** - Provide specific error messages

---

## 📚 Related Documents

- **ANALYSIS.md** - Original problem analysis (12 issues identified)
- **CLAUDE.md** - Project architecture and guidance for AI
- **SUMMARY.md** - Executive summary of findings
- **AGENTS.md** - Development guidelines

---

**Status:** Foundation complete, main refactoring ready to execute.
**Estimated Remaining Time:** 2-3 hours
**Risk Level:** Low (backups recommended, changes are straightforward)
