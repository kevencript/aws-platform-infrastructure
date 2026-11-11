# Trust between this account and GitHub Actions. A workflow job asks GitHub
# for a signed token and exchanges it at AWS STS for short-lived credentials
# of a role. No access key is stored anywhere.

locals {
  github_oidc_host = "token.actions.githubusercontent.com"

  # The audience the official credentials action asks for. It must appear in
  # the provider's client ID list and in each role's trust policy.
  github_oidc_audience = "sts.amazonaws.com"

  # Start of the token's subject for this repository, in GitHub's immutable
  # format: repo:OWNER@OWNER-ID/REPO@REPO-ID. The IDs tie the roles to this
  # exact repository even if its name is later reused by someone else.
  github_subject_prefix = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}"
}

# An account can hold one provider per issuer URL. No thumbprint is given:
# AWS verifies GitHub's certificate against its own list of trusted
# authorities.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = [local.github_oidc_audience]
}
