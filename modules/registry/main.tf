# The service's image repository, in this account.
#
# Each account has its own repository. Copying a released image from the dev
# registry to the prod registry belongs to the pipeline that builds and
# deploys the service, which this repository does not provision.

# Image layers are encrypted with a key of the account. ECR holds grants on
# it and makes the KMS calls itself: pushing and pulling need no permission
# on the key, only creating and deleting the repository do.
resource "aws_kms_key" "images" {
  description         = "Encrypts the images in ${var.name}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "images" {
  name          = "alias/${replace(var.name, "/", "-")}-ecr"
  target_key_id = aws_kms_key.images.key_id
}

resource "aws_ecr_repository" "this" {
  name = var.name

  # A tag, once pushed, always means the same image. A release is deployed
  # by its tag, so what runs can be traced to one build.
  image_tag_mutability = "IMMUTABLE"

  # Basic scanning of every pushed image for known vulnerabilities. An
  # account-wide enhanced scanning setting would belong to an account
  # baseline, not to one service's stack.
  image_scanning_configuration {
    scan_on_push = true
  }

  # Set at creation and never changed: a change replaces the repository.
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.images.arn
  }

  # A repository that still holds images is not deleted with the stack.
  force_delete = false
}

# Which images are deleted, in rule order. An image that matches the tags of
# a rule can only be expired by that rule. A later rule still counts it,
# though: rule 3 keeps the newest images of any kind, and expires only the
# ones that rules 1 and 2 do not cover. The rule with tag status "any" must
# come last. Deletion happens within a day of an image becoming eligible.
data "aws_ecr_lifecycle_policy_document" "this" {
  rule {
    priority    = 1
    description = "Untagged images, usually failed or replaced pushes, after ${var.untagged_expiry_days} days"

    selection {
      tag_status   = "untagged"
      count_type   = "sinceImagePushed"
      count_unit   = "days"
      count_number = var.untagged_expiry_days
    }

    action {
      type = "expire"
    }
  }

  rule {
    priority    = 2
    description = "Release images beyond the newest ${var.max_release_images}"

    selection {
      tag_status       = "tagged"
      tag_pattern_list = var.release_tag_patterns
      count_type       = "imageCountMoreThan"
      count_number     = var.max_release_images
    }

    action {
      type = "expire"
    }
  }

  rule {
    priority    = 3
    description = "Other images, such as commit builds, once outside the newest ${var.max_other_images} images of any kind"

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = var.max_other_images
    }

    action {
      type = "expire"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = data.aws_ecr_lifecycle_policy_document.this.json
}
