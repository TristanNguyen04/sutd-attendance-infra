---
name: add-service
description: Onboard a new backend service to the platform by adding an entry to the services map in stacks/platform. Use when a team (ours or another) needs an ECS service, ALB routes, queue, database and deploy role.
---

# Add a service

A service is one entry in `local.services` in `stacks/platform/services.tf`. The `modules/service` module creates everything else.

1. Collect from the requester: service `name` (lowercase, becomes `prod-<name>`), the GitHub repo (`OWNER/REPO`), CPU and memory (default 256 / 512), and which events it consumes (`source` and `detail_types`).
2. Choose an unused `priority` for the ALB rule. Priorities are unique across the map (validation enforces it); keep each team in its own range. `/health` has a reserved priority.
3. Add the entry. Do not invent repos or event names; if unknown, ask.
4. Add the name to the database list so the db-bootstrap task creates its role and database. This is derived from the same map; verify rather than duplicating.
5. Run `make fmt` and `make check`.
6. In the PR description note: new ongoing cost (a Fargate task at desired count 1, a log group, a queue), and that the first deploy needs the service repo's CI to set `--desired-count 1`, because Terraform creates the service at count 0.
7. The `apply` workflow runs the db-bootstrap task automatically after applying `platform`, which creates the service's role and database. If the maintainer applies from their own machine, they run it by hand (README section "Database bootstrap").

Do not run `terraform apply`.
