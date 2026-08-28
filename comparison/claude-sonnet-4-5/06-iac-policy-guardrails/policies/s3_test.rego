package terraform.s3

import rego.v1

# Test: S3 bucket without encryption should be denied
test_s3_without_encryption_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket",
                        "tags": {}
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "must have server-side encryption")
}

# Test: S3 bucket with encryption should pass
test_s3_with_encryption_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket",
                        "tags": {}
                    }
                }
            },
            {
                "address": "aws_s3_bucket_server_side_encryption_configuration.test",
                "type": "aws_s3_bucket_server_side_encryption_configuration",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "aws_s3_bucket.test.id",
                        "rule": [
                            {
                                "apply_server_side_encryption_by_default": {
                                    "sse_algorithm": "AES256"
                                }
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: S3 bucket with inline encryption should pass (older Terraform versions)
test_s3_with_inline_encryption_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket",
                        "server_side_encryption_configuration": [
                            {
                                "rule": [
                                    {
                                        "apply_server_side_encryption_by_default": {
                                            "sse_algorithm": "AES256"
                                        }
                                    }
                                ]
                            }
                        ],
                        "tags": {}
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: Only create/update actions are checked
test_s3_delete_not_checked if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["delete"],
                    "after": null
                }
            }
        ]
    }

    count(deny) == 0
}
