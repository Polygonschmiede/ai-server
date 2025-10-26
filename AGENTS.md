# Repository Guidelines

## Project Structure & Module Organization
- Root automation lives beside `install.sh`; group supporting helpers under `scripts/`.
- Mirror every entry-point script with a spec in `tests/` and fixtures in `tests/fixtures/`.
- Configuration templates (docker-compose overlays, `.env.example`) belong in `config/`; runtime artifacts stay ignored.

## Build, Test, and Development Commands
- `bash install.sh --non-interactive` — smoke-test the installer without prompts.
- `shellcheck install.sh scripts/**/*.sh` — lint Bash for quoting, portability, and unsafe patterns.
- `bats tests/install.bats` — run behavioral tests across GPU, CPU, and custom model-path flows.

## Coding Style & Naming Conventions
- Start Bash files with `#!/usr/bin/env bash` plus `set -euo pipefail`; constants are uppercase snake case (`MODE`, `LOCALAI_DIR`).
- Use two-space indentation, lower_snake_case function names (`require_cmd`), and long-form flags (`--models-path`).
- Keep helpers (`log`, `warn`, `err`) near the top, split functions over ~30 lines, and normalize with `shfmt -w`.

## Testing Guidelines
- Exercise every code path that mutates the host (Docker install, NVIDIA detection, systemd) through Bats tests.
- Snapshot generated artifacts (`docker-compose.yml`, systemd units) under `tests/fixtures/` and diff them in assertions.
- Hold coverage expectations around 90% of command paths; document intentional skips (e.g., alternate distros) in the PR.

## Commit & Pull Request Guidelines
- Write imperative, Conventional Commits-style subjects (`feat: add cpu fallback`) with wrapped bodies at 72 characters.
- Link issues using `Fixes #ID`/`Refs #ID`, note rollbacks, and share any manual validation steps.
- Attach logs from `shellcheck`/`bats` and confirm the installer remains idempotent after reruns.

## Security & Configuration Tips
- Highlight changes that touch sudo/systemd paths and record rollback steps in `docs/security.md`.
- Keep secrets out of source; rely on `.env.local` (gitignored) or environment variables, and verify downloads with checksums where possible.
