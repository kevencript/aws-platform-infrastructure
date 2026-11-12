output "postgres_address" {
  description = "Host name of the PostgreSQL primary."
  value       = aws_db_instance.postgres.address
}

output "postgres_port" {
  description = "Port of PostgreSQL."
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Database created with the instance."
  value       = aws_db_instance.postgres.db_name
}

output "postgres_master_secret_arn" {
  description = "ARN of the Secrets Manager secret that RDS keeps the master password in. Only the migration job may read it."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "redis_primary_endpoint" {
  description = "Host name of the Redis primary, for reads and writes."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Host name that spreads reads over the replicas."
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_app_username" {
  description = "ElastiCache user the API signs in as, with an IAM token."
  value       = aws_elasticache_user.app.user_name
}

output "app_policy_json" {
  description = "Permissions the API needs on the data stores, for its IRSA role."
  value       = data.aws_iam_policy_document.app.json
}

output "migrator_policy_json" {
  description = "Permissions the migration job needs, for its IRSA role."
  value       = data.aws_iam_policy_document.migrator.json
}

output "postgres_identifier" {
  description = "Identifier of the PostgreSQL instance, the dimension of its CloudWatch metrics."
  value       = aws_db_instance.postgres.identifier
}

output "redis_replication_group_id" {
  description = "ID of the Redis replication group. Its nodes are <id>-001, <id>-002 and so on."
  value       = aws_elasticache_replication_group.redis.replication_group_id
}
