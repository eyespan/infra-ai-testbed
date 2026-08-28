package terraform.tags

import rego.v1

# Test: S3 bucket without required tags should be denied
test_s3_missing_tags_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket",
                        "tags": {
                            "Environment": "dev"
                        }
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "missing required tags")
    contains(msg, "Owner")
    contains(msg, "CostCenter")
}

# Test: Resource with all required tags should pass
test_resource_all_tags_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket",
                        "tags": {
                            "Environment": "production",
                            "Owner": "platform",
                            "CostCenter": "eng"
                        }
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: Resource with extra tags should pass
test_resource_extra_tags_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.test",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket",
                        "tags": {
                            "Environment": "production",
                            "Owner": "platform",
                            "CostCenter": "eng",
                            "Application": "api",
                            "Terraform": "true"
                        }
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: Non-taggable resources should not be checked
test_non_taggable_resource_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group_rule.test",
                "type": "aws_security_group_rule",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "type": "ingress"
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: Resource without tags field should be denied
test_resource_no_tags_field_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-cluster"
                    }
                }
            }
        ]
    }

    count(deny) > 0
}

# Test: Resource with null tags should be denied
test_resource_null_tags_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-sg",
                        "tags": null
                    }
                }
            }
        ]
    }

    count(deny) > 0
}

# Test: Resource with empty tags should be denied
test_resource_empty_tags_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_instance.test",
                "type": "aws_instance",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "instance_type": "t3.micro",
                        "tags": {}
                    }
                }
            }
        ]
    }

    count(deny) > 0
}

# Test: Multiple resources, some compliant
test_multiple_resources_mixed if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.compliant",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "compliant-bucket",
                        "tags": {
                            "Environment": "prod",
                            "Owner": "team",
                            "CostCenter": "eng"
                        }
                    }
                }
            },
            {
                "address": "aws_s3_bucket.non_compliant",
                "type": "aws_s3_bucket",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "non-compliant-bucket",
                        "tags": {
                            "Environment": "prod"
                        }
                    }
                }
            }
        ]
    }

    # Should have exactly 1 denial (for non_compliant bucket)
    count(deny) == 1
    some msg in deny
    contains(msg, "non_compliant")
}

# Test: Encryption configuration resource should not be checked (non-taggable)
test_encryption_config_not_checked if {
    input := {
        "resource_changes": [
            {
                "address": "aws_s3_bucket_server_side_encryption_configuration.test",
                "type": "aws_s3_bucket_server_side_encryption_configuration",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "test-bucket"
                    }
                }
            }
        ]
    }

    count(deny) == 0
}
