# Jenkins → GitHub Actions migration

Do not push or deploy from this write-up. Wire GitHub Environments,
OIDC trust, and `DEPLOY_IMPLEMENTATION` before enabling the workflow.

## Preserved

| Jenkins | Actions |
| --- | --- |
| `npm ci` + `npm test` | `unit` job |
| `docker compose -f docker-compose.test.yml up --abort-on-container-exit` | `integration` job (same command) |
| `trivy fs --exit-code 1 --severity HIGH,CRITICAL .` | `scan` job via pinned `trivy-action`; **no** `continue-on-error` |
| `docker build` / `push` tagged with `GIT_COMMIT.take(12)` | `build` job; tag `${GITHUB_SHA:0:12}` |
| `APP` / `REGISTRY` | workflow `env` |
| `when { branch 'main' }` on deploy/approve | deploy jobs `if: push && refs/heads/main` |
| `input` before production | `environment: production` with **required reviewers** (UI) |
| Environment-specific secrets | GitHub Environment secrets on `staging` / `production` / `production-automation` |
| `platform.deploy` | composite `.github/actions/deploy` |
| `platform.notifySlack` | composite `.github/actions/notify-slack` (fails if webhook missing) |
| `platform.rollback('production')` on `post { failure }` when `IMAGE_TAG` set | `rollback` job when build succeeded and staging or production deploy failed |
| `disableConcurrentBuilds()` | `concurrency` group `…-deploy` on `main`, `cancel-in-progress: false` |
| 45 minute timeout | `timeout-minutes: 45` on each job (GHA has no single pipeline timeout) |
| `linux && docker` agent | `ubuntu-latest` (Docker available) |
| npm install cache (implicit on Jenkins agents) | `actions/setup-node` `cache: npm` keyed off **`package-lock.json`** |

## Shared library map

The Jenkinsfile used `@Library('platform')`. There is no equivalent
library load in Actions. Helpers are local composites:

| Helper | Composite | Notes |
| --- | --- | --- |
| `platform.deploy(env, tag)` | `.github/actions/deploy` | OIDC then `DEPLOY_IMPLEMENTATION`; Slack after success |
| `platform.notifySlack(msg)` | `.github/actions/notify-slack` | Needs `SLACK_WEBHOOK_URL` on the environment |
| `platform.rollback('production')` | `.github/actions/rollback` | Redeploys `github.event.before` (12-char), not a comment |
| Agent cloud credentials | `.github/actions/configure-aws-oidc` | `vars.AWS_DEPLOY_ROLE_ARN` + `vars.AWS_REGION` — no account IDs in git |

`DEPLOY_IMPLEMENTATION` is an environment secret holding the real
apply command (helm/kubectl/ECS). The deploy action **exits 1** if it
is unset so a no-op cannot look like a successful ship.

## Intentionally changed

1. **Build/push only on `main` pushes**, not on every branch. Jenkins
   built on all branches. Feature-branch images in GHCR and
   `packages: write` on non-main were dropped on purpose.
2. **PRs run unit/integration/scan only.** No registry login, no OIDC,
   no environment secrets. Avoids fork `pull_request` secret leakage.
   `pull_request_target` is not used. `actions/checkout` sets
   `persist-credentials: false`.
3. **Approval is a GitHub Environment**, not `workflow_dispatch` input
   and not `echo TODO`. Reviewers **must** be added under
   Settings → Environments → `production` → Required reviewers.
   YAML cannot attach the reviewer list; if that UI step is skipped,
   production deploys will not wait.
4. **Rollback is not gated by `production` reviewers.** A required
   reviewer on the same environment would block Jenkins-style automatic
   rollback. Job uses environment `production-automation` (no
   reviewers, same role/webhook/deploy secret, limited to `main`).
   IAM OIDC `sub` must allow that environment name (or a
   `job_workflow_ref` condition).
5. **OIDC instead of long-lived access keys** on Jenkins agents.
6. **Third-party actions pinned to commit SHAs** (tags are mutable).
7. **Cache key includes `package-lock.json`.** Starter `package.json`
   has no lockfile; `npm ci` and the cache path both **require** a
   lockfile in the real repo (same as Jenkins `npm ci`).
8. **No `latest` image tag.** Only the 12-character SHA.
9. **Staging/production secrets are per-environment**, not a single
   Jenkins `environment {}` block. Duplicate `SLACK_WEBHOOK_URL` and
   `DEPLOY_IMPLEMENTATION` onto each environment (or use org secrets).

## Repo settings to create (failure modes if skipped)

- Environment `staging` — optional wait timer; secrets above; vars
  `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION`.
- Environment `production` — **required reviewers**; same secret/var
  names with production values.
- Environment `production-automation` — **no** reviewers; production
  AWS role + webhook + `DEPLOY_IMPLEMENTATION`; deployment branch
  `main` only.
- OIDC provider trust for `repo:<org>/<repo>:environment:<name>`.
- `package-lock.json` committed.
- `docker-compose.test.yml` committed (referenced by Jenkins, not in
  this starter).

## Edge cases

- **`github.event.before` is all zeros** on the first push to `main`:
  rollback fails closed (no previous tag) instead of redeploying
  garbage.
- **Rollback previous tag is the previous commit on `main`**, not
  “last successful production deploy” if commits were skipped or a
  deploy was aborted after push. A stronger store is an environment
  variable updated only after a successful production apply.
- **Jenkins rolled back production even if staging failed** (any
  failure after `IMAGE_TAG`). Preserved: rollback runs if staging
  **or** production deploy fails after a successful build. A staging
  failure therefore still targets production rollback, which can no-op
  or revert prod if `DEPLOY_IMPLEMENTATION` is prod-scoped — same
  class of footgun as the Jenkinsfile.
- **Rejected production review** counts as `deploy-production`
  failure and triggers rollback.
- **Trivy HIGH/CRITICAL fails the pipeline** and skips build/deploy
  (no `IMAGE_TAG` → no rollback), matching Jenkins order (scan before
  build).
- **Integration compose vs GHA `services:`** — compose is what
  Jenkins ran. If `docker-compose.test.yml` expects a sidecar that
  GHA `services` would duplicate, do not add both.

## Least privilege

Workflow default `contents: read`. `packages: write` only on `build`.
`id-token: write` only on deploy/rollback. No `pull-requests: write`.
No inline passwords. No cloud account IDs in YAML.
