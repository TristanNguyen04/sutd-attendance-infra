# One-off task that creates, for every service, a login role and a database it owns.
# It is idempotent, so it is safe to run again after adding a service. Run it from your
# machine or the console; see "Database bootstrap" in the README.

locals {
  service_names = sort(keys(local.services))
}

resource "aws_cloudwatch_log_group" "db_bootstrap" {
  name              = "/ecs/prod-db-bootstrap"
  retention_in_days = 14
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "db_bootstrap_execution" {
  name               = "prod-db-bootstrap-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "db_bootstrap_execution" {
  role       = aws_iam_role.db_bootstrap_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "db_bootstrap_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = concat(
      [data.aws_ssm_parameter.db_master_secret_arn.value],
      [for m in module.service : m.db_secret_arn],
    )
  }
}

resource "aws_iam_role_policy" "db_bootstrap_secrets" {
  name   = "read-database-secrets"
  role   = aws_iam_role.db_bootstrap_execution.id
  policy = data.aws_iam_policy_document.db_bootstrap_secrets.json
}

resource "aws_ecs_task_definition" "db_bootstrap" {
  family                   = "prod-db-bootstrap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.db_bootstrap_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "bootstrap"
    image     = "public.ecr.aws/docker/library/postgres:16"
    essential = true
    command   = ["bash", "-c", file("${path.module}/scripts/db-bootstrap.sh")]

    environment = [
      { name = "PGHOST", value = data.aws_ssm_parameter.db_host.value },
      { name = "PGPORT", value = data.aws_ssm_parameter.db_port.value },
      { name = "PGDATABASE", value = "postgres" },
      { name = "PGSSLMODE", value = "require" },
      { name = "SERVICES", value = join(" ", local.service_names) },
    ]

    secrets = concat(
      [
        { name = "PGUSER", valueFrom = "${data.aws_ssm_parameter.db_master_secret_arn.value}:username::" },
        { name = "PGPASSWORD", valueFrom = "${data.aws_ssm_parameter.db_master_secret_arn.value}:password::" },
      ],
      [for name in local.service_names : {
        name      = "DB_PASSWORD_${upper(name)}"
        valueFrom = "${module.service[name].db_secret_arn}:password::"
      }],
    )

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.db_bootstrap.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "bootstrap"
      }
    }
  }])
}
