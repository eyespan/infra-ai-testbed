# CI Integration Guide for OPA Terraform Policies

## Overview

This guide explains how to integrate OPA/Rego policy validation into your CI/CD pipeline to enforce Infrastructure as Code (IaC) guardrails before Terraform applies changes.

## Prerequisites

- **Terraform** 1.0+
- **Conftest** (OPA CLI tool for testing) or **OPA** CLI
- CI/CD system (GitHub Actions, GitLab CI, Jenkins, etc.)

## Installation

### Install Conftest

```bash
# macOS
brew install conftest

# Linux
wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# Verify
conftest --version
```

### Install OPA CLI (alternative)

```bash
# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/

# Verify
opa version
```

## Local Testing

### Generate Terraform Plan JSON

```bash
# Initialize Terraform
terraform init

# Generate plan in JSON format
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
```

### Test with Conftest

```bash
# Test against all policies
conftest test tfplan.json --policy ./policies/

# Test specific policy
conftest test tfplan.json --policy ./policies/s3.rego

# Show all violations with details
conftest test tfplan.json --policy ./policies/ --all-namespaces
```

### Test with OPA CLI

```bash
# Run OPA unit tests
opa test policies/ -v

# Evaluate policies against plan
opa eval --data policies/ --input tfplan.json "data.terraform"

# Check for violations
opa eval --data policies/ --input tfplan.json "data.terraform.s3.deny"
```

## CI/CD Integration Examples

### GitHub Actions

Create `.github/workflows/terraform-policy-check.yml`:

```yaml
name: Terraform Policy Check

on:
  pull_request:
    paths:
      - '**.tf'
      - '**.tfvars'
      - 'policies/**'

jobs:
  policy-check:
    name: OPA Policy Validation
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Install Conftest
        run: |
          wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
          tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
          sudo mv conftest /usr/local/bin/
          conftest --version

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Plan
        run: |
          terraform plan -out=tfplan.binary
          terraform show -json tfplan.binary > tfplan.json
        working-directory: ./terraform

      - name: Run OPA Policy Tests
        run: |
          conftest test terraform/tfplan.json \
            --policy ./policies/ \
            --all-namespaces \
            --fail-on-warn

      - name: Comment PR with Results
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ Terraform policy check failed. Please review the policy violations in the CI logs.'
            })
```

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - plan
  - policy-check

terraform:plan:
  stage: plan
  image: hashicorp/terraform:1.6
  script:
    - terraform init
    - terraform plan -out=tfplan.binary
    - terraform show -json tfplan.binary > tfplan.json
  artifacts:
    paths:
      - tfplan.json
    expire_in: 1 day

opa:policy-check:
  stage: policy-check
  image: openpolicyagent/conftest:latest
  dependencies:
    - terraform:plan
  script:
    - conftest test tfplan.json --policy ./policies/ --all-namespaces
  only:
    - merge_requests
    - main
```

### Jenkins Pipeline

Create `Jenkinsfile`:

```groovy
pipeline {
    agent any

    stages {
        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan.binary'
                sh 'terraform show -json tfplan.binary > tfplan.json'
            }
        }

        stage('OPA Policy Check') {
            steps {
                script {
                    // Install conftest if not available
                    sh '''
                        if ! command -v conftest &> /dev/null; then
                            wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
                            tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
                            sudo mv conftest /usr/local/bin/
                        fi
                    '''

                    // Run policy check
                    def result = sh(
                        script: 'conftest test tfplan.json --policy ./policies/ --all-namespaces',
                        returnStatus: true
                    )

                    if (result != 0) {
                        error('OPA policy violations detected. Please fix before proceeding.')
                    }
                }
            }
        }

        stage('Manual Approval') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Approve Terraform Apply?'
            }
        }

        stage('Terraform Apply') {
            when {
                branch 'main'
            }
            steps {
                sh 'terraform apply tfplan.binary'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'tfplan.json', allowEmptyArchive: true
        }
    }
}
```

### CircleCI

Create `.circleci/config.yml`:

```yaml
version: 2.1

orbs:
  terraform: circleci/terraform@3.2

jobs:
  policy-check:
    docker:
      - image: hashicorp/terraform:1.6
    steps:
      - checkout

      - run:
          name: Install Conftest
          command: |
            wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
            tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
            mv conftest /usr/local/bin/

      - run:
          name: Terraform Init
          command: terraform init

      - run:
          name: Terraform Plan
          command: |
            terraform plan -out=tfplan.binary
            terraform show -json tfplan.binary > tfplan.json

      - run:
          name: OPA Policy Check
          command: conftest test tfplan.json --policy ./policies/ --all-namespaces

      - store_artifacts:
          path: tfplan.json

workflows:
  version: 2
  terraform:
    jobs:
      - policy-check
```

## Policy Check Workflow

### Recommended CI Flow

```
┌─────────────────────────────────────────────────────────┐
│  1. Developer commits Terraform changes                  │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  2. CI: Terraform init & plan                           │
│     terraform plan -out=tfplan.binary                   │
│     terraform show -json tfplan.binary > tfplan.json    │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  3. CI: Run OPA policy checks                           │
│     conftest test tfplan.json --policy ./policies/      │
└────────────────┬────────────────────────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
┌────────────┐    ┌─────────────┐
│ PASS ✓     │    │ FAIL ✗      │
│ Continue   │    │ Block PR    │
└──────┬─────┘    └─────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────┐
│  4. Manual approval (production only)                  │
└────────────┬───────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────┐
│  5. Terraform apply                                     │
└────────────────────────────────────────────────────────┘
```

## Configuration Options

### Conftest Configuration File

Create `.conftest.toml` in your repository root:

```toml
# Policy directory
policy = "policies"

