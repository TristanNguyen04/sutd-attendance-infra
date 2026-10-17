---
name: write-adr
description: Record an architecture decision as a short ADR in docs/adr. Use when a change adds a component, changes a trade-off, or reverses an earlier decision.
---

# Write an ADR

1. Look at `docs/adr/` and use the next number (`0004-...`). Keep the file name short and lowercase with hyphens.
2. Use this shape and keep it under about 25 lines:

```
# N. Title

Status: Proposed | Accepted | Superseded by N

## Context
Why a decision is needed. Constraints (cost, team size, deadlines).

## Decision
What we do, in plain sentences or a short list.

## Consequences
What gets easier, what gets harder, what to watch.
```

3. If it replaces an earlier decision, set the old ADR's status to `Superseded by N` instead of rewriting it.
4. Mark it `Proposed` until the user confirms. Do not mark a decision `Accepted` that the user has not agreed to.
5. Mention the ADR in the PR description.
