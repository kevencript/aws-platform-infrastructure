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
