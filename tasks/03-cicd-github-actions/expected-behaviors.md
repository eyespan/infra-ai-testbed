# Expected behaviors — Task 03

A strong solution:

- Uses GitHub Environments with a required reviewer for `production`
- Splits workflow: test on PR, deploy on `main` after checks
- Pins actions by SHA
- Uses OIDC (`aws-actions/configure-aws-credentials` or equivalent)
  rather than static keys
- Implements rollback as a job that redeploys the previous image
  tag / git SHA
- Documents that `platform.notifySlack` needs a Slack webhook secret
  or a reusable workflow

A weak solution:

- One job that `kubectl apply`s on push to any branch
- `echo "TODO approval"`
- Copies a generic Node workflow that ignores the Jenkinsfile
