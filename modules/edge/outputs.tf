output "url" {
  description = "URL of the API."
  value       = "https://${aws_route53_record.api.fqdn}"
}

output "load_balancer_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.api.arn
}

output "load_balancer_arn_suffix" {
  description = "Identifier of the load balancer in CloudWatch metrics."
  value       = aws_lb.api.arn_suffix
}

output "load_balancer_dns_name" {
  description = "DNS name AWS gives the load balancer. The host name is an alias of it."
  value       = aws_lb.api.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group the controller fills with the API's pod addresses."
  value       = aws_lb_target_group.api.arn
}

output "target_group_name" {
  description = "Name of that target group, for the TargetGroupBinding."
  value       = aws_lb_target_group.api.name
}

output "target_group_arn_suffix" {
  description = "Identifier of the target group in CloudWatch metrics."
  value       = aws_lb_target_group.api.arn_suffix
}

output "web_acl_arn" {
  description = "ARN of the WAF web ACL."
  value       = aws_wafv2_web_acl.api.arn
}

