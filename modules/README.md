# modules

Reusable building blocks used by the stacks. Add a module only when two or more places need it.

## service

Everything one backend service needs. Used by `stacks/platform/services.tf` with one instance per service.

Creates: ECR repository (keeps the last 20 images), log group, database credentials in Secrets Manager (write-only, not in state), task and execution roles, a seed task definition, the ECS service (created at desired count 0), target group, ALB listener rule for `/v1/<name>/*` and `/internal/<name>/*`, an optional SQS queue with a DLQ plus EventBridge rules, three alarms, the GitHub OIDC deploy role for the service's repo, and SSM parameters its CI reads.

How deploys work: Terraform owns the service shell and the task definition's roles, logging, environment and secrets. The service repo's CI clones the latest task definition revision, swaps the image, registers it and updates the service. The service ignores `task_definition` and `desired_count` changes for that reason. Details in [docs/service-deploy.md](../docs/service-deploy.md).

Convention the container must follow: listen on port 8080, answer `GET /_ping` with 200, read `DATABASE_URL` from the environment.
