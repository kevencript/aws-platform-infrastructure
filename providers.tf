provider "aws" {
  region = var.aws_region

  # A run that holds credentials for any other account fails when the
  # provider is configured, before it changes anything.
  allowed_account_ids = [var.aws_account_id]

  # Every resource gets these tags. Stack names the Terraform configuration
  # that owns the resource: "root" is this module, "bootstrap" is bootstrap/.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Stack       = "root"
      ManagedBy   = "terraform"
    }
  }
}
