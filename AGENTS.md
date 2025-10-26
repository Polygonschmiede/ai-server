# Repository Guidelines

## Project Structure & Module Organization
- Keep orchestration in `install.sh`; move reusable logic into `scripts/` and shared helpers into `scripts/lib/`.
- House Bats suites in `tests/` and their golden assets in `tests/fixtures/`.
- Leave templates such as `.env.example` or `config/*.yml` at the repo root and keep generated artifacts gitignored.

## Build, Test, and Development Commands
- `bash install.sh --non-interactive --cpu-only` — smoke-test LocalAI provisioning without GPU dependencies or prompts.
- `shellcheck install.sh scripts/**/*.sh` — lint for quoting, portability, and unsafe patterns; treat warnings as blockers.
- `shfmt -w install.sh scripts/**/*.sh` — enforce consistent two-space indentation before opening a PR.
- `bats tests` — execute end-to-end flows; add focused suites such as `tests/docker.bats` for new surfaces.
- `bash install.sh --repair` — rewrite systemd/docker assets in place to fix drift while keeping models intact.

## Coding Style & Naming Conventions
- Bash files start with `#!/usr/bin/env bash` and `set -euo pipefail`; declare globals as uppercase snake case (`LOCALAI_DIR`).
- Use two-space indentation, lowercase snake case for functions (`require_cmd`), and prefer explicit long flags (`--models-path`).
- Co-locate logging helpers (`log`, `warn`, `err`, `die`) near the top; document side effects with short comments when clarity helps.

## Testing Guidelines
- Mirror every mutating code path with Bats coverage, including GPU/CPU forks and failure branches (missing sudo, unsupported distro).
- Snapshot rendered artifacts into `tests/fixtures/` and compare with `diff` or `cmp` to detect regressions.
- Prefix new suites with their focus area (`tests/nvidia_toolkit.bats`); keep individual tests under ~15 setup lines.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat: add cpu fallback`, `fix: harden docker repo setup`) and wrap body text at 72 characters.
- Reference work items with `Refs #ID`/`Fixes #ID` and list manual validation steps plus shellcheck/bats results.
- PRs must outline risk, rollback strategy, and call out sudo/systemd touchpoints; include logs or screenshots when behavior changes.

## Security & Operations Notes
- Verify remote downloads with checksums or GPG whenever possible and document source URLs in code comments.
- Never ship real secrets; rely on `.env.local` (gitignored) or environment variables for overrides and remind operators to rotate credentials.
- Power management helpers persist state under `/etc/localai-installer/state.env`; rerun `bash install.sh --repair` after manual edits or when toggling `--skip-*` flags.
- WOL depends on `ethtool` and the managed `wol@.service`; keep edits in the installer so uninstall and reapply stay clean.
