---
paths:
  - "**/*.tf"
  - ".github/**"
---

# Security and safety

- No secrets in code, tfvars, workflow files or logs. Secrets live in Secrets Manager or SSM SecureString. RDS manages the master password.
- Generated database passwords are ephemeral values written through write-only attributes, so they are not in Terraform state. The RDS master password is managed by RDS. The state bucket is still private, versioned and encrypted. Keep docs consistent with this; if a change puts a secret into state, say so explicitly.
- GitHub Actions authenticates with OIDC. No long-lived AWS keys, ever. Trust policies pin the exact repo and ref or environment (`repo:OWNER/REPO:ref:refs/heads/main`), never a wildcard on the repo.
- Security groups: no `0.0.0.0/0` ingress. Tasks accept traffic only from the ALB security group; RDS only from the services security group.
- S3 buckets: public access block on, versioning on where state or data matters, encryption on.
- RDS and the state bucket keep `prevent_destroy`, deletion protection and a final snapshot.
- Least privilege for every role. The apply role may be broad (AdministratorAccess) but only trusts `main` through the `production` environment. The plan role is read-only.
- `iam:PassRole` is always restricted by resource and by `iam:PassedToService`.
- Public routes on the gateway are an explicit short list. Everything else sits behind the JWT authorizer.
- Anything that opens network access, widens IAM or disables a protection needs a line in the PR description explaining why.
