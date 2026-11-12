# Kafka on Amazon MSK: one broker per zone of the private data subnets.
#
# Clients authenticate with IAM over TLS (SASL/IAM, port 9098). There is no
# other listener: no plaintext, no unauthenticated access, no password.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  cluster_name = "${var.name_prefix}-kafka"

  # MSK requires the broker count to be a multiple of the number of subnets.
  broker_count = length(var.subnet_ids) * var.kafka.brokers_per_zone

  # With three brokers or more, a partition has three copies and accepts a
  # write once two have it, so it survives the loss of one broker, or of one
  # zone when each zone holds one copy. With two brokers, two copies and
  # one in sync: a broker failure can lose acknowledged writes. That is
  # accepted for dev only, where the zones are two.
  replication_factor  = min(local.broker_count, 3)
  min_insync_replicas = local.broker_count >= 3 ? 2 : 1
}

resource "aws_kms_key" "kafka" {
  description         = "Encrypts the Kafka data of ${var.name_prefix}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "kafka" {
  name          = "alias/${local.cluster_name}"
  target_key_id = aws_kms_key.kafka.key_id
}

# Broker settings. Topics are created on purpose, never by the first client
# that writes to a name, and a replica that fell behind never becomes leader.
resource "aws_msk_configuration" "kafka" {
  name           = local.cluster_name
  kafka_versions = [var.kafka.version]
  description    = "Broker settings of ${local.cluster_name}"

  server_properties = <<-PROPERTIES
    auto.create.topics.enable=false
    default.replication.factor=${local.replication_factor}
    min.insync.replicas=${local.min_insync_replicas}
    unclean.leader.election.enable=false
    num.partitions=3
    log.retention.hours=${var.kafka.retention_hours}
  PROPERTIES
}

resource "aws_msk_cluster" "kafka" {
  cluster_name           = local.cluster_name
  kafka_version          = var.kafka.version
  number_of_broker_nodes = local.broker_count

  # Per-cluster and per-topic metrics in CloudWatch, at no extra cost.
  enhanced_monitoring = "DEFAULT"

  broker_node_group_info {
    instance_type   = var.kafka.instance_type
    client_subnets  = var.subnet_ids
    security_groups = [var.security_group_id]

    storage_info {
      ebs_storage_info {
        volume_size = var.kafka.volume_size_gib
      }
    }

    connectivity_info {
      public_access {
        type = "DISABLED"
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kafka.arn

    # TLS between clients and brokers, and between brokers.
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    unauthenticated = false

    sasl {
      iam = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.kafka.arn
    revision = aws_msk_configuration.kafka.latest_revision
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.brokers.name
      }
    }
  }
}
