# Values of the bootstrap stack for the dev account.
#
# The first five values must equal those in terraform.tfvars next to this
# file. The quality gate checks that they do. They are placeholders, as
# explained there.
project        = "platform"
environment    = "dev"
aws_region     = "us-east-2"
aws_account_id = "111111111111"
domain_name    = "dev.example.com"

# The repository whose workflows may assume the CI roles. Placeholders too:
# replace them with the real names and numeric IDs before a first apply.
github_owner         = "example-org"
github_owner_id      = "123456"
github_repository    = "example-repo"
github_repository_id = "456789"

# The only branch that may apply to this account.
deploy_branch = "develop"
