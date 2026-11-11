# Three tiers of subnets, one subnet per tier in each zone. The blocks are
# computed from the VPC block and the zone's position in the list, so
# appending a zone adds subnets and never renumbers the existing ones.
#
#   tier          size  blocks in the /16                holds
#   public        /24   10.x.0.0,  10.x.1.0,  10.x.2.0   load balancer, NAT gateways
#   private data  /24   10.x.8.0,  10.x.9.0,  10.x.10.0  RDS, ElastiCache, MSK
#   private app   /20   10.x.16.0, 10.x.32.0, 10.x.48.0  EKS nodes and pod addresses
#
# The /24 blocks sit in the first /20 of the VPC, which the app tier skips.
# The app tier is large because the VPC CNI gives every pod a VPC address.

locals {
  zone_index = { for index, zone in var.availability_zones : zone => index }

  subnet_cidrs = {
    public = { for zone, index in local.zone_index : zone => cidrsubnet(var.vpc_cidr, 8, index) }
    data   = { for zone, index in local.zone_index : zone => cidrsubnet(var.vpc_cidr, 8, index + 8) }
    app    = { for zone, index in local.zone_index : zone => cidrsubnet(var.vpc_cidr, 4, index + 1) }
  }
}

resource "aws_subnet" "public" {
  for_each = local.subnet_cidrs.public

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # Nothing here needs an address of its own: AWS manages the load
  # balancer's, and each NAT gateway has an Elastic IP.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  for_each = local.subnet_cidrs.app

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name_prefix}-app-${each.key}"
    Tier = "app"
  }
}

resource "aws_subnet" "data" {
  for_each = local.subnet_cidrs.data

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name_prefix}-data-${each.key}"
    Tier = "data"
  }
}
