# Review criteria — Task 01

## Mechanical

- [ ] `terraform validate` passes without hand-edits
- [ ] No hardcoded account IDs or regions
- [ ] Variables and outputs required by the prompt exist

## Bugs to look for

- Node group in public subnets
- Missing cluster security group rules / no path for API to nodes
- OIDC provider created but no IAM role for IRSA consumers
- `desired_size` with no `min_size` / `max_size`
- Kubernetes version string invalid or pinned to a retired version
- CloudWatch log group missing retention or KMS
- `depends_on` missing so the node group races the cluster
- Example root module still uses `us-east-1` hardcoded from starter

## Edge cases

- AZ count in the region is 2
- `desired_capacity = 0`
- Cluster version upgrade vs node AMI skew
- CIDR too small for 6 subnets
- Remote state / locking not mentioned

## Reliability / failure modes

- Control plane logging cost
- Node group rolling update disruption
- IRSA trust policy too broad (`aud` / `sub` not constrained)

## Judgment questions

Would you merge this as a platform module? What is the blast radius
of a bad variable default?
