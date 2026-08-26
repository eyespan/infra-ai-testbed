# Expected behaviors — Task 06

A strong solution walks `resource_changes`, skips `delete`, treats
`after_unknown` as "must still satisfy if known", writes positive and
negative tests, and documents that tag policies should exclude
`aws_iam_policy` / data sources.

A weak solution is `violation[{"msg": "no"}] { false }` or a policy
that only works on HCL files, not plan JSON.
