package terraform.s3

import rego.v1

test_unencrypted_bucket_denied if {
  denials := deny with input as {"resource_changes": [{"address": "module.x.aws_s3_bucket.this[0]", "mode": "managed", "type": "aws_s3_bucket", "name": "this", "change": {"actions": ["create"], "after": {"bucket": "x"}, "after_unknown": {}}}]}
  count(denials) == 1
}

test_kms_default_encryption_allowed if {
  denials := deny with input as {"resource_changes": [{"address": "aws_s3_bucket.x", "mode": "managed", "type": "aws_s3_bucket", "name": "x", "change": {"actions": ["create"], "after": {"server_side_encryption_configuration": [{"rule": [{"apply_server_side_encryption_by_default": {"sse_algorithm": "aws:kms"}}]}]}, "after_unknown": {}}}]}
  count(denials) == 0
}

test_unknown_encryption_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_s3_bucket.x", "mode": "managed", "type": "aws_s3_bucket", "name": "x", "change": {"actions": ["update"], "after": {}, "after_unknown": {"server_side_encryption_configuration": true}}}]}
  count(denials) == 1
}

test_delete_skipped if {
  denials := deny with input as {"resource_changes": [{"address": "aws_s3_bucket.x", "mode": "managed", "type": "aws_s3_bucket", "name": "x", "change": {"actions": ["delete"], "after": null, "after_unknown": {}}}]}
  count(denials) == 0
}
