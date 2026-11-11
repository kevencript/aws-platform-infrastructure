# The VPC of one environment, and its default security group emptied.

data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # EKS, RDS and the VPC endpoints rely on DNS names inside the VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name_prefix
  }

  lifecycle {
    # A variable's validation cannot read the provider, so the Region of the
    # zones is checked here, at plan time.
    precondition {
      condition     = alltrue([for zone in var.availability_zones : startswith(zone, data.aws_region.current.name)])
      error_message = "Every Availability Zone must belong to the provider's Region."
    }
  }
}

# Every VPC comes with a default security group whose rules let its members
# reach each other and anything outside. Nothing in this platform uses it.
# Declaring it without rules removes them, so a resource created without a
# group of its own gets no access at all.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-default-unused"
  }
}
