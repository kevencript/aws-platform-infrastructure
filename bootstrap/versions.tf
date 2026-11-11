terraform {
  # Same constraints as the root module, for the same reasons.
  required_version = ">= 1.5.0, != 1.6.0, != 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The GitHub OIDC provider is declared without a thumbprint list, which
      # needs 5.81.0 or newer. 5.100.0 is the release every check runs on.
      version = ">= 5.100.0, < 6.0.0"
    }
  }

  # This stack creates the bucket that holds its own state. The first apply
  # in an account therefore runs on a local backend, set by an override file
  # that is never committed, and the state is then moved here. README.md in
  # this directory has the steps.
  backend "s3" {
    key = "bootstrap/terraform.tfstate"
  }
}
