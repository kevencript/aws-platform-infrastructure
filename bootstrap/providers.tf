provider "aws" {
  region = var.aws_region

  # This stack is applied by hand with administrator credentials, so it is
  # the apply most exposed to running in the wrong account. The provider
  # refuses any account other than the one named in the variable file.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Stack       = "bootstrap"
      ManagedBy   = "terraform"
    }
  }
}
