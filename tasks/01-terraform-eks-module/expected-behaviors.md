# Expected behaviors — Task 01

A strong solution:

- Replaces the starter rather than papering over it
- Uses `data.aws_availability_zones` (or a variable list) instead of
  a hardcoded three AZs
- Puts NAT / egress on public subnets and nodes on private
- Enables cluster encryption config or documents why it is omitted
- Tags subnets with the Kubernetes ELB discovery tags
- Constrains IRSA trust to a specific ServiceAccount
- Calls out: remote backend, KMS CMK, VPC CNI / CoreDNS / kube-proxy
  add-on versions, aws-auth / access entries, and that `plan` against
  a dummy provider is not a substitute for a real plan

A weak solution:

- Copies a blog module with `0.0.0.0/0` SSH on the node SG
- Leaves `region = "us-east-1"` in the example
- Creates EKS but no node group, or a node group with no IAM
- Claims "production-ready" with no limitations section
