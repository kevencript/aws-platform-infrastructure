# The root module wires the modules of the platform together. It creates no
# resource of its own: what it needs from the account, it looks up.

locals {
  # One naming scheme for the whole project: <project>-<environment>-<purpose>.
  name_prefix = "${var.project}-${var.environment}"
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
