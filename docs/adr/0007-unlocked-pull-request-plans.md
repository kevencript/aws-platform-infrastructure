# 7. Pull request plans run without the state lock

Status: accepted

## Context

Any pull request raised from a branch of the repository can assume the plan role of
each account, and it can change the workflow it runs. Terraform takes the state lock
by default, which needs write access to the lock table.

## Decision

The plan role is read-only: it cannot write the state, the lock table or any resource
Terraform manages, and it is denied secret values, decryption with any key other than
the state key, and every S3 object other than the root state. The pull request job runs
`terraform plan -lock=false`. The apply job, under the apply role, takes the lock.

## Alternatives considered

- **A plan role that can take the lock**, limited to the lock item by a condition on the
  table's partition key. A pull request could then hold the lock, or delete the lock
  that a running apply holds, letting a second apply start on the same state.

## Consequences

- No pull request can change anything in an account.
- A plan that overlaps an apply can fail on the state checksum, or succeed silently
  against a state the apply has not finished writing. A pull request plan is never
  applied; the apply job plans again under the lock.
- That `init` and an unlocked plan write nothing rests on the S3 backend's source code
  for Terraform 1.5.7 and 1.15.1, not on a real run.
