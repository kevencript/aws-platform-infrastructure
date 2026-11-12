variable "name_prefix" {
  description = "Start of every name: <project>-<environment>. Load balancer names take at most 32 characters, so it may have at most 28."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 28
    error_message = "The prefix may have at most 28 characters, so that <prefix>-api fits a load balancer name."
  }
}

variable "hostname" {
  description = "Host name the API is served at, inside the hosted zone, for example api.dev.example.com."
  type        = string
}

variable "zone_id" {
  description = "ID of the public hosted zone that holds the host name and the certificate's validation record."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC of the target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets of the load balancer, in at least two zones."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An Application Load Balancer needs subnets in at least two zones."
  }
}

variable "security_group_id" {
  description = "The alb security group from modules/security."
  type        = string
}

variable "app_port" {
  description = "Port the API's pods listen on. The security group's rule uses the same number."
  type        = number
}

variable "health_check_path" {
  description = "Path the load balancer requests on each pod to decide whether it can take traffic."
  type        = string
  default     = "/healthz"
}

variable "ssl_policy" {
  description = "TLS policy of the HTTPS listener. The default allows TLS 1.2 and 1.3 only, with post-quantum key exchange."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
}

variable "waf_rate_limit" {
  description = "Requests one address may send in five minutes before the WAF blocks it."
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 10
    error_message = "WAF rate limits start at 10 requests."
  }
}

variable "log_retention_days" {
  description = "Days CloudWatch Logs keeps the WAF logs."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention must be one of the values CloudWatch Logs accepts, for example 30 or 90."
  }
}
