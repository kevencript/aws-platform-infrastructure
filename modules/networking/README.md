# networking

The network of one environment. A VPC with three tiers of subnets in every Availability
Zone, the gateways and routes that give each tier the reach it needs and no more, an S3
gateway endpoint, and VPC flow logs. The layout and the reasons behind it are in
[the plan](../../docs/architecture.md#network-plan).

| Tier | Size | Default route | Holds |
|------|------|---------------|-------|
| Public | `/24` | Internet gateway | Load balancer, NAT gateways |
| Private app | `/20` | The NAT gateway of its zone, or the single one | EKS nodes and pod addresses |
| Private data | `/24` | None | RDS, ElastiCache, MSK |

| File | What it creates |
|------|-----------------|
| `vpc.tf` | The VPC, and its default security group emptied of rules |
| `subnets.tf` | One subnet per tier in each zone, numbered from the zone's position in the list |
| `routing.tf` | Internet gateway, NAT gateways with their Elastic IPs, one route table per tier, one per zone in the app tier |
| `endpoints.tf` | S3 gateway endpoint on the app route tables |
| `flow_logs.tf` | Flow log of the VPC into a CloudWatch Logs group, its encryption key and the role that writes into it |

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | Start of every name: `<project>-<environment>` |
| `vpc_cidr` | `string` | IPv4 `/16` block of the VPC |
| `availability_zones` | `list(string)` | Two to eight zones, in a fixed order. Append to add one; never reorder |
| `nat_gateway_mode` | `string` | `per_az` or `single` |
| `flow_log_retention_days` | `number` | Retention of the flow log group, in days |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id`, `vpc_cidr_block` | The VPC |
| `public_subnet_ids`, `app_subnet_ids`, `data_subnet_ids` | Subnet IDs of each tier, by zone |
| `nat_public_ips` | Addresses that outbound traffic leaves with |
| `flow_log_group_name` | The group that receives the flow logs |

## Notes

- Switching `nat_gateway_mode` changes gateways and routes, never subnets or route tables.
  Outbound traffic from the app tier stops briefly while the routes move.
- The zones must belong to the provider's Region. That is checked when a plan runs, not
  by `terraform validate`.
- The flow log key's policy lets CloudWatch Logs use it for this one log group only.
