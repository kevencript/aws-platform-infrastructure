# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-11

### Added

- Decision records (`docs/adr/`) for the seven main decisions, each with its
  alternatives and consequences.
- README sections on the key decisions, the root module's outputs, what was left out and
  why, the accepted trade-offs and the assumptions.

### Changed

- Dev's Kafka brokers run on `kafka.m7g.large`, the smallest type that offers KRaft
  mode, so dev keeps the same metadata mode as prod.

### Fixed

- The `node` security group's description contained a character EC2 rejects, which
  would have failed the first apply; a precondition now names the allowed characters.
- `modules/messaging` rejects KRaft mode on `kafka.t3.small` brokers, which MSK does not
  offer.
- The Container Insights performance log group is created before the CloudWatch agent,
  with a retention and the cluster's logs key, instead of by the agent without either.
- Documentation: the environment check runs the rules of each stack's own variables, not
  those inside modules; how the image lifecycle's third rule counts images; outputs
  missing from three module READMEs; two closed open points on Kafka.

## [0.5.0] - 2026-11-11

### Added

- Edge module (`modules/edge`): ACM certificate validated through the hosted zone, an
  internet-facing Application Load Balancer with an HTTPS listener on TLS 1.2 and 1.3
  and an HTTP listener that only redirects, an `ip` target group for the API's pods, the
  alias record of the API's host name, a WAF web ACL with a rate limit and three AWS
  managed rule groups, its filtered and redacted logs, and the load balancer
  controller's policy limited to the one target group.
- IRSA role for the AWS Load Balancer Controller, and the WAF log retention for `dev`
  and `prod`.
- Observability module (`modules/observability`): an alarm topic encrypted with a key
  that CloudWatch alarms may use, and alarms on PostgreSQL CPU and free storage, Redis
  memory per node, EKS node CPU, memory and file system from Container Insights, the
  node group's CPU from EC2, Kafka offline partitions and broker disks, and the API's
  server errors and unhealthy pods.
- The CloudWatch agent add-on in `modules/compute`, with an IRSA role of its own and
  container log shipping off.
- Outputs the alarms need: the node group's Auto Scaling group, the PostgreSQL
  identifier, the Redis replication group ID and the Kafka broker count.

## [0.4.0] - 2026-11-11

### Added

- Data module (`modules/data`): PostgreSQL on RDS with an RDS-managed master password,
  IAM database authentication, TLS required, Multi-AZ when asked, deletion protection
  and a final snapshot; Redis on ElastiCache with TLS required, encryption at rest and
  an ElastiCache user that authenticates with IAM; log groups and keys of their own;
  the client policies of the API and the migration job.
- IRSA roles for the API's service account and the migration job's, bound in the root
  module to the policies the data module publishes.
- Data store values for `dev` (single-AZ PostgreSQL, one Redis node) and `prod`
  (Multi-AZ PostgreSQL, Redis with a replica).
- Messaging module (`modules/messaging`): Kafka on MSK in KRaft mode, one broker per
  zone, SASL/IAM over TLS as the only listener, encryption at rest with a key of its
  own, no automatic topic creation, replication derived from the broker count, broker
  logs in an encrypted log group, and the API's Kafka policy limited to a name prefix.
- Kafka permissions on the API's IRSA role, and Kafka values for `dev` (two
  kafka.t3.small brokers) and `prod` (three kafka.m7g.large brokers).

### Changed

- `modules/irsa-role` takes inline policies as `inline_policies`, a map with keys chosen
  by the caller, instead of `inline_policy_json`. A count that compared a document
  with null could not be known at plan time when the document depends on new resources.

## [0.3.0] - 2026-11-11

### Added

- Networking module (`modules/networking`): VPC, public, private app and private data
  subnets in every zone, internet gateway, NAT gateways per zone or shared, route tables
  per tier with no default route in the data tier, S3 gateway endpoint, and VPC flow
  logs in a CloudWatch Logs group encrypted with its own key.
- Security module (`modules/security`): security groups for the load balancer, the
  nodes and the three data stores, with each internal flow written as a rule pair that
  names groups, not address ranges.
- Network values for `dev` (two zones, one NAT gateway) and `prod` (three zones, a NAT
  gateway in each).
- Compute module (`modules/compute`): EKS cluster with a private API endpoint, access
  entries, Kubernetes secrets and control plane logs encrypted with keys of the account,
  and standard support only; a managed node group on Amazon Linux 2023 with IMDSv2 and a
  hop limit of 1; the `vpc-cni`, `kube-proxy` and `coredns` add-ons; the OIDC provider
  for IRSA.
- IRSA role module (`modules/irsa-role`): an IAM role trusted by exactly one Kubernetes
  service account.
- Registry module (`modules/registry`): ECR repository with immutable tags, scan on
  push, a key of the account and a lifecycle policy.
- Cluster and repository values for `dev` (two t3.large nodes) and `prod` (at least
  three m6i.large nodes).

## [0.2.0] - 2026-11-11

### Added

- Bootstrap stack, applied once in each AWS account (`bootstrap/`): encrypted and
  versioned state bucket that refuses requests without TLS, lock table, state
  encryption key, public hosted zone, GitHub OIDC provider, and the two CI roles. The
  plan role is read-only, cannot take the state lock and has no access to secret
  values. The apply role can be assumed only from its GitHub environment and its deploy
  branch.
- Root module skeleton: Terraform and provider version constraints, S3 backend, AWS
  provider restricted to the environment's account, default tags, identity variables
  and the lookup of the hosted zone.
- Environment files for `dev` and `prod` with placeholder values
  (`environments/<env>/`): root variables, bootstrap variables and backend settings.
- Provider lock files for Linux and macOS, on amd64 and arm64.
- Local quality gate (`make check`): format check, validation on Terraform 1.5.7 and
  1.15.1, a check of the environment files against the code, and a trivy scan.
- GitHub Actions workflow (`.github/workflows/terraform.yml`): the checks of the quality
  gate on every pull request and push, a plan per account on pull requests, and an apply
  on a push to `develop` (dev) or `main` (prod), each with its account's CI role through
  OIDC. Actions are pinned to commit SHAs.

### Changed

- Architecture plan: the apply role's trust policy also pins the deploy branch, the
  backend file is shared by both stacks and no longer names the state object, and the
  CI roles are described statement by statement (`docs/architecture.md`).

## [0.1.0] - 2026-11-11

### Added

- Architecture diagram of the production topology, generated from code as an
  Excalidraw scene and a PNG (`diagram.png`, `docs/diagrams/`, `tools/diagram/`).
- Written architecture plan: traffic flows, network layout, security group matrix,
  identity model, state strategy, open points and delivery roadmap
  (`docs/architecture.md`).
- Contribution guide covering Git Flow, Conventional Commits and the release process.
- Pull request template.
