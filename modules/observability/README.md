# observability

CloudWatch alarms on every layer of the platform, and the encrypted SNS topic they
notify when they fire and when they recover.

| Alarm | Metric | Fires when |
|-------|--------|------------|
| `postgres-cpu` | `AWS/RDS` `CPUUtilization` | Average ≥ 80% for 15 minutes |
| `postgres-free-storage` | `AWS/RDS` `FreeStorageSpace` | Below 10% of the allocated storage, or no data |
| `redis-00N-memory`, per node | `AWS/ElastiCache` `DatabaseMemoryUsagePercentage` | Average ≥ 80% of the memory limit for 15 minutes |
| `nodes-cpu`, `nodes-memory`, `nodes-filesystem` | `ContainerInsights` `node_*_utilization` | The busiest node ≥ 80% for 15 minutes, or no data |
| `node-group-cpu` | `AWS/EC2` `CPUUtilization` of the node group | Average ≥ 80% for 15 minutes |
| `kafka-offline-partitions` | `AWS/Kafka` `OfflinePartitionsCount` | Any partition without a leader for 3 minutes |
| `kafka-broker-N-disk`, per broker | `AWS/Kafka` `KafkaDataLogsDiskUsed` | ≥ 80% for 10 minutes |
| `api-5xx` | `AWS/ApplicationELB` `HTTPCode_Target_5XX_Count` | More than `api_5xx_threshold` in 5 minutes |
| `api-unhealthy-targets` | `AWS/ApplicationELB` `UnHealthyHostCount` | A pod fails its health check for 3 minutes |

## What to know

- **Missing data.** Utilisation alarms keep `INSUFFICIENT_DATA` visible. Free storage and
  the Container Insights alarms treat silence as a failure: those metrics are always
  published, so no data means something stopped reporting. Event counts treat silence
  as healthy.
- **Node pressure needs the CloudWatch agent,** which the compute module installs. The
  `node-group-cpu` alarm reads EC2's own metric and works without it.
- **Names known before the resources exist.** Redis nodes are `<group>-001`, `-002` and
  so on, and MSK numbers brokers from 1, so the per-node alarms can be planned before
  the nodes exist.
- **The topic's key.** The key AWS manages for SNS does not let CloudWatch publish; the
  alarms would fail to notify without an error. The topic uses a key whose policy lets
  this account's CloudWatch alarms use it, and only they may publish to the topic.
- **Email subscriptions** stay pending until each address confirms them.
- `terraform validate` does not check namespaces, metric names or dimensions. A typo
  leaves an alarm in `INSUFFICIENT_DATA`. The names here are the documented ones.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | `<project>-<environment>` |
| `alarm_email_addresses` | `list(string)` | Subscribers of the topic. Default: none |
| `postgres_identifier`, `postgres_allocated_storage_gib` | | From `modules/data` and the environment's values |
| `redis_replication_group_id`, `redis_num_nodes` | | From `modules/data` and the environment's values |
| `cluster_name`, `node_group_autoscaling_group_name` | `string` | From `modules/compute` |
| `kafka_cluster_name`, `kafka_broker_count` | | From `modules/messaging` |
| `load_balancer_arn_suffix`, `target_group_arn_suffix` | `string` | From `modules/edge` |
| `api_5xx_threshold` | `number` | Default: 10 |

## Outputs

| Name | Description |
|------|-------------|
| `alarm_topic_arn` | The topic every alarm notifies |
