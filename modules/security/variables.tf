variable "name_prefix" {
  description = "Start of every name in the module: <project>-<environment>."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the groups belong to."
  type        = string
}
