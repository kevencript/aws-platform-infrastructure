# The security groups of the platform and every rule between them, in one
# place, so the whole traffic matrix can be read and reviewed here.
#
# Each group starts empty: when the provider creates a group it removes the
# rule AWS adds to allow all outbound traffic. Every rule is then a resource
# of its own. Internal rules name another group, never an address range.

locals {
  # Ports of the platform, published as an output so that the modules that
  # open them use the same numbers.
  ports = {
    https    = 443
    http     = 80
    app      = 3000
    postgres = 5432
    redis    = 6379
    kafka    = 9098 # MSK's listener for SASL/IAM over TLS
  }

  groups = {
    alb   = "Load balancer: HTTPS and HTTP from the internet, to the API pods"
    node  = "EKS nodes: connections from the API pods to the data stores"
    rds   = "PostgreSQL: connections from the EKS nodes only"
    redis = "Redis: connections from the EKS nodes only"
    msk   = "Kafka brokers: connections from the EKS nodes only"
  }

  # The internal flows. Each one becomes a rule pair: an egress rule on the
  # group that opens the connection and an ingress rule on the group that
  # accepts it, each naming the other. The data store groups appear only as
  # targets, so they get no egress rule at all and cannot open a connection.
  flows = {
    alb_to_node   = { from = "alb", to = "node", port = local.ports.app, what = "API traffic" }
    node_to_rds   = { from = "node", to = "rds", port = local.ports.postgres, what = "PostgreSQL over TLS" }
    node_to_redis = { from = "node", to = "redis", port = local.ports.redis, what = "Redis over TLS" }
    node_to_kafka = { from = "node", to = "msk", port = local.ports.kafka, what = "Kafka over TLS, SASL/IAM" }
  }
}

resource "aws_security_group" "this" {
  for_each = local.groups

  # A change to a group's description replaces the group. A generated name
  # lets the new group exist before the old one is deleted.
  name_prefix = "${var.name_prefix}-${each.key}-"
  description = each.value
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }

  lifecycle {
    create_before_destroy = true

    # EC2 accepts only these characters in a group description, and the
    # provider does not check them. An apostrophe would fail the apply.
    precondition {
      condition     = can(regex("^[a-zA-Z0-9 ._:/()#,@+=&;{}!$*\\[\\]-]*$", each.value))
      error_message = "A security group description may contain only letters, digits, spaces and ._-:/()#,@[]+=&;{}!$*."
    }
  }
}

resource "aws_vpc_security_group_egress_rule" "flow" {
  for_each = local.flows

  security_group_id            = aws_security_group.this[each.value.from].id
  referenced_security_group_id = aws_security_group.this[each.value.to].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "${each.value.what} to ${each.value.to}"
}

resource "aws_vpc_security_group_ingress_rule" "flow" {
  for_each = local.flows

  security_group_id            = aws_security_group.this[each.value.to].id
  referenced_security_group_id = aws_security_group.this[each.value.from].id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = "${each.value.what} from ${each.value.from}"
}

# The only rules that name an address range: the internet-facing load
# balancer must accept the internet. Port 80 only answers with a redirect to
# HTTPS.
resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  for_each = {
    https = local.ports.https
    http  = local.ports.http
  }

  security_group_id = aws_security_group.this["alb"].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  description       = "${upper(each.key)} from the internet"
}
