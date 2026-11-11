# data

PostgreSQL on RDS and Redis on ElastiCache for one environment, in the private data
subnets, with no password anywhere in code, a plan or the state.

| File | What it creates |
|------|-----------------|
| `postgres.tf` | The instance, its subnet group and parameter group, a storage key, a key for the master secret, and the enhanced monitoring role |
| `redis.tf` | The replication group, its subnet group, its key, and the users and user group it authenticates against |
| `logs.tf` | Log groups for the PostgreSQL logs and the Redis slow log, and one key for all of them |
| `client_policies.tf` | The permissions the API and the migration job need, published as outputs |

## How each client signs in

| Client | PostgreSQL | Redis |
|--------|------------|-------|
| API | IAM database authentication as `app_username`, a user without privileges on the master account | IAM authentication as the ElastiCache user `<prefix>-redis-<app_username>` |
| Migration job | The master user, whose password it reads from the secret RDS manages | None |

- **Master password.** RDS generates it, keeps it in a Secrets Manager secret encrypted
  with a key of its own, and rotates it. Terraform holds only the secret's ARN.
- **The API's database user.** The migration job creates it with `GRANT rds_iam`.
  Terraform never connects to the database. `rds_iam` is never granted to the master
  user, because IAM authentication would then replace its password.
- **Redis users.** The Redis OSS engine requires a user named `default` in every user
  group. It is replaced by one that is switched off and may run nothing. The API's user
  may run every command except the dangerous ones, such as `FLUSHALL`, `CONFIG` and
  `KEYS`.
- **TLS.** PostgreSQL refuses connections without it (`rds.force_ssl`), and Redis
  requires it (`transit_encryption_mode = "required"`), which IAM authentication needs
  anyway.

## Resilience and protection

- PostgreSQL runs Multi-AZ when `postgres.multi_az` is true. Redis gets a replica in
  another zone, with automatic failover, when `redis.num_nodes` is above 1.
- Deletion protection is on in every environment, and a final snapshot is taken on
  delete. Destroying the database starts with turning the protection off in code.
- Storage grows on its own up to `postgres.max_allocated_storage_gib`.
- RDS applies minor versions in the maintenance window; a major version is a change in
  code.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name_prefix` | `string` | `<project>-<environment>` |
| `subnet_ids` | `list(string)` | Private data subnets, at least two zones |
| `postgres_security_group_id`, `redis_security_group_id` | `string` | From `modules/security` |
| `postgres_port`, `redis_port` | `number` | From `modules/security`, so the rule and the listener agree |
| `database_name` | `string` | Database created with the instance |
| `app_username` | `string` | The API's user name |
| `master_username` | `string` | Default: `dbadmin` |
| `postgres` | `object` | `engine_version` (major), `instance_class`, `multi_az`, `allocated_storage_gib`, `max_allocated_storage_gib`, `backup_retention_days` |
| `redis` | `object` | `engine` (`redis` or `valkey`), `engine_version`, `node_type`, `num_nodes`, `snapshot_retention_days` |
| `log_retention_days` | `number` | Retention of the log groups |

## Outputs

| Name | Description |
|------|-------------|
| `postgres_address`, `postgres_port`, `database_name` | Where the API connects |
| `postgres_master_secret_arn` | The master secret, for the migration job |
| `redis_primary_endpoint`, `redis_reader_endpoint`, `redis_app_username` | Where and as whom the API connects to Redis |
| `app_policy_json`, `migrator_policy_json` | Permissions for the two IRSA roles |
