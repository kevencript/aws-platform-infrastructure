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

variable "postgres_identifier" {
  description = "Identifier of the PostgreSQL instance."
  type        = string
}

variable "postgres_allocated_storage_gib" {
  description = "Storage allocated to PostgreSQL at creation, in GiB. The free storage alarm fires below 10% of it."
  type        = number
}

variable "redis_replication_group_id" {
  description = "ID of the Redis replication group."
  type        = string
}

variable "redis_num_nodes" {
  description = "Number of nodes in the Redis replication group."
  type        = number
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "node_group_autoscaling_group_name" {
  description = "Auto Scaling group behind the EKS node group."
  type        = string
}

variable "kafka_cluster_name" {
  description = "Name of the MSK cluster."
  type        = string
}

variable "kafka_broker_count" {
  description = "Number of Kafka brokers."
  type        = number
}

variable "load_balancer_arn_suffix" {
  description = "Identifier of the load balancer in CloudWatch metrics."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Identifier of the API's target group in CloudWatch metrics."
  type        = string
}

variable "api_5xx_threshold" {
  description = "Server errors from the API in 5 minutes above which the alarm fires."
  type        = number
  default     = 10
}
