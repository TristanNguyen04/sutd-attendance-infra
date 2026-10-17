output "alerts_topic_arn" {
  description = "SNS topic that receives alarms from the other stacks."
  value       = aws_sns_topic.alerts.arn
}
