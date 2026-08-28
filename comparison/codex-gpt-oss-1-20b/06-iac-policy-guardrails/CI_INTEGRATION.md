# CI integration and exceptions

Run policy tests on every policy change, then run Conftest after `terraform
plan` and before any approval or apply step:

```sh
opa test policies -v
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
conftest test --policy policies tfplan.json
terraform apply tfplan.binary # only after Conftest succeeds and normal approval
```

`conftest test` exits non-zero for `deny` results, so the CI job must not use
`continue-on-error`. It receives plan JSON, not HCL, and evaluates every
managed `resource_changes` entry including resources expanded by `count`,
`for_each`, or a module address. Deletes and no-ops are deliberately skipped.

Example GitHub Actions job step:

```yaml
- name: Terraform plan
  run: |
    terraform plan -out=tfplan.binary
    terraform show -json tfplan.binary > tfplan.json
- name: Enforce Terraform policy
  run: conftest test --policy policies tfplan.json
```

Use a versioned, reviewed policy-exception mechanism outside Rego (for example,
an approved temporary exception record matched to resource address, policy ID,
expiry, and ticket). CI should validate expiry and record its use. Do not add
blanket `not exempt` conditions backed by arbitrary plan tags: callers could
self-exempt an unsafe change. Security-group public administration and missing
S3 encryption should require a time-bounded, separately approved exception.
