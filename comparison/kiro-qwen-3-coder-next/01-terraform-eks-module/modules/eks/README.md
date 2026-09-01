# EKS Module

A production-ready Terraform module for Amazon EKS clusters with managed node groups.

## Features

- **VPC Architecture**: Public and private subnets across 3 AZs with NAT gateways
- **EKS Control Plane**: Managed with API audit logging and encryption
- **Managed Node Group**: Scalable worker nodes with proper IAM roles
- **IRSA Support**: OIDC provider for IAM roles for service accounts
- **Security**: Least-privilege IAM policies and security groups
- **Logging**: CloudWatch logs for cluster control plane components
- **Encryption**: Optional KMS encryption for secrets

## Usage

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name       = "my-cluster"
  region             = "us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  kubernetes_version = "1.29"

  node_instance_type = "t3.medium"
  desired_capacity   = 3
  min_size           = 2
  max_size           = 6
}
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Name of the EKS cluster | - |
| `region` | AWS region | `""` |
| `vpc_cidr` | CIDR block for the VPC | `"10.0.0.0/16"` |
| `kubernetes_version` | Kubernetes version | `"1.29"` |
| `node_instance_type` | EC2 instance type for nodes | `"t3.medium"` |
| `desired_capacity` | Desired number of nodes | `3` |
| `min_size` | Minimum number of nodes | `2` |
| `max_size` | Maximum number of nodes | `6` |
| `enable_cluster_encryption` | Enable KMS encryption | `true` |
| `kms_key_arn` | KMS key ARN for encryption | `""` |
| `cluster_logging_types` | Control plane log types | `["api", "audit", "authenticator"]` |
| `log_retention_days` | Log retention period | `90` |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_endpoint` | EKS cluster endpoint |
| `cluster_name` | EKS cluster name |
| `oidc_provider_arn` | OIDC provider ARN for IRSA |
| `oidc_provider_url` | OIDC provider URL |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `cluster_security_group_id` | Security group ID for cluster |
| `node_security_group_id` | Security group ID for nodes |
| `cluster_iam_role_arn` | IAM role ARN for cluster |
| `node_iam_role_arn` | IAM role ARN for nodes |
| `cloudwatch_log_group_name` | CloudWatch log group name |

## Design Decisions

### Subnet Layout
- 3 public subnets (one per AZ) for NAT gateways and load balancers
- 3 private subnets (one per AZ) for EKS nodes
- CIDR calculation uses `cidrsubnet()` for consistency

### NAT Gateways
- One NAT gateway per public subnet for high availability
- EIPs are created and tagged for tracking

### Security Groups
- Cluster security group allows all outbound
- Node security group allows traffic from cluster SG
- Cluster SG allows node communication on required ports

### IRSA
- OIDC provider created with thumbprint from cluster
- IAM role with constrained trust policy
- Default policy for common S3 permissions

### Logging
- All control plane logs enabled by default
- Retention set to 90 days (can be adjusted)
- Log group uses default encryption

## Known Limitations

### What's Not Included

1. **Remote State Backend**: Must be configured in root module (S3 + DynamoDB recommended)

2. **KMS CMK**: KMS key rotation requires KMS permissions in IAM

3. **VPC CNI**: Default AWS VPC CNI is used; can be replaced with Cilium

4. **CoreDNS/kube-proxy**: Managed by EKS; can be updated via add-ons

5. **aws-auth ConfigMap**: For RBAC mapping, use AWS-auth or access entries

6. **Add-ons**: EKS add-ons (CoreDNS, Kube-proxy, VPC CNI) not managed by this module

7. **Fargate Profiles**: Not included; use separate module if needed

8. **Node Group Taints/Autoscaling**: Basic scaling only; consider Karpenter for advanced scheduling

### Before Production Apply

1. **Configure remote state** (S3 backend with DynamoDB locking)
2. **Set up KMS CMK** for encryption (current uses default key)
3. **Configure VPC CNI add-on** for custom networking
4. **Update aws-auth** ConfigMap for RBAC access
5. **Set up monitoring** (CloudWatch, Prometheus, etc.)
6. **Configure backup** for EKS and EBS volumes
7. **Review IRSA trust policy** and restrict to specific service accounts

## Troubleshooting

### Nodes not joining cluster
- Check security group rules (cluster SG to nodes SG)
- Verify IAM instance profile is attached to node instances
- Check CloudWatch logs for kubelet errors

### Terraform validation errors
- Run `terraform init -backend=false` to initialize without backend
- Verify AWS provider credentials are configured

### KMS encryption issues
- Ensure KMS key policy allows EKS service to use the key
- Check key alias permissions

## References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform EKS Module](https://github.com/aws-terraform-modules/terraform-aws-eks)