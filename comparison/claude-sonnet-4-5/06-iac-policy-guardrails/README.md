# OPA/Rego Terraform Policy Guardrails

## Overview

This directory contains OPA (Open Policy Agent) policies written in Rego to enforce Infrastructure as Code (IaC) guardrails on Terraform plans before applying changes to AWS infrastructure.

## Policies

### 1. S3 Encryption (`policies/s3.rego`)
**Rule:** No S3 buckets without server-side encryption

**Checks:**
- S3 buckets must have `aws_s3_bucket_server_side_encryption_configuration` resource
- Or inline `server_side_encryption_configuration` (older Terraform versions)

**Prevents:** Unencrypted data at rest

### 2. Security Group Restrictions (`policies/sg.rego`)
**Rule:** No security groups allowing 0.0.0.0/0 on ports 22 (SSH) or 3389 (RDP)

**Checks:**
- Security group ingress rules
- Standalone security group rule resources
- Both IPv4 (`0.0.0.0/0`) and IPv6 (`::/0`)
- Port ranges that include 22 or 3389

**Prevents:** Publicly accessible SSH/RDP services

### 3. EKS Control Plane Logging (`policies/eks.rego`)
**Rule:** All EKS clusters must have control plane logging enabled

**Checks:**
- `enabled_cluster_log_types` includes at minimum: `api`, `audit`, `authenticator`

**Prevents:** Security incidents without audit trail

### 4. Mandatory Tagging (`policies/tags.rego`)
**Rule:** All taggable resources must have required tags

**Required Tags:**
- `Environment` - Environment name (production, staging, dev, etc.)
- `Owner` - Team or person responsible
- `CostCenter` - Cost allocation identifier

**Checks:**
- All AWS resources that support tagging
- Excludes known non-taggable resources (security group rules, route table associations, etc.)

**Prevents:** Untrackable costs and unclear ownership

## Directory Structure

```
.
├── README.md                          # This file
├── CI_INTEGRATION.md                  # CI/CD integration guide
├── FALSE_POSITIVES.md                 # False positive documentation
├── SOLUTION.md                        # Solution summary
├── policies/
│   ├── s3.rego                       # S3 encryption policy
│   ├── s3_test.rego                  # S3 policy tests
│   ├── sg.rego                       # Security group policy
│   ├── sg_test.rego                  # Security group tests
│   ├── eks.rego                      # EKS logging policy
│   ├── eks_test.rego                 # EKS policy tests
│   ├── tags.rego                     # Tagging policy
│   └── tags_test.rego                # Tagging policy tests
└── fixtures/
    ├── plan.json                     # Failing plan fixture
    └── plan-passing.json             # Passing plan fixture
```

## Prerequisites

### Install Conftest

```bash
# macOS
brew install conftest

# Linux
wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/
```

### Or Install OPA CLI

```bash
# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/
```

## Quick Start

### 1. Run Unit Tests

Test policies against test cases:

```bash
# Run all policy unit tests
opa test policies/ -v

# Run tests for specific policy
opa test policies/s3.rego policies/s3_test.rego -v
```

**Expected Output:**
```
policies/s3_test.rego:
  data.terraform.s3.test_s3_without_encryption_denied: PASS (0.5ms)
  data.terraform.s3.test_s3_with_encryption_passes: PASS (0.3ms)
  data.terraform.s3.test_s3_with_inline_encryption_passes: PASS (0.4ms)
  data.terraform.s3.test_s3_delete_not_checked: PASS (0.2ms)
--------------------------------------------------------------------------------
PASS: 4/4
```

### 2. Test Against Fixtures

Test policies against Terraform plan fixtures:

```bash
# Test failing fixture (should find violations)
conftest test fixtures/plan.json --policy policies/

# Test passing fixture (should have no violations)
conftest test fixtures/plan-passing.json --policy policies/
```

**Expected Output for Failing Plan:**
```
FAIL - fixtures/plan.json - terraform.s3 - S3 bucket 'aws_s3_bucket.logs' must have server-side encryption enabled
FAIL - fixtures/plan.json - terraform.sg - Security group 'aws_security_group.bastion' allows public access (0.0.0.0/0) on sensitive port 22
FAIL - fixtures/plan.json - terraform.eks - EKS cluster 'aws_eks_cluster.main' must have control plane logging enabled for: api, audit, authenticator
FAIL - fixtures/plan.json - terraform.tags - Resource 'aws_s3_bucket.logs' (type: aws_s3_bucket) is missing required tags: Owner, CostCenter
FAIL - fixtures/plan.json - terraform.tags - Resource 'aws_security_group.bastion' (type: aws_security_group) is missing required tags: CostCenter
FAIL - fixtures/plan.json - terraform.tags - Resource 'aws_eks_cluster.main' (type: aws_eks_cluster) is missing required tags: Environment

6 tests, 0 passed, 0 warnings, 6 failures
```

**Expected Output for Passing Plan:**
```
6 tests, 6 passed, 0 warnings, 0 failures
```

### 3. Test Against Real Terraform Plan

Generate and test a real Terraform plan:

```bash
# Navigate to your Terraform directory
cd /path/to/terraform

# Generate plan in JSON format
terraform init
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Test against policies
conftest test tfplan.json --policy /path/to/policies/

# Or with detailed output
conftest test tfplan.json --policy /path/to/policies/ --all-namespaces
```

## Running Tests

### Option 1: OPA Test (Unit Tests)

```bash
# All tests with verbose output
opa test policies/ -v

# Specific test file
opa test policies/s3_test.rego -v

# With coverage report
opa test policies/ -v --coverage

# Fail on coverage below threshold
opa test policies/ -v --coverage --threshold 80
```

### Option 2: Conftest (Integration Tests)

