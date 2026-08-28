package terraform.sg

import rego.v1

test_ipv4_ssh_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_security_group.x", "mode": "managed", "type": "aws_security_group", "change": {"actions": ["create"], "after": {"ingress": [{"from_port": 20, "to_port": 25, "cidr_blocks": ["0.0.0.0/0"]}]}, "after_unknown": {}}}]}
  count(denials) == 1
}

test_ipv6_rdp_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_security_group.x", "mode": "managed", "type": "aws_security_group", "change": {"actions": ["create"], "after": {"ingress": [{"from_port": 3389, "to_port": 3389, "ipv6_cidr_blocks": ["::/0"]}]}, "after_unknown": {}}}]}
  count(denials) == 1
}

test_private_ssh_allowed if {
  denials := deny with input as {"resource_changes": [{"address": "aws_security_group.x", "mode": "managed", "type": "aws_security_group", "change": {"actions": ["update"], "after": {"ingress": [{"from_port": 22, "to_port": 22, "cidr_blocks": ["10.0.0.0/8"]}]}, "after_unknown": {}}}]}
  count(denials) == 0
}

test_unknown_ingress_denied if {
  denials := deny with input as {"resource_changes": [{"address": "aws_security_group.x", "mode": "managed", "type": "aws_security_group", "change": {"actions": ["create"], "after": {}, "after_unknown": {"ingress": true}}}]}
  count(denials) == 1
}
