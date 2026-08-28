# EKS module

This module creates a VPC with three public and three private subnets selected
from the caller's region, one NAT gateway per AZ, an EKS control plane, and a
managed node group. Nodes and the private-only API endpoint use private
subnets; public subnets are only for NAT egress and ELB discovery. The module
fails during planning if the selected region has fewer than three AZs or the
VPC CIDR cannot allocate the six subnets.

## Security and design decisions

- The cluster role and node role use only EKS-managed service policies; no
  administrator policy is attached. The node CNI policy is kept on the node
  role for the initial managed CNI. Move it to a separately scoped `aws-node`
  IRSA role when managing the VPC CNI add-on.
- OIDC is enabled and an example workload role is constrained by both the OIDC
  `aud` claim and one exact `system:serviceaccount:<namespace>:<name>` `sub`.
  It has no permissions unless the caller attaches reviewed policy ARNs.
- EKS Secrets envelope encryption and the CloudWatch log group require
  caller-supplied customer-managed KMS keys. API, audit, and authenticator
  control-plane logs retain for 30 days. These controls add KMS and CloudWatch
  cost; monitor log volume and key-policy access.
- Node updates allow one unavailable node. With a three-node default this is a
  controlled disruption, but workloads still need replicas, PDBs, and capacity
  headroom. `desired_capacity = 0` is allowed only with `min_capacity = 0`; it
  deliberately leaves no schedulable workload capacity.

## Example root

`staging/` is an example root, not a declaration of a real environment. It has
no default region, KMS key, Kubernetes version, account, or environment value.
Pass those through the approved variable mechanism. The Kubernetes version is
required so CI can choose an AWS-supported version rather than pinning a
possibly retired default.

Run static validation without a backend:

```sh
terraform -chdir=staging init -backend=false
terraform -chdir=staging validate
```

## Before a real apply

Configure an encrypted remote state backend with locking and restricted access;
verify KMS key policies for EKS and CloudWatch; review quota, CIDR capacity,
NAT cost, and the private API access path. Create EKS access entries (or an
approved equivalent) for human/CI administrators before attempting kubeconfig
use. Pin and manage compatible VPC CNI, CoreDNS, and kube-proxy add-on
versions; establish the `aws-auth`/access-entry migration plan; add backups,
observability, network policy, and workload-specific IRSA roles.

`terraform validate` checks syntax and provider schema after initialization; it
does not prove an AWS plan will succeed. A real reviewed plan with authorized
credentials is still required, and this module must not be applied by this
task.
