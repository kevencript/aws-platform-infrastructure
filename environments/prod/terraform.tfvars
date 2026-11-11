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

# Network. Three zones, because Kafka with replication factor 3 survives the
# loss of a zone only with three, and a NAT gateway in each of them.
vpc_cidr                = "10.30.0.0/16"
availability_zones      = ["us-east-2a", "us-east-2b", "us-east-2c"]
nat_gateway_mode        = "per_az"
flow_log_retention_days = 90
