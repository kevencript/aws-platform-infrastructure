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

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.compute.cluster_name
}

output "cluster_endpoint" {
  description = "URL of the Kubernetes API. Reachable from inside the VPC only."
  value       = module.compute.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider, which IRSA roles trust."
  value       = module.compute.oidc_provider_arn
}

output "ecr_repository_url" {
  description = "URL of the service's image repository."
  value       = module.registry.repository_url
}

output "db_host" {
  description = "Host name of the PostgreSQL primary."
  value       = module.data.postgres_address
}

output "db_port" {
  description = "Port of PostgreSQL."
  value       = module.data.postgres_port
}

output "db_name" {
  description = "Name of the service's database."
  value       = module.data.database_name
}

output "db_master_secret_arn" {
  description = "Secret that RDS keeps the master password in. Only the migration job's role may read it."
  value       = module.data.postgres_master_secret_arn
}

output "redis_endpoint" {
  description = "Host name of the Redis primary."
  value       = module.data.redis_primary_endpoint
}

output "redis_reader_endpoint" {
  description = "Host name that spreads reads over the Redis replicas."
  value       = module.data.redis_reader_endpoint
}

output "redis_username" {
  description = "ElastiCache user the API signs in as, with an IAM token."
  value       = module.data.redis_app_username
}

output "app_role_arn" {
  description = "IAM role of the API's service account, for its eks.amazonaws.com/role-arn annotation."
  value       = module.app_role.role_arn
}

output "db_migrator_role_arn" {
  description = "IAM role of the migration job's service account."
  value       = module.db_migrator_role.role_arn
}

output "msk_bootstrap_brokers" {
  description = "Kafka brokers to connect to with SASL/IAM over TLS, port 9098."
  value       = module.messaging.bootstrap_brokers_sasl_iam
}

output "api_url" {
  description = "URL of the API."
  value       = module.edge.url
}

output "load_balancer_dns_name" {
  description = "DNS name AWS gives the load balancer; the API's host name is an alias of it."
  value       = module.edge.load_balancer_dns_name
}

output "target_group_name" {
  description = "Target group the TargetGroupBinding names, for the AWS Load Balancer Controller."
  value       = module.edge.target_group_name
}

output "lb_controller_role_arn" {
  description = "IAM role of the AWS Load Balancer Controller's service account."
  value       = module.lb_controller_role.role_arn
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF web ACL in front of the load balancer."
  value       = module.edge.web_acl_arn
}
