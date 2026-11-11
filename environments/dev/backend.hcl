# Where this account keeps Terraform state. Both stacks read this file:
#   terraform init -backend-config=<this file>
# Each stack names its own object key in its backend block.
# encrypt and kms_key_id go together: encrypt alone would store the state
# under an S3 managed key instead of the state key.
bucket         = "platform-dev-tfstate-111111111111"
region         = "us-east-2"
dynamodb_table = "platform-dev-tfstate-lock"
encrypt        = true
kms_key_id     = "alias/platform-dev-tfstate"
