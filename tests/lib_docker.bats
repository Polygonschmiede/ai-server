#!/usr/bin/env bats
# Unit tests for scripts/lib/docker.sh

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_ROOT="$(dirname "${TEST_DIR}")"
  DOCKER_LIB="${PROJECT_ROOT}/scripts/lib/docker.sh"
  LOGGING_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
  SERVICE_LIB="${PROJECT_ROOT}/scripts/lib/service.sh"
  SYSTEM_LIB="${PROJECT_ROOT}/scripts/lib/system.sh"

  # Set up variables needed by docker.sh
  export DOCKER_CMD=""
  export SERVICE_NAME="localai.service"
  export LOCALAI_DIR="/opt/localai"

  # Source the libraries
  source "${LOGGING_LIB}"
  source "${SYSTEM_LIB}"
  source "${SERVICE_LIB}"
  source "${DOCKER_LIB}"
}

@test "docker.sh exists" {
  [ -f "${DOCKER_LIB}" ]
}

@test "docker.sh has correct shebang" {
  run head -n 1 "${DOCKER_LIB}"
  [[ "${output}" == "#!/usr/bin/env bash" ]]
}

@test "docker_bin function is defined" {
  run type docker_bin
  [ "${status}" -eq 0 ]
}

@test "docker_container_exists function is defined" {
  run type docker_container_exists
  [ "${status}" -eq 0 ]
}

@test "stop_localai_service function is defined" {
  run type stop_localai_service
  [ "${status}" -eq 0 ]
}

@test "stop_localai_containers function is defined" {
  run type stop_localai_containers
  [ "${status}" -eq 0 ]
}

@test "docker_bin returns empty when docker not found" {
  DOCKER_CMD=""
  PATH="/nonexistent"
  run docker_bin
  [ "${status}" -eq 0 ]
  [[ "${output}" == "" ]]
}
