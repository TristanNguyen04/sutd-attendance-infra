data "aws_ssm_parameter" "vpc_id" {
  name = "/prod/network/vpc_id"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/prod/network/public_subnet_ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/prod/network/private_subnet_ids"
}

data "aws_ssm_parameter" "sg_alb" {
  name = "/prod/network/sg_alb"
}

data "aws_ssm_parameter" "sg_services" {
  name = "/prod/network/sg_services"
}

data "aws_ssm_parameter" "alerts_topic_arn" {
  name = "/prod/observability/alerts_topic_arn"
}

data "aws_ssm_parameter" "db_host" {
  name = "/prod/data/host"
}

data "aws_ssm_parameter" "db_port" {
  name = "/prod/data/port"
}

data "aws_ssm_parameter" "db_master_secret_arn" {
  name = "/prod/data/master_secret_arn"
}

# Created by the bootstrap stack. One provider per URL exists in the account.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

resource "aws_ecs_cluster" "main" {
  name = "prod"

  setting {
    name  = "containerInsights"
    value = "disabled" # extra metrics cost money; the CloudWatch alarms in the service module are enough
  }
}

resource "aws_cloudwatch_event_bus" "main" {
  name = "prod-events"
}

# ---------------------------------------------------------------- internal ALB

resource "aws_lb" "internal" {
  name                       = "prod-internal"
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = local.private_subnet_ids
  security_groups            = [data.aws_ssm_parameter.sg_alb.value]
  drop_invalid_header_fields = true
  enable_deletion_protection = true
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP" # traffic stays inside the VPC; TLS ends at API Gateway

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "not found"
      status_code  = "404"
    }
  }
}

# Answers the gateway's public GET /health without involving any service.
resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "ok"
      status_code  = "200"
    }
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "prod-internal-alb-5xx"
  alarm_description   = "The internal ALB itself returned 5xx responses."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_ssm_parameter.alerts_topic_arn.value]

  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
  }
}

# ---------------------------------------------------------------- values for other stacks

resource "aws_ssm_parameter" "exports" {
  for_each = {
    listener_arn   = aws_lb_listener.http.arn
    cluster_name   = aws_ecs_cluster.main.name
    event_bus_name = aws_cloudwatch_event_bus.main.name
  }

  name  = "/prod/platform/${each.key}"
  type  = "String"
  value = each.value
}
