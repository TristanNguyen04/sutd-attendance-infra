output "db_host" {
  description = "Hostname of the shared PostgreSQL instance."
  value       = aws_db_instance.main.address
}

output "master_secret_arn" {
  description = "Secrets Manager secret (managed by RDS) holding the master credentials."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
