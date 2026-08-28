# EKS Terraform Module

Production-ready Terraform module for deploying Amazon EKS (Elastic Kubernetes Service) clusters with best practices.

## Features

- **VPC with High Availability**: Public and private subnets across 3 Availability Zones
- **EKS Control Plane**: Managed Kubernetes control plane with configurable version
- **Managed Node Group**: EC2-based worker nodes with auto-scaling
- **IRSA Support**: IAM Roles for Service Accounts via OIDC provider
- **Cluster Logging**: CloudWatch logs for api, audit, and authenticator
- **Private Networking**: Worker nodes run in private subnets with NAT gateway egress
- **Security**: Least-privilege IAM roles, security groups
- **No Hardcoded Values**: Fully parameterized for environment flexibility

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Public Subnets (3 AZs)                 │   │
│  │  ┌─────┐  ┌─────┐  ┌─────┐                          │   │
│  │  │ NAT │  │ NAT │  │ NAT │  (NAT Gateways)          │   │
│  │  └─────┘  └─────┘  └─────┘                          │   │
│  │     ↑         ↑         ↑                            │   │
│  │     └─────────┴─────────┘                            │   │
│  │             IGW (Internet Gateway)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Private Subnets (3 AZs)                 │   │
│  │                                                      │   │
│  │  ┌────────────────────────────────────────────┐    │   │
│  │  │        EKS Control Plane                   │    │   │
│  │  │  (Managed by AWS, Multi-AZ)                │    │   │
│  │  └────────────────────────────────────────────┘    │   │
│  │                       ↕                             │   │
│  │  ┌────────────────────────────────────────────┐    │   │
│  │  │        EKS Managed Node Group              │    │   │
│  │  │  ┌─────┐  ┌─────┐  ┌─────┐                │    │   │
│  │  │  │ EC2 │  │ EC2 │  │ EC2 │  (Worker Nodes) │    │   │
│  │  │  └─────┘  └─────┘  └─────┘                │    │   │
│  │  └────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name       = "my-eks-cluster"
  kubernetes_version = "1.28"
  vpc_cidr           = "10.0.0.0/16"

  node_instance_type = "t3.medium"
  desired_capacity   = 3
  min_capacity       = 1
  max_capacity       = 5

  tags = {
    Environment = "staging"
    Team        = "platform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |
| tls | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| tls | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| kubernetes_version | Kubernetes version to use for the EKS cluster | `string` | `"1.28"` | no |
| vpc_cidr | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| node_instance_type | EC2 instance type for the EKS managed node group | `string` | `"t3.medium"` | no |
| desired_capacity | Desired number of worker nodes | `number` | `3` | no |
| min_capacity | Minimum number of worker nodes | `number` | `1` | no |
| max_capacity | Maximum number of worker nodes | `number` | `5` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_endpoint | Endpoint for EKS control plane |
| cluster_name | Name of the EKS cluster |
| cluster_id | ID of the EKS cluster |
| cluster_arn | ARN of the EKS cluster |
| cluster_version | Version of the EKS cluster |
| cluster_security_group_id | Security group ID attached to the EKS cluster |
| cluster_certificate_authority_data | Base64 encoded certificate data (sensitive) |
| oidc_provider_arn | ARN of the OIDC Provider for IRSA |
| oidc_provider_url | URL of the OIDC Provider |
| node_group_id | ID of the EKS node group |
| node_group_arn | ARN of the EKS node group |
| node_group_role_arn | IAM role ARN of the EKS node group |
| vpc_id | ID of the VPC |
| private_subnet_ids | IDs of the private subnets |
| public_subnet_ids | IDs of the public subnets |
| kubeconfig_command | Command to update kubeconfig for kubectl access |

## Design Decisions

### Networking

- **3 Availability Zones**: High availability for both control plane and worker nodes
- **Public Subnets**: Host NAT gateways for private subnet egress
- **Private Subnets**: Worker nodes run here for security (no direct internet access)
- **NAT Gateways**: One per AZ for fault tolerance (high availability)
- **Subnet Tagging**: Kubernetes-specific tags for ELB and internal ELB discovery

### IAM

- **Least Privilege**: Only required AWS managed policies attached
  - Cluster role: `AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController`
  - Node role: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- **IRSA (IAM Roles for Service Accounts)**: OIDC provider enables fine-grained pod-level IAM permissions
- **No AdministratorAccess**: All permissions are scoped to what's required

### Logging

- **CloudWatch Logs**: Cluster logging enabled for `api`, `audit`, and `authenticator`
- **Retention**: 7-day retention (configurable if needed)
- **Compliance**: Audit logs satisfy many compliance requirements

### Node Group

- **Managed Node Group**: AWS handles OS patching, updates, and lifecycle
- **Private Subnets Only**: Nodes have no public IPs
- **Auto Scaling**: Configured with min/max/desired capacity
- **Rolling Updates**: `max_unavailable = 1` for zero-downtime updates

### Security

- **No Hardcoded Values**: Region, account ID, AZs all discovered dynamically
- **Security Groups**: Minimal egress-only rules for control plane
- **Private API Endpoint**: Enabled alongside public for secure access options

## Known Limitations

### 1. Cost Optimization

**Current State:**
- 3 NAT Gateways (one per AZ) = ~$100/month
- Always-on node group

**Production Considerations:**
- For dev/staging, consider single NAT gateway to reduce costs
- Implement cluster autoscaler for dynamic node scaling
- Consider Fargate for serverless compute option

### 2. Logging

**Current State:**
- 7-day CloudWatch retention

**Production Considerations:**
- Extend retention for compliance (e.g., 90+ days)
- Export logs to S3 for long-term storage
- Enable additional log types (`controllerManager`, `scheduler`) if needed

### 3. Security Hardening

**Not Included (Would Add for Production):**
- **Pod Security Standards**: PSS/PSP policies
- **Network Policies**: CNI-level traffic control
- **Secrets Encryption**: KMS key for secrets encryption at rest
- **Private Endpoint Only**: Disable public endpoint access for highly secure environments
- **VPC Flow Logs**: Network traffic logging

### 4. Add-ons and Tools

**Not Included (Required for Production):**
- **CoreDNS**: Verify version compatibility
- **kube-proxy**: Verify configuration
- **AWS VPC CNI**: May need to update to latest version
- **Cluster Autoscaler**: For automatic node scaling
- **AWS Load Balancer Controller**: For Kubernetes Ingress
- **External DNS**: For automatic Route53 DNS management
- **cert-manager**: For TLS certificate management
- **Metrics Server**: For HPA (Horizontal Pod Autoscaler)
- **Prometheus/Grafana**: Monitoring and observability

### 5. State Management

**Not Configured:**
- Remote state backend (S3 + DynamoDB)
- State encryption

**Before Production Apply:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### 6. Disaster Recovery

**Consider Adding:**
- **Velero**: Backup and restore for cluster resources
- **Multi-Region**: Cross-region replication strategy
- **Snapshots**: EBS volume snapshots for persistent data

### 7. CI/CD Integration

**Would Add:**
- Terraform Cloud/Enterprise for collaborative workflows
- Automated drift detection
- Policy-as-code (Sentinel, OPA) for compliance

## Pre-Apply Checklist

Before applying this module in production:

1. ✅ Configure remote state backend (S3)
2. ✅ Enable state encryption with KMS
3. ✅ Add secrets encryption at rest (KMS key for EKS)
4. ✅ Review and adjust NAT gateway count (cost vs. HA)
5. ✅ Configure CloudWatch log retention policy
6. ✅ Set up VPC Flow Logs
7. ✅ Configure backup solution (Velero)
8. ✅ Install required add-ons:
   - Cluster Autoscaler
   - AWS Load Balancer Controller
   - External DNS
   - cert-manager
   - Metrics Server
9. ✅ Implement Pod Security Standards
10. ✅ Configure Network Policies
11. ✅ Set up monitoring (Prometheus, Grafana)
12. ✅ Configure alerting (CloudWatch Alarms, PagerDuty)
13. ✅ Document runbooks for common operations
14. ✅ Test disaster recovery procedures

## Testing

```bash
# Initialize Terraform (no backend)
terraform init -backend=false

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check

# Plan (requires AWS credentials)
terraform plan

# Note: Do not apply without completing pre-apply checklist
```

## Accessing the Cluster

After deployment, configure kubectl:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify access
kubectl get nodes
kubectl get pods -A
```

## Maintenance

### Upgrading Kubernetes Version

1. Update `kubernetes_version` variable
2. Plan and apply Terraform changes
3. Upgrade node group to match
4. Test workloads thoroughly

### Scaling Nodes

```hcl
# Update variables
desired_capacity = 5
min_capacity     = 2
max_capacity     = 10
```

### Adding IRSA for Pods

Example: Grant S3 access to a pod

```hcl
# In your app Terraform
data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::my-bucket/*"]
  }
}

resource "aws_iam_role" "app_role" {
  name = "my-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:my-namespace:my-serviceaccount"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_policy" {
  role   = aws_iam_role.app_role.name
  policy = data.aws_iam_policy_document.s3_access.json
}
```

## Support

For issues or questions:
- Review AWS EKS documentation: https://docs.aws.amazon.com/eks/
- Check Terraform AWS provider docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

## License

See LICENSE file in repository root.
