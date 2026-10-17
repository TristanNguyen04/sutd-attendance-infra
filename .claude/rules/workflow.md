# Workflow

- Work on a branch and open a pull request. Do not commit to `main` directly.
- Commit messages: short imperative subject (`Add network stack`), a body that says why when it is not obvious.
- One logical change per pull request. Infrastructure changes and unrelated cleanups go separately.
- Before opening a PR: `make check` passes, README/ADR updated, and the reviewer agent has looked at the change.
- A change that alters a decision (new component, different trade-off) gets a new ADR or updates the existing one. Use `/write-adr`.
- Keep the apply order consistent across `AGENTS.md`, `README.md`, `stacks/README.md` and `.github/workflows/apply.yml`.
- Report honestly: say what was validated, what was only syntax-checked, and what was not run (plan, apply, SQL against a real database).
- Keep it cheap and simple. If a change adds a recurring AWS cost, state the rough monthly cost in the PR description.
