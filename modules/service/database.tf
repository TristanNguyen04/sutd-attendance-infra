# The password is generated as an ephemeral value and written through a write-only
# attribute, so it is never stored in Terraform state.
ephemeral "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "prod/${var.name}/database"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string_wo = jsonencode({
    username = var.name
    password = ephemeral.random_password.db.result
    host     = var.db_host
    port     = var.db_port
    dbname   = var.name
    url      = "postgres://${var.name}:${ephemeral.random_password.db.result}@${var.db_host}:${var.db_port}/${var.name}?sslmode=require"
  })
  secret_string_wo_version = var.db_secret_version
}
