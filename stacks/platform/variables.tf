variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "github_owner" {
  type        = string
  description = "GitHub user or organisation that owns the service repositories."

  validation {
    condition     = length(var.github_owner) > 0 && var.github_owner != "CHANGE_ME"
    error_message = "Set github_owner in terraform.tfvars; the CHANGE_ME placeholder is not allowed."
  }
}

variable "sessions_repo" {
  type        = string
  description = "Name of the GitHub repository of the sessions service."

  validation {
    condition     = length(var.sessions_repo) > 0 && var.sessions_repo != "CHANGE_ME"
    error_message = "Set sessions_repo in terraform.tfvars; the CHANGE_ME placeholder is not allowed."
  }
}

variable "appeals_repo" {
  type        = string
  description = "Name of the GitHub repository of the appeals service."

  validation {
    condition     = length(var.appeals_repo) > 0 && var.appeals_repo != "CHANGE_ME"
    error_message = "Set appeals_repo in terraform.tfvars; the CHANGE_ME placeholder is not allowed."
  }
}
