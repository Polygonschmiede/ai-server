# Scripts

Reusable Bash helpers live here. Keep each helper focused on a single task and source them from entry-point scripts such as `install.sh`.

- Place shared functions under `lib/` (for example, `lib/docker.sh`).
- Add unit or integration coverage in `tests/` whenever a helper mutates the host system.
- Run `shellcheck` and `shfmt -w` on every change before opening a pull request.
