# Jenkins to GitHub Actions migration

## Preserved behavior

| Jenkins behavior | GitHub Actions mapping |
| --- | --- |
| `Unit` | `unit`: `npm ci` then `npm test` |
| `Integration` | `integration`: retains `docker compose -f docker-compose.test.yml up --abort-on-container-exit`; a Postgres service container is available for tests that use runner services |
| `Scan` | `scan`: Trivy filesystem scan fails on HIGH/CRITICAL findings (`--exit-code 1`) |
| Build/push with a 12-character commit tag | `build`: pushes only `ghcr.io/example/payments-api:<12-char-sha>` after all checks pass |
| Staging deploy on main | protected `staging` environment job, only on push to `main` |
| Jenkins `input` before production | the `production` GitHub Environment pauses the production job for configured required reviewers |
| `disableConcurrentBuilds()` | workflow concurrency group; in-progress runs are not cancelled |
| `post { failure { rollback } }` | `rollback-production` is an executable, protected job that runs `kubectl rollout undo` and waits for recovery after a production deployment fails |
| `platform.deploy` | local `deploy` composite action |
| `platform.rollback` | local `rollback` composite action |
| `platform.notifySlack` | local `notify-slack` composite action using an environment-scoped webhook secret |

## Intentional security and reliability changes

- Pull requests run checks only. No build, deployment, environment secret, OIDC
  token, or package-write permission is granted to PR jobs, including forks.
- Each checkout disables persisted credentials. Action dependencies that are
  used are pinned to commit SHAs.
- Dependency caching keys include `hashFiles('package-lock.json')`; this assumes
  the application repository supplies its npm lockfile, as required by `npm ci`.
- Deployments use a 15-minute AWS OIDC session rather than long-lived cloud or
  kubeconfig secrets. Environment variables, not committed values, supply
  `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION`, and `KUBERNETES_CLUSTER_NAME`.
- Each job has a timeout. The production rollback is intentionally limited to a
  failed production deployment, rather than rolling back production because an
  earlier test or staging step failed.
- The Trivy container uses an explicit release tag. The platform image allowlist
  should replace it with a verified digest before enabling the workflow.

## Required repository configuration

1. Create `staging` and `production` GitHub Environments. Configure required
   reviewers on **production**; the YAML cannot create reviewer rules itself.
2. Set the three environment variables named above for each environment. The
   AWS role trust policy must constrain GitHub OIDC to this repository and the
   intended environment, and the role must have only the EKS/Kubernetes access
   required to update this deployment.
3. Add `SLACK_WEBHOOK_URL` as an environment secret if notifications are
   required. This is the explicit replacement for `platform.notifySlack`; omit
   the notification steps only if the incident-notification owner approves it.
4. Verify that the deployment/container name is `payments-api` and namespace
   names are `staging` and `production`; they are assumptions carried from the
   Jenkins helper's undocumented behavior.
5. Test the protected approval and rollback sequence in staging or a dedicated
   non-production environment before retiring Jenkins. No workflow was pushed
   or run as part of this migration.
