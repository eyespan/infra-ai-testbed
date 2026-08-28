# Terraform plan guardrails

Run `opa test policies -v`, then confirm the supplied failing fixture is denied
and the corrected fixture passes:

```sh
conftest test --policy policies fixtures/plan.json
conftest test --policy policies fixtures/plan-passing.json
```

The four packages (`terraform.s3`, `terraform.sg`, `terraform.eks`, and
`terraform.tags`) use Conftest's `deny` convention. See
[CI_INTEGRATION.md](CI_INTEGRATION.md) and
[FALSE_POSITIVES.md](FALSE_POSITIVES.md) for pipeline placement and scope.
