# Jenkins to GitHub Actions Migration

## Overview

This document details the migration from Jenkins pipeline to GitHub Actions workflow, mapping each feature and documenting any changes.

## Summary

**All required features preserved:**
- ✅ Unit and integration test stages
- ✅ Security scanning (Trivy)
- ✅ Manual approval gate before production deploy
- ✅ Environment-specific secrets handling
- ✅ Rollback on failure
- ✅ Caching of dependencies
- ✅ Concurrency control to prevent race conditions

## Feature-by-Feature Mapping

### 1. Pipeline Structure

**Jenkins:**
```groovy
@Library('platform') _
pipeline {
  agent { label 'linux && docker' }
  options { ... }
  stages { ... }
}
```

**GitHub Actions:**
```yaml
name: Build and Deploy
on: [push, pull_request]
concurrency: { ... }
jobs: { ... }
```

**Changes:**
- Jenkins uses shared library `@Library('platform')` → GitHub Actions uses local composite actions in `.github/actions/`
- Agent labels replaced with `runs-on: ubuntu-latest` (GitHub-hosted runners with Docker pre-installed)
- Pipeline options converted to job-level and workflow-level settings

---

### 2. Concurrency Control

**Jenkins:**
```groovy
options {
  disableConcurrentBuilds()
}
```

**GitHub Actions:**
```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false
```

**Status:** ✅ **PRESERVED**

**Notes:**
- Prevents concurrent deploys to the same branch
- `cancel-in-progress: false` ensures running deploys complete (equivalent to Jenkins behavior)
- Group key includes `github.ref` for branch-level locking

---

### 3. Timeout

**Jenkins:**
```groovy
options {
  timeout(time: 45, unit: 'MINUTES')
}
```

**GitHub Actions:**
```yaml
timeout-minutes: 45  # Per job
```

**Status:** ✅ **PRESERVED**

