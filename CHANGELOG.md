# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
