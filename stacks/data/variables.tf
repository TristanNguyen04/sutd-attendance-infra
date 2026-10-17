variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.micro"
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL major version. RDS picks the current minor and upgrades minors automatically."
  default     = "16"
}

variable "allocated_storage_gb" {
  type        = number
  description = "Initial storage in GB."
  default     = 20
}

variable "max_allocated_storage_gb" {
  type        = number
  description = "Storage autoscaling ceiling in GB."
  default     = 50
}

variable "backup_retention_days" {
  type        = number
  description = "Automated backup retention."
  default     = 7
}

variable "max_connections_alarm" {
  type        = number
  description = "Connection count that raises an alarm. A db.t4g.micro allows roughly 100 connections."
  default     = 70
}
