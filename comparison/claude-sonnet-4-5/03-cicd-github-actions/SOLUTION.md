# CI/CD Migration: Jenkins to GitHub Actions

## Overview

Complete migration of Jenkins pipeline to GitHub Actions, preserving all functionality and semantics from the original Jenkinsfile including shared library functions.

## Deliverables

### 1. Main Workflow
**`.github/workflows/deploy.yml`**

Complete GitHub Actions workflow with:
- Parallel test execution (unit, integration, security)
- Docker build and push with layer caching
- Staging deployment
- Manual approval gate for production
- Production deployment
- Automatic rollback on failure
- Slack notifications
- Concurrency control

### 2. Composite Actions (Shared Library Equivalents)

**`.github/actions/deploy/action.yml`**
- Maps to `platform.deploy(environment, imageTag)`
- Deploys application to Kubernetes
- Configures kubectl, updates deployment, verifies rollout

**`.github/actions/notify-slack/action.yml`**
- Maps to `platform.notifySlack(message)`
- Sends rich Slack notifications with deployment metadata
- Color-coded by status (success/failure)

**`.github/actions/rollback/action.yml`**
- Maps to `platform.rollback(environment)`
- Performs kubectl rollout undo on failure
- Verifies rollback completion

### 3. Migration Documentation
**`MIGRATION.md`**

Comprehensive documentation covering:
- Feature-by-feature mapping from Jenkins to GitHub Actions
- Shared library to composite action mapping
- All preserved functionality
- Intentional changes and improvements
- Configuration checklist
- Secrets setup guide
- Rollback plan

## Key Features Preserved

✅ **Unit and integration test stages** - Run in parallel for faster feedback  
✅ **Security scanning** - Trivy with GitHub Security integration  
✅ **Manual approval gate** - GitHub Environment protection rules  
✅ **Environment-specific secrets** - Separate secrets per environment  
✅ **Rollback on failure** - Automatic kubectl rollout undo  
✅ **Caching of dependencies** - npm and Docker layer caching  
✅ **Concurrency control** - Prevents deployment races  

## Configuration Required

### 1. GitHub Secrets

Add these secrets in Repository Settings → Secrets and variables → Actions:

```
STAGING_DEPLOY_TOKEN       # Staging deployment auth token
STAGING_KUBECONFIG         # Staging kubectl config (base64)
PRODUCTION_DEPLOY_TOKEN    # Production deployment auth token
PRODUCTION_KUBECONFIG      # Production kubectl config (base64)
SLACK_WEBHOOK_URL          # Slack incoming webhook
```

### 2. GitHub Environments

Create environments with protection rules:

**`staging`**
- No protection rules needed
- URL: https://staging.example.com

**`production-approval`**
- Enable "Required reviewers"
- Add authorized approvers (e.g., tech leads, release managers)

**`production`**
- URL: https://production.example.com
- Can add additional protection rules (wait timer, etc.)

### 3. Base64 Encode Kubeconfig

```bash
# Encode kubeconfig for GitHub secrets
cat ~/.kube/staging-config | base64 | pbcopy
cat ~/.kube/production-config | base64 | pbcopy
```

## Workflow Behavior

### On Pull Requests
- ✅ Unit tests run
- ✅ Integration tests run
- ✅ Security scan runs
- ❌ Build skipped
- ❌ Deployments skipped

### On Push to Main
1. ✅ Unit tests (parallel)
2. ✅ Integration tests (parallel)
3. ✅ Security scan (parallel)
4. ✅ Build Docker image and push to GHCR
5. ✅ Deploy to staging + Slack notification
6. ⏸️ **Wait for manual approval**
7. ✅ Deploy to production + Slack notification
8. 🔄 Automatic rollback if deployment fails

## Usage

### Normal Deployment Flow

1. Merge PR to main branch
2. Workflow automatically starts
3. Tests and security scan run
4. Image built and pushed
5. Staging deployed automatically
6. Approval notification sent
7. Navigate to Actions tab → Pending approval
8. Click "Review deployments" → Approve
9. Production deployment proceeds

### Monitoring

- **Workflow runs:** Repository → Actions tab
- **Deployment history:** Repository → Environments
- **Security alerts:** Repository → Security → Code scanning

### Manual Workflow Trigger

Workflows can also be triggered manually:
1. Actions tab → Build and Deploy workflow
2. Click "Run workflow"
3. Select branch

## Differences from Jenkins

### Improvements
- ⚡ Parallel test execution (faster feedback)
- 📦 Docker layer caching (faster builds)
- 🔒 Security results in GitHub Security tab
- 📊 Better deployment visibility (Environment tracking)
- 🔗 Deployment URLs for quick access

### Semantic Equivalents
- `@Library('platform')` → Composite actions in `.github/actions/`
- `input` step → GitHub Environment protection rules
- `disableConcurrentBuilds()` → Workflow-level concurrency control
- `post { failure }` → Step-level `if: failure()` conditions

## Testing

### Validate on Feature Branch

```bash
git checkout -b test-actions
git add .github/
git commit -m "Add GitHub Actions workflow"
git push origin test-actions
```

Verify tests run (deployment stages skipped on non-main branches)

### Validate on Main Branch

```bash
git checkout main
git merge test-actions
git push origin main
```

Verify full pipeline including deployment and approval

### Test Rollback

Temporarily break the deployment to trigger rollback:
1. Deploy invalid image tag
2. Watch workflow automatically rollback
3. Verify previous version restored

## Troubleshooting

### Approval Not Showing

**Issue:** "Review deployments" button not visible

**Solution:** 
1. Check environment configuration (Settings → Environments)
2. Verify you're added as a required reviewer
3. Ensure user has appropriate repository permissions

### Deployment Fails

**Issue:** Deployment step fails with kubectl errors

**Solution:**
1. Verify KUBECONFIG secret is base64 encoded
2. Test kubectl connectivity manually
3. Check namespace exists in target cluster
4. Verify service account permissions

### Slack Notifications Not Sent

**Issue:** No Slack messages received

**Solution:**
1. Verify SLACK_WEBHOOK_URL secret is set
2. Test webhook URL manually with curl
3. Check Slack app permissions
4. Review workflow logs for error messages

## Rollback to Jenkins

If migration needs to be reverted:

1. Re-enable Jenkins job
2. Update branch protection rules
3. Disable GitHub Actions workflow:
   ```yaml
   on: []  # Disables all triggers
   ```

## Next Steps

1. ✅ Add GitHub secrets
2. ✅ Configure environments
3. ✅ Test on feature branch
4. ✅ Test full deployment to staging
5. ✅ Validate approval process
6. ✅ Test rollback mechanism
7. ✅ Monitor for 2 weeks
8. ✅ Decommission Jenkins job

## Support

- **CI/CD Issues:** #platform-team on Slack
- **GitHub Actions:** https://docs.github.com/en/actions
- **This Migration:** See `MIGRATION.md` for detailed documentation
