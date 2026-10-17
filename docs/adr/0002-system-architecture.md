# 2. System architecture

Status: Accepted

## Context

Three teams own five functional branches (permissions, attendance records, verify attendance, appeals, sessions). Clients should call one URL. Teams need independent deploys and data.

## Decision

- One backend service per branch, each with its own database, all written in Rust with Loco.
- Clients call one URL: API Gateway (HTTP API) with a JWT authorizer, through a VPC link, to an internal ALB that routes by path: `/v1/<branch>/*` from the gateway, `/internal/<branch>/*` for service-to-service calls only.
- Services run on ECS Fargate. One container per service runs the web server, Loco workers and the event loops.
- Synchronous queries use internal HTTP. State changes are events: a shared EventBridge bus (`prod-events`), one SQS queue (with DLQ) per consumer service, outbox on the publisher, idempotent consumers. Events use the publishing service's name as `Source` and `<Event>.v<N>` as `DetailType`.
- One shared RDS PostgreSQL instance, one database and one owner role per service, created by a one-off db-bootstrap task. Generated passwords never enter Terraform state.
- Tokens are issued by the permissions service (username and password login). Services enforce roles and ownership themselves.
- Service repos own their task definitions and run migrations (SeaORM, one-off ECS task) before each service update.

## Consequences

- Eventual consistency and cross-service debugging cost. Mitigated with correlation IDs and DLQ alarms.
- One shared RDS instance is cheaper but is a shared failure point. Databases and roles keep ownership separate.
- Cron or resilience jobs are deferred. They will run as EventBridge Scheduler to ECS RunTask, outside the web service.
