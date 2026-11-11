# Values of the root module for the prod environment.
#
# Nothing in this repository is applied, so the account ID and the domain are
# placeholders: the ID is not a real account, and example.com is reserved for
# documentation. Replace both before a first apply. The bucket name in
# backend.hcl ends with the account ID and changes with it.
project        = "platform"
environment    = "prod"
aws_region     = "us-east-2"
aws_account_id = "222222222222"
domain_name    = "prod.example.com"
