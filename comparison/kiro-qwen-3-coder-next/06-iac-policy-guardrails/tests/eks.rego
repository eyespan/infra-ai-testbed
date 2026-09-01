package terraform.eks

test_eks_without_logging_should_fail {
  not deny with input as data.test_input_eks_no_logging
}

test_eks_with_partial_logging_should_fail {
  not deny with input as data.test_input_eks_partial_logging
}

test_eks_with_complete_logging_should_pass {
  not deny with input as data.test_input_eks_complete_logging
}

data.test_input_eks_no_logging := {
  "resource_changes": [{
    "address": "aws_eks_cluster.main",
    "mode": "managed",
    "type": "aws_eks_cluster",
    "name": "main",
    "change": {
      "actions": ["create"],
      "after": {
        "name": "main",
        "enabled_cluster_log_types": [],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}

data.test_input_eks_partial_logging := {
  "resource_changes": [{
    "address": "aws_eks_cluster.main",
    "mode": "managed",
    "type": "aws_eks_cluster",
    "name": "main",
    "change": {
      "actions": ["create"],
      "after": {
        "name": "main",
        "enabled_cluster_log_types": ["api"],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}

data.test_input_eks_complete_logging := {
  "resource_changes": [{
    "address": "aws_eks_cluster.main",
    "mode": "managed",
    "type": "aws_eks_cluster",
    "name": "main",
    "change": {
      "actions": ["create"],
      "after": {
        "name": "main",
        "enabled_cluster_log_types": ["api", "audit", "authenticator"],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}
