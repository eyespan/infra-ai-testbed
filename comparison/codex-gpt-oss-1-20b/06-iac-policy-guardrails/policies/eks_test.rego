package terraform.eks

import rego.v1

test_missing_logs_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_eks_cluster.x", "mode": "managed", "type": "aws_eks_cluster", "change": {"actions": ["create"], "after": {"enabled_cluster_log_types": ["api"]}, "after_unknown": {}}}]}
  count(denials) == 1
}

test_required_logs_allowed if {
  denials := deny with input as {"resource_changes": [{"address": "aws_eks_cluster.x", "mode": "managed", "type": "aws_eks_cluster", "change": {"actions": ["update"], "after": {"enabled_cluster_log_types": ["api", "audit", "authenticator"]}, "after_unknown": {}}}]}
  count(denials) == 0
}

test_unknown_logs_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_eks_cluster.x", "mode": "managed", "type": "aws_eks_cluster", "change": {"actions": ["create"], "after": {}, "after_unknown": {"enabled_cluster_log_types": true}}}]}
  count(denials) == 2
}
