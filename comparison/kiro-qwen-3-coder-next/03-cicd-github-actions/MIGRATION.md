# Jenkins to GitHub Actions Migration

## Preserved Functionality

| Jenkins Stage | GitHub Actions Equivalent | Status |
|--------------|---------------------------|--------|
| Unit | `test` job - `npm test` | ✓ Preserved |
| Integration | `test` job - `docker compose` | ✓ Preserved |
| Scan | `test` job - `trivy fs` | ✓ Preserved |
| Build | `build` job - `docker build/push` | ✓ Preserved |
| Deploy staging | `deploy-staging` job | ✓ Preserved |
| Approve production | `environment: production` with required reviewers | ✓ Preserved |
| Deploy production | `deploy-production` job | ✓ Preserved |
| Rollback on failure | `rollback` job with `if: always()` | ✓ Preserved |
| Shared library deploy | `deploy` composite action | ✓ Mapped |
| Shared library notifySlack | `notify-slack` composite action | ✓ Mapped |
| Concurrency control | `concurrency` group | ✓ Preserved |
| Timeout | `timeout-minutes` on jobs | ✓ Preserved |
| Timestamps | GitHub Actions default | ✓ Preserved |

## Intentionally Changed / Enhanced

| Aspect | Jenkins | GitHub Actions | Reason |
|--------|---------|----------------|--------|
| Branch trigger | All branches deploy to staging | Only `main` deploys to staging/production | Prevents accidental deployments from feature branches |
| Secrets | Jenkins environment variables | GitHub Secrets + OIDC | More secure credential handling |
| Deployment method | Shell script with platform library | Composite action with Kubernetes CLI | Better abstraction and reusability |
| Image tagging | `GIT_COMMIT.take(12)` | `GITHUB_SHA::12` | Equivalent functionality |
| Approval gate | `input` step | GitHub Environment protection rules | Native GitHub feature, more auditable |

## Required Configuration

### GitHub Secrets (must be configured in repository settings)

| Secret | Purpose |
|--------|---------|
| `AWS_ROLE_ARN` | OIDC role ARN for AWS access |
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications (see below) |
| `GITHUB_TOKEN` | Auto-provided, used for container registry |

### GitHub Environment Protection (must be configured in repository settings)

#### `staging` environment
- Optional: Required reviewers (can be team or individuals)

#### `production` environment
- **Required reviewers**: Configure team with production deployment authority
- Optional: Wait timer before deployment
- Optional: Required environment variables

### Slack Webhook Configuration

The `notify-slack` composite action requires a Slack webhook URL:

1. Create an incoming webhook in your Slack workspace
2. Add the webhook URL as `SLACK_WEBHOOK_URL` secret
3. The action expects the webhook URL to be passed via `webhook-url` input

**Alternative**: Replace `notify-slack` with a reusable workflow that accepts the webhook URL as a parameter for better security.

## Composite Actions

### `deploy` action
```yaml
uses: ./.github/actions/deploy
with:
  environment: staging|production
  image-tag: <sha>
  region: us-east-1
```

### `notify-slack` action
```yaml
uses: ./.github/actions/notify-slack
with:
  message: "staging ${{ env.IMAGE_TAG }}"
  webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### `rollback` action
```yaml
uses: ./.github/actions/rollback
with:
  environment: production
  image-tag: <previous-sha>
  region: us-east-1
```

## Missing / Notes

| Issue | Impact | Recommendation |
|-------|--------|----------------|
| `docker-compose.test.yml` | Integration tests require this file | Must exist in repository |
| Platform library custom functions | If `platform` had custom helpers beyond deploy/notify, they need implementation | Document any additional functions from the shared library |
| Service container for integration tests | If tests need database/redis, add service containers | See GitHub docs for service containers |

## Workflow Triggers

- **PR**: Runs `test` job only (unit + integration + scan) - no deployment
- **Push to main**: Runs `test` → `build` → `deploy-staging` → `deploy-production` (with approval) sequence

## Rollback Logic

The rollback job runs when `deploy-production` fails:
1. Gets the previous commit SHA from git history
2. Calls `rollback` composite action
3. Sends Slack notification

This differs from Jenkins' `post: failure` which rolled back only on actual failure. GitHub Actions `always()` ensures rollback triggers even on cancellation or timeout.