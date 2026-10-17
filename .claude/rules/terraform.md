---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
---

# Terraform style

- Files per stack: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `backend.tf`. Split `main.tf` by concern (`alb.tf`, `iam.tf`) once it passes about 200 lines.
- Every variable has `type` and `description`. Add `validation` for values that must not be placeholders or that have a fixed shape.
- Every output has a `description`.
- Use `for_each` over `count` for collections, so removing an item does not shift the others. `count` is fine for a simple on/off switch.
- Resource names are `prod-<component>`. Terraform resource labels are `snake_case`; use `this` only when a module creates exactly one of a kind.
- Tags come from the provider's `default_tags`. Add resource tags only for `Name` or when a resource needs something extra.
- Pin `required_version` and every provider with `~>`. Never use `latest` or an unpinned module.
- Prefer data sources and SSM parameters over hardcoded ARNs and IDs. No account IDs in code.
- IAM policies use `aws_iam_policy_document` data sources, not inline JSON strings. Scope `Resource` to specific ARNs; use `*` only where the API requires it and add a short comment saying why.
- Comments explain *why*, not what. Do not leave commented-out code.
- Run `make fmt` before committing.
