# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
