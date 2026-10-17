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

variable "create_oidc_provider" {
  type        = bool
  description = "Create the account's GitHub Actions OIDC provider. Set to false when the account already has one (only one per URL is allowed): it is then looked up and never modified or destroyed by this stack."
  default     = true
}
