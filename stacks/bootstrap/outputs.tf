output "state_bucket" {
  description = "Name of the S3 bucket that holds Terraform state. Use it for -backend-config and the TF_STATE_BUCKET GitHub variable."
  value       = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN GitHub variable of this repository."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN GitHub variable of this repository."
  value       = aws_iam_role.apply.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}
