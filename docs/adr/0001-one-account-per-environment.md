# 1. One AWS account per environment, environments as data

Status: accepted

## Context

The platform runs in two environments, `dev` and `prod`, from the same code. They need
separate state, and a mistake in one must not reach the other. Terraform offers
workspaces for this, and a single AWS account could hold both environments.

## Decision

- Each environment runs in its own AWS account. The bootstrap stack is applied once in
  each and creates that account's state bucket, lock table, state key, GitHub OIDC
  provider, CI roles and hosted zone. The accounts share no AWS resource.
- Each account holds two states: the bootstrap stack's and the root module's.
- An environment is a directory of data, `environments/<env>/`: the root module's
  variables, the bootstrap stack's variables, and the backend settings. The files have
  the same keys in both environments and are committed.
- The provider is restricted to the environment's account with `allowed_account_ids`.

## Alternatives considered

- **Terraform workspaces.** All workspaces of a configuration share one backend, so both
  states would sit in one bucket in one account, and the selected workspace is local
  state that never appears in review.
- **One account for both environments.** Cheaper to set up, but dev and prod would be
  separated only by names and IAM conditions, and a policy that is too broad in dev
  would reach prod.
- **One state per layer** (network, cluster, data). A smaller blast radius per apply, at
  the cost of wiring states together. Deferred: the modules are already cut along those
  boundaries.

## Consequences

- An IAM policy that is too broad in dev grants nothing in prod.
- Every bootstrap resource exists twice, and each account is set up by hand once.
- A run with the wrong credentials fails when the provider is configured.
- The accounts still share the repository: its workflows can assume the CI roles of
  both.