# Namespaces to check
namespace = [
  "terraform.s3",
  "terraform.sg",
  "terraform.eks",
  "terraform.tags"
]

# Fail on warnings
fail_on_warn = true

# Output format (stdout, json, tap, table)
output = "stdout"

# Show successes in output
all_namespaces = true
```

### Policy Enforcement Levels

You can configure different enforcement levels:

```yaml
# .github/workflows/terraform-policy-check.yml
- name: Run OPA Policy Tests (Strict)
  run: |
    conftest test tfplan.json \
      --policy ./policies/ \
      --all-namespaces \
      --fail-on-warn  # Fail on any violation

# Or for soft enforcement (warn only)
- name: Run OPA Policy Tests (Warn)
  run: |
    conftest test tfplan.json \
      --policy ./policies/ \
      --all-namespaces \
      --no-fail  # Don't fail CI, just warn
  continue-on-error: true
```

## Branch Protection Rules

### GitHub Branch Protection

Require policy checks to pass before merge:

1. Go to repository Settings → Branches
2. Add branch protection rule for `main`
3. Enable "Require status checks to pass before merging"
4. Select "OPA Policy Validation" from the list
5. Enable "Require branches to be up to date before merging"

### GitLab Merge Request Approvals

```yaml
# .gitlab-ci.yml
opa:policy-check:
  stage: policy-check
  script:
    - conftest test tfplan.json --policy ./policies/
  only:
    - merge_requests
  allow_failure: false  # Block merge if policies fail
```

Configure in GitLab:
1. Settings → Merge Requests → Merge checks
2. Enable "Pipelines must succeed"

## Pre-commit Hooks

Integrate policy checks locally before commit:

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: terraform-plan-policy
        name: Terraform Policy Check
        entry: bash -c 'terraform plan -out=tfplan.binary && terraform show -json tfplan.binary > tfplan.json && conftest test tfplan.json --policy ./policies/'
        language: system
        pass_filenames: false
        files: \.tf$
```

Install pre-commit:

```bash
pip install pre-commit
pre-commit install
```

## Monitoring and Reporting

### Policy Violation Metrics

Track policy violations over time:

```bash
# Generate JSON report
conftest test tfplan.json \
  --policy ./policies/ \
  --output json > policy-report.json

# Parse and send to metrics system
cat policy-report.json | jq '.[] | select(.failures) | .failures[]' | wc -l
```

### Integration with Security Tools

Forward policy violations to security platforms:

```yaml
# GitHub Actions example
- name: Upload Policy Results to Security Hub
  if: always()
  run: |
    conftest test tfplan.json \
      --policy ./policies/ \
      --output json | \
    jq -r '.' > policy-results.json

    # Upload to AWS Security Hub, Splunk, etc.
    ./scripts/send-to-security-hub.sh policy-results.json
```

## Troubleshooting

### Common Issues

**Issue: Policies not found**
```bash
# Ensure policy directory is correct
conftest test tfplan.json --policy ./policies/ --trace
```

**Issue: Plan JSON format unexpected**
```bash
# Validate plan JSON structure
jq '.resource_changes' tfplan.json | head -n 50

# Check Terraform version compatibility
terraform version
```

**Issue: Tests pass locally but fail in CI**
```bash
# Use same Terraform version in CI and locally
# Check if .terraform.lock.hcl is committed
# Verify all policy files are committed
```

### Debug Mode

Run with verbose output:

```bash
# Conftest debug
conftest test tfplan.json --policy ./policies/ --trace

# OPA debug
opa eval --data policies/ --input tfplan.json \
  "data.terraform" --explain full
```

## Best Practices

1. **Version Control Policies:** Store policies in same repo as infrastructure code
2. **Test Policies:** Write unit tests for all policies (see `*_test.rego` files)
3. **Document Policies:** Add comments explaining business rules
4. **Gradual Rollout:** Start with warnings, then enforce
5. **Regular Reviews:** Review and update policies quarterly
6. **Exceptions Process:** Define process for policy exceptions (not bypassing)
7. **Policy Ownership:** Assign team ownership for policy maintenance
8. **Fail Fast:** Run policy checks early in pipeline (before expensive operations)

## Policy Exception Workflow

For legitimate exceptions:

```yaml
# terraform/exemptions.json
{
  "exemptions": [
    {
      "resource": "aws_security_group.legacy_bastion",
      "policy": "terraform.sg",
      "reason": "Legacy system, decommissioning Q2 2024",
      "approved_by": "security-team",
      "expires": "2024-06-30"
    }
  ]
}
```

Update policies to check exemptions file (not included in basic policies).

## Next Steps

1. **Deploy policies to CI** following examples above
2. **Train team** on policy requirements
3. **Monitor violations** and adjust policies as needed
4. **Expand policies** for additional resource types
5. **Integrate with** security scanning tools (Checkov, tfsec, etc.)

## References

- [Conftest Documentation](https://www.conftest.dev/)
- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Terraform JSON Plan Format](https://www.terraform.io/internals/json-format)
- Policy files in `./policies/` directory
- Test files in `./policies/*_test.rego`
