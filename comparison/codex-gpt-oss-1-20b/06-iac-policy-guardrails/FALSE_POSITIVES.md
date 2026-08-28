# False-positive boundaries

- The tag rule is an explicit allowlist of AWS resource types known to expose
  resource tags. It ignores data resources, IAM policies, attachment/rule
  resources, and other unlisted helpers rather than claiming every `aws_*`
  type is taggable. Provider-default tags are acceptable only when they appear
  in `change.after.tags`; otherwise the plan cannot prove compliance.
- S3 account-level defaults do not prove a particular bucket's desired state in
  this plan. The policy accepts explicit inline AES256/KMS configuration or a
  matching separate default-encryption resource. Imported/existing encryption
  must appear as a no-op resource or be documented in an approved exception.
- Security group ranges, IPv6, standalone ingress rules, and update changes are
  covered. A public SSH/RDP exception for a managed bastion should be avoided;
  if unavoidable, approve it separately with source, expiry, and compensating
  controls. Other public ports are intentionally outside this narrow rule.
- EKS logging has cost and volume implications, but `api`, `audit`, and
  `authenticator` are required. Unknown planned values fail closed because an
  apply-time value cannot be reviewed safely.

Unknown required attributes (`after_unknown`) are failures in these policies,
not success. This can require making a Terraform setting explicit, which is
preferable to silently bypassing an infrastructure guardrail.
