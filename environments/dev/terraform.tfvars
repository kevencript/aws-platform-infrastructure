# Values of the root module for the dev environment.
#
# Nothing in this repository is applied, so the account ID and the domain are
# placeholders: the ID is not a real account, and example.com is reserved for
# documentation. Replace both before a first apply. The bucket name in
# backend.hcl ends with the account ID and changes with it.
project        = "platform"
environment    = "dev"
aws_region     = "us-east-2"
aws_account_id = "111111111111"
domain_name    = "dev.example.com"

# Network. Two zones and one shared NAT gateway: dev accepts losing outbound
# access during an outage of the first zone, to save a second gateway.
vpc_cidr                = "10.20.0.0/16"
availability_zones      = ["us-east-2a", "us-east-2b"]
nat_gateway_mode        = "single"
flow_log_retention_days = 30
