package terraform.s3

import rego.v1

# Deny S3 buckets without server-side encryption

deny contains msg if {
    # Get all S3 bucket resources being created or updated
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    action_creates_or_updates(resource.change.actions)

    # Check if encryption is missing or disabled
    not has_encryption(resource)

    msg := sprintf(
        "S3 bucket '%s' must have server-side encryption enabled. Add aws_s3_bucket_server_side_encryption_configuration resource.",
        [resource.address]
    )
}

# Helper: Check if action creates or updates resource
action_creates_or_updates(actions) if {
    "create" in actions
}

action_creates_or_updates(actions) if {
    "update" in actions
}

# Helper: Check if bucket has encryption
# Note: In Terraform AWS provider v4+, encryption is a separate resource
has_encryption(bucket_resource) if {
    # Look for corresponding encryption configuration
    encryption := input.resource_changes[_]
    encryption.type == "aws_s3_bucket_server_side_encryption_configuration"

    # Extract bucket name from encryption resource
    # Format: aws_s3_bucket_server_side_encryption_configuration.bucket_name
    bucket_ref := encryption.change.after.bucket

    # Check if it references our bucket
    # This can be a reference like aws_s3_bucket.logs.id or direct bucket name
    contains(bucket_ref, bucket_resource.name)
}

# Alternative: Check if encryption is inline (older Terraform versions)
has_encryption(bucket_resource) if {
    bucket_resource.change.after.server_side_encryption_configuration
}
