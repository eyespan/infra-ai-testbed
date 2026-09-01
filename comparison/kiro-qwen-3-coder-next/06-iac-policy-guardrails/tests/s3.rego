package terraform.s3

test_s3_bucket_without_encryption_should_fail {
  not deny with input as data.test_input_s3_unencrypted
}

test_s3_bucket_with_encryption_should_pass {
  not deny with input as data.test_input_s3_encrypted
}

test_s3_bucket_with_kms_encryption_should_pass {
  not deny with input as data.test_input_s3_kms
}

data.test_input_s3_unencrypted := {
  "resource_changes": [{
    "address": "aws_s3_bucket.test",
    "mode": "managed",
    "type": "aws_s3_bucket",
    "name": "test",
    "change": {
      "actions": ["create"],
      "after": {
        "bucket": "my-unencrypted-bucket",
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      },
      "after_unknown": {}
    }
  }]
}

data.test_input_s3_encrypted := {
  "resource_changes": [{
    "address": "aws_s3_bucket.test",
    "mode": "managed",
    "type": "aws_s3_bucket",
    "name": "test",
    "change": {
      "actions": ["create"],
      "after": {
        "bucket": "my-encrypted-bucket",
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"},
        "server_side_encryption_configuration": [{
          "rule": [{
            "apply_server_side_encryption_by_default": [{
              "sse_algorithm": "AES256"
            }]
          }]
        }]
      },
      "after_unknown": {}
    }
  }]
}

data.test_input_s3_kms := {
  "resource_changes": [{
    "address": "aws_s3_bucket.test",
    "mode": "managed",
    "type": "aws_s3_bucket",
    "name": "test",
    "change": {
      "actions": ["create"],
      "after": {
        "bucket": "my-kms-bucket",
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"},
        "server_side_encryption_configuration": [{
          "rule": [{
            "apply_server_side_encryption_by_default": [{
              "sse_algorithm": "aws:kms",
              "kms_master_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
            }]
          }]
        }]
      },
      "after_unknown": {}
    }
  }]
}
