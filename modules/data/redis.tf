# Redis on ElastiCache, as a replication group without sharding: a primary
# and, in prod, a replica in another zone that takes over automatically.
#
# No password exists. The API signs in as an ElastiCache user that
# authenticates with IAM: it presents a short-lived token signed with its
# role's credentials. Connections must use TLS, which IAM authentication
# requires anyway.

locals {
  redis_id = "${var.name_prefix}-redis"

  # ElastiCache user IDs take letters, digits and hyphens only.
  redis_app_user = "${local.redis_id}-${replace(var.app_username, "_", "-")}"

  # The Redis OSS engine requires a user named "default" in every user
  # group. Valkey does not.
  needs_default_user = var.redis.engine == "redis"

  replicated = var.redis.num_nodes > 1
}

resource "aws_kms_key" "redis" {
  description         = "Encrypts the Redis data of ${var.name_prefix}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${local.redis_id}"
  target_key_id = aws_kms_key.redis.key_id
}

resource "aws_elasticache_subnet_group" "redis" {
  name        = local.redis_id
  description = "Private data subnets of ${var.name_prefix}"
  subnet_ids  = var.subnet_ids
}

# --- users

# Replaces the built-in default user, which would otherwise accept
# connections without a password. It is switched off and may run nothing.
resource "aws_elasticache_user" "default" {
  count = local.needs_default_user ? 1 : 0

  user_id       = "${local.redis_id}-default"
  user_name     = "default"
  engine        = var.redis.engine
  access_string = "off -@all"

  authentication_mode {
    type = "no-password-required"
  }
}

# The API's user. Its ID equals its name, as IAM authentication requires.
# It may run every command except the dangerous ones, such as FLUSHALL,
# CONFIG and KEYS.
resource "aws_elasticache_user" "app" {
  user_id       = local.redis_app_user
  user_name     = local.redis_app_user
  engine        = var.redis.engine
  access_string = "on ~* +@all -@dangerous"

  authentication_mode {
    type = "iam"
  }
}

resource "aws_elasticache_user_group" "redis" {
  user_group_id = local.redis_id
  engine        = var.redis.engine
  user_ids      = concat([aws_elasticache_user.app.user_id], aws_elasticache_user.default[*].user_id)
}

# --- the replication group

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = local.redis_id
  description          = "Cache of ${var.name_prefix}"
  engine               = var.redis.engine
  engine_version       = var.redis.engine_version
  node_type            = var.redis.node_type
  port                 = var.redis_port

  num_cache_clusters         = var.redis.num_nodes
  automatic_failover_enabled = local.replicated
  multi_az_enabled           = local.replicated

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  # Every connection uses TLS; a client without it is refused.
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn

  user_group_ids = [aws_elasticache_user_group.redis.user_group_id]

  snapshot_retention_limit   = var.redis.snapshot_retention_days
  auto_minor_version_upgrade = true

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.data["redis_slow_log"].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
}