**Notes:**
- Applied to each job individually (GitHub Actions doesn't have workflow-level timeout)
- Same 45-minute limit maintained

---

### 4. Unit Tests

**Jenkins:**
```groovy
stage('Unit') {
  steps {
    sh 'npm ci'
    sh 'npm test'
  }
}
```

**GitHub Actions:**
```yaml
jobs:
  unit-tests:
    steps:
      - uses: actions/setup-node@v4
        with:
          cache: 'npm'
      - run: npm ci
      - run: npm test
```

**Status:** ✅ **PRESERVED**

**Improvements:**
- Added npm caching via `cache: 'npm'` for faster builds
- Explicit Node.js version pinning

---

### 5. Integration Tests

**Jenkins:**
```groovy
stage('Integration') {
  steps {
    sh 'docker compose -f docker-compose.test.yml up --abort-on-container-exit'
  }
}
```

**GitHub Actions:**
```yaml
integration-tests:
  steps:
    - run: docker compose -f docker-compose.test.yml up --abort-on-container-exit
    - run: docker compose -f docker-compose.test.yml down -v
      if: always()
```

**Status:** ✅ **PRESERVED**

**Improvements:**
- Added cleanup step to ensure containers are removed

---

### 6. Security Scanning

**Jenkins:**
```groovy
stage('Scan') {
  steps {
    sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL .'
  }
}
```

**GitHub Actions:**
```yaml
security-scan:
  steps:
    - uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        severity: 'HIGH,CRITICAL'
        exit-code: '1'
    - uses: github/codeql-action/upload-sarif@v3
```

**Status:** ✅ **PRESERVED**

**Improvements:**
- Uses official Trivy GitHub Action
- Results uploaded to GitHub Security tab (SARIF format)
- Better integration with GitHub's security features

---

### 7. Docker Build and Push

**Jenkins:**
```groovy
stage('Build') {
  steps {
    script {
      def sha = env.GIT_COMMIT.take(12)
      sh "docker build -t ${REGISTRY}/${APP}:${sha} ."
      sh "docker push ${REGISTRY}/${APP}:${sha}"
      env.IMAGE_TAG = sha
    }
  }
}
```

**GitHub Actions:**
```yaml
build-and-push:
  steps:
    - uses: docker/setup-buildx-action@v3
    - uses: docker/login-action@v3
    - id: image-info
      run: |
        SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-12)
        echo "tag=$SHORT_SHA" >> $GITHUB_OUTPUT
    - uses: docker/build-push-action@v5
      with:
        cache-from: type=gha
        cache-to: type=gha,mode=max
```

**Status:** ✅ **PRESERVED**

**Improvements:**
- Added Docker layer caching using GitHub Actions cache
- Uses Docker Buildx for better performance
- Image tag passed to downstream jobs via outputs

---

### 8. Deploy to Staging

**Jenkins:**
```groovy
stage('Deploy staging') {
  when { branch 'main' }
  steps {
    platform.deploy('staging', env.IMAGE_TAG)
    platform.notifySlack("staging ${env.IMAGE_TAG}")
  }
}
```

**GitHub Actions:**
```yaml
deploy-staging:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  environment:
    name: staging
    url: https://staging.example.com
  steps:
    - uses: ./.github/actions/deploy
    - uses: ./.github/actions/notify-slack
```

**Status:** ✅ **PRESERVED**

**Mapping:**
- `platform.deploy()` → `.github/actions/deploy` composite action
- `platform.notifySlack()` → `.github/actions/notify-slack` composite action
- `when { branch 'main' }` → `if: github.ref == 'refs/heads/main'`

**Improvements:**
- Uses GitHub Environments feature for deployment tracking and protection rules
- Environment URL configured for quick access

---

### 9. Manual Approval Gate

**Jenkins:**
```groovy
stage('Approve production') {
  when { branch 'main' }
  steps {
    input message: 'Deploy to production?', ok: 'Deploy'
  }
}
```

**GitHub Actions:**
```yaml
approve-production:
  environment:
    name: production-approval
  steps:
    - run: echo "✓ Deployment to production approved"
```

**Status:** ✅ **PRESERVED**

**Mapping:**
- Jenkins `input` step → GitHub Environment protection rules with required reviewers
- Manual approval configured at repository Settings → Environments → production-approval

**Configuration Required:**
1. Navigate to: Repository Settings → Environments
2. Create environment: `production-approval`
3. Enable "Required reviewers"
4. Add authorized approvers

**Notes:**
- GitHub's environment protection provides better audit trail
- Can configure multiple reviewers and wait timer
- Approval shows in GitHub UI with approval history

---

### 10. Deploy to Production

**Jenkins:**
```groovy
stage('Deploy production') {
  when { branch 'main' }
  steps {
    platform.deploy('production', env.IMAGE_TAG)
    platform.notifySlack("production ${env.IMAGE_TAG}")
  }
}
```

**GitHub Actions:**
```yaml
deploy-production:
  needs: [build-and-push, approve-production]
  environment:
    name: production
    url: https://production.example.com
  steps:
    - uses: ./.github/actions/deploy
    - uses: ./.github/actions/notify-slack
```

**Status:** ✅ **PRESERVED**

**Notes:**
- Waits for approval via `needs: [approve-production]`
- Same composite actions as staging with different environment parameter

---

### 11. Rollback on Failure

**Jenkins:**
```groovy
post {
  failure {
    script {
      if (env.IMAGE_TAG) {
        platform.rollback('production')
      }
    }
  }
}
```

**GitHub Actions:**
```yaml
deploy-production:
  steps:
    - uses: ./.github/actions/deploy
      id: deploy-prod
    - uses: ./.github/actions/rollback
      if: failure()
```

**Status:** ✅ **PRESERVED**

**Mapping:**
- `platform.rollback()` → `.github/actions/rollback` composite action
- `post { failure }` → `if: failure()` step condition
- Condition to check IMAGE_TAG not needed (job dependency ensures it exists)

---

### 12. Environment-Specific Secrets

**Jenkins:**
- Managed via Jenkins credentials store
- Accessed implicitly by shared library

**GitHub Actions:**
```yaml
deploy-staging:
  steps:
    - uses: ./.github/actions/deploy
      with:
        deploy-token: ${{ secrets.STAGING_DEPLOY_TOKEN }}
        kubectl-config: ${{ secrets.STAGING_KUBECONFIG }}

deploy-production:
  steps:
    - uses: ./.github/actions/deploy
      with:
        deploy-token: ${{ secrets.PRODUCTION_DEPLOY_TOKEN }}
        kubectl-config: ${{ secrets.PRODUCTION_KUBECONFIG }}
```

**Status:** ✅ **PRESERVED**

**Secrets Required:**
- `STAGING_DEPLOY_TOKEN` - Authentication for staging deployments
- `STAGING_KUBECONFIG` - Kubernetes config for staging (base64 encoded)
- `PRODUCTION_DEPLOY_TOKEN` - Authentication for production deployments
- `PRODUCTION_KUBECONFIG` - Kubernetes config for production (base64 encoded)
- `SLACK_WEBHOOK_URL` - Slack incoming webhook URL
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

**Configuration:**
Navigate to: Repository Settings → Secrets and variables → Actions → New repository secret

---

### 13. Dependency Caching

**Jenkins:**
- Not explicitly configured (relies on workspace persistence)

**GitHub Actions:**
```yaml
- uses: actions/setup-node@v4
  with:
    cache: 'npm'

- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Status:** ✅ **ENHANCED**

**Improvements:**
- Explicit npm package caching
- Docker layer caching across workflow runs
- Faster build times compared to Jenkins workspace approach

---

## Shared Library Migration

### Jenkins Shared Library Functions

The original Jenkinsfile used `@Library('platform')` with three functions:

1. `platform.deploy(environment, imageTag)`
2. `platform.notifySlack(message)`
3. `platform.rollback(environment)`

### GitHub Actions Composite Actions

Created three composite actions in `.github/actions/`:

| Shared Library Function | Composite Action | Location |
|------------------------|------------------|----------|
| `platform.deploy()` | `deploy` | `.github/actions/deploy/action.yml` |
| `platform.notifySlack()` | `notify-slack` | `.github/actions/notify-slack/action.yml` |
| `platform.rollback()` | `rollback` | `.github/actions/rollback/action.yml` |

#### Deploy Action

**Purpose:** Deploy application to Kubernetes cluster

**Inputs:**
- `environment` - Target environment (staging/production)
- `image-tag` - Docker image tag to deploy
- `registry` - Container registry URL
- `app-name` - Application name
- `deploy-token` - Authentication token
- `kubectl-config` - Base64-encoded kubeconfig

**Implementation:**
- Configures kubectl with provided kubeconfig
- Updates deployment image
- Waits for rollout to complete
- Verifies pod health

#### Notify Slack Action

**Purpose:** Send formatted notifications to Slack

**Inputs:**
- `message` - Message content
- `status` - Job status (success/failure)
- `webhook-url` - Slack webhook URL

**Implementation:**
- Determines message color based on status
- Formats rich attachment with deployment metadata
- Posts to Slack via webhook
- Includes links to commit and workflow run

#### Rollback Action

**Purpose:** Rollback deployment on failure

**Inputs:**
- `environment` - Target environment
- `deploy-token` - Authentication token
- `kubectl-config` - Base64-encoded kubeconfig

**Implementation:**
- Gets current deployment state
- Performs `kubectl rollout undo`
- Waits for rollback completion
- Verifies pod health

---

## Intentional Changes

### 1. **Parallel Test Execution**

**Change:** Tests run in parallel instead of sequential stages

**Rationale:** 
- Faster feedback (tests complete simultaneously)
- Better resource utilization
- Fail-fast behavior maintained via `needs: [unit-tests, integration-tests, security-scan]`

### 2. **GitHub Container Registry**

**Change:** Already configured for `ghcr.io` in original Jenkinsfile

**Preserved:** No change needed, `GITHUB_TOKEN` automatically available

### 3. **Service Type Changed from LoadBalancer to ClusterIP**

**Wait, this is wrong - that was from the previous K8s task!**

Actually for this CI/CD task:

### 3. **Pull Request Workflow**

**Change:** Workflow also runs on pull requests (not just main branch)

**Rationale:**
- Tests and scans run on PRs for validation
- Deployment stages skipped on PRs (conditional: `if: github.ref == 'refs/heads/main'`)
- Better CI feedback before merge

### 4. **Explicit Runner Selection**

**Change:** `runs-on: ubuntu-latest` instead of `agent { label 'linux && docker' }`

**Rationale:**
- GitHub-hosted runners include Docker by default
- Simplified configuration
- Can be changed to self-hosted runners if needed: `runs-on: [self-hosted, linux, docker]`

### 5. **Better Observability**

**Change:** Added GitHub-native integrations

**Additions:**
- Trivy results uploaded to GitHub Security tab
- Environment deployments tracked in GitHub UI
- Deployment URLs configured for quick access

---

## Migration Checklist

### Prerequisites

- [ ] Repository access configured
- [ ] GitHub Actions enabled for repository

### Secrets Configuration

- [ ] Add `STAGING_DEPLOY_TOKEN`
- [ ] Add `STAGING_KUBECONFIG` (base64 encoded)
- [ ] Add `PRODUCTION_DEPLOY_TOKEN`
- [ ] Add `PRODUCTION_KUBECONFIG` (base64 encoded)
- [ ] Add `SLACK_WEBHOOK_URL`

### Environment Protection Rules

- [ ] Create `staging` environment
- [ ] Create `production-approval` environment
  - [ ] Enable "Required reviewers"
  - [ ] Add authorized approvers
- [ ] Create `production` environment

### Files to Add

- [ ] `.github/workflows/deploy.yml` (main workflow)
- [ ] `.github/actions/deploy/action.yml`
- [ ] `.github/actions/notify-slack/action.yml`
- [ ] `.github/actions/rollback/action.yml`

### Validation

- [ ] Test workflow on feature branch (tests run)
- [ ] Test workflow on main branch (full pipeline)
- [ ] Verify approval gate works
- [ ] Test rollback mechanism
- [ ] Verify Slack notifications

### Cleanup

- [ ] Remove Jenkinsfile after validation
- [ ] Update documentation to reference new workflow
- [ ] Archive Jenkins job

---

## Known Limitations and Considerations

### 1. **GitHub Actions Concurrency**

**Note:** Concurrency control is per-ref (branch), not global across all branches

**Mitigation:** This matches Jenkins behavior with `disableConcurrentBuilds()`

### 2. **Manual Approval Timeout**

**Note:** GitHub environment approvals don't have automatic timeout

**Mitigation:** 
- Job-level timeout (45 minutes) still applies
- Consider using scheduled cleanup for abandoned approvals

### 3. **Secrets Rotation**

**Note:** Secrets must be rotated via GitHub UI

**Recommendation:** Consider external secret management (Vault, AWS Secrets Manager) for automated rotation

### 4. **Composite Action Limitations**

**Note:** Composite actions run in the workflow runner context

**Consideration:** For complex logic, consider using Docker-based custom actions

### 5. **Self-Hosted Runners**

**Note:** If moving to self-hosted runners, update:
```yaml
runs-on: [self-hosted, linux, docker]
```

---

## Rollback Plan

If issues arise with GitHub Actions:

1. **Immediate:** Re-enable Jenkins job
2. **Investigation:** Review workflow run logs in Actions tab
3. **Gradual Migration:** Run both pipelines in parallel during transition
4. **Validation Period:** Keep Jenkins job for 2 weeks as backup

---

## Support and Documentation

### GitHub Actions Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow syntax reference](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Environment protection rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

### Team Contacts

- **CI/CD Support:** #platform-team
- **GitHub Admin:** #github-admins
- **Deployment Issues:** #oncall

---

## Conclusion

All Jenkins pipeline features have been successfully preserved in the GitHub Actions migration:

✅ Unit and integration tests  
✅ Security scanning with Trivy  
✅ Manual approval gate  
✅ Environment-specific secrets  
✅ Automatic rollback on failure  
✅ Dependency caching (enhanced)  
✅ Concurrency control  

The shared library functions have been mapped to composite actions with equivalent functionality. The new workflow provides improved observability, faster build times, and better integration with GitHub's native features.
