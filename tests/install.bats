#!/usr/bin/env bats
# Integration tests for install.sh

setup() {
  # Load test helpers
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_ROOT="$(dirname "${TEST_DIR}")"
  INSTALL_SCRIPT="${PROJECT_ROOT}/install.sh"
}

@test "install.sh exists and is executable" {
  [ -f "${INSTALL_SCRIPT}" ]
  [ -x "${INSTALL_SCRIPT}" ]
}

@test "install.sh has correct shebang" {
  run head -n 1 "${INSTALL_SCRIPT}"
  [[ "${output}" == "#!/usr/bin/env bash" ]]
}

@test "install.sh uses pipefail" {
  run grep -F "set -euo pipefail" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh defines log function" {
  run grep -E "^log\(\)" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh defines warn function" {
  run grep -E "^warn\(\)" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh defines err function" {
  run grep -E "^err\(\)" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh defines die function" {
  run grep -E "^die\(\)" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh handles --cpu-only flag" {
  run grep -F "--cpu-only" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh handles --non-interactive flag" {
  run grep -F "--non-interactive" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh handles --repair flag" {
  run grep -F "--repair" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh handles --models-path flag" {
  run grep -F "--models-path" "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh defines LOCALAI_DIR variable" {
  run grep 'LOCALAI_DIR="/opt/localai"' "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh defines SERVICE_NAME variable" {
  run grep 'SERVICE_NAME="localai.service"' "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh checks for Ubuntu" {
  run grep -E 'Ubuntu.*unterstützt' "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "install.sh checks architecture" {
  run grep 'dpkg --print-architecture' "${INSTALL_SCRIPT}"
  [ "${status}" -eq 0 ]
}
