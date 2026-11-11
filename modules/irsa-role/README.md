# irsa-role

An IAM role for exactly one Kubernetes service account, through IAM Roles for Service
Accounts (IRSA).

A pod running under the service account receives a token signed by the cluster's OIDC
issuer and exchanges it at STS for this role's credentials. The trust policy accepts
the exchange only when both conditions hold:

| Claim | Must equal |
|-------|------------|
| `aud` | `sts.amazonaws.com` |
| `sub` | `system:serviceaccount:<namespace>:<service_account>` |

Both are `StringEquals`, and the inputs reject a wildcard: a role never trusts a whole
namespace.

The other half of IRSA lives in Kubernetes: the service account carries the annotation
`eks.amazonaws.com/role-arn` with this role's ARN. This repository does not deploy
Kubernetes objects.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `name` | `string` | Role name, at most 64 characters |
| `oidc_provider_arn` | `string` | The cluster's IAM OIDC provider |
| `oidc_issuer_url` | `string` | The cluster's issuer URL, with or without `https://` |
| `namespace`, `service_account` | `string` | The one service account the role trusts |
| `managed_policy_arns` | `map(string)` | Managed policies, under keys chosen by the caller. Default: none |
| `inline_policies` | `map(string)` | Policy documents of the role's own, under keys chosen by the caller. Default: none |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | For the service account's annotation |
| `role_name` | The role's name |
