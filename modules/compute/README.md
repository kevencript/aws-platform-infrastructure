# compute

The EKS cluster of one environment: the control plane, a managed node group, the
add-ons the cluster needs to run pods, and the OIDC provider that IRSA roles trust.

| File | What it creates |
|------|-----------------|
| `cluster.tf` | Cluster role, the key that encrypts Kubernetes secrets, the control plane log group and its key, the cluster, the IAM OIDC provider |
| `access.tf` | An access entry with cluster admin rights for each named IAM principal |
| `nodes.tf` | Node role, launch template and managed node group on Amazon Linux 2023 |
| `addons.tf` | The `vpc-cni` add-on with its own IRSA role, `kube-proxy`, `coredns`, and the CloudWatch agent add-on with its own IRSA role |

## What to know

- **Private API endpoint.** The Kubernetes API is reachable from inside the VPC only.
  Terraform never calls it, so the pipeline does not need a path to it. A person needs
  one, such as a VPN or a session through an instance in the VPC; this repository
  provisions none.
- **Access entries, not the `aws-auth` ConfigMap.** Access is an AWS resource reviewed in
  code. The identity that creates the cluster gets no implicit rights, which is why
  `cluster_admin_principal_arns` cannot be empty.
- **Two security groups on every node.** The node group from `modules/security`, which
  the data stores accept, and the cluster group EKS creates, which carries control plane
  and node-to-node traffic. A launch template that sets security groups must list the
  cluster group itself.
- **IMDSv2 with a hop limit of 1.** A pod that is not on the host network cannot reach
  the node's credentials, so every pod permission comes from IRSA. The VPC CNI policy is
  on the add-on's own role for the same reason, not on the node role.
- **Add-on order.** `vpc-cni` and `kube-proxy` exist before the node group, because a
  node without them never becomes Ready. `coredns` and the CloudWatch agent run as pods,
  so they wait for the nodes.
- **Add-on versions.** Each add-on runs the version EKS recommends for the cluster's
  Kubernetes version. When EKS changes that recommendation, a plan shows the upgrade.
- **Standard support only.** When a Kubernetes version leaves standard support, EKS
  upgrades the cluster instead of moving it into paid extended support.
- **Secrets and logs encrypted with keys of the account.** The control plane log group is
  created before the cluster, so it has a retention and a key.

- **CloudWatch agent, metrics only.** It publishes the node metrics the node pressure
  alarms read. Container log shipping is off: it would create log groups without a
  retention or a key of this platform.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | `<project>-<environment>`, also the cluster name |
| `kubernetes_version` | `string` | For example `"1.36"` |
| `subnet_ids` | `list(string)` | Private app subnets, at least two zones |
| `node_security_group_id` | `string` | The node group from `modules/security` |
| `cluster_admin_principal_arns` | `list(string)` | IAM roles or users with cluster admin access. At least one |
| `cluster_log_retention_days` | `number` | Retention of the control plane logs |
| `node_instance_types` | `list(string)` | EC2 instance types |
| `node_scaling` | `object` | `min_size`, `desired_size`, `max_size` |
| `node_capacity_type` | `string` | `ON_DEMAND` (default) or `SPOT` |
| `node_disk_size_gib` | `number` | Root volume size. Default: 50 |
| `service_ipv4_cidr` | `string` | Block for Kubernetes service addresses. Default: `172.20.0.0/16` |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data` | To reach the Kubernetes API from inside the VPC |
| `cluster_security_group_id` | The group EKS created |
| `oidc_provider_arn`, `oidc_issuer_url` | For IRSA roles |
| `node_role_arn` | The nodes' role |
