package terraform.tags

import rego.v1

test_missing_tags_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_s3_bucket.x", "mode": "managed", "type": "aws_s3_bucket", "change": {"actions": ["create"], "after": {"tags": {"Environment": "dev"}}, "after_unknown": {}}}]}
  count(denials) == 1
}

test_complete_tags_allowed if {
  denials := deny with input as {"resource_changes": [{"address": "aws_s3_bucket.x", "mode": "managed", "type": "aws_s3_bucket", "change": {"actions": ["create"], "after": {"tags": {"Environment": "dev", "Owner": "platform", "CostCenter": "eng"}}, "after_unknown": {}}}]}
  count(denials) == 0
}

test_data_and_non_taggable_resources_skipped if {
  denials := deny with input as {"resource_changes": [{"address": "data.aws_ami.x", "mode": "data", "type": "aws_ami", "change": {"actions": ["read"], "after": {}, "after_unknown": {}}}, {"address": "aws_iam_policy.x", "mode": "managed", "type": "aws_iam_policy", "change": {"actions": ["create"], "after": {}, "after_unknown": {}}}]}
  count(denials) == 0
}

test_unknown_tags_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_eks_cluster.x", "mode": "managed", "type": "aws_eks_cluster", "change": {"actions": ["create"], "after": {}, "after_unknown": {"tags": true}}}]}
  count(denials) == 2
}
