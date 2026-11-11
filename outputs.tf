output "hosted_zone_id" {
  description = "ID of the environment's public hosted zone, found by name in this account."
  value       = data.aws_route53_zone.public.zone_id
}
