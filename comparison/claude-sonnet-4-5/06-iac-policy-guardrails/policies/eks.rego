package terraform.eks

import rego.v1

# Deny EKS clusters without required control plane logging enabled

required_log_types := {"api", "audit", "authenticator"}

deny contains msg if {
    # Get all EKS cluster resources
    resource := input.resource_changes[_]
    resource.type == "aws_eks_cluster"
    action_creates_or_updates(resource.change.actions)

    # Get enabled log types (can be null, empty array, or array with values)
    enabled_logs := get_enabled_logs(resource.change.after)

    # Find missing required log types
    missing := required_log_types - enabled_logs

    # If any required log types are missing, deny
    count(missing) > 0

    msg := sprintf(
        "EKS cluster '%s' must have control plane logging enabled for: %s. Currently enabled: %s. Missing: %s",
        [resource.address, concat(", ", required_log_types), concat(", ", enabled_logs), concat(", ", missing)]
    )
}

# Helper: Check if action creates or updates resource
action_creates_or_updates(actions) if {
    "create" in actions
}

action_creates_or_updates(actions) if {
    "update" in actions
}

# Helper: Get enabled log types, handling various cases
get_enabled_logs(after) := enabled if {
    # enabled_cluster_log_types is an array
    is_array(after.enabled_cluster_log_types)
    enabled := {log | log := after.enabled_cluster_log_types[_]}
}

get_enabled_logs(after) := set() if {
    # enabled_cluster_log_types is null or doesn't exist
    not after.enabled_cluster_log_types
}

get_enabled_logs(after) := set() if {
    # enabled_cluster_log_types exists but is empty array
    after.enabled_cluster_log_types == []
}
