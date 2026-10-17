# Deploying a service from its own repo

For the people who own a service repo (sessions, appeals, and the other teams'). The infra repo has already created everything around your service; your CI only ships new images.

## What you get from infra

- IAM role `prod-deploy-<name>`, assumable by GitHub Actions of your repo's `main` branch through OIDC. Store its ARN as the repository variable `AWS_DEPLOY_ROLE_ARN`. No access keys.
- ECR repository `prod-<name>`.
- ECS service `prod-<name>` in cluster `prod`, task definition family `prod-<name>`. The service starts at 0 tasks.
- SSM parameters `/prod/<name>/{cluster,service,task_family,subnets,security_group,ecr_repository,log_group}`. Your role can read them.
- Environment variables set in the container: `LOCO_ENV=production`, `PORT=8080`, `SERVICE_NAME`, `AWS_REGION`, `EVENT_BUS_NAME`, `RUN_EVENT_LOOPS`, and `EVENT_QUEUE_URL` if the service consumes events. Secret: `DATABASE_URL`.

## What your container must do

- Listen on **port 8080**.
- Answer `GET /_ping` with 200 (the ALB health check).
- Serve your API under `/v1/<name>/*` and service-to-service endpoints under `/internal/<name>/*`.
- Publish events to the bus `EVENT_BUS_NAME` with `Source` = your service name and `DetailType` = `<Event>.v<N>`.

## Deploy sequence (per merge to main)

1. Build the image, tag it with the commit SHA, push to ECR.
2. Take the latest revision of the task definition family, replace the container image, register it as a new revision. (`aws ecs describe-task-definition`, edit with `jq`, `aws ecs register-task-definition`.)
3. Run migrations as a one-off task from the new revision, using a command override, and wait for exit code 0. Stop the pipeline if it fails.
   ```
   aws ecs run-task --cluster prod --launch-type FARGATE --task-definition <new revision arn> \
     --overrides '{"containerOverrides":[{"name":"app","command":["db","migrate"]}]}' \
     --network-configuration "awsvpcConfiguration={subnets=[...],securityGroups=[...],assignPublicIp=ENABLED}"
   ```
   The exact command depends on how the Loco binary is named in your image.
4. Update the service to the new revision (`--desired-count 1` on the first deploy, because infra creates it at 0) and wait until it is stable. The circuit breaker rolls back a deployment whose tasks keep failing.
5. Smoke test through the gateway.

Run one deploy at a time per repo (a GitHub Actions `concurrency` group).

## Rules

- Migrations are SeaORM migrations, always run before the service update. Never edit a migration that has been applied; add a new one. Keep them backward compatible (expand, then contract), because old tasks run against the new schema during a rolling deploy.
- To roll back, deploy the previous task definition revision directly. Do not rely on down migrations.
- Your role and (empty) database are created automatically when the platform maintainers apply your service's entry. Your migrations create the tables.
