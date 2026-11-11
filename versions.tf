terraform {
  # 1.5 is the oldest Terraform this code is validated on, and 1.15.1 the
  # newest. Two releases in between are excluded.
  # 1.6.0 rejects a key alias in the backend's kms_key_id, fixed in 1.6.1.
  # 1.15.0 makes validate require the backend's required arguments in the
  # block, and a partial configuration leaves the bucket to backend.hcl;
  # 1.15.1 took that back.
  required_version = ">= 1.5.0, != 1.6.0, != 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.100.0 is the newest 5.x release and the one every check runs on.
      # Major version 6 is excluded on purpose.
      version = ">= 5.100.0, < 6.0.0"
    }
  }

  # The bucket, region, lock table and encryption key differ per account and
  # come from environments/<env>/backend.hcl. The object key is the same in
  # every account, so it is written here. The bootstrap stack reads the same
  # file, and a key in that file would point both stacks at one object.
  backend "s3" {
    key = "platform/terraform.tfstate"
  }
}
