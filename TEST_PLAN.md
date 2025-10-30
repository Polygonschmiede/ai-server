# Test Coverage Improvement Plan

**Created:** 2025-10-30
**Status:** 📋 Planning Phase
**Priority:** Medium (addresses Issue #6 from ANALYSIS.md)

---

## Current State

### Existing Test Coverage (~5%)

**Location:** `tests/` directory with 5 basic Bats test files

**What's Tested:**
- ✅ File existence checks
- ✅ Correct shebang (`#!/usr/bin/env bash`)
- ✅ Presence of specific functions in scripts
- ✅ String pattern matching in files

**Test Files:**
1. `tests/test_install_script.bats` - Basic install.sh structure
2. `tests/test_helper_libraries.bats` - Helper library structure
3. `tests/test_ollama_script.bats` - Basic install-ollama.sh structure
4. `tests/test_auto_suspend.bats` - Auto-suspend structure
5. `tests/test_service_manager.bats` - Service manager structure

### What's NOT Tested (Major Gaps)

❌ **No actual installation tests**
- Scripts execute without errors
- Docker gets installed correctly
- Services start successfully
- Containers are created and running

❌ **No integration tests**
- Docker + LocalAI interaction
- Service dependencies (stay-awake → auto-suspend)
- GPU detection and configuration
- Network connectivity

❌ **No functional tests**
- Auto-suspend actually suspends after idle time
- Stay-awake HTTP endpoints work
- Wake-on-LAN configuration functions
- Model loading and inference

❌ **No error handling tests**
- Invalid arguments are caught
- Missing dependencies are detected
- Insufficient permissions fail gracefully
- Corrupted installations are detected

❌ **No rollback/uninstall tests**
- Uninstall removes all components
- Model data is preserved
- Clean uninstall possible after partial install

---

## Proposed Test Structure

### Level 1: Unit Tests (Quick, Isolated)

**Purpose:** Test individual functions in isolation

**Framework:** Bats-core (already used)

**Target:** Helper libraries in `scripts/lib/`

**Test Files:**
```
tests/unit/
├── test_logging.bats       # Test log(), warn(), err(), die()
├── test_docker.bats        # Test Docker helper functions
├── test_service.bats       # Test systemd service functions
├── test_power.bats         # Test WOL, auto-suspend helpers
├── test_system.bats        # Test system utility functions
└── test_install_helpers.bats  # Test installation helpers
```

**Example Tests:**
- `log()` outputs correct color codes
- `require_cmd()` detects missing commands
- `docker_container_exists()` correctly identifies containers
- `service_active()` reports service status accurately

**Estimated Effort:** 4-6 hours
**Priority:** HIGH - Easy wins, fast feedback

---

### Level 2: Integration Tests (Docker, Services)

**Purpose:** Test components working together

**Framework:** Bats-core + Docker containers

**Environment:** Docker-in-Docker or test VM

**Test Files:**
```
tests/integration/
├── test_docker_install.bats     # Docker installation works
├── test_localai_deployment.bats # LocalAI deploys and starts
├── test_ollama_deployment.bats  # Ollama deploys and starts
├── test_service_lifecycle.bats  # Start/stop/restart services
├── test_auto_suspend_service.bats  # Auto-suspend service functions
├── test_stay_awake_service.bats    # Stay-awake HTTP works
├── test_parallel_services.bats     # LocalAI + Ollama together
└── test_repair_mode.bats           # --repair flag works
```

**Example Tests:**
- Install Docker, verify `docker ps` works
- Deploy LocalAI, verify container is running
- Start auto-suspend service, verify it's active
- Call stay-awake HTTP endpoint, verify response
- Run both services, verify GPU sharing
- Run repair mode, verify services reconfigure

**Estimated Effort:** 12-16 hours
**Priority:** HIGH - Critical functionality

---

### Level 3: End-to-End Tests (Full Installation)

**Purpose:** Test complete installation workflows

**Framework:** Bats-core + VM/Container

**Environment:** Fresh Ubuntu 24.04 VM or container

**Test Files:**
```
tests/e2e/
├── test_fresh_install_gpu.bats      # Full GPU installation
├── test_fresh_install_cpu.bats      # CPU-only installation
├── test_custom_config.bats          # Custom flags work
├── test_non_interactive.bats        # --non-interactive works
├── test_uninstall.bats              # Uninstall is clean
├── test_upgrade.bats                # Upgrade from previous version
└── test_multi_run_idempotent.bats   # Running twice is safe
```

**Example Tests:**
- Fresh Ubuntu → run install.sh → verify everything works
- Run install.sh twice → verify no errors
- Install → uninstall → verify clean system
- Install with custom ports → verify ports are used

**Estimated Effort:** 16-20 hours
**Priority:** MEDIUM - Slower, but comprehensive

---

### Level 4: Functional Tests (Behavior Verification)

**Purpose:** Test actual AI server and power management behavior

**Framework:** Python pytest + API calls

**Test Files:**
```
tests/functional/
├── test_localai_api.py         # LocalAI API responses
├── test_ollama_api.py          # Ollama API responses
├── test_auto_suspend_behavior.py  # Auto-suspend triggers
├── test_stay_awake_http.py     # Stay-awake prevents suspend
├── test_gpu_detection.py       # GPU properly detected
├── test_model_loading.py       # Models load correctly
└── test_wol_config.py          # Wake-on-LAN configured
```

**Example Tests:**
- Call LocalAI `/health` endpoint, verify response
- Load a model, run inference, verify output
- Simulate idle time, verify auto-suspend triggers
- Call stay-awake endpoint, verify suspend delayed
- Check nvidia-smi output, verify GPU visible

**Estimated Effort:** 12-16 hours
**Priority:** MEDIUM - Nice to have

---

### Level 5: Error Condition Tests (Negative Tests)

**Purpose:** Test failure modes and error handling

**Framework:** Bats-core

**Test Files:**
```
tests/errors/
├── test_invalid_args.bats       # Invalid flags are caught
├── test_missing_deps.bats       # Missing commands detected
├── test_insufficient_perms.bats # Non-root fails gracefully
├── test_disk_full.bats          # Low disk space handled
├── test_port_conflicts.bats     # Port already in use
└── test_corrupted_install.bats  # Partial install detected
```

**Example Tests:**
- Run install.sh without sudo → verify error message
- Run with invalid flag → verify help message
- Simulate port 8080 in use → verify error handling
- Delete critical file → verify detection and repair

**Estimated Effort:** 8-12 hours
**Priority:** LOW - Edge cases

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1) - **RECOMMENDED START**

