package terraform.eks

import rego.v1

required := {"api", "audit", "authenticator"}

in_scope(rc) if {
  rc.mode == "managed"
  some action in rc.change.actions
  action in {"create", "update"}
}

known_logs(after) := logs if {
  configured := object.get(after, "enabled_cluster_log_types", [])
  is_array(configured)
  logs := {entry | entry := configured[_]}
}
known_logs(after) := set() if {
  not is_array(object.get(after, "enabled_cluster_log_types", []))
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  rc.type == "aws_eks_cluster"
  missing := required - known_logs(rc.change.after)
  count(missing) > 0
  msg := sprintf("EKS cluster %q is missing required control-plane logs: %s.", [rc.address, concat(", ", missing)])
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  rc.type == "aws_eks_cluster"
  object.get(rc.change.after_unknown, "enabled_cluster_log_types", false) == true
  msg := sprintf("EKS cluster %q control-plane log types are unknown in this plan.", [rc.address])
}
