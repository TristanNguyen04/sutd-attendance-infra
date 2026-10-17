output "api_endpoint" {
  description = "Default invoke URL of the API."
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_url" {
  description = "URL the apps should call: the custom domain when configured, otherwise the default endpoint."
  value       = var.domain_name != null ? "https://${var.domain_name}" : aws_apigatewayv2_api.main.api_endpoint
}
