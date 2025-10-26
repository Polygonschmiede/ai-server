# Tests

Integration and regression suites go here. Use [Bats](https://bats-core.readthedocs.io/) for behavior-driven coverage of shell entrypoints.

- Organize suites by feature area (for example, `install.bats`, `nvidia_toolkit.bats`).
- Store golden artifacts such as rendered configs inside `fixtures/` and assert against them with `diff` or `cmp`.
- Prefer deterministic mocks over real network access; document any unavoidable external dependencies in the test header.
