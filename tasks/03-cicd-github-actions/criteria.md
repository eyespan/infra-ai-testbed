# Review criteria — Task 03

## Mechanical

- [ ] Workflow YAML is valid
- [ ] `environment:` (or equivalent) used for production protection
- [ ] Secrets referenced via GitHub secrets, not inline

## Bugs / misses

- No approval gate (the most common fail)
- `pull_request` from forks leaking secrets
- `actions/checkout` with persist-credentials and a write token
- Cache key does not include lockfile hash
- Deploy job runs on every branch
- Rollback is a comment, not a job
- `latest` action tags without SHA pin
- Missing `concurrency` group

## Edge cases

- Shared library `notifySlack` has no Actions equivalent
- Integration tests need a service container
- Production environment reviewers not configured in the repo
  (must be documented)
- Failed Trivy should fail the pipeline, not `continue-on-error: true`

## Reliability

- Timeout on jobs
- `if: failure()` rollback vs `on: failure` workflow
- OIDC to cloud vs long-lived access keys
