variable "name_prefix" {
  description = "Start of every name: <project>-<environment>."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnets. Each one gets the same number of brokers."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "MSK needs subnets in at least two zones."
  }
}

variable "security_group_id" {
  description = "The msk security group, which accepts connections from the nodes only."
  type        = string
}

variable "kafka" {
  description = "Kafka version, broker size and count, storage, and how long data and logs are kept."
  type = object({
    version                   = string # for example "3.9.x.kraft": a cluster without ZooKeeper
    instance_type             = string
    brokers_per_zone          = number
    volume_size_gib           = number
    retention_hours           = number # how long a topic keeps a message, unless the topic says otherwise
    broker_log_retention_days = number
  })

  validation {
    condition     = var.kafka.brokers_per_zone >= 1
    error_message = "Each zone needs at least one broker."
  }

  validation {
    condition     = var.kafka.volume_size_gib >= 1 && var.kafka.volume_size_gib <= 16384
    error_message = "Broker storage must be between 1 and 16384 GiB."
  }

  validation {
    condition     = var.kafka.retention_hours >= 1
    error_message = "Messages must be kept for at least one hour."
  }

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.kafka.broker_log_retention_days)
    error_message = "The broker log retention must be one of the values CloudWatch Logs accepts, for example 30 or 90."
  }
}

variable "app_name_prefix" {
  description = "Start of the names of the topics and consumer groups the API may use, ending with a separator, for example \"api.\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]*[._-]$", var.app_name_prefix))
    error_message = "The prefix must end with \".\", \"_\" or \"-\", so that \"api.\" cannot also match a name such as \"apiary\"."
  }
}
