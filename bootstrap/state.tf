# Where Terraform state lives in this account: an encryption key, a versioned
# bucket and a lock table. Both states of the account use them: this stack's
# own state and the root module's.

# No key policy is set, so the default one applies: the account's IAM policies
# decide who may use the key. The CI roles get that access in their own files.
resource "aws_kms_key" "state" {
  description         = "Encrypts the Terraform state of ${local.name_prefix}"
  enable_key_rotation = true

  # Without this key, no version of the state can be read again.
  lifecycle {
    prevent_destroy = true
  }
}

# The alias gives the key a name that is known before the key exists, so
# environments/<env>/backend.hcl can be committed without a key ID.
resource "aws_kms_alias" "state" {
  name          = "alias/${local.name_prefix}-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

# Access logging is left out on purpose. It needs a second bucket, and S3
# requires a log destination to use S3 managed keys, so that bucket could not
# use this key and the scanner would flag it in turn. Requests to the state
# are better recorded by CloudTrail data events, an account-wide setting
# outside this stack.
#trivy:ignore:AWS-0089
resource "aws_s3_bucket" "state" {
  # Bucket names are global, so the account ID makes this one unique.
  bucket = "${local.name_prefix}-tfstate-${var.aws_account_id}"

  # The bucket holds the only record of what Terraform manages.
  lifecycle {
    prevent_destroy = true
  }
}

# Every write keeps the previous state as an older version, which is the way
# back from a bad apply or a damaged state file.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Objects written without an encryption header still get this key. The
# backend also names the key on every write (kms_key_id in backend.hcl).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
  }
}

# New buckets already block public access. Declaring it keeps the setting in
# code, so a change made by hand shows up as drift.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Every request to the bucket must use TLS. Terraform and the AWS SDKs already
# do, so this changes nothing for them; it refuses any client that would not.
# A statement that only denies does not make the policy public, so the public
# access block above does not reject it.
data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid     = "DenyRequestsWithoutTls"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  # S3 can reject two configuration changes made to one bucket at the same
  # time, so the policy waits for the public access block.
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# The S3 backend takes a lock by writing an item to this table, and requires
# the partition key to be a string named LockID.
#
# Two scanner findings are accepted here. The table holds lock records and a
# checksum of the state, never the state itself.
# AWS-0024, point-in-time recovery: nothing in the table is worth restoring. A
# lock is gone when the run ends, and a restored checksum would be out of date.
# AWS-0025, customer managed key: DynamoDB already encrypts the table with a
# key it owns. Using the state key here would add KMS permissions to both CI
# roles and protect nothing that is secret.
#trivy:ignore:AWS-0024
#trivy:ignore:AWS-0025
resource "aws_dynamodb_table" "lock" {
  name         = "${local.name_prefix}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
