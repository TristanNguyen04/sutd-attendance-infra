# sutd-attendance-infra

Terraform for the shared AWS infrastructure of the SUTD attendance system: network, database, ECS platform, event bus, and the public API gateway.

Owned by Team 1-3. One AWS account, **prod only**, region `us-east-1`. Application services (sessions, appeals, and the other teams') live in their own repos; they build images and deploy from their own CI. This repo owns everything around them.

## Layout

```
stacks/                  each directory is its own root module with its own state
  bootstrap/             state bucket, GitHub OIDC provider, plan and apply roles
  observability/         alerts topic, monthly budget
  network/               VPC, subnets, security groups
  data/                  shared RDS PostgreSQL instance
  platform/              ECS cluster, internal ALB, event bus, services (see services.tf), db-bootstrap task
  gateway/               API Gateway HTTP API, JWT authorizer, VPC link, optional custom domain
modules/service/         everything one backend service needs
docs/                    ADRs and the deploy guide for service repos
.claude/ AGENTS.md       rules, skills and a reviewer agent for AI-assisted work in this repo
```

**Apply order** (stacks have no numeric prefixes, so the order lives here): `bootstrap`, `observability`, `network`, `data`, `platform`, `gateway`. Each later stack reads values the earlier ones publish to SSM under `/prod/<stack>/...`.

## What gets built

```
clients ─► API Gateway (HTTP API, JWT authorizer) ─► VPC link ─► internal ALB ─► ECS Fargate services
                                                                    /v1/<service>/*          │
                                                                    /internal/<service>/*    ├─► shared RDS (one database + role per service)
                                                                                             └─► EventBridge bus ─► one SQS queue (+DLQ) per consumer
```

- The gateway forwards `/v1/*`. `/internal/*` is reachable only from inside the VPC.
- Public routes (no token): `POST /v1/auth/login`, `POST /v1/auth/refresh`, `GET /.well-known/*`, `GET /health`. Login is throttled harder.
- The gateway cannot serve real traffic until the permissions service publishes `/.well-known/openid-configuration` and its keys at the issuer URL, and tokens carry the configured `aud`.
- Cost is kept low on purpose, see [ADR 0003](docs/adr/0003-cost-trimmed-network.md).

## Conventions

- Terraform version pinned in `.terraform-version`; providers pinned with `~>`; `.terraform.lock.hcl` committed per stack for Linux and macOS ARM.
- Resource names `prod-<component>`. Provider `default_tags`: `project=attendance`, `managed-by=terraform`, `repo=sutd-attendance-infra`.
- No secrets in code, tfvars or workflows. Generated database passwords are ephemeral values written to Secrets Manager through write-only attributes, so they are **not** in Terraform state. The RDS master password is managed by RDS.
- Stateful resources (RDS, state bucket) have `prevent_destroy` and deletion protection.
- `terraform.tfvars` holds non-secret inputs. Values still set to `CHANGE_ME` are rejected by validation, so a plan fails loudly instead of using a placeholder.
- A new backend service is one entry in `stacks/platform/services.tf`.

## Workflow

1. Branch and open a pull request. `ci` runs `make check` (fmt, validate every stack, tflint). `plan` shows each stack's plan using a read-only role.
2. Merge to `main`.
3. Run the `apply` workflow once per stack that changed, in apply order. It plans, waits for approval on the `production` environment, then applies that exact plan.

Run the same checks locally with `make check` (needs `terraform` and `tflint`; versions in `.terraform-version` and `.github/workflows/ci.yml`).

PR plans use `-refresh=false` and a role that cannot read secrets, so they never expose secret values. The trade-off is that they do not detect drift.

## First-time setup (one-off)

1. Secure the AWS account: MFA on the root user, no root access keys. Work as an admin IAM user (or Identity Center user) with MFA, never as root. Sign in from the terminal with `aws login --profile sutd-admin`, then `export AWS_PROFILE=sutd-admin` and check `aws sts get-caller-identity`.
2. Edit the `CHANGE_ME` values: `github_owner` in `bootstrap` and `platform`, `alert_email` in `observability`, the two service repo names in `platform`. `jwt_issuer` in `gateway` can wait until `gateway` is applied.
3. Apply `bootstrap` with local state, then move its state into the bucket it creates. Read the bucket name before restoring `backend.tf`, because `terraform output` stops working once the backend is configured but not yet initialised:
   ```
   cd stacks/bootstrap
   mv backend.tf backend.tf.off
   terraform init && terraform apply
   BUCKET=$(terraform output -raw state_bucket)
   mv backend.tf.off backend.tf
   terraform init -migrate-state -backend-config="bucket=$BUCKET"
   ```
   Answer `yes` when it asks to copy the existing state to S3.
   An AWS account can have only one GitHub OIDC provider. If yours already has one, set `create_oidc_provider = false` in `stacks/bootstrap/terraform.tfvars` (done for the current account): the stack then only looks it up and never changes or destroys it, so other projects using it are safe.
4. In the GitHub repository settings: add variables `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN` and `TF_STATE_BUCKET` (from the bootstrap outputs), and create an environment named `production` that requires a reviewer and only allows the `main` branch.
5. Apply the remaining stacks in order with the `apply` workflow. Confirm the SNS email subscription from the email AWS sends.
6. Give each service repo its deploy role (see [docs/service-deploy.md](docs/service-deploy.md)). Service databases are created by the `apply` workflow when `platform` is applied.

### Database bootstrap

The `apply` workflow runs this automatically after it applies `platform`, so registering a service needs no extra command. It creates each service's role and database and is idempotent. Only if you apply `platform` from your own machine do you need to run the task by hand:

```
aws ecs run-task --cluster prod --launch-type FARGATE --task-definition prod-db-bootstrap \
  --network-configuration "awsvpcConfiguration={subnets=[<ids from /prod/network/public_subnet_ids>],securityGroups=[<id from /prod/network/sg_services>],assignPublicIp=ENABLED}"
```

Read its output in the `/ecs/prod-db-bootstrap` log group. The script is idempotent.

## Not verified yet

- Nothing has been planned or applied. AWS credentials were not available when this was written.
- `make check` only checks syntax and provider schemas, not IAM permissions or runtime behaviour.
- The SQL in `stacks/platform/scripts/db-bootstrap.sh` (role membership on RDS PostgreSQL 16, `\gexec`) and the workflow step that runs it have not run against a real instance.
- API Gateway access logging to CloudWatch has not been tried end to end.
- The Loco services' own contracts (config, port 8080, `/_ping`, event names) are proposals until the teams agree them.

## For other teams

Adding a service, a database, API routes or event subscriptions: follow [docs/onboarding.md](docs/onboarding.md). Deploying once registered: [docs/service-deploy.md](docs/service-deploy.md).

## Decisions

See [docs/adr](docs/adr).
