@AGENTS.md

## Claude Code notes

- Project rules are in `.claude/rules/`, skills in `.claude/skills/`, and the reviewer subagent in `.claude/agents/reviewer.md`.
- `.claude/settings.json` denies destructive Terraform commands. If one is needed, ask the user to run it.
- Prefer the dedicated Read/Edit/Grep tools over shell equivalents.
