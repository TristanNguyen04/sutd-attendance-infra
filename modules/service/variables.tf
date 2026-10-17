variable "name" {
  type        = string
  description = "Service name. Lowercase letters and digits only. Resources are named prod-<name>; the API paths are /v1/<name>/* and /internal/<name>/*."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,19}$", var.name))
    error_message = "name must be 2-20 characters: lowercase letters and digits, starting with a letter."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository (OWNER/REPO) whose main branch may deploy this service through OIDC."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo)) && !strcontains(var.github_repo, "CHANGE_ME")
    error_message = "github_repo must look like OWNER/REPO and must not contain the CHANGE_ME placeholder."
  }
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the GitHub Actions OIDC provider created by the bootstrap stack."
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster."
}

variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster."
}

variable "vpc_id" {
  type        = string
  description = "VPC that holds the target group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the Fargate tasks (public subnets, because there is no NAT gateway)."
}

variable "security_group_id" {
  type        = string
  description = "Security group for the tasks. It accepts traffic from the ALB only."
}

variable "listener_arn" {
  type        = string
  description = "ARN of the internal ALB listener that gets this service's path rule."
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of the internal ALB, used for CloudWatch alarm dimensions."
}

variable "priority" {
  type        = number
  description = "ALB listener rule priority. Must be unique across services."

  validation {
    condition     = var.priority >= 100 && var.priority < 50000
    error_message = "priority must be between 100 and 49999; lower numbers are reserved for platform rules."
  }
}

variable "extra_paths" {
  type        = list(string)
  description = "Additional ALB path patterns routed to this service, for example /.well-known/* for the permissions service."
  default     = []
}

variable "cpu" {
  type        = number
  description = "Fargate task CPU units."
  default     = 256
}

variable "memory" {
  type        = number
  description = "Fargate task memory in MiB."
  default     = 512
}

variable "cpu_architecture" {
  type        = string
  description = "CPU architecture of the container image."
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be ARM64 or X86_64."
  }
}

variable "desired_count" {
  type        = number
  description = "Initial task count. Stays 0 until the service repo's CI deploys a real image; CI owns the count afterwards."
  default     = 0
}

variable "health_check_path" {
  type        = string
  description = "Path the ALB health-checks on the container."
  default     = "/_ping"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention."
  default     = 14
}

variable "ecr_keep_images" {
  type        = number
  description = "Number of most recent images kept in the ECR repository."
  default     = 20
}

variable "event_bus_name" {
  type        = string
  description = "Name of the shared EventBridge bus."
}

variable "event_bus_arn" {
  type        = string
  description = "ARN of the shared EventBridge bus."
}

variable "subscriptions" {
  type = list(object({
    source       = string
    detail_types = list(string)
  }))
  description = "Events this service consumes. One SQS queue (with a dead-letter queue) receives all of them. Empty means the service only publishes."
  default     = []

  validation {
    condition     = length(distinct([for s in var.subscriptions : s.source])) == length(var.subscriptions)
    error_message = "Each source may appear once in subscriptions; list all detail types for a source together."
  }

  validation {
    condition     = alltrue([for s in var.subscriptions : length(s.detail_types) > 0])
    error_message = "Every subscription needs at least one detail type."
  }
}

variable "db_host" {
  type        = string
  description = "Hostname of the shared RDS instance."
}

variable "db_port" {
  type        = number
  description = "Port of the shared RDS instance."
  default     = 5432
}

variable "db_secret_version" {
  type        = number
  description = "Bump this to write a freshly generated database password into the secret (write-only attribute, so Terraform cannot detect changes itself)."
  default     = 1
}

variable "alerts_topic_arn" {
  type        = string
  description = "SNS topic that receives this service's alarms."
}
