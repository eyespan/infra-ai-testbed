package terraform.tags

test_resource_without_tags_should_fail {
  not deny with input as data.test_input_no_tags
}

test_resource_with_all_tags_should_pass {
  not deny with input as data.test_input_all_tags
}

test_resource_with_missing_tags_should_fail {
  not deny with input as data.test_input_missing_tags
}

test_s3_bucket_should_pass_with_tags {
  not deny with input as data.test_input_s3_bucket
}

data.test_input_no_tags := {
  "resource_changes": [{
    "address": "aws_instance.web",
    "mode": "managed",
    "type": "aws_instance",
    "name": "web",
    "change": {
      "actions": ["create"],
      "after": {
        "instance_type": "t3.micro",
        "ami": "ami-12345678"
      }
    }
  }]
}

data.test_input_all_tags := {
  "resource_changes": [{
    "address": "aws_instance.web",
    "mode": "managed",
    "type": "aws_instance",
    "name": "web",
    "change": {
      "actions": ["create"],
      "after": {
        "instance_type": "t3.micro",
        "ami": "ami-12345678",
        "tags": {
          "Environment": "prod",
          "Owner": "team",
          "CostCenter": "123"
        }
      }
    }
  }]
}

data.test_input_missing_tags := {
  "resource_changes": [{
    "address": "aws_instance.web",
    "mode": "managed",
    "type": "aws_instance",
    "name": "web",
    "change": {
      "actions": ["create"],
      "after": {
        "instance_type": "t3.micro",
        "ami": "ami-12345678",
        "tags": {
          "Environment": "prod",
          "Owner": "team"
          # Missing CostCenter
        }
      }
    }
  }]
}

data.test_input_s3_bucket := {
  "resource_changes": [{
    "address": "aws_s3_bucket.logs",
    "mode": "managed",
    "type": "aws_s3_bucket",
    "name": "logs",
    "change": {
      "actions": ["create"],
      "after": {
        "bucket": "my-logs-bucket",
        "tags": {
          "Environment": "prod",
          "Owner": "team",
          "CostCenter": "123"
        },
        "server_side_encryption_configuration": [{
          "rule": [{
            "apply_server_side_encryption_by_default": [{
              "sse_algorithm": "AES256"
            }]
          }]
        }]
      }
    }
  }]
}
