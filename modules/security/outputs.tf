output "security_group_ids" {
  description = "IDs of the security groups, by role: alb, node, rds, redis and msk."
  value       = { for role, group in aws_security_group.this : role => group.id }
}

output "ports" {
  description = "Ports of the platform. The modules that open them use these numbers, so a rule and its listener cannot disagree."
  value       = local.ports
}
