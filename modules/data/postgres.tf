# PostgreSQL on RDS. No password exists in code, in a plan or in the state:
# RDS generates the master password, keeps it in a Secrets Manager secret of
# its own and rotates it. Terraform only ever holds the secret's ARN.
#
# The API does not use that password. It signs in with IAM database
# authentication as a user without privileges on the master account. The
# migration job reads the master secret, applies the schema and creates that
# user with GRANT rds_iam. rds_iam is never granted to the master user,
# because IAM authentication would then replace its password.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  postgres_identifier = "${var.name_prefix}-postgres"
}

# --- keys

# Encrypts the database storage, its snapshots and Performance Insights.
resource "aws_kms_key" "postgres" {
  description         = "Encrypts the PostgreSQL storage of ${var.name_prefix}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "postgres" {
  name          = "alias/${var.name_prefix}-postgres"
  target_key_id = aws_kms_key.postgres.key_id
}

# Encrypts the master secret. A key of its own, because the migration job
# may decrypt with it and must not be able to decrypt the storage.
resource "aws_kms_key" "master_secret" {
  description         = "Encrypts the PostgreSQL master secret of ${var.name_prefix}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "master_secret" {
  name          = "alias/${var.name_prefix}-postgres-master-secret"
  target_key_id = aws_kms_key.master_secret.key_id
}

# --- network and parameters

resource "aws_db_subnet_group" "postgres" {
  name        = local.postgres_identifier
  description = "Private data subnets of ${var.name_prefix}"
  subnet_ids  = var.subnet_ids
}

# The parameter group's family follows the major version, so a major
# upgrade needs a new group before the old one goes.
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${local.postgres_identifier}-"
  family      = "postgres${var.postgres.engine_version}"
  description = "PostgreSQL ${var.postgres.engine_version} parameters of ${var.name_prefix}"

  # Connections without TLS are refused. This is already the default from
  # PostgreSQL 15; setting it states the intent.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- enhanced monitoring

data "aws_iam_policy_document" "rds_monitoring_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

# RDS assumes this role to publish operating system metrics of the instance.
resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.postgres_identifier}-monitoring"
  description        = "Assumed by RDS to publish enhanced monitoring metrics of ${local.postgres_identifier}."
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_trust.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- the instance

resource "aws_db_instance" "postgres" {
  identifier     = local.postgres_identifier
  engine         = "postgres"
  engine_version = var.postgres.engine_version
  instance_class = var.postgres.instance_class
  db_name        = var.database_name
  port           = var.postgres_port

  # The master user's password is generated, stored and rotated by RDS.
  username                      = var.master_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.master_secret.arn

  iam_database_authentication_enabled = true

  storage_type          = "gp3"
  allocated_storage     = var.postgres.allocated_storage_gib
  max_allocated_storage = var.postgres.max_allocated_storage_gib
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.postgres.arn

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [var.postgres_security_group_id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.postgres.name

  # A standby in a second zone takes over if the primary fails.
  multi_az = var.postgres.multi_az

  backup_retention_period = var.postgres.backup_retention_days
  copy_tags_to_snapshot   = true

  # On in every environment. Destroying the database means turning this off
  # in code first, which is a change somebody reviews.
  deletion_protection = true

  # A last snapshot is taken when the instance is deleted.
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.postgres_identifier}-final"

  # RDS resolves the minor version and applies minor upgrades in the
  # maintenance window. A major upgrade is a deliberate change in code.
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.postgres.arn
  performance_insights_retention_period = 7
  database_insights_mode                = "standard"

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  depends_on = [
    aws_iam_role_policy_attachment.rds_monitoring,
    aws_cloudwatch_log_group.data,
  ]
}
