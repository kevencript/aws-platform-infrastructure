variable "name" {
  description = "Name of the IAM role."
  type        = string

  validation {
    condition     = length(var.name) <= 64
    error_message = "An IAM role name has at most 64 characters."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_issuer_url" {
  description = "Issuer URL of the cluster, with or without https://."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account."
  type        = string

  validation {
    condition     = length(var.namespace) > 0 && !strcontains(var.namespace, "*")
    error_message = "Name one namespace exactly. A wildcard would let other service accounts assume the role."
  }
}

variable "service_account" {
  description = "Name of the Kubernetes service account that may assume the role."
  type        = string

  validation {
    condition     = length(var.service_account) > 0 && !strcontains(var.service_account, "*")
    error_message = "Name one service account exactly. A wildcard would let other service accounts assume the role."
  }
}

variable "managed_policy_arns" {
  description = "Managed policies to attach, under keys chosen by the caller."
  type        = map(string)
  default     = {}
}

variable "inline_policy_json" {
  description = "A policy document of the role's own, or null."
  type        = string
  default     = null
}
