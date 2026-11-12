# A WAF web ACL in front of the load balancer. Requests pass unless a rule
# blocks them. The rules run in priority order, cheapest first:
#
#   1   rate limit: an address that sends more than the limit in five
#       minutes is blocked until it slows down
#   10  AWS's list of addresses with a bad reputation
#   20  AWS's common rule set: the usual web exploits
#   30  AWS's known bad inputs: payloads of known vulnerabilities
#
# The rate limit sees the real client address because the load balancer is
# the first hop. Behind a CDN it would need the forwarded address instead.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  managed_rule_groups = {
    AWSManagedRulesAmazonIpReputationList = 10
    AWSManagedRulesCommonRuleSet          = 20
    AWSManagedRulesKnownBadInputsRuleSet  = 30
  }
}

resource "aws_wafv2_web_acl" "api" {
  name        = "${var.name_prefix}-api"
  description = "In front of the ${var.name_prefix} API load balancer"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-address"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.waf_rate_limit
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-address"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = local.managed_rule_groups

    content {
      name     = rule.key
      priority = rule.value

      # A managed group's own rules decide; "none" keeps their actions.
      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"

          # The common rule set blocks request bodies above 8 KB, which a
          # JSON API can send legitimately. That one rule only counts.
          dynamic "rule_action_override" {
            for_each = rule.key == "AWSManagedRulesCommonRuleSet" ? ["SizeRestrictions_BODY"] : []

            content {
              name = rule_action_override.value

              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-api"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_lb.api.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}

# --- logs: only the requests the WAF blocked or counted

locals {
  # WAF writes only to log groups whose name starts with aws-waf-logs-.
  waf_log_group_name = "aws-waf-logs-${var.name_prefix}-api"
  waf_log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.waf_log_group_name}"
}

data "aws_iam_policy_document" "waf_logs_key" {
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
    sid    = "CloudWatchLogsForTheWafLogGroup"
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
      values   = [local.waf_log_group_arn]
    }
  }
}

resource "aws_kms_key" "waf_logs" {
  description         = "Encrypts the WAF logs of ${var.name_prefix}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.waf_logs_key.json
}

resource "aws_kms_alias" "waf_logs" {
  name          = "alias/${var.name_prefix}-waf-logs"
  target_key_id = aws_kms_key.waf_logs.key_id
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = local.waf_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.waf_logs.arn
}

# WAF logs reach the group through the CloudWatch Logs delivery service,
# which needs the group's permission to write, for this account only.
data "aws_iam_policy_document" "waf_log_delivery" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.waf.arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name     = "${var.name_prefix}-waf-log-delivery"
  policy_document = data.aws_iam_policy_document.waf_log_delivery.json
}

# Only blocked and counted requests are kept, and the headers that carry
# credentials are redacted before anything is written.
resource "aws_wafv2_web_acl_logging_configuration" "api" {
  resource_arn            = aws_wafv2_web_acl.api.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      condition {
        action_condition {
          action = "COUNT"
        }
      }
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}
