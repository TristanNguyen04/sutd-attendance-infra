variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "jwt_issuer" {
  type        = string
  description = "Issuer URL of the access tokens (the permissions service). It must serve /.well-known/openid-configuration and a JWKS endpoint, publicly, through this gateway."

  validation {
    condition     = startswith(var.jwt_issuer, "https://") && !strcontains(var.jwt_issuer, "CHANGE_ME")
    error_message = "jwt_issuer must be an https:// URL; the CHANGE_ME placeholder is not allowed."
  }
}

variable "jwt_audience" {
  type        = list(string)
  description = "Accepted values of the token's aud claim. The permissions service must issue tokens with one of them."
  default     = ["api"]
}

variable "domain_name" {
  type        = string
  description = "Custom domain for the API, for example api.example.com. Null uses the default execute-api URL."
  default     = null
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone that holds the domain. Required when domain_name is set."
  default     = null
}

variable "cors_allowed_origins" {
  type        = list(string)
  description = "Browser origins allowed to call the API (the back-office web app). Empty disables CORS; native apps do not need it."
  default     = []
}

variable "default_throttle_rate" {
  type        = number
  description = "Steady-state requests per second allowed on all routes."
  default     = 100
}

variable "default_throttle_burst" {
  type        = number
  description = "Burst allowance for all routes."
  default     = 200
}

variable "login_throttle_rate" {
  type        = number
  description = "Requests per second allowed on the login route, to slow brute-force attempts."
  default     = 5
}

variable "login_throttle_burst" {
  type        = number
  description = "Burst allowance on the login route."
  default     = 10
}
