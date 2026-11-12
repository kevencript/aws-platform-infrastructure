# The brokers' logs, in a group created before the cluster with a retention
# and a key of its own. Same pattern as the other log groups of the
# platform: CloudWatch Logs may use the key for this one group.

locals {
  broker_log_group_name = "/aws/msk/${local.cluster_name}/brokers"
  broker_log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.broker_log_group_name}"
}

data "aws_iam_policy_document" "broker_logs_key" {
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

  statement {
    sid    = "CloudWatchLogsForTheBrokerLogGroup"
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
      values   = [local.broker_log_group_arn]
    }
  }
}

resource "aws_kms_key" "broker_logs" {
  description         = "Encrypts the Kafka broker logs of ${var.name_prefix}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.broker_logs_key.json
}

resource "aws_kms_alias" "broker_logs" {
  name          = "alias/${local.cluster_name}-logs"
  target_key_id = aws_kms_key.broker_logs.key_id
}

resource "aws_cloudwatch_log_group" "brokers" {
  name              = local.broker_log_group_name
  retention_in_days = var.kafka.broker_log_retention_days
  kms_key_id        = aws_kms_key.broker_logs.arn
}
