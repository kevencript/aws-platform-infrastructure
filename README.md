# AWS Platform Infrastructure

Production-oriented AWS infrastructure for a containerised backend service, written in
Terraform: EKS, PostgreSQL, Redis, Kafka and the network, identity and delivery
pipeline around them.

![Architecture diagram](diagram.png)

## What this is

A case study in provisioning the infrastructure one backend microservice needs to run
in production. The service is a Node.js API that serves HTTPS traffic from the
internet, stores data in PostgreSQL, caches in Redis and exchanges events over Kafka.

The design follows three ideas:

- **No secret in code or state.** RDS generates and rotates the only password in the
  system. The API reaches the database, the cache and the broker with IAM credentials,
  and the pipeline uses OIDC.
- **One root module, environments as data.** `dev` and `prod` are the same code with
  different variable values. Each runs in its own AWS account with its own state.
- **Terraform stops at the AWS API.** A single provider, no third-party modules.

The full plan is in [`docs/architecture.md`](docs/architecture.md): traffic flows,
network layout, security group matrix, identity model and state strategy.

## Status

The project is delivered in batches, one per knowledge area. See the
[delivery roadmap](docs/architecture.md#delivery-roadmap) and the
[changelog](CHANGELOG.md).

| Release | Scope | Status |
|---------|-------|--------|
| `0.1.0` | Architecture diagram, written plan, contribution conventions | Released |
| `0.2.0` | Terraform foundation and CI pipeline | In progress: foundation done, pipeline next |
| `0.3.0` | Networking, security groups and compute | Planned |
| `0.4.0` | Data layer and messaging | Planned |
| `0.5.0` | Edge and observability | Planned |
| `1.0.0` | Documentation and final review | Planned |

## Repository layout

```
.
├── versions.tf              # root module: Terraform, provider and backend
├── providers.tf             #   AWS provider, account restriction, default tags
├── variables.tf             #   identity of the environment
├── main.tf                  #   module wiring; today, the hosted zone lookup
├── outputs.tf
├── environments/
│   ├── dev/                 # terraform.tfvars, bootstrap.tfvars, backend.hcl
│   └── prod/                # the same three files, the same keys
├── bootstrap/               # per-account stack: state storage, hosted zone, CI identity
├── Makefile                 # local quality gate
├── tools/
│   ├── check-environments.sh  # checks the environment files against the code
│   └── diagram/             # diagram source and the build that renders it
├── diagram.png              # architecture diagram, generated
├── docs/
│   ├── architecture.md      # the written plan
│   └── diagrams/            # the diagram as an Excalidraw scene, generated
├── .github/                 # pull request template
├── CONTRIBUTING.md          # Git Flow, commit and release conventions
└── CHANGELOG.md
```

The modules of the platform (`modules/`) arrive with the next releases.

## How to run

Nothing in this repository is applied to an AWS account. The account IDs, the domain and
the GitHub repository in `environments/` are placeholders. What runs today is the
quality gate; the commands for a real account are listed for completeness and have not
been run.

### Quality gate

It needs no AWS account and no credentials.

| Tool | Version |
|------|---------|
| Terraform | 1.5 or newer, except 1.6.0 and 1.15.0. Checked with 1.5.7 and 1.15.1. The lock files pin the AWS provider to 5.100.0 |
| trivy | Checked with 0.74.0 |
| make | Checked with GNU Make 3.81, the one shipped with macOS |

```sh
make check
```

| Step | Command it runs | What it proves |
|------|-----------------|----------------|
| `make fmt` | `terraform fmt -check -recursive`, and each `backend.hcl` through standard input | Canonical formatting of every `.tf`, `.tfvars` and backend file |
| `make validate` | `terraform init -backend=false` and `terraform validate`, in the root module and in `bootstrap/` | The code is internally consistent and matches the provider schema |
| `make environments` | `tools/check-environments.sh` | `dev` and `prod` have the same keys, and every variable file satisfies the types and validation rules of its stack |
| `make scan` | `trivy config`, once per environment | No misconfiguration known to the scanner. Accepted findings are ignored next to the resource, with the reason |

To prove the version floor as well, point `TERRAFORM_MIN` at a Terraform 1.5 binary. It
repeats `make validate` and `make environments` with that binary:

```sh
make check TERRAFORM_MIN=/path/to/terraform-1.5.7
```

The gate does not show that the code works against AWS. `terraform validate` reads
neither the backend settings nor an IAM policy's meaning, and it never contacts an
account.

The gate initialises three working directories, and each one installs the AWS provider,
about 650 MB unpacked. Setting `TF_PLUGIN_CACHE_DIR` to an existing directory makes
them share one copy.

### A new account

Each environment has its own AWS account. An account is set up in this order:

1. Apply the bootstrap stack, by hand, once. The steps are in
   [`bootstrap/README.md`](bootstrap/README.md).
2. Delegate the environment's hosted zone from the parent domain.
3. Plan and apply the root module.

### The root module

One value, the environment name, selects both files:

```sh
terraform init -reconfigure -backend-config=environments/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars -out=tfplan
terraform apply tfplan
```

- `-reconfigure` is what makes it safe to switch between environments in one working
  directory: Terraform forgets the previous backend instead of offering to copy state.
- A mismatched pair of files fails instead of changing the wrong account. Each variable
  file names its account, and the provider refuses credentials from any other account.
  Credentials for one account cannot open the other account's state bucket.
- Terraform 1.11 and later print a deprecation warning for the lock table on every
  `init`, `plan` and `apply`. The quality gate never shows it, because it does not
  initialise the backend. The warning is expected:
  [the plan explains why](docs/architecture.md#state-and-environments).

## Contributing

Branching, commit and release conventions are described in
[`CONTRIBUTING.md`](CONTRIBUTING.md).
