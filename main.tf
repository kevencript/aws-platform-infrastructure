# The root module wires the modules of the platform together. It creates no
# resource of its own: what it needs from the account, it looks up.

locals {
  # One naming scheme for the whole project: <project>-<environment>-<purpose>.
  name_prefix = "${var.project}-${var.environment}"

  # The service's name where hyphens are not allowed: its database and its
  # database user.
  app_name = replace(var.service_name, "-", "_")
}

# The public hosted zone is created by the bootstrap stack, because it must
# outlive the environment. The root module finds it by name, so the two
# stacks share a name and no state.
data "aws_route53_zone" "public" {
  name         = var.domain_name
  private_zone = false
}

# The network: VPC, subnet tiers, gateways, routes, S3 endpoint, flow logs.
module "networking" {
  source = "./modules/networking"

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  availability_zones      = var.availability_zones
  nat_gateway_mode        = var.nat_gateway_mode
  flow_log_retention_days = var.flow_log_retention_days
}

# Every security group and the rules between them. The cluster, the data
# stores and the load balancer receive their group from here.
module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  vpc_id      = module.networking.vpc_id
}

# The EKS cluster, its nodes and add-ons, and the OIDC provider for IRSA.
module "compute" {
  source = "./modules/compute"

  name_prefix                  = local.name_prefix
  kubernetes_version           = var.kubernetes_version
  subnet_ids                   = values(module.networking.app_subnet_ids)
  node_security_group_id       = module.security.security_group_ids["node"]
  node_instance_types          = var.node_instance_types
  node_scaling                 = var.node_scaling
  cluster_admin_principal_arns = var.cluster_admin_principal_arns
  cluster_log_retention_days   = var.cluster_log_retention_days
}

# The service's image repository in this account.
module "registry" {
  source = "./modules/registry"

  name = "${var.project}/${var.service_name}"
}

# PostgreSQL and Redis, in the data subnets.
module "data" {
  source = "./modules/data"

  name_prefix                = local.name_prefix
  subnet_ids                 = values(module.networking.data_subnet_ids)
  postgres_security_group_id = module.security.security_group_ids["rds"]
  redis_security_group_id    = module.security.security_group_ids["redis"]
  postgres_port              = module.security.ports.postgres
  redis_port                 = module.security.ports.redis
  database_name              = local.app_name
  app_username               = local.app_name
  postgres                   = var.postgres
  redis                      = var.redis
  log_retention_days         = var.data_log_retention_days
}

# Kafka, in the data subnets.
module "messaging" {
  source = "./modules/messaging"

  name_prefix       = local.name_prefix
  subnet_ids        = values(module.networking.data_subnet_ids)
  security_group_id = module.security.security_group_ids["msk"]
  kafka             = var.kafka
  app_name_prefix   = "${var.service_name}."
}

# The API's public entry point: certificate, load balancer, WAF and host name.
module "edge" {
  source = "./modules/edge"

  name_prefix        = local.name_prefix
  hostname           = "${var.service_name}.${var.domain_name}"
  zone_id            = data.aws_route53_zone.public.zone_id
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = values(module.networking.public_subnet_ids)
  security_group_id  = module.security.security_group_ids["alb"]
  app_port           = module.security.ports.app
  log_retention_days = var.waf_log_retention_days
}

# Alarms on the data stores, the nodes, Kafka and the API, and the topic
# they notify.
module "observability" {
  source = "./modules/observability"

  name_prefix                       = local.name_prefix
  alarm_email_addresses             = var.alarm_email_addresses
  postgres_identifier               = module.data.postgres_identifier
  postgres_allocated_storage_gib    = var.postgres.allocated_storage_gib
  redis_replication_group_id        = module.data.redis_replication_group_id
  redis_num_nodes                   = var.redis.num_nodes
  cluster_name                      = module.compute.cluster_name
  node_group_autoscaling_group_name = module.compute.node_group_autoscaling_group_name
  kafka_cluster_name                = module.messaging.cluster_name
  kafka_broker_count                = module.messaging.broker_count
  load_balancer_arn_suffix          = module.edge.load_balancer_arn_suffix
  target_group_arn_suffix           = module.edge.target_group_arn_suffix
}

# The identities of the service's workloads: one IRSA role per Kubernetes
# service account. Each module publishes the permissions its clients need,
# and they are bound here.
module "app_role" {
  source = "./modules/irsa-role"

  name              = "${local.name_prefix}-${var.service_name}"
  oidc_provider_arn = module.compute.oidc_provider_arn
  oidc_issuer_url   = module.compute.oidc_issuer_url
  namespace         = var.service_name
  service_account   = var.service_name

  inline_policies = {
    data-stores = module.data.app_policy_json
    kafka       = module.messaging.app_policy_json
  }
}

module "db_migrator_role" {
  source = "./modules/irsa-role"

  name              = "${local.name_prefix}-${var.service_name}-db-migrator"
  oidc_provider_arn = module.compute.oidc_provider_arn
  oidc_issuer_url   = module.compute.oidc_issuer_url
  namespace         = var.service_name
  service_account   = "db-migrator"

  inline_policies = {
    master-secret = module.data.migrator_policy_json
  }
}

# The AWS Load Balancer Controller's identity: it registers the API's pod
# addresses in the edge module's target group, and nothing else.
module "lb_controller_role" {
  source = "./modules/irsa-role"

  name              = "${local.name_prefix}-lb-controller"
  oidc_provider_arn = module.compute.oidc_provider_arn
  oidc_issuer_url   = module.compute.oidc_issuer_url
  namespace         = "kube-system"
  service_account   = "aws-load-balancer-controller"

  inline_policies = {
    target-group = module.edge.controller_policy_json
  }
}
