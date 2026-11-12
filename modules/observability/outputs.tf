output "alarm_topic_arn" {
  description = "SNS topic every alarm notifies. Other subscriptions, such as a chat integration, attach here."
  value       = aws_sns_topic.alarms.arn
}
