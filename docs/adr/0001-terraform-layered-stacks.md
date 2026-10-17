# 1. Terraform, split into layered stacks

Status: Accepted

## Context

The infra repo is shared by three teams and deployed through GitHub Actions. Service repos deploy new images themselves. If both this repo and a service's CI write the ECS task definition, each infra apply would revert the last deploy.

## Decision

- Use Terraform, not CDK. Its `lifecycle { ignore_changes = [task_definition] }` lets this repo own the ECS service while service-repo CI owns the image in the task definition.
- Split state into stacks by how often they change and how dangerous they are (`bootstrap`, `observability`, `network`, `data`, `platform`, `gateway`), so a bad apply of a frequently changing stack cannot touch the network or database. Stack directories carry no number prefix; the apply order is written in the README.
- Remote state in S3 with native locking. CI authenticates through GitHub OIDC: a read-only plan role for pull requests and a broad apply role usable only from `main` through an approved `production` environment.
- Apply is a manual workflow, one stack at a time, applying a saved plan after approval. No auto-apply.
- Stacks pass values through SSM parameters instead of hardcoded IDs.

## Consequences

- A few more directories than one big root module, in exchange for a smaller blast radius.
- Each dependency costs one SSM lookup.
- The bootstrap stack needs a one-off local-state apply and a state migration.
- PR plans skip refresh so they never read secrets; they do not show drift.
