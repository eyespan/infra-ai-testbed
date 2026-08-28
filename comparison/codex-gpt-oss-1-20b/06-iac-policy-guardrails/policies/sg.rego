package terraform.sg

import rego.v1

in_scope(rc) if {
  rc.mode == "managed"
  some action in rc.change.actions
  action in {"create", "update"}
}

public(rule) if { "0.0.0.0/0" in object.get(rule, "cidr_blocks", []) }
public(rule) if { "::/0" in object.get(rule, "ipv6_cidr_blocks", []) }

sensitive_port(rule) if {
  from := object.get(rule, "from_port", -1)
  to := object.get(rule, "to_port", -1)
  from <= 22
  to >= 22
}
sensitive_port(rule) if {
  from := object.get(rule, "from_port", -1)
  to := object.get(rule, "to_port", -1)
  from <= 3389
  to >= 3389
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  rc.type == "aws_security_group"
  rule := object.get(rc.change.after, "ingress", [])[_]
  public(rule)
  sensitive_port(rule)
  msg := sprintf("Security group %q permits public SSH/RDP in ingress rule %v-%v.", [rc.address, rule.from_port, rule.to_port])
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  rc.type in {"aws_security_group_rule", "aws_vpc_security_group_ingress_rule"}
  object.get(rc.change.after, "type", "ingress") == "ingress"
  public(rc.change.after)
  sensitive_port(rc.change.after)
  msg := sprintf("Security-group rule %q permits public SSH/RDP.", [rc.address])
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  rc.type == "aws_security_group"
  object.get(rc.change.after_unknown, "ingress", false) == true
  msg := sprintf("Security group %q ingress is unknown in this plan and cannot be checked for public SSH/RDP.", [rc.address])
}
