# security

Every security group of the platform and every rule between them, in one module, so the
traffic matrix is read and reviewed in one place: [`main.tf`](main.tf). The reasoning is
in [the plan](../../docs/architecture.md#security-groups).

| Group | Ingress | Egress |
|-------|---------|--------|
| `alb` | TCP 443 and 80 from `0.0.0.0/0` | TCP 3000 to `node` |
| `node` | TCP 3000 from `alb` | TCP 5432 to `rds`, 6379 to `redis`, 9098 to `msk` |
| `rds` | TCP 5432 from `node` | None |
| `redis` | TCP 6379 from `node` | None |
| `msk` | TCP 9098 from `node` | None |

- Each group starts empty, and each rule is a resource of its own. An internal flow is a
  rule pair, generated from one entry of `local.flows`.
- The data store groups only appear as targets, so they get no egress rule: they cannot
  open a connection.
- The EKS cluster security group is created by EKS. The rules that involve it belong
  with the cluster, not here.
- Groups get generated names and are replaced before they are destroyed, because a
  change to a group's description replaces the group.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | Start of every name: `<project>-<environment>` |
| `vpc_id` | `string` | The VPC the groups belong to |

## Outputs

| Name | Description |
|------|-------------|
| `security_group_ids` | Group IDs by role: `alb`, `node`, `rds`, `redis`, `msk` |
| `ports` | The ports of the platform, for the modules that open them |
