# False Positive Risks and Mitigation

## Overview

This document describes known false-positive scenarios for each OPA policy, why they occur, and how to handle them appropriately.

## Table of Contents

1. [S3 Encryption Policy](#s3-encryption-policy)
2. [Security Group Policy](#security-group-policy)
3. [EKS Logging Policy](#eks-logging-policy)
4. [Tagging Policy](#tagging-policy)
5. [General Mitigation Strategies](#general-mitigation-strategies)

---

## S3 Encryption Policy

### Policy Rule
**Deny S3 buckets without server-side encryption**

### False Positive Scenarios

#### 1. S3 Bucket with Default Encryption at Account Level

**Scenario:**
```hcl
# S3 bucket without explicit encryption config
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

# But encryption is enforced at AWS account level via:
# - S3 Bucket Key enabled by default
# - Organization SCPs requiring encryption
```

**Why it's flagged:**
The policy only checks Terraform plan JSON. It cannot see AWS account-level defaults or SCPs.

**Risk Level:** Medium
- Bucket might actually be encrypted by account defaults
- Explicit configuration is still better practice

**Mitigation:**
1. **Best Practice:** Always explicitly define encryption in Terraform:
   ```hcl
   resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
     bucket = aws_s3_bucket.example.id
     rule {
       apply_server_side_encryption_by_default {
         sse_algorithm = "AES256"
       }
     }
   }
   ```

2. **Policy Exception:** If account-level defaults are strictly enforced, document as exemption:
   ```yaml
   exemptions:
     - resource: aws_s3_bucket.legacy
       policy: terraform.s3
       reason: Account-level default encryption enforced by SCP
       approved_by: security-team
   ```

#### 2. S3 Bucket for Public Website Hosting

**Scenario:**
```hcl
# Public static website bucket
resource "aws_s3_bucket" "website" {
  bucket = "my-public-website"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}
```

**Why it's flagged:**
Public website content is typically not sensitive, but policy applies to all buckets.

**Risk Level:** Low
- Static website assets rarely need encryption
- However, logs or assets might still be sensitive

**Mitigation:**
- **Recommendation:** Still encrypt. Encryption has minimal cost/performance impact
- If truly not needed, document exemption with business justification

#### 3. Bucket Already Encrypted (Terraform Import)

**Scenario:**
```hcl
# Bucket imported from existing AWS resources
# Encryption already configured outside Terraform
resource "aws_s3_bucket" "imported" {
  bucket = "existing-encrypted-bucket"
}
```

**Why it's flagged:**
Terraform plan shows resource creation without encryption config in TF state.

**Risk Level:** Low
- Actual bucket in AWS is encrypted
- Terraform state doesn't reflect real configuration yet

**Mitigation:**
- Import encryption configuration into Terraform:
  ```bash
  terraform import aws_s3_bucket_server_side_encryption_configuration.imported existing-encrypted-bucket
  ```

---

## Security Group Policy

### Policy Rule
**Deny security groups allowing 0.0.0.0/0 on port 22 (SSH) or 3389 (RDP)**

### False Positive Scenarios

#### 1. Bastion Host with Session Manager

**Scenario:**
```hcl
# Bastion security group
# SSH rule exists but AWS Systems Manager Session Manager is used instead
resource "aws_security_group" "bastion" {
  name = "bastion"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Why it's flagged:**
Rule allows public SSH access, which is a security risk even if Session Manager is preferred.

**Risk Level:** High
- Even if Session Manager is intended, SSH port is still open
- Attackers can still attempt SSH brute force
- Rule provides no additional value if Session Manager is used

**Mitigation:**
- **Best Practice:** Remove SSH rule entirely if using Session Manager:
  ```hcl
  # Session Manager requires only outbound HTTPS (443) to AWS endpoints
  # No inbound rules needed
  resource "aws_security_group" "bastion" {
    name = "bastion"
    egress {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ```

**Not a false positive:** This should remain blocked.

#### 2. Security Group with Source Security Group (Not CIDR)

**Scenario:**
```hcl
# Security group allowing SSH from another security group
resource "aws_security_group" "app" {
  name = "app-servers"
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
}
```

**Why it's NOT flagged:**
Policy checks for `cidr_blocks = ["0.0.0.0/0"]`. Security group references don't trigger the policy.

**Risk Level:** N/A - This is correct behavior

**Note:** Policy correctly allows security group-based rules.

#### 3. Load Balancer Health Check Port

**Scenario:**
```hcl
# ALB/NLB requiring public access on custom port
resource "aws_security_group" "alb" {
  name = "alb"
  ingress {
    from_port   = 8080  # Custom health check port
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Why it's NOT flagged:**
Port 8080 is not 22 or 3389, so policy doesn't apply.

**Risk Level:** N/A - Policy is specific to SSH/RDP only

#### 4. Port Range Including 22

**Scenario:**
```hcl
# Security group with wide port range (e.g., ephemeral ports)
resource "aws_security_group" "example" {
  name = "example"
  ingress {
    from_port   = 1024  # Ephemeral port range
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Why it might be flagged:**
If range includes 22 or 3389, policy will flag it.

**Risk Level:** High
- Likely a mistake or overly permissive rule
- Should be narrowed to specific ports needed

**Mitigation:**
- **Best Practice:** Specify exact ports needed:
  ```hcl
  ingress {
    from_port   = 32768
    to_port     = 60999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ```

#### 5. IPv6 Equivalent (`::/0`)

**Scenario:**
```hcl
resource "aws_security_group" "example" {
  name = "example"
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]  # IPv6 equivalent of 0.0.0.0/0
  }
}
```

**Why it's flagged:**
Policy checks both IPv4 (`0.0.0.0/0`) and IPv6 (`::/0`).

**Risk Level:** High
- Same risk as IPv4
- Should be restricted

**Not a false positive:** This should remain blocked.

---

## EKS Logging Policy

### Policy Rule
**EKS clusters must have control plane logging enabled for: api, audit, authenticator**

### False Positive Scenarios

#### 1. EKS Cluster with CloudWatch Subscription Filter

**Scenario:**
```hcl
# EKS cluster without enabled_cluster_log_types
resource "aws_eks_cluster" "example" {
  name = "my-cluster"
  enabled_cluster_log_types = []
}

# But logs are collected via CloudWatch subscription filter
resource "aws_cloudwatch_log_subscription_filter" "eks_logs" {
  name            = "eks-logs"
  log_group_name  = "/aws/eks/my-cluster/cluster"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs.arn
}
```

**Why it's flagged:**
Policy checks `enabled_cluster_log_types` in Terraform plan. Alternative log collection methods aren't visible.

**Risk Level:** Medium
- Cluster logs might be collected via other means
- However, explicit control plane logging is EKS-native and more reliable

**Mitigation:**
- **Best Practice:** Enable native EKS control plane logging:
  ```hcl
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  ```
- **Reason:** CloudWatch subscription filters won't capture logs unless EKS logging is enabled first

**Not a false positive:** Subscription filters require control plane logging to be enabled. This should remain blocked.

#### 2. EKS Cluster in Development/Testing

**Scenario:**
```hcl
# Dev cluster without logging to reduce costs
resource "aws_eks_cluster" "dev" {
  name                      = "dev-cluster"
  enabled_cluster_log_types = []
  tags = {
    Environment = "development"
  }
}
```

**Why it's flagged:**
Policy applies to all EKS clusters regardless of environment.

**Risk Level:** Medium
- Development clusters may not need full logging
- However, security incidents happen in dev too

**Mitigation:**
1. **Recommended:** Enable logging even in dev (cost is minimal)
2. **Alternative:** Update policy to exempt dev environments:
   ```rego
   # In eks.rego
   is_non_production(resource) if {
       env := resource.change.after.tags.Environment
       env in {"development", "dev", "sandbox"}
   }

   deny contains msg if {
       resource := input.resource_changes[_]
       resource.type == "aws_eks_cluster"
       not is_non_production(resource)
       # ... rest of policy
   }
   ```

#### 3. EKS Cluster with Only Some Required Logs

**Scenario:**
```hcl
# Cluster with partial logging
resource "aws_eks_cluster" "example" {
  name = "my-cluster"
  enabled_cluster_log_types = ["api", "audit"]  # Missing authenticator
}
```

**Why it's flagged:**
Policy requires ALL three: api, audit, AND authenticator.

**Risk Level:** Medium
- Most critical logs (api, audit) are enabled
- Authenticator logs help with access troubleshooting

**Mitigation:**
- **Recommendation:** Enable all three required logs
- **Rationale:** 
  - `api`: API server activity (critical for security)
  - `audit`: Audit trail (compliance requirement)
  - `authenticator`: Authentication attempts (security incidents)

---

## Tagging Policy

### Policy Rule
**All taggable resources must have tags: Environment, Owner, CostCenter**

### False Positive Scenarios

#### 1. Resources That Don't Support Tags

**Scenario:**
```hcl
# Security group rule (separate resource)
resource "aws_security_group_rule" "example" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}
```

**Why it might be flagged:**
Some resources don't support tags at all.

**Risk Level:** Low
- Resource physically cannot have tags
- AWS API doesn't accept tags for this resource type

**Mitigation:**
Policy already includes `non_taggable_resource_types` list:
```rego
non_taggable_resource_types := {
    "aws_security_group_rule",
    "aws_s3_bucket_server_side_encryption_configuration",
    "aws_route",
    "aws_route_table_association",
    # ... etc
}
```

**Action Required:** If you find a false positive:
1. Verify resource type doesn't support tags in AWS documentation
2. Add to `non_taggable_resource_types` set in `tags.rego`
3. Submit PR with documentation link

#### 2. Resources with Provider-Generated Tags

**Scenario:**
```hcl
# Provider-level default tags
provider "aws" {
  default_tags {
    tags = {
      Environment = "production"
      Owner       = "platform"
      CostCenter  = "eng"
    }
  }
}

# Resource without explicit tags (inherits from provider)
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
  # No tags block - uses provider default_tags
}
```

**Why it's flagged:**
Terraform plan JSON shows resource without tags in `after` section. Provider default tags are merged later.

**Risk Level:** Low
- Tags are actually applied via provider defaults
- Terraform plan JSON doesn't reflect merged tags

**Mitigation:**

**Option 1:** Explicitly declare tags (best practice):
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
  tags = {
    Environment = "production"
    Owner       = "platform"
    CostCenter  = "eng"
  }
}
```

**Option 2:** Update policy to check for provider defaults:
```rego
# Check if provider default_tags cover required tags
# Note: This requires parsing Terraform configuration, not just plan
# More complex implementation required
```

**Recommendation:** Use explicit tags for clarity and policy compliance.

#### 3. Imported Resources with Existing Tags

**Scenario:**
```hcl
# Resource imported from AWS with existing tags
resource "aws_instance" "imported" {
  ami           = "ami-123456"
  instance_type = "t3.micro"
  # Tags not yet in Terraform state
}
```

**Why it's flagged:**
Terraform plan shows resource without tags because state hasn't been refreshed.

**Risk Level:** Low
- Resource in AWS has correct tags
- Terraform state not in sync yet

**Mitigation:**
- Run `terraform refresh` or `terraform plan` to sync state
- Add tags to Terraform configuration explicitly

#### 4. Tags with Different Naming Conventions

**Scenario:**
```hcl
# Resource with tags using different naming
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
  tags = {
    environment = "production"  # lowercase
    owner       = "platform"    # lowercase
    cost_center = "eng"         # underscore instead of camelCase
  }
}
```

**Why it's flagged:**
Policy checks for exact tag names: `Environment`, `Owner`, `CostCenter` (case-sensitive).

**Risk Level:** Medium
- Tags exist but don't match naming convention
- Inconsistent naming breaks cost tracking and automation

**Mitigation:**
- **Best Practice:** Standardize tag naming across organization
- **Update resources** to use standard names:
  ```hcl
  tags = {
    Environment = "production"  # Capital E
    Owner       = "platform"    # Capital O
    CostCenter  = "eng"         # CamelCase
  }
  ```

**Not a false positive:** Consistent naming is important for automation.

#### 5. Module-Created Resources

**Scenario:**
```hcl
# Using a third-party module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  # Module may not expose tag parameters for all resources
}
```

**Why it might be flagged:**
Module creates resources without proper tags if module doesn't support tagging.

**Risk Level:** Medium
- Module-created resources may lack required tags
- Not all modules support full tag customization

**Mitigation:**

**Option 1:** Use module's tag parameters if available:
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "my-vpc"
  cidr   = "10.0.0.0/16"

  tags = {
    Environment = "production"
    Owner       = "platform"
    CostCenter  = "eng"
  }
}
```

**Option 2:** Fork and update module to support tags

**Option 3:** Policy exemption for module-created resources (not recommended)

#### 6. Auto-Scaling Group Launch Template

**Scenario:**
```hcl
# Launch template for ASG
resource "aws_launch_template" "example" {
  name          = "example"
  image_id      = "ami-123456"
  instance_type = "t3.micro"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Environment = "production"
      Owner       = "platform"
      CostCenter  = "eng"
    }
  }

  # Launch template itself has no tags
  # tags = {} <- Missing
}
```

**Why it's flagged:**
Launch template resource itself needs tags, not just `tag_specifications` for launched instances.

**Risk Level:** Low
- Instances will be tagged correctly
- Launch template itself should also be tagged for resource management

**Mitigation:**
- **Best Practice:** Tag both template and instances:
  ```hcl
  resource "aws_launch_template" "example" {
    name = "example"
    # ... config ...

    tags = {
      Environment = "production"
      Owner       = "platform"
      CostCenter  = "eng"
    }

    tag_specifications {
      resource_type = "instance"
      tags = {
        Environment = "production"
        Owner       = "platform"
        CostCenter  = "eng"
      }
    }
  }
  ```

---

## General Mitigation Strategies

### 1. Policy Exemptions Framework

Create an exemptions file checked by policies:

```json
// exemptions.json
{
  "exemptions": [
    {
      "resource_address": "aws_s3_bucket.legacy_logs",
      "policy": "terraform.s3",
      "reason": "Legacy bucket with account-level encryption, migrating Q2 2024",
      "approved_by": "security-team@example.com",
      "approved_date": "2024-01-15",
      "expires": "2024-06-30",
      "ticket": "SEC-12345"
    }
  ]
}
```

Update policies to check exemptions:

```rego
# In each policy
import data.exemptions

is_exempt(resource_address, policy_name) if {
    exemption := exemptions.exemptions[_]
    exemption.resource_address == resource_address
    exemption.policy == policy_name
    not is_expired(exemption.expires)
}

is_expired(expires) if {
    # Check if exemption is past expiration date
    # Implementation depends on date comparison library
}
```

### 2. Environment-Specific Policies

Different rules for different environments:

```rego
# Less strict for development
is_development(resource) if {
    env := resource.change.after.tags.Environment
    env in {"development", "dev", "sandbox"}
}

deny contains msg if {
    resource := input.resource_changes[_]
    not is_development(resource)
    # ... strict checks for prod/staging
}
```

### 3. Warning vs. Error Levels

Implement severity levels:

```rego
# Generate warnings instead of denials for certain cases
warn contains msg if {
    # Less critical violations
}

deny contains msg if {
    # Critical violations only
}
```

### 4. Documentation Requirements

For each exemption, require:
- **Business justification:** Why exception is needed
- **Compensating controls:** Alternative security measures
- **Expiration date:** When exception will be reviewed
- **Approval:** Who authorized the exception
- **Ticket reference:** Link to approval ticket/process

### 5. Regular Policy Reviews

- **Quarterly:** Review false positives and update policies
- **After incidents:** Check if policies could have prevented issue
- **On AWS updates:** Check for new resource types or features
- **Team feedback:** Collect developer feedback on policy pain points

---

## Reporting False Positives

If you encounter a false positive not covered here:

1. **Document the scenario:**
   - Resource type and configuration
   - Why it's flagged
   - Why it should pass
   - Business justification

2. **Verify it's actually a false positive:**
   - Check AWS documentation
   - Confirm resource supports the requirement
   - Ensure it's not a legitimate violation

3. **Submit for review:**
   - Create issue/ticket with details
   - Propose policy update or exemption
   - Security team approval required

4. **Update documentation:**
   - Add scenario to this document
   - Update policy with fix
   - Communicate to team

---

## Summary Table

| Policy | Common False Positives | Risk Level | Recommended Action |
|--------|----------------------|------------|-------------------|
| **S3 Encryption** | Account-level defaults | Medium | Explicit config preferred |
| **S3 Encryption** | Public website buckets | Low | Encrypt anyway |
| **Security Groups** | Bastion + Session Manager | High | Remove SSH rule |
| **Security Groups** | Port ranges | High | Narrow to specific ports |
| **EKS Logging** | CloudWatch alternatives | Medium | Enable native logging |
| **EKS Logging** | Dev environments | Medium | Enable or exempt by policy |
| **Tags** | Non-taggable resources | Low | Add to exempt list |
| **Tags** | Provider default tags | Low | Use explicit tags |
| **Tags** | Wrong naming convention | Medium | Standardize naming |
| **Tags** | Module resources | Medium | Use module tag params |

---

## Conclusion

False positives are inevitable with policy-as-code. The key is:
1. **Design policies thoughtfully** - Consider edge cases
2. **Document exceptions** - Clear process for legitimate exceptions
3. **Review regularly** - Update policies based on feedback
4. **Balance security and productivity** - Overly strict policies get bypassed

When in doubt, err on the side of security. It's better to require justification for an exception than to allow a security gap.
