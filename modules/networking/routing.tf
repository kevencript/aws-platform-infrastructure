# Routing, tier by tier:
#
#   public  0.0.0.0/0 -> internet gateway
#   app     0.0.0.0/0 -> the NAT gateway of its zone, or the single one
#   data    no default route: only the VPC's local route, so nothing in this
#           tier can open a connection out of the VPC

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name_prefix
  }
}

locals {
  # A NAT gateway lives in one zone. "per_az" puts one in every zone, so
  # losing a zone does not cut outbound access for the others. "single" puts
  # one in the first zone and shares it: cheaper, but an outage of that zone
  # cuts outbound access, and with it STS calls and image pulls, everywhere.
  nat_zones = var.nat_gateway_mode == "per_az" ? var.availability_zones : [var.availability_zones[0]]

  # The zone of the NAT gateway that each app subnet routes through.
  nat_zone_for = {
    for zone in var.availability_zones : zone => var.nat_gateway_mode == "per_az" ? zone : var.availability_zones[0]
  }
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_zones)

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.name_prefix}-nat-${each.key}"
  }

  # A NAT gateway reaches the internet through the internet gateway.
  depends_on = [aws_internet_gateway.this]
}

# --- public tier: one table for every zone

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- app tier: one table per zone in either mode, so a change of mode
# changes routes and gateways, never the tables.

resource "aws_route_table" "app" {
  for_each = aws_subnet.app

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-app-${each.key}"
  }
}

resource "aws_route" "app_nat" {
  for_each = aws_route_table.app

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.nat_zone_for[each.key]].id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# --- data tier: one table with no route of its own

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-data"
  }
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}
