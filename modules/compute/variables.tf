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
