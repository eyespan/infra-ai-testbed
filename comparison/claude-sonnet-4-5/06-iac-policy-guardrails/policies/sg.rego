package terraform.sg

import rego.v1

# Deny security groups that allow 0.0.0.0/0 on port 22 (SSH) or 3389 (RDP)

deny contains msg if {
    # Get all security group resources
    resource := input.resource_changes[_]
    resource.type == "aws_security_group"
    action_creates_or_updates(resource.change.actions)

    # Check ingress rules
    ingress := resource.change.after.ingress[_]

    # Check if rule allows SSH (22) or RDP (3389)
    is_sensitive_port(ingress)

    # Check if rule allows traffic from anywhere (0.0.0.0/0)
    allows_public_access(ingress)

    msg := sprintf(
        "Security group '%s' allows public access (0.0.0.0/0) on sensitive port %d. Restrict to specific CIDR blocks.",
        [resource.address, ingress.from_port]
    )
}

# Also check standalone security group rules
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_security_group_rule"
    action_creates_or_updates(resource.change.actions)
    resource.change.after.type == "ingress"

    # Check if rule allows SSH or RDP
    is_sensitive_port(resource.change.after)

    # Check if rule allows traffic from anywhere
    allows_public_access(resource.change.after)

    msg := sprintf(
        "Security group rule '%s' allows public access (0.0.0.0/0) on sensitive port %d. Restrict to specific CIDR blocks.",
        [resource.address, resource.change.after.from_port]
    )
}

# Helper: Check if action creates or updates resource
action_creates_or_updates(actions) if {
    "create" in actions
}

action_creates_or_updates(actions) if {
    "update" in actions
}

# Helper: Check if port is sensitive (SSH or RDP)
is_sensitive_port(rule) if {
    rule.from_port == 22
}

is_sensitive_port(rule) if {
    rule.from_port == 3389
}

is_sensitive_port(rule) if {
    rule.from_port <= 22
    rule.to_port >= 22
}

is_sensitive_port(rule) if {
    rule.from_port <= 3389
    rule.to_port >= 3389
}

# Helper: Check if rule allows public access
allows_public_access(rule) if {
    cidr := rule.cidr_blocks[_]
    cidr == "0.0.0.0/0"
}

allows_public_access(rule) if {
    cidr := rule.ipv6_cidr_blocks[_]
    cidr == "::/0"
}
