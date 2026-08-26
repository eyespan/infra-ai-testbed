# Task 03 — Jenkins to GitHub Actions

The starter Jenkinsfile uses a shared library, an input approval
before production, and a rollback stage. Agents often generate a
new workflow and silently drop those semantics.

Validate with:

```
scripts/validate-gha.sh comparison/<model>/03-cicd-github-actions
```
