# The topic every alarm notifies, when it fires and when it recovers.
#
# It is encrypted with a key of its own. The key AWS manages for SNS would
# not let CloudWatch publish, and the alarms would fail to notify without an
# error anywhere.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "alarms_key" {
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

  # CloudWatch encrypts each notification it publishes to the topic.
  statement {
    sid       = "CloudWatchAlarmsOfThisAccount"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "alarms" {
  description         = "Encrypts the alarm notifications of ${var.name_prefix}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.alarms_key.json
}

resource "aws_kms_alias" "alarms" {
  name          = "alias/${var.name_prefix}-alarms"
  target_key_id = aws_kms_key.alarms.key_id
}

resource "aws_sns_topic" "alarms" {
  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = aws_kms_key.alarms.arn
}

# Only this account's alarms may publish to the topic.
data "aws_iam_policy_document" "alarms_topic" {
  statement {
    sid       = "CloudWatchAlarmsOfThisAccount"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:*"]
    }
  }
}

resource "aws_sns_topic_policy" "alarms" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.alarms_topic.json
}

# Each address must confirm its subscription from the email AWS sends; until
# then it receives nothing.
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alarm_email_addresses)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

locals {
  # Every alarm notifies when it fires and when it recovers.
  alarm_actions = [aws_sns_topic.alarms.arn]
}
