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
| `0.2.0` | Terraform foundation and CI pipeline | Planned |
| `0.3.0` | Networking, security groups and compute | Planned |
| `0.4.0` | Data layer and messaging | Planned |
| `0.5.0` | Edge and observability | Planned |
| `1.0.0` | Documentation and final review | Planned |

## Repository layout

```
.
├── diagram.png              # architecture diagram, generated
├── docs/
│   ├── architecture.md      # the written plan
│   └── diagrams/            # the diagram as an Excalidraw scene, generated
├── tools/diagram/           # diagram source and the build that renders it
├── .github/                 # pull request template
├── CONTRIBUTING.md          # Git Flow, commit and release conventions
└── CHANGELOG.md
```

## Contributing

Branching, commit and release conventions are described in
[`CONTRIBUTING.md`](CONTRIBUTING.md).
