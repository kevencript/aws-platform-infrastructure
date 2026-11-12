# messaging

Kafka on Amazon MSK for one environment: one broker per zone of the private data
subnets, reachable only with IAM over TLS.

| File | What it creates |
|------|-----------------|
| `main.tf` | The cluster, its broker configuration and the key that encrypts its data |
| `logs.tf` | The broker log group and its key |
| `client_policy.tf` | The permissions the API needs, published as an output |

## What to know

- **One listener.** Clients use SASL/IAM over TLS on port 9098. There is no plaintext
  listener, no unauthenticated access and no password. Brokers also encrypt traffic
  between themselves.
- **Brokers per zone.** MSK needs the broker count to be a multiple of the number of
  subnets, so the count is `subnets × brokers_per_zone`.
- **Replication follows the broker count.** With three brokers or more, topics get three
  copies and accept a write once two have it: a topic survives the loss of a broker, or
  of a zone. With two brokers, two copies and one in sync, which can lose acknowledged
  writes when a broker fails. That is the dev setting.
- **Topics are created on purpose.** Automatic topic creation is off, and the API may not
  create topics. Creating them is an operation outside this repository.
- **The API's reach.** It may connect, read and write the topics and use the consumer
  groups whose names start with `app_name_prefix`, nothing else. Kafka ACLs do not apply
  to IAM clients; the IAM actions are the access control.
- **No ZooKeeper.** The version string ends with `.kraft`, which creates a cluster that
  keeps its metadata in Kafka itself.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | `<project>-<environment>` |
| `subnet_ids` | `list(string)` | Private data subnets, at least two zones |
| `security_group_id` | `string` | The `msk` group from `modules/security` |
| `kafka` | `object` | `version`, `instance_type`, `brokers_per_zone`, `volume_size_gib`, `retention_hours`, `broker_log_retention_days` |
| `app_name_prefix` | `string` | Prefix of the API's topics and groups, ending with a separator, such as `api.` |

## Outputs

| Name | Description |
|------|-------------|
| `bootstrap_brokers_sasl_iam` | Where clients connect |
| `cluster_arn`, `cluster_name` | The cluster |
| `app_policy_json` | Permissions for the API's IRSA role |
| `broker_count` | Number of brokers, numbered from 1 in their metrics |
