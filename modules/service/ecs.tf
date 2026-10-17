# Terraform seeds the task definition (roles, logging, environment, secrets). The service
# repo's CI clones the latest revision, swaps the image, registers it and updates the
# service. The service therefore ignores task_definition and desired_count changes.
resource "aws_ecs_task_definition" "this" {
  family                   = local.full_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  # Keep old revisions: the running service may still point at one.
  skip_destroy = true

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([{
    name         = "app"
    image        = "${aws_ecr_repository.this.repository_url}:bootstrap"
    essential    = true
    stopTimeout  = 30
    portMappings = [{ containerPort = local.container_port, protocol = "tcp" }]

    environment = concat(
      [
        { name = "LOCO_ENV", value = "production" },
        { name = "PORT", value = tostring(local.container_port) },
        { name = "SERVICE_NAME", value = var.name },
        { name = "AWS_REGION", value = data.aws_region.current.region },
        { name = "EVENT_BUS_NAME", value = var.event_bus_name },
        { name = "RUN_EVENT_LOOPS", value = "true" },
      ],
      local.has_queue ? [{ name = "EVENT_QUEUE_URL", value = aws_sqs_queue.events[0].url }] : [],
    )

    secrets = [
      { name = "DATABASE_URL", valueFrom = "${aws_secretsmanager_secret.db.arn}:url::" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

resource "aws_lb_target_group" "this" {
  name                 = local.full_name
  port                 = local.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = local.paths
    }
  }
}

resource "aws_ecs_service" "this" {
  name                               = local.full_name
  cluster                            = var.cluster_arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener_rule.this]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
