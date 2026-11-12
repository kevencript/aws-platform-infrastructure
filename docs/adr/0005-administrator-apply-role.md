# 5. An administrator apply role, limited by trust, account and Deny statements

Status: accepted

## Context

The pipeline applies the root module, which creates IAM roles for the cluster, its
nodes and its workloads. A principal that can create roles and attach policies to them
can give itself any permission.

## Decision

The apply role of each account holds the AWS managed `AdministratorAccess` policy.
Three things limit it instead of a list of services:

- **Its trust policy:** one repository, identified by its numeric owner and repository
  IDs; one GitHub environment; one branch, checked in IAM with the token's `ref`.
- **Its account:** it reaches one environment, and no role in the other account trusts
  it.
- **Deny statements on the bootstrap resources:** it cannot change the CI roles or the
  OIDC provider, cannot administer the state bucket, the lock table or the state key,
  cannot read or write the bootstrap state, and cannot delete the hosted zone.

## Alternatives considered

- **A list of allowed services.** Looks smaller, but a role that can create roles can
  escape it, so it would not be weaker.
- **A permissions boundary on every role the pipeline creates.** The rigorous answer:
  the apply role could only create roles that carry the boundary. It constrains every
  module and cannot be exercised without an account. It is the next hardening step.

## Consequences

- The apply role can read every secret of its account, the PostgreSQL master secret
  included.
- The Deny statements stop a reviewed change to the root module from touching the
  bootstrap resources. They do not stop someone who already controls an apply run,
  who can create a second role without them.
- Branch protection decides who can run the role. A rule that only requires a pull
  request adds no second person; for prod, the environment's required reviewer does.
