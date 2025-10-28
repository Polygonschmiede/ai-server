#!/usr/bin/env bats
# Unit tests for scripts/lib/logging.sh

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_ROOT="$(dirname "${TEST_DIR}")"
  LOGGING_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"

  # Source the library
  source "${LOGGING_LIB}"
}

@test "logging.sh exists" {
  [ -f "${LOGGING_LIB}" ]
}

@test "logging.sh has correct shebang" {
  run head -n 1 "${LOGGING_LIB}"
  [[ "${output}" == "#!/usr/bin/env bash" ]]
}

@test "log function outputs with green prefix" {
  run log "test message"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"test message"* ]]
}

@test "warn function outputs with yellow prefix" {
  run warn "warning message"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"warning message"* ]]
}

@test "err function outputs to stderr" {
  run err "error message"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"error message"* ]]
}

@test "die function exits with status 1" {
  run die "fatal error"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"fatal error"* ]]
}
