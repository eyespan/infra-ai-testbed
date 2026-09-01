# CI Integration for IaC Policy Guardrails

## Overview

These OPA/Rego policies run in CI before `terraform apply` to prevent security issues from reaching production infrastructure.

## Where to Run

Place the policy check step **after** `terraform plan` and **before** `terraform apply`:

```yaml
# .github/workflows/terraform.yml
jobs:
  terraform:
    steps:
      - name: Terraform Plan
        run: terraform plan -input=false -out=tfplan

      - name: OPA Policy Check
        run: conftest test -p policies tfplan.json

      - name: Terraform Apply
        if: success()
        run: terraform apply -input=false tfplan
```

## CI Run Command

```bash
conftest test -p policies/ *.json
```

Or for specific policies:

```bash
conftest test -p policies/s3.rego -p policies/sg.rego -p policies/eks.rego -p policies/tags.rego tfplan.json
```

## Fail Behavior

- Policy violations will cause the step to fail with exit code 1
- The failure message will list all violations with resource addresses
- Pipeline stops before `terraform apply` can execute

## Exception Handling

Exceptions can be granted in two ways:

### 1. Policy Override Annotation
Add `#policy-exception: <reason>` comment in Terraform resource:

```hcl
resource "aws_security_group" "bastion" {
  #policy-exception: SSH from 0.0.0.0/0 required for emergency access
  name = "bastion"
  # ...
}
```

### 2. Policy Exemption Config
Add to `exemptions.json`:

```json
{
  "exemptions": [
    {
      "resources": ["aws_security_group.bastion"],
      "reason": "Emergency SSH access required",
      "approved_by": "security-team"
    }
  ]
}
```

## Local Testing

```bash
# Test against all fixtures
conftest test -p policies fixtures/*.json

# Run tests
conftest test --test tests/*.rego policies/*.rego

# Use opa test directly
opa test -v policies/*.rego tests/*.rego
```

## Policy Update Process

1. Update policies in `policies/` directory
2. Run tests: `conftest test --test tests/*.rego policies/*.rego`
3. Update fixtures if needed
4. Commit changes with test updates

## Troubleshooting

### Common CI Failures

1. **conftest not found**: Install via `brew install conftest` or download from https://github.com/open-policy-agent/conftest

2. **Policy not found**: Ensure paths are correct relative to CI root

3. **False positives**: Review exception handling options above
