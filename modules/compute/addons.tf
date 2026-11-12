# EKS add-ons. The cluster is created without any (bootstrap_self_managed_
# addons = false), so each one the cluster needs is managed here:
#
#   vpc-cni     gives pods VPC addresses. Without it a node never becomes
#               Ready, so it is created before the node group.
#   kube-proxy  routes traffic to Kubernetes services. Also before the nodes.
#   coredns     DNS inside the cluster. It runs as pods, so it needs nodes
#               and is created after the node group.
#   amazon-cloudwatch-observability
#               the CloudWatch agent, which publishes the node metrics the
#               node pressure alarms read (Container Insights). Also pods,
#               also after the node group.

locals {
  addons = toset(["vpc-cni", "kube-proxy", "coredns", "amazon-cloudwatch-observability"])
}

# The version EKS recommends for the cluster's Kubernetes version. When EKS
# changes it, a plan shows the upgrade; nothing changes without a plan.
data "aws_eks_addon_version" "default" {
  for_each = local.addons

  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = false
}

# The VPC CNI calls the EC2 API to attach network interfaces and addresses.
# It gets that permission from a role of its own, not from the node role.
module "vpc_cni_role" {
  source = "../irsa-role"

  name              = "${local.cluster_name}-vpc-cni"
  oidc_provider_arn = aws_iam_openid_connect_provider.cluster.arn
  oidc_issuer_url   = aws_iam_openid_connect_provider.cluster.url
  namespace         = "kube-system"
  service_account   = "aws-node"

  managed_policy_arns = {
    cni = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "vpc-cni"
  addon_version            = data.aws_eks_addon_version.default["vpc-cni"].version
  service_account_role_arn = module.vpc_cni_role.role_arn

  # Terraform is the source of truth for the add-on's configuration.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.default["kube-proxy"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.default["coredns"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}

# The agent publishes metrics with a role of its own, for the
# cloudwatch-agent service account the add-on creates.
module "cloudwatch_agent_role" {
  source = "../irsa-role"

  name              = "${local.cluster_name}-cloudwatch-agent"
  oidc_provider_arn = aws_iam_openid_connect_provider.cluster.arn
  oidc_issuer_url   = aws_iam_openid_connect_provider.cluster.url
  namespace         = "amazon-cloudwatch"
  service_account   = "cloudwatch-agent"

  managed_policy_arns = {
    agent = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
  }
}

resource "aws_cloudwatch_log_group" "container_insights" {
  name              = local.container_insights_log_group_name
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = aws_kms_key.cluster_logs.arn
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "amazon-cloudwatch-observability"
  addon_version            = data.aws_eks_addon_version.default["amazon-cloudwatch-observability"].version
  service_account_role_arn = module.cloudwatch_agent_role.role_arn

  # Metrics only. Shipping every container's logs would create log groups
  # without a retention or a key of this platform, at a cost per gigabyte.
  configuration_values = jsonencode({
    containerLogs = {
      enabled = false
    }
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.this,
    aws_cloudwatch_log_group.container_insights,
  ]
}
