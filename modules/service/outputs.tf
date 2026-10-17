output "ecr_repository_url" {
  description = "ECR repository URL the service repo pushes images to."
  value       = aws_ecr_repository.this.repository_url
}

output "deploy_role_arn" {
  description = "IAM role the service repo's GitHub Actions workflow assumes."
  value       = aws_iam_role.deploy.arn
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the service's database credentials."
  value       = aws_secretsmanager_secret.db.arn
}

output "queue_url" {
  description = "URL of the service's event queue, or null if it consumes no events."
  value       = local.has_queue ? aws_sqs_queue.events[0].url : null
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}
