package terraform.sg

test_security_group_ssh_open_to_internet_should_fail {
  not deny with input as data.test_input_sg_ssh_open
}

test_security_group_rdp_open_to_internet_should_fail {
  not deny with input as data.test_input_sg_rdp_open
}

test_security_group_ssh_open_ipv6_should_fail {
  not deny with input as data.test_input_sg_ssh_ipv6
}

test_security_group_ssh_restricted_should_pass {
  not deny with input as data.test_input_sg_ssh_restricted
}

test_security_group_http_open_should_pass {
  not deny with input as data.test_input_sg_http_open
}

data.test_input_sg_ssh_open := {
  "resource_changes": [{
    "address": "aws_security_group.bastion",
    "mode": "managed",
    "type": "aws_security_group",
    "name": "bastion",
    "change": {
      "actions": ["create"],
      "after": {
        "ingress": [{
          "from_port": 22,
          "to_port": 22,
          "protocol": "tcp",
          "cidr_blocks": ["0.0.0.0/0"]
        }],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}

data.test_input_sg_rdp_open := {
  "resource_changes": [{
    "address": "aws_security_group.rdp",
    "mode": "managed",
    "type": "aws_security_group",
    "name": "rdp",
    "change": {
      "actions": ["create"],
      "after": {
        "ingress": [{
          "from_port": 3389,
          "to_port": 3389,
          "protocol": "tcp",
          "cidr_blocks": ["0.0.0.0/0"]
        }],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}

data.test_input_sg_ssh_ipv6 := {
  "resource_changes": [{
    "address": "aws_security_group.bastion",
    "mode": "managed",
    "type": "aws_security_group",
    "name": "bastion",
    "change": {
      "actions": ["create"],
      "after": {
        "ingress": [{
          "from_port": 22,
          "to_port": 22,
          "protocol": "tcp",
          "cidr_blocks": ["::/0"]
        }],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}

data.test_input_sg_ssh_restricted := {
  "resource_changes": [{
    "address": "aws_security_group.bastion",
    "mode": "managed",
    "type": "aws_security_group",
    "name": "bastion",
    "change": {
      "actions": ["create"],
      "after": {
        "ingress": [{
          "from_port": 22,
          "to_port": 22,
          "protocol": "tcp",
          "cidr_blocks": ["10.0.0.0/8"]
        }],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}

data.test_input_sg_http_open := {
  "resource_changes": [{
    "address": "aws_security_group.web",
    "mode": "managed",
    "type": "aws_security_group",
    "name": "web",
    "change": {
      "actions": ["create"],
      "after": {
        "ingress": [{
          "from_port": 80,
          "to_port": 80,
          "protocol": "tcp",
          "cidr_blocks": ["0.0.0.0/0"]
        }],
        "tags": {"Environment": "prod", "Owner": "team", "CostCenter": "123"}
      }
    }
  }]
}
