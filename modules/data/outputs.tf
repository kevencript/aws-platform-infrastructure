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

