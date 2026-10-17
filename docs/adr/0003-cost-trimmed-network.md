# 3. Cost-trimmed network

Status: Proposed

## Context

This is a student project on a personal AWS account, prod only. A NAT gateway is usually the largest avoidable fixed cost, and an ALB is the second.

## Decision

- Keep the internal ALB, since path routing there keeps the gateway stable as services are added.
- No NAT gateway. ECS tasks run in public subnets with a public IP, but their security groups accept traffic only from the ALB. The database stays in private subnets.
- One task per service, 0.25 vCPU, ARM64 where the image supports it.
- Configuration in SSM Parameter Store rather than Secrets Manager where a secret is not required.
- An AWS Budget alarm from day one.

## Consequences

- Roughly half the monthly cost of the fully private layout, by rough estimate. Verify with the AWS Pricing Calculator.
- Tasks are reachable from the internet at the network level, protected by security groups only.
- If requirements change, moving tasks to private subnets with a NAT gateway or VPC endpoints is a change in the `network` and `platform` stacks.