```bash
# Test specific fixture
conftest test fixtures/plan.json --policy policies/

# Test with all namespaces shown
conftest test fixtures/plan.json --policy policies/ --all-namespaces

# Test and show passing tests too
conftest test fixtures/plan.json --policy policies/ --show-builtin-errors

# Output in JSON format
conftest test fixtures/plan.json --policy policies/ --output json

# Fail on warnings (treat warnings as failures)
conftest test fixtures/plan.json --policy policies/ --fail-on-warn
```

### Option 3: OPA Eval (Manual Testing)

```bash
# Evaluate all policies
opa eval --data policies/ --input fixtures/plan.json "data.terraform"

# Evaluate specific policy
opa eval --data policies/s3.rego --input fixtures/plan.json "data.terraform.s3.deny"

# With pretty printing
opa eval --data policies/ --input fixtures/plan.json "data.terraform" --format pretty
```

## Writing New Policies

### Policy Template

```rego
package terraform.RESOURCE_TYPE

import rego.v1

deny contains msg if {
    # Get resources of interest
    resource := input.resource_changes[_]
    resource.type == "aws_RESOURCE_TYPE"

    # Check if action is create or update
    action_creates_or_updates(resource.change.actions)

    # Check for violation condition
    # ... your condition logic ...

    # Generate violation message
    msg := sprintf(
        "Resource '%s' violates policy: ...",
        [resource.address]
    )
}

# Helper functions
action_creates_or_updates(actions) if {
    "create" in actions
}

action_creates_or_updates(actions) if {
    "update" in actions
}
```

### Test Template

```rego
package terraform.RESOURCE_TYPE

import rego.v1

test_policy_denies_violation if {
    input := {
        "resource_changes": [
            {
                "address": "aws_resource.test",
                "type": "aws_resource",
                "change": {
                    "actions": ["create"],
                    "after": {
                        # Resource config that should be denied
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "expected violation message")
}

test_policy_allows_compliant if {
    input := {
        "resource_changes": [
            {
                "address": "aws_resource.test",
                "type": "aws_resource",
                "change": {
                    "actions": ["create"],
                    "after": {
                        # Compliant resource config
                    }
                }
            }
        ]
    }

    count(deny) == 0
}
```

## Terraform Plan JSON Structure

Policies expect Terraform plan JSON with this structure:

```json
{
  "format_version": "1.2",
  "resource_changes": [
    {
      "address": "aws_s3_bucket.example",
      "mode": "managed",
      "type": "aws_s3_bucket",
      "name": "example",
      "change": {
        "actions": ["create"],
        "before": null,
        "after": {
          "bucket": "my-bucket",
          "tags": {
            "Environment": "production"
          }
        },
        "after_unknown": {}
      }
    }
  ]
}
```

Generate this format with:
```bash
terraform show -json tfplan.binary > tfplan.json
```

## CI/CD Integration

See [CI_INTEGRATION.md](./CI_INTEGRATION.md) for detailed CI/CD setup instructions including:
- GitHub Actions
- GitLab CI
- Jenkins
- CircleCI
- Pre-commit hooks
- Branch protection rules

## False Positives

See [FALSE_POSITIVES.md](./FALSE_POSITIVES.md) for:
- Common false positive scenarios
- Risk assessments
- Mitigation strategies
- When to exempt vs. fix

## Troubleshooting

### Tests Fail Locally But Pass in CI

```bash
# Check OPA/Conftest version
opa version
conftest --version

# Ensure using same version in CI and locally
```

### Policy Not Detecting Violation

```bash
# Debug with trace
conftest test tfplan.json --policy policies/ --trace

# Check input structure
jq '.resource_changes[] | select(.type == "aws_s3_bucket")' tfplan.json

# Evaluate rule step by step
opa eval --data policies/s3.rego --input tfplan.json \
  'data.terraform.s3.deny' --explain full
```

### Test Fails with "undefined"

```bash
# Common cause: missing import rego.v1
# Add to top of policy file:
import rego.v1
```

### "No test files found"

```bash
# Ensure test files end with _test.rego
# Must be in same directory as policy files
# Run from directory containing policies:
opa test . -v
```

## Best Practices

1. **Write tests first** - TDD approach ensures policy works as expected
2. **Test edge cases** - Include tests for boundary conditions
3. **Document rationale** - Add comments explaining business rules
4. **Keep policies simple** - One policy per rule, avoid complex logic
5. **Use helper functions** - Reuse common checks across policies
6. **Version control** - Track policy changes with git
7. **Review regularly** - Update policies as AWS features evolve
8. **Measure coverage** - Aim for >80% test coverage

## Performance Considerations

- Policies run on every Terraform plan (fast)
- Large plans (>1000 resources) may take 1-2 seconds
- Optimize by avoiding nested loops
- Use sets for membership checks (faster than arrays)

## Security

- Policies are code - review like any code change
- Test policies thoroughly before deployment
- Policies cannot modify infrastructure (read-only)
- Policies run locally or in CI (no external dependencies)

## Contributing

1. Add new policy in `policies/RESOURCE.rego`
2. Add tests in `policies/RESOURCE_test.rego`
3. Run all tests: `opa test policies/ -v`
4. Add fixture examples
5. Document in FALSE_POSITIVES.md if applicable
6. Update this README

## References

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Conftest Documentation](https://www.conftest.dev/)
- [Terraform JSON Plan Format](https://www.terraform.io/internals/json-format)
- [AWS Resource Tagging](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)

## Support

- **Issues:** Create issue in repository
- **Questions:** Ask in #infrastructure channel
- **False Positives:** Document in FALSE_POSITIVES.md
- **Policy Requests:** Submit via issue template

## License

See LICENSE file in repository root.
