# Review criteria — Task 06

## Mechanical

- [ ] Policies actually deny the provided `plan.json`
- [ ] Tests exist (not just comments)
- [ ] Package names match how CI would call `conftest test`

## Bugs / misses

- Checks `resource_changes[].change.after` but not `after_unknown`
- Misses IPv6 `::/0` on SSH
- Requires tags on resources that cannot be tagged
- EKS logging check looks at a string instead of the
  `enabled_cluster_log_types` list
- S3 encryption only looks at `server_side_encryption_configuration`
  and misses default bucket encryption / KMS
- Policy uses `data` resources as if they were managed

## Edge cases

- `create` vs `update` vs `no-op` vs `delete` (deletes should not
  fail encryption checks)
- Count / for_each expansion
- Module-wrapped resources (`module.foo.aws_s3_bucket.this`)
- Missing attributes because they are computed at apply

## CI integration

- Fail the pipeline on deny
- Where it runs relative to `terraform plan`
- How exceptions are granted (if at all)
