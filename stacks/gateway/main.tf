data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/prod/network/private_subnet_ids"
}

data "aws_ssm_parameter" "sg_vpc_link" {
  name = "/prod/network/sg_vpc_link"
}

data "aws_ssm_parameter" "listener_arn" {
  name = "/prod/platform/listener_arn"
}

data "aws_ssm_parameter" "alerts_topic_arn" {
  name = "/prod/observability/alerts_topic_arn"
}

locals {
  login_route = "POST /v1/auth/login"

  # Reachable without a token. Everything else under /v1 needs a valid JWT.
  public_routes = toset([
    local.login_route,
    "POST /v1/auth/refresh",
    "GET /.well-known/{proxy+}",
    "GET /health",
  ])
}

resource "aws_apigatewayv2_api" "main" {
  name          = "prod-api"
  protocol_type = "HTTP"

  dynamic "cors_configuration" {
    for_each = length(var.cors_allowed_origins) > 0 ? [1] : []

    content {
      allow_origins = var.cors_allowed_origins
      allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
      allow_headers = ["authorization", "content-type", "x-request-id"]
      max_age       = 3600
    }
  }
}

resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "prod"
  subnet_ids         = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  security_group_ids = [data.aws_ssm_parameter.sg_vpc_link.value]
}

# One integration to the internal ALB listener; the ALB routes by path.
resource "aws_apigatewayv2_integration" "alb" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = data.aws_ssm_parameter.listener_arn.value
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.main.id
  name             = "jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.jwt_issuer
    audience = var.jwt_audience
  }
}

resource "aws_apigatewayv2_route" "protected" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /v1/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_route" "public" {
  for_each = local.public_routes

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/apigw/prod-api"
  retention_in_days = 14
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.default_throttle_rate
    throttling_burst_limit = var.default_throttle_burst
  }

  route_settings {
    route_key              = local.login_route
    throttling_rate_limit  = var.login_throttle_rate
    throttling_burst_limit = var.login_throttle_burst
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      method           = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      path             = "$context.path"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      authorizerError  = "$context.authorizer.error"
    })
  }

  depends_on = [aws_apigatewayv2_route.protected, aws_apigatewayv2_route.public]
}

# ---------------------------------------------------------------- custom domain (optional)

resource "aws_acm_certificate" "api" {
  count = var.domain_name != null ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.route53_zone_id != null
      error_message = "route53_zone_id is required when domain_name is set."
    }
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = var.domain_name != null ? {
    for o in aws_acm_certificate.api[0].domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      record = o.resource_record_value
      type   = o.resource_record_type
    }
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  count = var.domain_name != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for r in aws_route53_record.certificate_validation : r.fqdn]
}

resource "aws_apigatewayv2_domain_name" "api" {
  count = var.domain_name != null ? 1 : 0

  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api[0].certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  count = var.domain_name != null ? 1 : 0

  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.api[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "api" {
  count = var.domain_name != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------------- alarm

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "prod-api-5xx"
  alarm_description   = "The public API returned many 5xx responses."
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [data.aws_ssm_parameter.alerts_topic_arn.value]

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.default.name
  }
}
