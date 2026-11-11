output "hosted_zone_id" {
  description = "ID of the environment's public hosted zone, found by name in this account."
  value       = data.aws_route53_zone.public.zone_id
}

output "vpc_id" {
  description = "ID of the environment's VPC."
  value       = module.networking.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs of each tier, by zone: public, app and data."
  value = {
    public = module.networking.public_subnet_ids
    app    = module.networking.app_subnet_ids
    data   = module.networking.data_subnet_ids
  }
}

output "nat_public_ips" {
  description = "Addresses that outbound traffic from the app tier leaves with."
  value       = module.networking.nat_public_ips
}

output "security_group_ids" {
  description = "Security group IDs by role: alb, node, rds, redis and msk."
  value       = module.security.security_group_ids
}
