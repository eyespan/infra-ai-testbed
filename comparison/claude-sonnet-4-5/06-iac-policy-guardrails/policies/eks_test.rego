package terraform.eks

import rego.v1

# Test: EKS cluster without logging should be denied
test_eks_no_logging_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-cluster",
                        "enabled_cluster_log_types": []
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "control plane logging")
    contains(msg, "api")
    contains(msg, "audit")
    contains(msg, "authenticator")
}

# Test: EKS cluster with partial logging should be denied
test_eks_partial_logging_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-cluster",
                        "enabled_cluster_log_types": ["api", "audit"]
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "authenticator")
}

# Test: EKS cluster with all required logging should pass
test_eks_required_logging_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-cluster",
                        "enabled_cluster_log_types": ["api", "audit", "authenticator"]
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: EKS cluster with all logging enabled should pass
test_eks_all_logging_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-cluster",
                        "enabled_cluster_log_types": [
                            "api",
                            "audit",
                            "authenticator",
                            "controllerManager",
                            "scheduler"
                        ]
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: EKS cluster with null logging should be denied
test_eks_null_logging_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "name": "test-cluster",
                        "enabled_cluster_log_types": null
                    }
                }
            }
        ]
    }

    count(deny) > 0
}

# Test: EKS cluster update should also be checked
test_eks_update_checked if {
    input := {
        "resource_changes": [
            {
                "address": "aws_eks_cluster.test",
                "type": "aws_eks_cluster",
                "change": {
                    "actions": ["update"],
                    "after": {
                        "name": "test-cluster",
                        "enabled_cluster_log_types": []
                    }
                }
            }
        ]
    }

    count(deny) > 0
}
