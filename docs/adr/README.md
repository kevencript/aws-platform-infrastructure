# Decision records

Each record states one decision that had a real alternative: the context, the decision,
the alternatives considered and the consequences, including the ones that cost
something. The full plan they belong to is [`../architecture.md`](../architecture.md).

| # | Decision |
|---|----------|
| [1](0001-one-account-per-environment.md) | One AWS account per environment, environments as data |
| [2](0002-iam-authentication-for-data-stores.md) | IAM authentication instead of passwords for the data stores |
| [3](0003-terraform-owns-the-edge.md) | Terraform owns the edge; the controller only binds pods |
| [4](0004-node-security-group-as-source.md) | The node security group is the source of the data store rules |
| [5](0005-administrator-apply-role.md) | An administrator apply role, limited by trust, account and Deny statements |
| [6](0006-private-cluster-endpoint.md) | A private Kubernetes API, and no Kubernetes provider |
| [7](0007-unlocked-pull-request-plans.md) | Pull request plans run without the state lock |

A decision that changes gets a new record that supersedes the old one; records are not
rewritten.
