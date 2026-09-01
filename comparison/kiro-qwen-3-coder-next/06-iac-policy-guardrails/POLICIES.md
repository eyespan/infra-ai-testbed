# IaC Policy Guardrails - Documentation

## Policies Overview

This repository contains OPA/Rego policies that enforce security and tagging standards on Terraform infrastructure.

## Policy Files

### `policies/s3.rego`
- **Purpose**: Ensure S3 buckets have server-side encryption enabled
- **Checks**:
  - `server_side_encryption_configuration` block exists
  - Default bucket encryption configuration
- **Violation Example**: `aws_s3_bucket.logs` without encryption config

### `policies/sg.rego`
- **Purpose**: Prevent security groups from allowing SSH (22) or RDP (3389) from any source
- **Checks**:
  - `0.0.0.0/0` CIDR on port 22
  - `::/0` (IPv6) CIDR on port 22
  - `0.0.0.0/0` CIDR on port 3389
  - `::/0` (IPv6) CIDR on port 3389
- **Violation Example**: Security group with ingress from `0.0.0.0/0` on port 22

### `policies/eks.rego`
- **Purpose**: Ensure EKS clusters have required control-plane logging
- **Checks**:
  - `enabled_cluster_log_types` contains `api`
  - `enabled_cluster_log_types` contains `audit`
  - `enabled_cluster_log_types` contains `authenticator`
- **Violation Example**: EKS cluster with empty `enabled_cluster_log_types: []`

### `policies/tags.rego`
- **Purpose**: Enforce mandatory tags on taggable AWS resources
- **Required Tags**: `Environment`, `Owner`, `CostCenter`
- **Excluded Resources**: Data sources, IAM policies, AMIs, VPC components, S3 objects (resources that cannot be tagged)
- **Violation Example**: EC2 instance without all three required tags

## Running Policies

### Using conftest
```bash
conftest test -p policies/ tfplan.json
```

### Using opa test
```bash
opa test -v policies/*.rego tests/*.rego
```

### Docker
```bash
docker run -v $(pwd):/work openpolicyagent/conftest test -p /work/policies /work/tfplan.json
```

## False Positive Risks

### Tag Policy
1. **Data Sources**: `aws_iam_policy_document`, `aws_caller_identity` - cannot be tagged
2. **Computed Resources**: `aws_ami`, `aws_ami_ids` - created by AWS, cannot tag
3. **S3 Objects**: `aws_s3_bucket_object`, `aws_s3_bucket` versioning - separate from tags
4. **Network Components**: VPCs, subnets, route tables, security groups, NAT gateways - some AWS services don't support tagging on all resource types
5. **Lambda Resources**: `aws_lambda_function` is taggable, but `aws_lambda_layer_version` has limited tagging

### S3 Encryption Policy
1. **Cross-account buckets**: Encryption may be managed by another account
2. **Replication buckets**: Encryption configured on source bucket

### Security Group Policy
1. **Internal security groups**: May legitimately use `10.0.0.0/8` ranges for internal access
2. **Load balancer security groups**: May have different rules than expected

### EKS Logging Policy
1. **EKS managed node groups**: Logging is cluster-level, not node-group level
2. **External clusters**: EKS clusters managed outside this Terraform

## Testing

### Run all tests
```bash
conftest test --test tests/*.rego policies/*.rego
```

### Test specific policy
```bash
conftest test --test tests/s3.rego policies/s3.rego
```

### Test with a specific plan
```bash
conftest test -p policies tfplan.json
```

## Policy Changes

To add a new policy:

1. Create `policies/<name>.rego` with package `terraform.<name>`
2. Define `deny[msg]` rule with violation messages
3. Create `tests/<name>.rego` with test cases
4. Update this documentation
