package terraform.sg

# Security groups must not allow 0.0.0.0/0 or ::/0 on port 22 (SSH) or 3389 (RDP)
deny[msg] {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  resource.type == "aws_security_group"
  resource.change.actions[_] == "create"

  # Check ingress rules for SSH/RDP from any source
  ingress := resource.change.after.ingress[_]
  is_dangerous_port(ingress.from_port, ingress.to_port)
  is_any_source(ingress.cidr_blocks)
  is_tcp_protocol(ingress.protocol)

  msg := sprintf(
    "Security group '%s' allows %s from 0.0.0.0/0 or ::/0 on port %d-%d",
    [resource.name, ingress.protocol, ingress.from_port, ingress.to_port]
  )
}

# SSH is port 22, RDP is port 3389
is_dangerous_port(from, to) {
  from <= 22 and to >= 22
}

is_dangerous_port(from, to) {
  from <= 3389 and to >= 3389
}

# Check for IPv4 any-source or IPv6 any-source
is_any_source(cidr_blocks) {
  cidr_blocks[_] == "0.0.0.0/0"
}

is_any_source(cidr_blocks) {
  cidr_blocks[_] == "::/0"
}

# Only check TCP (SSH/RDP are TCP protocols)
is_tcp_protocol(protocol) {
  protocol == "tcp"
}

# Handle cases where protocol is not specified (defaults to tcp)
is_tcp_protocol(protocol) {
  protocol == "-1"
}
