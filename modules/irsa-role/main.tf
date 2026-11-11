# An IAM role for exactly one Kubernetes service account (IRSA).
#
# A pod that runs under the service account gets a token signed by the
# cluster's OIDC issuer. It exchanges the token at STS for credentials of
# this role. The trust policy accepts the exchange only when the token was
# issued for STS (aud) and names this one service account (sub).

locals {
  # IAM condition keys use the issuer without its scheme.
  issuer = trimprefix(var.oidc_issuer_url, "https://")
}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "ServiceAccount"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  description        = "Assumed by the ${var.namespace}/${var.service_account} service account through IRSA."
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# A map with keys chosen by the caller, so the set of attachments is known
# at plan time even when an ARN is not.
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  name   = "permissions"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}
