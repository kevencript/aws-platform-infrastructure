# Values of the root module for the dev environment.
#
# Nothing in this repository is applied, so the account ID, the domain and the
# cluster admin role are placeholders: the ID is not a real account,
# example.com is reserved for documentation, and the role must exist in the
# account. Replace them before a first apply. The bucket name in backend.hcl
# ends with the account ID and changes with it.
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

# The service. Its image repository is platform/api.
service_name = "api"

# Cluster. Two burstable nodes, enough for a development API.
kubernetes_version           = "1.36"
node_instance_types          = ["t3.large"]
node_scaling                 = { min_size = 2, desired_size = 2, max_size = 4 }
cluster_admin_principal_arns = ["arn:aws:iam::111111111111:role/platform-dev-cluster-admin"]
cluster_log_retention_days   = 30
