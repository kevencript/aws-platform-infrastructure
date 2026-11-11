# Bootstrap stack

This stack creates what an AWS account needs before the root module can run in it, and
what must outlive the environment. It is applied by a person, once per account, with
administrator credentials. The pipeline never applies it.

Each environment has its own account, so the stack is applied twice: once in the dev
account and once in the prod account. The two accounts share no resource.

## What it creates

| File | Resources | Why |
|------|-----------|-----|
| `state.tf` | KMS key and alias, S3 bucket, DynamoDB table | Encrypted, versioned and locked storage for both Terraform states of the account |
| `dns.tf` | Public Route 53 hosted zone | The parent domain delegates to it once, and a recreated zone would get new name servers |
| `github_oidc.tf` | IAM OIDC provider for GitHub Actions | Workflow jobs exchange a GitHub token for short-lived credentials; no access key exists |
| `ci_plan_role.tf` | Plan role | Assumed by pull request runs: read-only, with no write permission |
| `ci_apply_role.tf` | Apply role | Assumed by deploy runs of the account's GitHub environment, from its deploy branch only |

The inputs are in [`../environments/<env>/bootstrap.tfvars`](../environments). The
committed values are placeholders: replace the account ID, the domain and the four
GitHub values before a first apply. The bucket name in `backend.hcl` ends with the
account ID, so update it too. Step 3 below checks the file against what was created.

## What the two roles can do

| | Plan role | Apply role |
|---|-----------|------------|
| Who can assume it | A job of this repository on a `pull_request` event that names no GitHub environment | A job of this repository that names the account's GitHub environment and runs from the deploy branch |
| Permissions | The AWS managed `ReadOnlyAccess` policy and read access to the root state. No write of any kind | The AWS managed `AdministratorAccess` policy |
| Denied | Secret values, decryption with any key but the state key, and every S3 object but the root state | Any change to the two CI roles and the OIDC provider, any administration of the state bucket, lock table and state key, any access to this stack's own state, and deletion of the hosted zone |

The apply role is an administrator of its account on purpose: it creates IAM roles, and
a principal that can do that can grant itself anything. What limits it is who can assume
it, and the account it lives in. Its Deny statements stop the changes listed above when
one arrives as a change to the root module. They do not stop someone who already
controls an apply run, who can create a second role without them. The reasoning is in
[`docs/architecture.md`](../docs/architecture.md#ci-roles).

The plan role has no write permission, so it cannot take the state lock. The pull
request job therefore runs `terraform plan -lock=false`. That plan is never applied. If
it overlaps an apply it can fail on the state checksum or show a stale result, and it is
run again.

## Before the first apply

- Terraform 1.5 or newer, except 1.6.0 and 1.15.0, which `versions.tf` refuses, and
  administrator credentials for the target account in the shell. The provider stops if
  the credentials belong to any other account.
- The account has no IAM OIDC provider for `token.actions.githubusercontent.com` yet.
  An account can hold only one per issuer. If one exists, import it instead of creating
  it.
- The repository issues tokens with immutable subject claims
  (`repo:OWNER@OWNER-ID/REPO@REPO-ID:...`). That is the default for repositories created
  after 15 July 2026. An older repository opts in from its Actions OIDC settings.
- `bootstrap/` holds no `terraform.tfstate` left over from another account.

## First apply in an account

The stack creates the bucket that will hold its own state, so the first apply keeps the
state in a local file. The commands below use `dev`; the prod account uses the files
under `environments/prod`.

1. Use a local backend for this one apply. The file is ignored by Git and must never be
   committed.

   ```sh
   cd bootstrap
   printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
   ```

2. Create the resources. `-reconfigure` makes Terraform ignore any backend this
   directory was initialised with before, for example the other account's.

   ```sh
   terraform init -reconfigure
   terraform apply -var-file=../environments/dev/bootstrap.tfvars
   ```

3. Check that the committed backend file matches what was created. The command prints
   nothing when they match.

   ```sh
   terraform output -raw backend_config | diff - ../environments/dev/backend.hcl
   ```

   If it prints a difference, correct `../environments/dev/backend.hcl` and commit it
   before step 4, which reads that file. This writes the exact content:

   ```sh
   terraform output -raw backend_config > ../environments/dev/backend.hcl
   ```

4. Move the state into the bucket. Terraform asks before it copies the state.

   ```sh
   rm backend_override.tf
   terraform init -migrate-state -backend-config=../environments/dev/backend.hcl
   ```

5. Confirm that the state moved, then remove the local copies.

   ```sh
   terraform plan -var-file=../environments/dev/bootstrap.tfvars   # expects: No changes
   rm -f terraform.tfstate terraform.tfstate.backup
   ```

6. Delegate the zone. In the parent domain, create an NS record for the zone name with
   the four values of `terraform output name_servers`. Certificates cannot be validated
   in the zone before this is done.

7. Tell the pipeline which roles to assume. Create these GitHub Actions repository
   variables from `terraform output plan_role_arn` and `terraform output apply_role_arn`:

   | Variable | dev account | prod account |
   |----------|-------------|--------------|
   | Plan role | `AWS_PLAN_ROLE_ARN_DEV` | `AWS_PLAN_ROLE_ARN_PROD` |
   | Apply role | `AWS_APPLY_ROLE_ARN_DEV` | `AWS_APPLY_ROLE_ARN_PROD` |

8. Create the GitHub environment named after this account's environment (`dev` or
   `prod`, in lower case) and restrict its deployment branches to the deploy branch.
   For `prod`, add required reviewers.

9. Once for the repository: protect `develop` and `main` so that changes reach them
   through pull requests only. The apply role trusts every run on its deploy branch,
   whoever pushed the commit.

Steps 1 to 8 apply to the second account as well, with its own credentials and its own
files under `environments/`.

## Later changes

A change to this stack is reviewed in a pull request like any other, then applied by a
person:

```sh
cd bootstrap
terraform init -reconfigure -backend-config=../environments/dev/backend.hcl
terraform plan -var-file=../environments/dev/bootstrap.tfvars -out=tfplan
terraform apply tfplan
```

The bucket, the key and the hosted zone carry `prevent_destroy`. Removing one of them is
a deliberate edit of the code, not a side effect of a plan.

## Status

Nothing in this repository is applied to an AWS account. The code is formatted,
validated on Terraform 1.5 and on the current release, and scanned. The steps above
follow the Terraform and AWS documentation and have not been run.
