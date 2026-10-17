data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Two AZs: the ALB requires at least two. See ADR 0003 for why there is no NAT gateway.
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i) }
  private_subnets = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 10) }
  container_port  = 8080
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "prod" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "prod" }
}

# Public subnets hold the Fargate tasks (they need to reach ECR and AWS APIs without a NAT gateway).
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = { Name = "prod-public-${each.key}" }
}

# Private subnets hold the internal ALB, the API Gateway VPC link and the database. No route to the internet.
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = { Name = "prod-private-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "prod-public" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "prod-private" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------- security groups

resource "aws_security_group" "vpc_link" {
  name        = "prod-vpc-link"
  description = "API Gateway VPC link"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "alb" {
  name        = "prod-alb"
  description = "Internal ALB"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "services" {
  name        = "prod-services"
  description = "ECS tasks"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "rds" {
  name        = "prod-rds"
  description = "Shared PostgreSQL instance"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_alb" {
  security_group_id            = aws_security_group.vpc_link.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "VPC link to the internal ALB"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_vpc_link" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.vpc_link.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "Public API traffic through the gateway"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_services" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.services.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "Service-to-service calls under /internal"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_services" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.services.id
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
  description                  = "ALB to the tasks"
}

resource "aws_vpc_security_group_ingress_rule" "services_from_alb" {
  security_group_id            = aws_security_group.services.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
  description                  = "Only the ALB may reach the tasks"
}

# Tasks need outbound access to ECR, AWS APIs, RDS and the ALB.
resource "aws_vpc_security_group_egress_rule" "services_all" {
  security_group_id = aws_security_group.services.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_services" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.services.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from the tasks"
}

# ---------------------------------------------------------------- values for other stacks

resource "aws_ssm_parameter" "exports" {
  for_each = {
    vpc_id             = aws_vpc.main.id
    public_subnet_ids  = join(",", [for s in aws_subnet.public : s.id])
    private_subnet_ids = join(",", [for s in aws_subnet.private : s.id])
    sg_vpc_link        = aws_security_group.vpc_link.id
    sg_alb             = aws_security_group.alb.id
    sg_services        = aws_security_group.services.id
    sg_rds             = aws_security_group.rds.id
  }

  name  = "/prod/network/${each.key}"
  type  = "String"
  value = each.value
}
