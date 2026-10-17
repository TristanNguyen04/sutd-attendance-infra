---
name: add-stack
description: Scaffold a new Terraform stack in this repo following its conventions (files, backend, providers, tags, lock file, docs, apply order). Use when asked to add a new stack under stacks/.
---

# Add a stack

Only add a stack when the resources have a different change frequency or blast radius from the existing ones. Otherwise extend an existing stack.

1. Pick a short lowercase name with no number prefix (for example `observability`). Decide where it sits in the apply order.
2. Create `stacks/<name>/` with `versions.tf`, `backend.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars`. Copy `versions.tf` and `backend.tf` from an existing stack, then change the state `key` to `<name>/terraform.tfstate`.
3. `versions.tf`: `required_version = ">= 1.11"`, `hashicorp/aws ~> 6.0`, an `aws` provider with `region = var.region` and `default_tags` (`project=attendance`, `managed-by=terraform`, `repo=sutd-attendance-infra`).
4. Export values other stacks need as `aws_ssm_parameter` resources under `/prod/<name>/<key>`. Read other stacks' values with `data "aws_ssm_parameter"`.
5. Put non-secret inputs in `terraform.tfvars`. Add `validation` blocks that reject `CHANGE_ME` for values the user must supply.
6. Generate the lock file: `terraform -chdir=stacks/<name> init -backend=false` then `terraform -chdir=stacks/<name> providers lock -platform=linux_amd64 -platform=darwin_arm64`.
7. Add the stack to the apply order in `AGENTS.md`, `README.md`, `stacks/README.md` and the choice list in `.github/workflows/apply.yml`, plus the plan matrix in `.github/workflows/plan.yml`.
8. Run `make fmt` and `make check`. Do not run `terraform apply`.
