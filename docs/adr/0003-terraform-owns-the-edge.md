# 3. Terraform owns the edge; the controller only binds pods

Status: accepted

## Context

Internet traffic reaches the API through an Application Load Balancer with an HTTPS
listener, an ACM certificate and a WAF web ACL. In EKS, the AWS Load Balancer Controller
can create all of that from a Kubernetes Ingress, or Terraform can create it and leave
the controller a smaller job.

## Decision

Terraform creates the certificate, the load balancer, both listeners, the target group,
the WAF association and the host name. The target group's targets are pod addresses.
The controller runs in the cluster only to keep that target group filled with the API's
pods, through a `TargetGroupBinding`, under an IRSA role whose write actions are limited
to that one target group.

## Alternatives considered

- **The controller creates the load balancer from an Ingress.** The least Terraform, but
  the load balancer, its certificate binding, its security groups and its WAF
  association would live outside the state. The alarms could not reference them, a
  destroy would leave them behind and block the VPC's deletion, and the controller
  would need its full IAM policy.
- **Instance targets behind a NodePort.** All in Terraform, but every node opens a port,
  traffic takes an extra hop through a node, and health checks test nodes instead of
  pods.

## Consequences

- Every public resource is in the state and in review, and the alarms read its metrics.
- Until the binding exists, the target group is empty and the load balancer answers 503.
- The controller must start with `--aws-region` and `--aws-vpc-id`, because the nodes'
  metadata hop limit of 1 keeps it from reading them, and with its WAF and Shield
  features off.
