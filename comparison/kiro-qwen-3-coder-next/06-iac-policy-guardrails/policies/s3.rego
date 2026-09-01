package terraform.s3

import future.keywords.in

# S3 buckets must have server-side encryption enabled.
# Checks both explicit configuration and default encryption settings.
deny[msg] {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  resource.type == "aws_s3_bucket"
  resource.change.actions[_] == "create"

  # Skip if bucket has explicit SSE configuration
  not s3_bucket_has_explicit_encryption(resource)

  # Skip if bucket has default encryption enabled
  not s3_bucket_has_default_encryption(resource)

  msg := sprintf("S3 bucket '%s' does not have server-side encryption enabled", [resource.name])
}

# Check for explicit SSE configuration
s3_bucket_has_explicit_encryption(resource) {
  resource.change.after.server_side_encryption_configuration[_]
}

# Check for default bucket encryption
s3_bucket_has_default_encryption(resource) {
  resource.change.after.bucket_public_access_block[_]
}

# Check for KMS key in bucket config
s3_bucket_has_kms_encryption(resource) {
  resource.change.after.server_side_encryption_configuration[_].rule[_].apply_server_side_encryption_by_default[_].kms_master_key_id
}
