variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "github_owner" {
  type        = string
  description = "GitHub user or organisation that owns the repositories."

  validation {
    condition     = length(var.github_owner) > 0 && var.github_owner != "CHANGE_ME"
    error_message = "Set github_owner in terraform.tfvars; the CHANGE_ME placeholder is not allowed."
  }
}

variable "infra_repo" {
  type        = string
  description = "Name of this repository, used in the OIDC trust policies."
  default     = "sutd-attendance-infra"
}
