#!/usr/bin/env bats
# Unit tests for scripts/lib/service.sh

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_ROOT="$(dirname "${TEST_DIR}")"
  SERVICE_LIB="${PROJECT_ROOT}/scripts/lib/service.sh"
  LOGGING_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
  SYSTEM_LIB="${PROJECT_ROOT}/scripts/lib/system.sh"

  # Source the libraries
  source "${LOGGING_LIB}"
  source "${SYSTEM_LIB}"
  source "${SERVICE_LIB}"
}

@test "service.sh exists" {
  [ -f "${SERVICE_LIB}" ]
}

@test "service.sh has correct shebang" {
  run head -n 1 "${SERVICE_LIB}"
  [[ "${output}" == "#!/usr/bin/env bash" ]]
}

@test "unit_exists function is defined" {
  run type unit_exists
  [ "${status}" -eq 0 ]
}

@test "service_active function is defined" {
  run type service_active
  [ "${status}" -eq 0 ]
}

@test "stop_service function is defined" {
  run type stop_service
  [ "${status}" -eq 0 ]
}

@test "disable_service function is defined" {
  run type disable_service
  [ "${status}" -eq 0 ]
}

@test "remove_managed_unit function is defined" {
  run type remove_managed_unit
  [ "${status}" -eq 0 ]
}

@test "remove_managed_file function is defined" {
  run type remove_managed_file
  [ "${status}" -eq 0 ]
}
