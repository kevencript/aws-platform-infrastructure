# The plan role. Any pull request raised from a branch of the repository can
# assume it, and such a pull request can also change the workflow it runs.
# The role is therefore treated as available to anyone who can push a branch:
# it reads configuration and the root state, and it has no write permission
# of any kind. A plan needs none when it runs with -lock=false, which is how
# the pull request job runs it.

locals {
  # Object key of the root module's state. It must equal the key in the
  # backend block of versions.tf in the repository root. It is the one S3
  # object the plan role may read.
  root_state_key = "platform/terraform.tfstate"
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    sid     = "GitHubPullRequestRuns"
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

    # A job gets this subject only on a pull_request event and only if it
    # names no GitHub environment. IAM has no condition for the target
    # branch, so the subject is the whole control.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = ["${local.github_subject_prefix}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${local.name_prefix}-ci-plan"
  description        = "Assumed by pull request runs to plan. Read-only: it holds no write permission."
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

# What a plan reads: the configuration of every resource the root module
# manages. The AWS managed policy is kept up to date by AWS as services
# change. It also allows some reads of data; the Deny statements below close
# the ones that matter here.
resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan" {
  # --- What the S3 backend needs for a plan -------------------------------

  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadRootState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.root_state_key}"]
  }

  statement {
    sid       = "DecryptState"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.state.arn]
  }

  # The backend keeps a checksum of the state next to the lock and reads it
  # to detect a stale read. The role cannot write to the table, so it cannot
  # take the lock: the pull request plan runs with -lock=false. That plan is
  # never applied. If it overlaps an apply it can fail on the checksum or show
  # a stale result, and it is run again.
  statement {
    sid       = "ReadLockTable"
    effect    = "Allow"
    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.lock.arn]
  }

  # --- What ReadOnlyAccess must not be used for ---------------------------
  # An explicit Deny wins over any Allow, including one that AWS adds to the
  # managed policy later.

  statement {
    sid       = "DenySecretValues"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:BatchGetSecretValue"]
    resources = ["*"]
  }

  # Secrets and encrypted parameters are decrypted with the caller's own
  # permissions, so this also blocks them at the key.
  statement {
    sid           = "DenyDecryptExceptState"
    effect        = "Deny"
    actions       = ["kms:Decrypt"]
    not_resources = [aws_kms_key.state.arn]
  }

  # The root state is the only S3 object this role reads. That excludes this
  # stack's own state and every object in any other bucket. The third action
  # is how objects in a directory bucket are read: through a session, which
  # ReadOnlyAccess allows in read-only mode.
  statement {
    sid           = "DenyObjectsExceptRootState"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:GetObjectVersion", "s3express:CreateSession"]
    not_resources = ["${aws_s3_bucket.state.arn}/${local.root_state_key}"]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "state-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}
