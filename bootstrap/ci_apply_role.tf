# The apply role. It creates everything the root module manages, including
# IAM roles for the cluster and its workloads. A principal that can create
# roles and attach policies to them can give itself any permission, so a
# shorter list of allowed services would not make this role weaker. The role
# is an administrator of its own account, and the controls are placed where
# they hold:
#
#   - the trust policy below decides who can become the role;
#   - the account is the limit of what the role can reach: it holds one
#     environment, and no role in the other account trusts this one;
#   - the Deny statements stop the role from changing the CI roles, the OIDC
#     provider, and the configuration of the state bucket, the lock table and
#     the state key, from reading or writing this stack's own state, and from
#     deleting the hosted zone.
#
# They stop such a change when it arrives as a change to the root module.
# They do not stop the creation of a new role, so they do not stop someone
# who already controls an apply run: that person can create a second role
# without them.

data "aws_iam_policy_document" "apply_trust" {
  statement {
    sid     = "GitHubDeployRuns"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = [local.github_oidc_audience]
    }

    # The job must name this account's GitHub environment, so the
    # environment's protection rules apply before the job starts.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = ["${local.github_subject_prefix}:environment:${var.environment}"]
    }

    # The run must also come from the deploy branch. Any job can name an
    # environment, including one in a pull request, and GitHub creates an
    # environment that does not exist yet without any rule. This condition
    # does not depend on how the environment is configured. It does depend
    # on who can push to the branch, which is why the branch is protected.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:ref"
      values   = ["refs/heads/${var.deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name               = "${local.name_prefix}-ci-apply"
  description        = "Assumed by deploy runs of the ${var.environment} GitHub environment to apply the root module."
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json

  # A first apply creates the cluster, the database and the Kafka brokers
  # and can run longer than IAM's default limit of one hour. Terraform does
  # not renew the credentials of a run, so the session may last two hours.
  max_session_duration = 7200
}

locals {
  # Object key of this stack's own state. It must equal the key in the
  # backend block of versions.tf in this directory.
  bootstrap_state_key = "bootstrap/terraform.tfstate"
}

data "aws_iam_policy_document" "apply_guardrails" {
  # The pipeline cannot change the trust or the permissions of the two CI
  # roles, or the provider they trust.
  statement {
    sid     = "DenyChangesToCiIdentity"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = [
      aws_iam_role.apply.arn,
      aws_iam_role.plan.arn,
      aws_iam_openid_connect_provider.github.arn,
    ]
  }

  # On the bucket, the lock table and the key, the pipeline may make the
  # calls the S3 backend makes and no others. It cannot delete them, delete
  # an old version of the state, or change a policy, versioning or
  # encryption.
  statement {
    sid    = "DenyStateStoreAdministration"
    effect = "Deny"
    not_actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
      aws_dynamodb_table.lock.arn,
      aws_kms_key.state.arn,
    ]
  }

  # The bucket holds two states. The pipeline reads and writes the root
  # module's. This stack's own state belongs to the person who applies it.
  statement {
    sid       = "DenyBootstrapState"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.state.arn}/${local.bootstrap_state_key}"]
  }

  # The pipeline manages the records in the zone, but the zone itself stays.
  statement {
    sid       = "DenyHostedZoneDeletion"
    effect    = "Deny"
    actions   = ["route53:DeleteHostedZone"]
    resources = [aws_route53_zone.public.arn]
  }
}

resource "aws_iam_role_policy" "apply_guardrails" {
  name   = "bootstrap-guardrails"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_guardrails.json
}

resource "aws_iam_role_policy_attachment" "apply_administrator" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  # The guard rails are attached first, so the role never holds
  # administrator rights without them.
  depends_on = [aws_iam_role_policy.apply_guardrails]
}
