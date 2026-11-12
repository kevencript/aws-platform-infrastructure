variable "name_prefix" {
  description = "Start of every name: <project>-<environment>."
  type        = string
}

variable "alarm_email_addresses" {
  description = "Addresses subscribed to the alarm topic. Each must confirm its subscription."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for address in var.alarm_email_addresses : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", address))])
    error_message = "Each entry must be an email address."
  }
}

