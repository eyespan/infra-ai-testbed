Write OPA/Rego policies that enforce the following on Terraform
plans (input is Terraform plan JSON, as in
`starter/fixtures/plan.json`):

1. No S3 buckets without server-side encryption
2. No security groups that allow 0.0.0.0/0 on port 22 or 3389
3. All EKS clusters must have control-plane logging enabled
   (at least api, audit, authenticator)
4. Mandatory tags on tagged resources: Environment, Owner, CostCenter

Also:

- Provide `conftest`/`opa test` unit tests that fail the fixture
  plan and pass a corrected fixture you write
- Document how these policies run in CI before apply
- Document false-positive risks (for example resources that do not
  support tags)

Starter files in `starter/policies/` are stubs. Replace them.

Do not apply infrastructure.
