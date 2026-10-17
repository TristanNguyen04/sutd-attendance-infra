output "deploy_role_arns" {
  description = "Per service: the IAM role its GitHub Actions workflow assumes. Set each as the AWS_DEPLOY_ROLE_ARN variable in that service's repository."
  value       = { for name, m in module.service : name => m.deploy_role_arn }
}

output "ecr_repository_urls" {
  description = "Per service: the ECR repository its CI pushes images to."
  value       = { for name, m in module.service : name => m.ecr_repository_url }
}

output "db_bootstrap_task_definition" {
  description = "Task definition family to run once to create the per-service databases and roles."
  value       = aws_ecs_task_definition.db_bootstrap.family
}
