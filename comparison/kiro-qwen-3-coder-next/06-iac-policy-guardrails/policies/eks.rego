package terraform.eks

# EKS clusters must have control-plane logging enabled for at least api, audit, and authenticator
deny[msg] {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  resource.type == "aws_eks_cluster"
  resource.change.actions[_] == "create"

  # Get enabled log types from the cluster configuration
  enabled_logs := resource.change.after.enabled_cluster_log_types

  # Check if required logs are present
  not has_required_logs(enabled_logs)

  msg := sprintf(
    "EKS cluster '%s' does not have required control-plane logging enabled. Required: api, audit, authenticator. Found: %v",
    [resource.name, enabled_logs]
  )
}

# Check if all required logs are present in the list
has_required_logs(logs) {
  logs[_] == "api"
  logs[_] == "audit"
  logs[_] == "authenticator"
}

# Handle case where enabled_cluster_log_types is empty or missing
has_required_logs(logs) {
  count(logs) == 0
  false
}
