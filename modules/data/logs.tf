# The log groups of the data stores, created before the stores so that RDS
# writes into them instead of creating groups without a retention or a key.
# One key encrypts all of them.

locals {
  log_group_names = {
    postgresql       = "/aws/rds/instance/${local.postgres_identifier}/postgresql"
    postgres_upgrade = "/aws/rds/instance/${local.postgres_identifier}/upgrade"
  }

  log_group_arn_prefix = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:"
}

data "aws_iam_policy_document" "logs_key" {
  statement {
    sid       = "AccountIamPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # CloudWatch Logs may use the key for these log groups only.
  statement {
    sid    = "CloudWatchLogsForTheDataLogGroups"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [for name in values(local.log_group_names) : "${local.log_group_arn_prefix}${name}"]
    }
  }
}

resource "aws_kms_key" "logs" {
  description         = "Encrypts the logs of the data stores of ${var.name_prefix}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.logs_key.json
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-data-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_cloudwatch_log_group" "data" {
  for_each = local.log_group_names

  name              = each.value
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
}
