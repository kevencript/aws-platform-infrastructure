variable "name_prefix" {
  description = "Start of every name: <project>-<environment>. It is also the cluster's name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version of the control plane, for example \"1.36\". Nodes follow it."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "The Kubernetes version must look like \"1.36\"."
  }
}

variable "subnet_ids" {
  description = "Private app subnets for the control plane's network interfaces and the nodes."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS needs subnets in at least two Availability Zones."
  }
}

variable "service_ipv4_cidr" {
  description = "Block that Kubernetes service addresses come from. It must not overlap any VPC block the cluster talks to."
  type        = string
  default     = "172.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.service_ipv4_cidr)) && try(tonumber(split("/", var.service_ipv4_cidr)[1]) >= 12 && tonumber(split("/", var.service_ipv4_cidr)[1]) <= 24, false)
    error_message = "The service block must be an IPv4 block between /12 and /24."
  }
}

variable "cluster_log_retention_days" {
  description = "Days CloudWatch Logs keeps the control plane logs."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cluster_log_retention_days)
    error_message = "The retention must be one of the values CloudWatch Logs accepts, for example 30 or 90."
  }
}

variable "cluster_admin_principal_arns" {
  description = "IAM roles or users that get cluster admin access to the Kubernetes API. At least one: the identity that creates the cluster gets none."
  type        = list(string)

  validation {
    condition     = length(var.cluster_admin_principal_arns) >= 1 && alltrue([for arn in var.cluster_admin_principal_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/.+$", arn))])
    error_message = "Give at least one IAM role or user ARN. Without one, nobody can use the cluster."
  }
}

variable "node_security_group_id" {
  description = "The node security group, which the data stores accept connections from."
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types of the nodes. More than one helps capacity, mainly with SPOT."
  type        = list(string)

  validation {
    condition     = length(var.node_instance_types) >= 1
    error_message = "Give at least one instance type."
  }
}

variable "node_capacity_type" {
  description = "ON_DEMAND, or SPOT for cheaper nodes that AWS may take back."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "The capacity type must be ON_DEMAND or SPOT."
  }
}

variable "node_scaling" {
  description = "Number of nodes: the group never goes below min_size or above max_size."
  type = object({
    min_size     = number
    desired_size = number
    max_size     = number
  })

  validation {
    condition     = var.node_scaling.min_size >= 1 && var.node_scaling.min_size <= var.node_scaling.desired_size && var.node_scaling.desired_size <= var.node_scaling.max_size
    error_message = "The sizes must satisfy 1 <= min_size <= desired_size <= max_size."
  }
}

variable "node_disk_size_gib" {
  description = "Size of each node's root volume, in GiB. It holds the container images."
  type        = number
  default     = 50

  validation {
    condition     = var.node_disk_size_gib >= 20
    error_message = "The root volume must be at least 20 GiB."
  }
}
