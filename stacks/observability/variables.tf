variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "alert_email" {
  type        = string
  description = "Email address that receives alarms and budget notifications."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email)) && !strcontains(var.alert_email, "CHANGE_ME")
    error_message = "Set alert_email in terraform.tfvars to a real address; the CHANGE_ME placeholder is not allowed."
  }
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly cost budget in USD. A notification goes out at 80% of actual spend and at 100% of forecast spend."
  default     = 60
}
