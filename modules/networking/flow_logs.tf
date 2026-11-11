# VPC flow logs: a record of every connection accepted or rejected in the
# VPC, delivered to a CloudWatch Logs group encrypted with a key of its own.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  flow_log_group_name = "/aws/vpc/${var.name_prefix}/flow-logs"

  # Built from the name, not read from the log group, because the key policy
  # below must exist before the group can be created with the key.
  flow_log_group_arn = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.flow_log_group_name}"
}

data "aws_iam_policy_document" "flow_logs_key" {
  # The account's IAM policies decide who else may use the key. This is the
  # statement a key gets when no policy is given.
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

  # CloudWatch Logs encrypts with the key itself, as a service, so the key
  # policy must name it. The condition limits it to this one log group.
  statement {
    sid    = "CloudWatchLogsForTheFlowLogGroup"
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
      values   = [local.flow_log_group_arn]
    }
  }
}

resource "aws_kms_key" "flow_logs" {
  description         = "Encrypts the VPC flow logs of ${var.name_prefix}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.flow_logs_key.json
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.name_prefix}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = local.flow_log_group_name
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.flow_logs.arn
}

# The role the flow log service assumes to write into the group. The two
# conditions keep another account's flow logs from using it.
data "aws_iam_policy_document" "flow_logs_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"]
    }
  }
}

# Writes to this group only. The group is created by Terraform, so the role
# needs no permission to create one.
data "aws_iam_policy_document" "flow_logs_write" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.flow_logs.arn,
      "${aws_cloudwatch_log_group.flow_logs.arn}:*",
    ]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name_prefix}-vpc-flow-logs"
  description        = "Assumed by VPC Flow Logs to write into ${local.flow_log_group_name}."
  assume_role_policy = data.aws_iam_policy_document.flow_logs_trust.json
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_write.json
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  # Ten minutes is the default. One minute gives finer records for a higher
  # volume of logs.
  max_aggregation_interval = 600

  tags = {
    Name = var.name_prefix
  }
}
