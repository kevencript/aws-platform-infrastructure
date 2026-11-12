# PostgreSQL and Redis.

# CPU above 80% for 15 minutes: queries are queuing, or the instance is too
# small for the load.
resource "aws_cloudwatch_metric_alarm" "postgres_cpu" {
  alarm_name        = "${var.name_prefix}-postgres-cpu"
  alarm_description = "PostgreSQL CPU above 80% for 15 minutes."

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"
  dimensions  = { DBInstanceIdentifier = var.postgres_identifier }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 80
  treat_missing_data  = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# Less than 10% of the allocated storage free. Storage grows on its own up
# to its ceiling; this says the ceiling is near, or growth cannot keep up.
# Silence counts as a problem: the metric is always published.
resource "aws_cloudwatch_metric_alarm" "postgres_free_storage" {
  alarm_name        = "${var.name_prefix}-postgres-free-storage"
  alarm_description = "PostgreSQL free storage below 10% of the allocated storage."

  namespace   = "AWS/RDS"
  metric_name = "FreeStorageSpace"
  dimensions  = { DBInstanceIdentifier = var.postgres_identifier }

  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.postgres_allocated_storage_gib * 1024 * 1024 * 1024 * 0.1
  treat_missing_data  = "breaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

# Redis memory above 80% of its limit on any node. Past the limit, Redis
# evicts keys or refuses writes. ElastiCache publishes the metric per node,
# and the nodes of a replication group without sharding are named
# <group>-001, <group>-002 and so on, so their names are known before they
# exist.
resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  for_each = toset([for index in range(var.redis_num_nodes) : format("%s-%03d", var.redis_replication_group_id, index + 1)])

  alarm_name        = "${each.value}-memory"
  alarm_description = "Redis node ${each.value} uses more than 80% of its memory limit."

  namespace   = "AWS/ElastiCache"
  metric_name = "DatabaseMemoryUsagePercentage"
  dimensions  = { CacheClusterId = each.value }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 80
  treat_missing_data  = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
