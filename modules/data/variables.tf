variable "name_prefix" {
  description = "Start of every name: <project>-<environment>."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnets, in at least two zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS and ElastiCache subnet groups need subnets in at least two zones."
  }
}

variable "postgres_security_group_id" {
  description = "The rds security group, which accepts connections from the nodes only."
  type        = string
}

variable "redis_security_group_id" {
  description = "The redis security group, which accepts connections from the nodes only."
  type        = string
}

variable "postgres_port" {
  description = "Port PostgreSQL listens on. The security group's rule uses the same number."
  type        = number
}

variable "redis_port" {
  description = "Port Redis listens on. The security group's rule uses the same number."
  type        = number
}

variable "database_name" {
  description = "Database created with the instance."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "The database name must start with a letter and contain lower-case letters, digits and underscores."
  }
}

variable "app_username" {
  description = "Name of the API's database user. The API's Redis user is <prefix>-redis-<app_username>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.app_username))
    error_message = "The user name must start with a letter and contain lower-case letters, digits and underscores."
  }
}

variable "master_username" {
  description = "Name of the PostgreSQL master user. Its password is managed by RDS."
  type        = string
  default     = "dbadmin"
}

variable "postgres" {
  description = "PostgreSQL size and resilience."
  type = object({
    engine_version            = string # major version only, for example "17"
    instance_class            = string
    multi_az                  = bool
    allocated_storage_gib     = number
    max_allocated_storage_gib = number
    backup_retention_days     = number
  })

  validation {
    condition     = can(regex("^[0-9]{2}$", var.postgres.engine_version))
    error_message = "Give the PostgreSQL major version only, for example \"17\". RDS chooses the minor version."
  }

  validation {
    condition     = var.postgres.max_allocated_storage_gib >= var.postgres.allocated_storage_gib
    error_message = "The storage ceiling must be at least the allocated storage."
  }

  validation {
    condition     = var.postgres.backup_retention_days >= 1 && var.postgres.backup_retention_days <= 35
    error_message = "Keep automated backups for 1 to 35 days."
  }
}

variable "redis" {
  description = "Redis engine, size and resilience."
  type = object({
    engine                  = string # "redis", or "valkey"
    engine_version          = string
    node_type               = string
    num_nodes               = number # 1, or more for a replica with automatic failover
    snapshot_retention_days = number
  })

  validation {
    condition     = contains(["redis", "valkey"], var.redis.engine)
    error_message = "The engine must be \"redis\" or \"valkey\"."
  }

  validation {
    condition     = var.redis.num_nodes >= 1 && var.redis.num_nodes <= 6
    error_message = "A replication group without sharding has 1 to 6 nodes."
  }

  validation {
    condition     = var.redis.snapshot_retention_days >= 1 && var.redis.snapshot_retention_days <= 35
    error_message = "Keep daily snapshots for 1 to 35 days."
  }
}

variable "log_retention_days" {
  description = "Days CloudWatch Logs keeps the logs of the data stores."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention must be one of the values CloudWatch Logs accepts, for example 30 or 90."
  }
}
