package terraform.sg

import rego.v1

# Test: Security group allowing 0.0.0.0/0 on port 22 should be denied
test_sg_public_ssh_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "ingress": [
                            {
                                "from_port": 22,
                                "to_port": 22,
                                "protocol": "tcp",
                                "cidr_blocks": ["0.0.0.0/0"]
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "allows public access")
    contains(msg, "port 22")
}

# Test: Security group allowing 0.0.0.0/0 on port 3389 should be denied
test_sg_public_rdp_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "ingress": [
                            {
                                "from_port": 3389,
                                "to_port": 3389,
                                "protocol": "tcp",
                                "cidr_blocks": ["0.0.0.0/0"]
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) > 0
    some msg in deny
    contains(msg, "port 3389")
}

# Test: Security group with restricted CIDR should pass
test_sg_restricted_cidr_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "ingress": [
                            {
                                "from_port": 22,
                                "to_port": 22,
                                "protocol": "tcp",
                                "cidr_blocks": ["10.0.0.0/8"]
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: Security group allowing 0.0.0.0/0 on non-sensitive port should pass
test_sg_public_https_passes if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "ingress": [
                            {
                                "from_port": 443,
                                "to_port": 443,
                                "protocol": "tcp",
                                "cidr_blocks": ["0.0.0.0/0"]
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) == 0
}

# Test: Port range that includes 22 should be denied
test_sg_port_range_including_ssh_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "ingress": [
                            {
                                "from_port": 20,
                                "to_port": 25,
                                "protocol": "tcp",
                                "cidr_blocks": ["0.0.0.0/0"]
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) > 0
}

# Test: Security group rule resource should also be checked
test_sg_rule_public_ssh_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group_rule.test",
                "type": "aws_security_group_rule",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "type": "ingress",
                        "from_port": 22,
                        "to_port": 22,
                        "protocol": "tcp",
                        "cidr_blocks": ["0.0.0.0/0"]
                    }
                }
            }
        ]
    }

    count(deny) > 0
}

# Test: IPv6 public access should also be denied
test_sg_ipv6_public_ssh_denied if {
    input := {
        "resource_changes": [
            {
                "address": "aws_security_group.test",
                "type": "aws_security_group",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "ingress": [
                            {
                                "from_port": 22,
                                "to_port": 22,
                                "protocol": "tcp",
                                "ipv6_cidr_blocks": ["::/0"]
                            }
                        ]
                    }
                }
            }
        ]
    }

    count(deny) > 0
}