**Effort:** 4-6 hours
**Impact:** Immediate feedback on refactored code

1. ✅ Set up test fixtures and utilities
2. ✅ Create unit tests for helper libraries
3. ✅ Add CI/CD integration (GitHub Actions)
4. ✅ Document test execution in README

**Deliverables:**
- `tests/unit/` directory with 6 test files
- 50+ unit tests covering helper functions
- GitHub Actions workflow running tests on PR
- Test coverage report

---

### Phase 2: Integration (Week 2) - **HIGH PRIORITY**

**Effort:** 12-16 hours
**Impact:** Catch deployment issues early

1. ✅ Docker installation tests
2. ✅ Service deployment tests
3. ✅ Service lifecycle tests
4. ✅ Parallel service tests

**Deliverables:**
- `tests/integration/` directory with 8 test files
- 80+ integration tests
- Docker-based test environment
- Service interaction validation

---

### Phase 3: End-to-End (Week 3-4) - **MEDIUM PRIORITY**

**Effort:** 16-20 hours
**Impact:** Full installation validation

1. ✅ Fresh install scenarios
2. ✅ Idempotency tests
3. ✅ Uninstall tests
4. ✅ Upgrade tests

**Deliverables:**
- `tests/e2e/` directory with 7 test files
- VM/container-based test environment
- Complete workflow validation

---

### Phase 4: Functional + Error Tests (Ongoing) - **LOWER PRIORITY**

**Effort:** 20+ hours
**Impact:** Edge case coverage

1. ✅ API functionality tests
2. ✅ Auto-suspend behavior tests
3. ✅ Error condition tests

