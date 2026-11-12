# 4. The node security group is the source of the data store rules

Status: accepted

## Context

The data stores must accept connections from the API's pods only, and never open
connections themselves. With the default VPC CNI, a pod's traffic carries its node's
security groups, so at the network layer the data stores see nodes, not pods. Security
groups for pods would give pods their own groups.

## Decision

- Every security group starts empty, and each internal flow is a rule pair that names
  groups, never address ranges: an egress rule on the caller and an ingress rule on the
  target. The data store groups have no egress rule.
- The node security group is the source in every data store rule.
- Pod-level least privilege comes from identity: only a pod whose IRSA role was granted
  access can authenticate to a data store (see decision 2).
- The data subnets have no default route, so routing backs up the security groups.
- The nodes also carry the cluster security group EKS creates. Its rules allow all
  traffic out, so the node group's egress rules document intent; what enforces each
  data flow is the ingress rule on the data store.

## Alternatives considered

- **Security groups for pods.** Network-level isolation per pod, but it needs Nitro
  instance types with trunk interfaces (no burstable `t` types), the VPC resource
  controller, a `SecurityGroupPolicy` deployed in Kubernetes, and it caps the pods per
  node that can use it.
- **Leaving the cluster security group off the nodes.** Stricter egress, but every rule
  EKS keeps in that group for the control plane, DNS and node-to-node traffic would have
  to be written by hand.

## Consequences

- Any pod on the node group can open a TCP connection to a data store. Only a pod with
  the right IAM role can authenticate.
- Moving to security groups for pods later is a change of the source group in one map.
