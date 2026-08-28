package terraform.tags

import rego.v1

# Mandatory tags that must be present on all taggable resources
required_tags := {"Environment", "Owner", "CostCenter"}

# Resource types that support tags
# This list includes common AWS resources that support tagging
taggable_resource_types := {
    "aws_s3_bucket",
    "aws_security_group",
    "aws_instance",
    "aws_eks_cluster",
    "aws_rds_instance",
    "aws_rds_cluster",
    "aws_lambda_function",
    "aws_dynamodb_table",
    "aws_vpc",
    "aws_subnet",
    "aws_ebs_volume",
    "aws_efs_file_system",
    "aws_elb",
    "aws_lb",
    "aws_autoscaling_group",
    "aws_launch_template",
    "aws_ecr_repository",
    "aws_ecs_cluster",
    "aws_ecs_service",
    "aws_ecs_task_definition",
    "aws_cloudwatch_log_group",
    "aws_sns_topic",
    "aws_sqs_queue",
    "aws_kinesis_stream",
    "aws_kms_key",
    "aws_route53_zone",
}

# Resource types that do NOT support tags (common false positives)
non_taggable_resource_types := {
    "aws_s3_bucket_public_access_block",
    "aws_s3_bucket_server_side_encryption_configuration",
    "aws_s3_bucket_versioning",
    "aws_s3_bucket_lifecycle_configuration",
    "aws_security_group_rule",
    "aws_route",
    "aws_route_table_association",
    "aws_internet_gateway_attachment",
    "aws_iam_role_policy_attachment",
    "aws_iam_policy_attachment",
    "aws_vpc_security_group_ingress_rule",
    "aws_vpc_security_group_egress_rule",
}

deny contains msg if {
    # Get all resources being created or updated
    resource := input.resource_changes[_]
    action_creates_or_updates(resource.change.actions)

    # Check if resource type supports tags
    is_taggable(resource.type)

    # Get tags from resource
    tags := get_tags(resource.change.after)

    # Find missing required tags
    missing := required_tags - tags

    # If any required tags are missing, deny
    count(missing) > 0

    msg := sprintf(
        "Resource '%s' (type: %s) is missing required tags: %s. Required tags are: %s",
        [resource.address, resource.type, concat(", ", missing), concat(", ", required_tags)]
    )
}

# Helper: Check if action creates or updates resource
action_creates_or_updates(actions) if {
    "create" in actions
}

action_creates_or_updates(actions) if {
    "update" in actions
}

# Helper: Check if resource type is taggable
is_taggable(resource_type) if {
    resource_type in taggable_resource_types
}

is_taggable(resource_type) if {
    # Default to true for unknown AWS resources (fail-safe)
    # unless explicitly in non-taggable list
    startswith(resource_type, "aws_")
    not resource_type in non_taggable_resource_types
    not resource_type in taggable_resource_types
    # This creates a "warn by default" behavior for unknown resources
}

# Helper: Get tags from resource, handling various formats
get_tags(after) := tag_keys if {
    # tags field exists and is an object
    is_object(after.tags)
    tag_keys := {key | after.tags[key]}
}

get_tags(after) := set() if {
    # tags field doesn't exist
    not after.tags
}

get_tags(after) := set() if {
    # tags field is null
    after.tags == null
}

get_tags(after) := set() if {
    # tags field is empty object
    after.tags == {}
}
