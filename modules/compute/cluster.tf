# The EKS control plane: its IAM role, the key that encrypts Kubernetes
# secrets, the log group of its logs, the cluster itself and the OIDC
# provider that IRSA roles trust.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  cluster_name = var.name_prefix

  # EKS writes control plane logs to this group. Created here first, so it
  # has a retention and a key; EKS would otherwise create it without either.
  cluster_log_group_name = "/aws/eks/${local.cluster_name}/cluster"

  # The CloudWatch agent writes performance events here (addons.tf), and
  # would otherwise create the group itself, without a retention or a key.
  container_insights_log_group_name = "/aws/containerinsights/${local.cluster_name}/performance"

  log_group_arn_prefix = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:"
}

# --- cluster role

data "aws_iam_policy_document" "cluster_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-eks-cluster"
  description        = "Assumed by EKS to manage the ${local.cluster_name} control plane."
  assume_role_policy = data.aws_iam_policy_document.cluster_trust.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- encryption of Kubernetes secrets

# Kubernetes keeps secrets in etcd. EKS encrypts them again with this key
# (envelope encryption), so a copy of etcd is unreadable without KMS access.
# No key policy is set: the account's IAM policies decide who may use it.
resource "aws_kms_key" "secrets" {
  description         = "Encrypts the Kubernetes secrets of ${local.cluster_name}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# --- control plane logs

data "aws_iam_policy_document" "cluster_logs_key" {
  statement {
    sid       = "AccountIamPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Same pattern as the flow logs: CloudWatch Logs may use the key for the
  # cluster's two log groups only.
  statement {
    sid    = "CloudWatchLogsForTheClusterLogGroups"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "${local.log_group_arn_prefix}${local.cluster_log_group_name}",
        "${local.log_group_arn_prefix}${local.container_insights_log_group_name}",
      ]
    }
  }
}

resource "aws_kms_key" "cluster_logs" {
  description         = "Encrypts the control plane and Container Insights logs of ${local.cluster_name}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.cluster_logs_key.json
}

resource "aws_kms_alias" "cluster_logs" {
  name          = "alias/${local.cluster_name}-eks-logs"
  target_key_id = aws_kms_key.cluster_logs.key_id
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = local.cluster_log_group_name
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = aws_kms_key.cluster_logs.arn
}

# --- the cluster

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.subnet_ids

    # The Kubernetes API is reachable from inside the VPC only. Terraform
    # never calls it: everything here goes through the AWS API.
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  # Access is granted with access entries (access.tf), which are AWS
  # resources reviewed in code. The identity that creates the cluster gets
  # no implicit admin rights.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.secrets.arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Kubernetes service addresses. Chosen, not left to EKS, and outside every
  # VPC block of the platform.
  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = var.service_ipv4_cidr
  }

  # EKS installs no add-on by itself; add-ons.tf manages each one.
  bootstrap_self_managed_addons = false

  # When standard support of a version ends, EKS upgrades the cluster
  # instead of moving it into paid extended support.
  upgrade_policy {
    support_type = "STANDARD"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# --- IRSA

# The cluster's OIDC issuer, registered in IAM. IRSA roles name it as the
# identity provider they trust. No thumbprint is given: IAM verifies the
# issuer's certificate against its own trusted authorities.
resource "aws_iam_openid_connect_provider" "cluster" {
  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
}
