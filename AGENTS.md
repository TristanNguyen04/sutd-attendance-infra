# Agent guide for `sutd-attendance-infra`

Terraform for the shared AWS infrastructure of the SUTD attendance system (network, database, ECS platform, event bus, public API gateway). Owned by Team 1-3. One AWS account, **prod only**, region `us-east-1`. Keep it simple and cheap: do not add components that the decisions in `docs/adr/` do not call for.

Read `README.md` for the full picture and `docs/adr/` for why things are the way they are.

## Layout

```
stacks/<name>/   independent root module, own state. Apply order is below.
modules/service/ one backend service: ECR, ECS service shell, target group, ALB rule, IAM, logs, SQS + DLQ, alarms, deploy role
docs/adr/        decision records
.claude/         rules, skills and the reviewer agent for this repo
```

Apply order (stacks have no numeric prefixes, so the order is written down in text; keep `README.md`, `stacks/README.md`, `plan.yml` and `apply.yml` in sync):

`bootstrap` -> `observability` -> `network` -> `data` -> `platform` -> `gateway`

Observability comes second because later stacks attach alarms to its SNS topic.

Stacks read each other's outputs from SSM parameters under `/prod/<stack>/...`, never hardcoded IDs.

## Hard rules

- **Never run `terraform apply`, `terraform destroy`, `terraform state rm`, `terraform force-unlock`, or any AWS command that creates, changes or deletes resources**, unless the user explicitly asks in that message. `.claude/settings.json` blocks the first four. `terraform plan` needs AWS credentials the user has to provide.
- No secrets in code, tfvars, logs or commit messages. Never read or print `*.tfstate` or `.env` files.
- Stateful resources (RDS, state bucket) keep `prevent_destroy` and deletion protection. Do not weaken them to make a change easier.
- Do not commit or push unless the user asks. Never push to `main`: work on a branch and open a pull request. The user merges it (or asks you to) once `ci` is green.
- Do not invent other teams' repos, domains, emails or account IDs. Use the placeholder values and validations already in the tfvars files.

## Commands

```
make fmt        format all Terraform
make check      fmt-check + validate (every stack) + tflint; run before every PR
```

CI runs `make check` on every pull request. Plan runs on pull requests once the AWS role variables exist; apply is a manual workflow with an approval.

## Conventions (details in `.claude/rules/`)

- Terraform `>= 1.11`, version pinned in `.terraform-version`. Providers pinned, `.terraform.lock.hcl` committed per stack.
- Names `prod-<component>`; tags via provider `default_tags` (`project=attendance`, `managed-by=terraform`, `repo=sutd-attendance-infra`).
- Each stack: `main.tf variables.tf outputs.tf versions.tf backend.tf` and a committed `terraform.tfvars` with non-secret values.
- Variables have types and descriptions. Placeholders (`CHANGE_ME`) are rejected by validation so a plan fails loudly.
- Public API paths `/v1/<service>/*`; service-to-service `/internal/<service>/*` is never routed by the gateway.
- Update the README and the relevant ADR in the same change as the code.

## Skills and reviewer

- `/add-stack` scaffold a new stack. `/add-service` onboard a backend service. `/write-adr` record a decision.
- `.claude/agents/reviewer.md` is a read-only reviewer. Use it on a finished change before opening a PR.

## What validation cannot tell you

`make check` only checks syntax and provider schemas. It does not check IAM permissions, that SQL runs on a real database, or what a plan will change. Say so when reporting results, and say when nothing was planned or applied.
