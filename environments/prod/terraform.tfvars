# Values of the root module for the prod environment.
#
# Nothing in this repository is applied, so the account ID, the domain and the
# cluster admin role are placeholders: the ID is not a real account,
# example.com is reserved for documentation, and the role must exist in the
# account. Replace them before a first apply. The bucket name in backend.hcl
# ends with the account ID and changes with it.
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

# The service. Its image repository is platform/api.
service_name = "api"

# Cluster. At least three nodes, spread over the three zones.
kubernetes_version           = "1.36"
node_instance_types          = ["m6i.large"]
node_scaling                 = { min_size = 3, desired_size = 3, max_size = 6 }
cluster_admin_principal_arns = ["arn:aws:iam::222222222222:role/platform-prod-cluster-admin"]
cluster_log_retention_days   = 90

# Data stores. PostgreSQL with a standby in another zone, and Redis with a
# replica that takes over automatically.
postgres = {
  engine_version            = "17"
  instance_class            = "db.m7g.large"
  multi_az                  = true
  allocated_storage_gib     = 100
  max_allocated_storage_gib = 500
  backup_retention_days     = 14
}
redis = {
  engine                  = "redis"
  engine_version          = "7.1"
  node_type               = "cache.m7g.large"
  num_nodes               = 2
  snapshot_retention_days = 7
}
data_log_retention_days = 90

# Kafka. One broker in each of the three zones: topics keep three copies and
# accept a write once two have it, so they survive the loss of a zone.
kafka = {
  version                   = "3.9.x.kraft"
  instance_type             = "kafka.m7g.large"
  brokers_per_zone          = 1
  volume_size_gib           = 100
  retention_hours           = 168
  broker_log_retention_days = 90
}
