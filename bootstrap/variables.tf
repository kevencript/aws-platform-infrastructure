# Values come from environments/<env>/bootstrap.tfvars. A variable that the
# root module also declares means the same here, and must hold the same
# value as in environments/<env>/terraform.tfvars.

variable "project" {
  description = "Short project name. It starts every resource name and fills the Project tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "The project name must be 2 to 16 characters: a lower-case letter, then lower-case letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Environment that this account holds. It is also the name of the GitHub environment whose jobs may assume the apply role."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be \"dev\" or \"prod\"."
  }
}

variable "aws_region" {
  description = "AWS Region of the state bucket, the lock table and the encryption key."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "The Region must look like \"us-east-2\"."
  }
}

variable "aws_account_id" {
  description = "ID of the AWS account being bootstrapped. The provider refuses to run in any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The account ID must be exactly 12 digits, written as a string so that leading zeros are kept."
  }
}

variable "domain_name" {
  description = "Name of the public hosted zone to create for this environment, for example dev.example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "The domain name must be lower case, with at least two labels and no trailing dot."
  }
}