**Deliverables:**
- `tests/functional/` directory with 7 test files
- `tests/errors/` directory with 6 test files
- Comprehensive edge case coverage

---

## Test Environment Setup

### Local Development

**Requirements:**
- Bats-core: `sudo apt install bats`
- Docker: For integration tests
- Python pytest: `pip install pytest pytest-cov`

**Run Tests:**
```bash
# Unit tests (fast)
bats tests/unit/

# Integration tests (requires Docker)
bats tests/integration/

# All tests
bats tests/

# With coverage
pytest tests/ --cov=. --cov-report=html
```

---

### CI/CD (GitHub Actions)

**Workflow:** `.github/workflows/tests.yml`

**Triggers:**
- On pull request
- On push to main
- Nightly (full test suite)

**Jobs:**
1. **Lint:** ShellCheck on all bash scripts
2. **Unit Tests:** Fast unit tests on every commit
3. **Integration Tests:** Docker-based integration tests
4. **E2E Tests:** Full VM-based tests (nightly only)

**Example Workflow:**
```yaml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v3
      - name: Install bats
        run: sudo apt-get install -y bats
      - name: Run unit tests
        run: bats tests/unit/

  integration-tests:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v3
      - name: Set up Docker
        uses: docker/setup-buildx-action@v2
      - name: Install bats
        run: sudo apt-get install -y bats
      - name: Run integration tests
        run: bats tests/integration/
```

---

## Success Metrics

### Phase 1 Complete When:
- ✅ 50+ unit tests written
- ✅ All helper library functions have tests
- ✅ Tests run in < 2 minutes
- ✅ CI/CD running unit tests automatically

### Phase 2 Complete When:
- ✅ 80+ integration tests written
- ✅ Docker + service deployment tested
- ✅ Tests run in < 10 minutes
- ✅ 70%+ code coverage

### Phase 3 Complete When:
- ✅ Full installation workflows tested
- ✅ Idempotency verified
- ✅ Uninstall validated
- ✅ 85%+ code coverage

### Overall Success:
- ✅ **Target:** 80%+ code coverage
- ✅ **Goal:** No deployment failures catch us by surprise
- ✅ **Result:** Confidence in refactoring and changes

---

## Test Maintenance

### Adding New Tests

1. **For new functions:** Add unit test immediately
2. **For new features:** Add integration test
3. **For bug fixes:** Add regression test
4. **Document** in this file

### Test Standards

- **Naming:** `test_<function>_<scenario>.bats`
- **Documentation:** Comment explaining what's tested
- **Isolation:** Tests don't depend on each other
- **Cleanup:** Tests clean up after themselves
- **Speed:** Unit tests < 1s, integration tests < 30s

---

## Quick Start for Contributors

### Run Existing Tests

```bash
# All structural tests (current)
bats tests/

# Specific test file
bats tests/test_install_script.bats
```

### Add a Unit Test

```bash
# Create test file
cat > tests/unit/test_myfeature.bats <<'EOF'
#!/usr/bin/env bats

# Load helpers
load '../test_helper'

setup() {
  # Setup code
}

@test "my_function returns expected output" {
  source scripts/lib/mylib.sh
  result=$(my_function "test")
  [ "$result" = "expected" ]
}
EOF

# Run it
bats tests/unit/test_myfeature.bats
```

---

## Related Documentation

- **ANALYSIS.md** - Issue #6: Incomplete Test Coverage
- **AGENTS.md** - Development guidelines
- **README.md** - User documentation
- **Bats Documentation:** https://bats-core.readthedocs.io/

---

## Conclusion

Current test coverage is ~5% (structural tests only). This plan provides a roadmap to achieve 80%+ coverage over 4 phases.

**Immediate Next Steps:**
1. Start with Phase 1: Unit tests for helper libraries (4-6 hours)
2. Set up CI/CD with GitHub Actions
3. Gradually add integration and E2E tests

**Estimated Total Effort:** 60-80 hours for complete coverage

**Recommendation:** Implement Phase 1 immediately (high ROI), then Phases 2-4 incrementally as time allows.

---

**Status:** 📋 **PLAN READY - Awaiting Implementation**
