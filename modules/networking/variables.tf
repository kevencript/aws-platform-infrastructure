variable "name_prefix" {
  description = "Start of every name in the module: <project>-<environment>."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 block of the VPC. The subnet layout in subnets.tf is written for a /16."
  type        = string

  validation {
    condition     = try(cidrsubnet(var.vpc_cidr, 0, 0) == var.vpc_cidr, false) && endswith(var.vpc_cidr, "/16")
    error_message = "The VPC block must be an IPv4 network address with a /16 prefix, for example 10.20.0.0/16."
  }
}

variable "availability_zones" {
  description = "Zones of the environment, in a fixed order. Each one gets a subnet in every tier. Add a zone at the end; never reorder the list, which would renumber subnets."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 8 && length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "Give between two and eight distinct zones. The subnet layout has room for eight."
  }
}

variable "nat_gateway_mode" {
  description = "\"per_az\" puts a NAT gateway in every zone. \"single\" puts one in the first zone and shares it."
  type        = string

  validation {
    condition     = contains(["per_az", "single"], var.nat_gateway_mode)
    error_message = "The NAT gateway mode must be \"per_az\" or \"single\"."
  }
}

variable "flow_log_retention_days" {
  description = "Days CloudWatch Logs keeps the flow logs."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "The retention must be one of the values CloudWatch Logs accepts, for example 30 or 90."
  }
}
