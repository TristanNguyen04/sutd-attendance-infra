# Onboarding a service

For teams that want to add a backend service to the platform (new database, API routes, event subscriptions). You do not need AWS access. You change one file in this repo through a pull request, the platform maintainers review and apply it, and then your service repo deploys itself.

## How it works

```
1. You open a PR to this repo        adds ONE entry to stacks/platform/services.tf
2. CI + plan check the PR            mistakes fail with a clear message
3. Platform maintainers review/merge, then run the "apply" workflow for "platform"
      -> creates your ECS service, ECR repo, database + login, queue, alarms, deploy role
4. You set one variable in your repo and deploy from your own CI  (see docs/service-deploy.md)
```

You never create a database, an API route or a queue by hand. They all come from your entry.

## Before you start

- Your service repo exists on GitHub and its default branch is **`main`**. Deploys are only allowed from `main`.
- You know the exact `OWNER/REPO` (capital letters count).
- Your container will:
  - listen on **port 8080**
  - answer `GET /_ping` with 200
  - serve its API under **`/v1/<name>/*`** (public) and **`/internal/<name>/*`** (service-to-service only)
  - read `DATABASE_URL` from the environment

## Step 1: add your entry

Edit `stacks/platform/services.tf` and add one entry to `local.services`, next to the existing ones. Use the literal `OWNER/REPO` string for `github_repo`.

```hcl
yourservice = {
  github_repo = "OWNER/your-repo"
  priority    = 300          # next free number: existing services use 100, 200; take 300, 400, ...
  cpu         = 256
  memory      = 512
  extra_paths = []
  subscriptions = [
    { source = "sessions", detail_types = ["SessionClosed.v1"] },
  ]
}
```

| Field | Rule |
|---|---|
| Entry name (`yourservice`) | 2-20 characters, lowercase letters and digits only, starts with a letter. It becomes `prod-yourservice`, the path `/v1/yourservice/*`, and your database name. |
| `github_repo` | `OWNER/REPO` exactly as on GitHub. |
| `priority` | Must be unique across all services and at least 100. |
| `cpu` / `memory` | Start with 256 / 512. Each service adds roughly $11 per month (a task, its public IP, a secret, alarms). Ask before going bigger. |
| `extra_paths` | Only if you need routes outside `/v1/yourservice/*` (see below). |
| `subscriptions` | The events you consume (see Events). Empty list if you only publish. |

Do not touch other entries or other stacks in the same PR. Changes to `network`, `data`, `gateway`, `bootstrap` or `modules/` need a discussion with the maintainers first.

## Step 2: open the pull request

1. Branch from `main`, commit, push the branch, open a PR. Do not push to `main`.
2. Fill in the PR template. Mention the monthly cost your service adds.
3. CI (`check`) must pass. The plan job shows what will be created: roughly an ECR repo, a log group, a secret, two IAM roles plus a deploy role, a task definition, an ECS service, a target group and ALB rule, alarms, and (if you subscribe to events) a queue with a dead-letter queue and one rule per source.
4. The platform maintainers review it (CODEOWNERS requests them automatically) and merge it.

## Step 3: wait for the apply

A maintainer runs the `apply` workflow for `platform` and approves it. The workflow also runs the database setup task, which creates your login role and an empty database with your name. When it is done they send you your **deploy role ARN**, which looks like `arn:aws:iam::<account>:role/prod-deploy-yourservice`. It also appears in the apply log under outputs (`deploy_role_arns`).

## Step 4: connect your service repo

1. In your repo, add the variable `AWS_DEPLOY_ROLE_ARN` (Settings, Secrets and variables, Actions, Variables) with that ARN. It is not a secret.
2. In your deploy workflow use GitHub OIDC (no access keys): `permissions: id-token: write` and `aws-actions/configure-aws-credentials` with `role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}`. The role can only be assumed by runs on `main`.
3. Follow the deploy sequence in [service-deploy.md](service-deploy.md): build and push the image, register a new task definition revision, run migrations, update the service.

## Common tasks

| You want to... | Do this |
|---|---|
| **A new database** | It comes with your entry. Your migrations (SeaORM) create the tables; your login owns the database. Never ask for the admin password. |
| **New API endpoints** | Nothing in this repo if they stay under `/v1/yourservice/*`. Add the routes in your service and deploy. They require a valid token automatically. |
| **Endpoints for other services only** | Put them under `/internal/yourservice/*`. The gateway never exposes this prefix. |
| **A route outside `/v1/yourservice/*`** | Add the pattern to your entry's `extra_paths`, for example `["/.well-known/*"]`. If it must work **without a token**, it also needs a route in `stacks/gateway/main.tf` (`local.public_routes`); open that as a separate PR and say why. |
| **Consume an event** | Add it to `subscriptions` in your entry (see below) and apply. |
| **Publish an event** | Nothing to register. Publish to the bus named in `EVENT_BUS_NAME` with `Source` = your service name and `DetailType` = `<Event>.v<N>`. |
| **More CPU or memory** | Change `cpu` / `memory` in your entry and explain the cost in the PR. |
| **Remove a service** | Do not delete the entry. Ask the maintainers; the database is not removed by Terraform and needs a deliberate decision. |

## Events

Subscribe by listing the exact `source` and `detail_types`:

```hcl
subscriptions = [
  { source = "sessions", detail_types = ["SessionClosed.v1", "SessionCancelled.v1"] },
  { source = "records",  detail_types = ["RecordCorrected.v1"] },
]
```

- Matching is exact. A new event type or a `.v2` is delivered only after you add it here and `platform` is applied again.
- You get one queue; its URL is in `EVENT_QUEUE_URL`. Messages that fail five times land in a dead-letter queue, which raises an alarm.
- Delivery is at least once and not ordered. Deduplicate on the envelope `id` and ignore stale versions.
- A subscription to an event nobody publishes is not an error; it just never receives anything. Test with a real event.
- Agree event names and payloads with the publishing team in the shared contracts, not in this repo.

## Special case: the permissions service

It also hosts login and token discovery, which must be reachable without a token. Its entry adds `extra_paths = ["/v1/auth/*", "/.well-known/*"]`. The gateway already has public routes for `POST /v1/auth/login`, `POST /v1/auth/refresh` and `GET /.well-known/*`, so no gateway change is needed unless it adds more public endpoints.

## Environment you get

`LOCO_ENV=production`, `PORT=8080`, `SERVICE_NAME`, `AWS_REGION`, `EVENT_BUS_NAME`, `RUN_EVENT_LOOPS`, `EVENT_QUEUE_URL` (if you subscribe), and the secret `DATABASE_URL`. Need more configuration? Ask the maintainers; it is added in the module, not by hand.

## If something goes wrong

| Symptom | Likely cause |
|---|---|
| Plan fails: "name must be 2-20 characters" | Entry name has capitals, hyphens or underscores |
| Plan fails: "unique ALB rule priority" | Another service already uses that `priority` |
| Plan fails: "github_repo must look like OWNER/REPO" | Typo, or the placeholder is still there |
| Deploy fails at "Configure AWS credentials" | Wrong `AWS_DEPLOY_ROLE_ARN`, wrong repo name or capitalisation in `github_repo`, or the run is not on `main` |
| Tasks keep restarting after deploy | Container does not listen on 8080 or `/_ping` does not return 200 |
| Cannot connect to the database | The setup task has not run for your service yet, or `DATABASE_URL` is not read from the environment |
| Events never arrive | Wrong `source` or `detail_types` in `subscriptions`, or `platform` was not applied after the change |

Questions or a failed apply: ask the platform maintainers and include the link to the run.
