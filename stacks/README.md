# stacks

Each directory is an independent Terraform root module with its own state. Apply them in this order:

`bootstrap` → `observability` → `network` → `data` → `platform` → `gateway`

| Stack | Changes | Notes |
|---|---|---|
| `bootstrap` | rarely | State bucket, GitHub OIDC provider, plan and apply roles. First apply uses local state, then migrates to S3 (see the root README). |
| `observability` | rarely | SNS alerts topic and the monthly budget. Comes early because other stacks attach alarms to the topic. |
| `network` | rarely | VPC, public and private subnets (no NAT gateway), security groups. |
| `data` | rarely | One shared RDS PostgreSQL instance. Protected against destroy. |
| `platform` | often | ECS cluster, internal ALB, event bus, and the `services` map that drives `modules/service`. Also the one-off db-bootstrap task. |
| `gateway` | rarely | HTTP API, JWT authorizer, VPC link, optional custom domain. Services add their own ALB rules, so routes seldom change. |

## Rules

- A stack reads other stacks' values from SSM parameters (`/prod/<stack>/<key>`), never hardcoded IDs.
- Every stack has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `backend.tf` and a committed `terraform.tfvars`.
- `backend.tf` leaves the bucket unset; pass it at init: `terraform init -backend-config="bucket=<state bucket>"`. Each stack uses its own state `key`.
- Commit each stack's `.terraform.lock.hcl`. Regenerate with `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`.
- Keep the apply order identical in `README.md`, `AGENTS.md`, this file and both workflows (`plan.yml` matrix, `apply.yml` options).

Use the `/add-stack` skill to add a stack.
