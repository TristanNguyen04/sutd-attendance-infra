data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  full_name      = "prod-${var.name}"
  container_port = 8080
  has_queue      = length(var.subscriptions) > 0
  subscriptions  = { for s in var.subscriptions : s.source => s }
  paths          = concat(["/v1/${var.name}/*", "/internal/${var.name}/*"], var.extra_paths)
}
