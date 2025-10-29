#!/usr/bin/env bats
# Unit tests for scripts/lib/system.sh

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_ROOT="$(dirname "${TEST_DIR}")"
  SYSTEM_LIB="${PROJECT_ROOT}/scripts/lib/system.sh"
  LOGGING_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"

  # Source the libraries
  source "${LOGGING_LIB}"
  source "${SYSTEM_LIB}"
}

@test "system.sh exists" {
  [ -f "${SYSTEM_LIB}" ]
}

@test "system.sh has correct shebang" {
  run head -n 1 "${SYSTEM_LIB}"
  [[ "${output}" == "#!/usr/bin/env bash" ]]
}

@test "require_cmd succeeds for existing command" {
  run require_cmd "bash"
  [ "${status}" -eq 0 ]
}

@test "require_cmd fails for non-existing command" {
  run require_cmd "nonexistent_command_xyz"
  [ "${status}" -eq 1 ]
}

@test "join_by joins strings with delimiter" {
  run join_by "," "a" "b" "c"
  [ "${status}" -eq 0 ]
  [[ "${output}" == "a,b,c" ]]
}

@test "join_by handles single item" {
  run join_by "," "a"
  [ "${status}" -eq 0 ]
  [[ "${output}" == "a" ]]
}

@test "join_by handles empty list" {
  run join_by ","
  [ "${status}" -eq 0 ]
  [[ "${output}" == "" ]]
}

@test "backup_file returns 0 for non-existent file" {
  run backup_file "/tmp/nonexistent_file_xyz_12345"
  [ "${status}" -eq 0 ]
}
