data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/prod/network/private_subnet_ids"
}

data "aws_ssm_parameter" "sg_rds" {
  name = "/prod/network/sg_rds"
}

data "aws_ssm_parameter" "alerts_topic_arn" {
  name = "/prod/observability/alerts_topic_arn"
}

locals {
  parameter_family = "postgres${split(".", var.engine_version)[0]}"
}

resource "aws_db_subnet_group" "main" {
  name       = "prod"
  subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

resource "aws_db_parameter_group" "main" {
  name   = "prod-${local.parameter_family}"
  family = local.parameter_family

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

# One shared instance; each service gets its own database and owner role, created by the
# db-bootstrap task in the platform stack. The master password is managed by RDS in Secrets Manager.
resource "aws_db_instance" "main" {
  identifier     = "prod-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  username                    = "dbadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [data.aws_ssm_parameter.sg_rds.value]
  parameter_group_name   = aws_db_parameter_group.main.name
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = var.backup_retention_days
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "prod-postgres-final"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "prod-postgres-cpu"
  alarm_description   = "Database CPU has been above 80% for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [data.aws_ssm_parameter.alerts_topic_arn.value]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "free_storage" {
  alarm_name          = "prod-postgres-free-storage"
  alarm_description   = "Less than 2 GB of free storage."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [data.aws_ssm_parameter.alerts_topic_arn.value]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  alarm_name          = "prod-postgres-connections"
  alarm_description   = "Connection count is close to the instance limit."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.max_connections_alarm
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [data.aws_ssm_parameter.alerts_topic_arn.value]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

resource "aws_ssm_parameter" "exports" {
  for_each = {
    host              = aws_db_instance.main.address
    port              = tostring(aws_db_instance.main.port)
    master_secret_arn = aws_db_instance.main.master_user_secret[0].secret_arn
  }

  name  = "/prod/data/${each.key}"
  type  = "String"
  value = each.value
}
