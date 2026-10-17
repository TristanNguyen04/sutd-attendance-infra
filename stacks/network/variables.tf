variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC. Subnets are carved out of it with /24 blocks."
  default     = "10.0.0.0/16"
}
