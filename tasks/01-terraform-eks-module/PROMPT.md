You are an infrastructure engineer. Complete and correct the Terraform
in `starter/` into a production-ready module for an Amazon EKS cluster.

Requirements:

- VPC with public and private subnets across 3 AZs
- EKS control plane plus a managed node group (instance type and
  desired capacity are variables; default t3.medium, desired=3)
- Nodes must run in private subnets
- IRSA enabled (OIDC provider)
- Cluster logging for api, audit, and authenticator to CloudWatch
- Least-privilege IAM (no AdministratorAccess)
- No hardcoded account IDs, regions, or environment names
- Variables: cluster_name, kubernetes_version, node_instance_type,
  desired_capacity, vpc_cidr
- Outputs: cluster_endpoint, cluster_name, oidc_provider_arn,
  kubeconfig helper notes
- `terraform validate` must succeed (init with `-backend=false`)

Deliver:

1. A complete module under `modules/eks/`
2. An example root module for a `staging` environment that uses it
3. A short README covering design decisions, known limitations, and
   what would still be required before a real apply (remote state,
   KMS, add-ons, etc.)

Do not apply anything. Do not invent a real AWS account.
