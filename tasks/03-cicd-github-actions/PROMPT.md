Migrate the provided Jenkinsfile to a GitHub Actions workflow that
preserves:

- Unit and integration test stages
- Security scanning (Trivy or equivalent)
- A manual approval gate before production deploy
- Environment-specific secrets handling
- Rollback on failure
- Caching of dependencies
- Concurrency control so two deploys cannot race

The original pipeline uses a shared library (`@Library('platform')`)
and an `input` approval step. Your workflow must not silently drop
those semantics. Map the shared library helpers to Actions
equivalents or document a composite action you would create.

Deliver:

1. `.github/workflows/deploy.yml`
2. `MIGRATION.md` listing what was preserved vs intentionally changed
3. Any helper composite action stubs you need

Do not push or deploy.
