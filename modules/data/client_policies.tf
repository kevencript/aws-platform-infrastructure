# The smallest permissions each client of the data stores needs. This
# module owns the stores, so it knows their ARNs; the root module attaches
# each document to the IRSA role of the matching service account.

# The API: sign in to PostgreSQL as its own database user and to Redis as
# its own ElastiCache user, both with IAM. Nothing else.
data "aws_iam_policy_document" "app" {
  statement {
    sid     = "PostgresAsTheAppUser"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgres.resource_id}/${var.app_username}",
    ]
  }

  statement {
    sid     = "RedisAsTheAppUser"
    effect  = "Allow"
    actions = ["elasticache:Connect"]
    resources = [
      aws_elasticache_replication_group.redis.arn,
      aws_elasticache_user.app.arn,
    ]
  }
}

# The migration job: read the master secret, and decrypt it only through
# Secrets Manager.
data "aws_iam_policy_document" "migrator" {
  statement {
    sid       = "ReadTheMasterSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
  }

  statement {
    sid       = "DecryptTheMasterSecret"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.master_secret.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}
