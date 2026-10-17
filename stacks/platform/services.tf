# One entry per backend service. Adding a service is adding an entry here.
#
# Event contracts below are proposals; adjust them when the teams agree the contracts.
# Published events use the service name as the EventBridge source and "<Name>.v<N>" as the detail-type.
#
# The permissions service (owned by another team) will need extra_paths so login and the
# OIDC discovery endpoints are reachable through the gateway:
#   extra_paths = ["/v1/auth/*", "/.well-known/*"]
locals {
  services = {
    sessions = {
      github_repo   = "${var.github_owner}/${var.sessions_repo}"
      priority      = 100
      cpu           = 256
      memory        = 512
      extra_paths   = []
      subscriptions = []
    }

    appeals = {
      github_repo = "${var.github_owner}/${var.appeals_repo}"
      priority    = 200
      cpu         = 256
      memory      = 512
      extra_paths = []
      subscriptions = [
        {
          source = "sessions"
          detail_types = [
            "SessionScheduled.v1",
            "SessionRescheduled.v1",
            "SessionCancelled.v1",
            "SessionClosed.v1",
          ]
        },
        {
          source       = "records"
          detail_types = ["RecordCorrected.v1", "RecordCorrectionFailed.v1"]
        },
      ]
    }
  }
}

# Fails the plan if two services share an ALB rule priority.
resource "terraform_data" "check_services" {
  lifecycle {
    precondition {
      condition     = length(distinct([for s in local.services : s.priority])) == length(local.services)
      error_message = "Every service needs a unique ALB rule priority."
    }
  }
}

module "service" {
  source   = "../../modules/service"
  for_each = local.services

  name        = each.key
  github_repo = each.value.github_repo
  priority    = each.value.priority
  cpu         = each.value.cpu
  memory      = each.value.memory
  extra_paths = each.value.extra_paths

  subscriptions = each.value.subscriptions

  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  cluster_name      = aws_ecs_cluster.main.name
  cluster_arn       = aws_ecs_cluster.main.arn
  vpc_id            = local.vpc_id
  subnet_ids        = local.public_subnet_ids
  security_group_id = data.aws_ssm_parameter.sg_services.value
  listener_arn      = aws_lb_listener.http.arn
  alb_arn_suffix    = aws_lb.internal.arn_suffix
  event_bus_name    = aws_cloudwatch_event_bus.main.name
  event_bus_arn     = aws_cloudwatch_event_bus.main.arn
  db_host           = data.aws_ssm_parameter.db_host.value
  db_port           = tonumber(data.aws_ssm_parameter.db_port.value)
  alerts_topic_arn  = data.aws_ssm_parameter.alerts_topic_arn.value

  depends_on = [terraform_data.check_services]
}
