# Identity of the environment. None of these has a default: the values come
# from environments/<env>/terraform.tfvars, so no account, region or name is
# written in code.

variable "project" {
  description = "Short project name. It starts every resource name and fills the Project tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "The project name must be 2 to 16 characters: a lower-case letter, then lower-case letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Environment name. It follows the project in every resource name and fills the Environment tag."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be \"dev\" or \"prod\"."
  }
}

variable "aws_region" {
  description = "AWS Region that holds every resource of the environment."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "The Region must look like \"us-east-2\"."
  }
}

variable "aws_account_id" {
  description = "ID of the AWS account that belongs to this environment. The provider refuses to run in any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The account ID must be exactly 12 digits, written as a string so that leading zeros are kept."
  }
}

variable "domain_name" {
  description = "Name of the environment's public hosted zone, for example dev.example.com. The bootstrap stack creates the zone."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "The domain name must be lower case, with at least two labels and no trailing dot."
  }
}

# Network of the environment. modules/networking validates each value.

variable "vpc_cidr" {
  description = "IPv4 /16 block of the environment's VPC."
  type        = string
}

variable "availability_zones" {
  description = "Zones of the environment, in a fixed order. Append to add one; never reorder."
  type        = list(string)
}

variable "nat_gateway_mode" {
  description = "\"per_az\" for a NAT gateway in every zone, \"single\" for one shared gateway."
  type        = string
}

variable "flow_log_retention_days" {
  description = "Days CloudWatch Logs keeps the VPC flow logs."
  type        = number
}

# The service the platform runs.

variable "service_name" {
  description = "Short name of the service, for example \"api\". Its image repository is <project>/<service_name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.service_name))
    error_message = "The service name must be 2 to 31 characters: a lower-case letter, then lower-case letters, digits or hyphens."
  }
}

# Cluster of the environment. modules/compute validates each value.

variable "kubernetes_version" {
  description = "Kubernetes version of the cluster, for example \"1.36\"."
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types of the worker nodes."
  type        = list(string)
}

variable "node_scaling" {
  description = "Minimum, desired and maximum number of worker nodes."
  type = object({
    min_size     = number
    desired_size = number
    max_size     = number
  })
}

variable "cluster_admin_principal_arns" {
  description = "IAM roles or users with cluster admin access to the Kubernetes API. At least one."
  type        = list(string)
}

variable "cluster_log_retention_days" {
  description = "Days CloudWatch Logs keeps the control plane logs."
  type        = number
}
