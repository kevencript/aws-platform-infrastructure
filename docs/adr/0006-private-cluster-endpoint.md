# 6. A private Kubernetes API, and no Kubernetes provider

Status: accepted

## Context

EKS can expose the Kubernetes API to the internet, to the VPC, or both. Terraform could
also manage Kubernetes objects through the `kubernetes` or `helm` providers, which would
need a network path to the API from wherever Terraform runs.

## Decision

- The Kubernetes API endpoint is private only.
- Terraform uses one provider, AWS, and never calls the Kubernetes API. The pipeline
  therefore runs on GitHub-hosted runners with no path into the VPC.
- Access to the Kubernetes API is granted with EKS access entries for named IAM
  principals. The identity that creates the cluster gets no implicit rights, so at
  least one admin principal is required.
- Kubernetes objects, such as the load balancer controller, the `TargetGroupBinding`,
  the annotated service accounts, the migration job and the API, are deployed by a
  separate path from inside the VPC.

## Alternatives considered

- **A public endpoint with an allow-list.** Lets the pipeline and people reach the API
  from outside, but exposes it to the internet and depends on stable source addresses.
  trivy rates a public endpoint critical even with an allow-list.
- **Kubernetes and Helm providers in this repository.** One tool for everything, but a
  second and third provider, a network path from the pipeline into the cluster, and a
  plan that fails whenever the cluster is unreachable.

## Consequences

- Nothing outside the VPC can reach the Kubernetes API.
- A person needs a path inside the VPC to use `kubectl`, such as a VPN or a session
  through an instance there; this repository provisions none.
- IRSA is split: the roles are here, and the service account annotations are with the
  workloads.
