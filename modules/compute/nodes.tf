# The worker nodes: an EKS managed node group on Amazon Linux 2023, started
# from a launch template that sets their security groups, their metadata
# options and an encrypted root volume.

# --- node role

data "aws_iam_policy_document" "node_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.cluster_name}-eks-node"
  description        = "Assumed by the worker nodes of ${local.cluster_name}."
  assume_role_policy = data.aws_iam_policy_document.node_trust.json
}

# What a node needs to join the cluster and pull images. The VPC CNI policy
# is not here: it belongs to the vpc-cni add-on's own IRSA role.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = {
    worker = "AmazonEKSWorkerNodePolicy"
    pull   = "AmazonEC2ContainerRegistryPullOnly"
  }

  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# --- launch template

resource "aws_launch_template" "node" {
  name_prefix = "${local.cluster_name}-node-"
  description = "Worker nodes of ${local.cluster_name}"

  # With security groups in the template, EKS no longer adds the cluster
  # group by itself, so both are listed: the node group, which the data
  # stores accept connections from, and the cluster group, which carries
  # control plane and node-to-node traffic.
  vpc_security_group_ids = [
    var.node_security_group_id,
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  ]

  # IMDSv2 only, with a hop limit of 1: a pod that is not on the host
  # network cannot reach the node's credentials, so every pod permission
  # comes from IRSA. A launch template without these options would raise the
  # hop limit to 2.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size_gib
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # The provider's default tags reach the template, not what it launches.
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.cluster_name}-node"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${local.cluster_name}-node"
    }
  }
}

# --- node group

resource "aws_eks_node_group" "this" {
  cluster_name = aws_eks_cluster.this.name

  # Changing the instance types replaces the node group. A generated name
  # lets the new group come up before the old one is drained and deleted.
  node_group_name_prefix = "${local.cluster_name}-"
  node_role_arn          = aws_iam_role.node.arn
  subnet_ids             = var.subnet_ids

  # Nodes follow the control plane's Kubernetes version.
  version        = aws_eks_cluster.this.version
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    min_size     = var.node_scaling.min_size
    desired_size = var.node_scaling.desired_size
    max_size     = var.node_scaling.max_size
  }

  # One node at a time is replaced during an update.
  update_config {
    max_unavailable = 1
  }

  # EKS replaces nodes that report themselves unhealthy.
  node_repair_config {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }

  # The node role's policies, and the two add-ons a node needs to become
  # Ready. Without them the group would wait for nodes that never join.
  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}
