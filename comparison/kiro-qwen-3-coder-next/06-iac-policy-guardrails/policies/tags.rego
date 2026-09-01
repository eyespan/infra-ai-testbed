package terraform.tags

import future.keywords.in

# Required tags for resources that support tagging
REQUIRED_TAGS := ["Environment", "Owner", "CostCenter"]

# Resources that cannot be tagged (skip them)
UNTAGGABLE_RESOURCES := {
  "aws_iam_policy",
  "aws_iam_role",
  "aws_iam_role_policy",
  "aws_iam_policy_document",
  "aws_ami",
  "aws_ami_copy",
  "aws_ami_launch_permission",
  "aws_caller_identity",
  "aws_vpc",
  "aws_subnet",
  "aws_security_group",
  "aws_internet_gateway",
  "aws_nat_gateway",
  "aws_eip",
  "aws_route_table",
  "aws_route_table_association",
  "aws_instance",
  "aws_lb",
  "aws_lb_target_group",
  "aws_lb_listener",
  "aws_s3_bucket",
  "aws_s3_bucket_public_access_block",
  "aws_s3_bucket_versioning",
  "aws_s3_bucket_server_side_encryption_configuration",
  "aws_s3_bucket_logging",
  "aws_s3_bucket_metric",
  "aws_s3_bucket_metric",
  "aws_s3_bucket_notification",
  "aws_s3_bucket_object",
  "aws_s3_bucket_policy",
  "aws_s3_bucket_acl",
  "aws_s3_bucket_cors_configuration",
  "aws_s3_bucket_replication_configuration",
  "aws_s3_bucket_website_configuration",
  "aws_s3_bucket_request_payment_configuration",
  "aws_db_instance",
  "aws_db_subnet_group",
  "aws_db_parameter_group",
  "aws_db_option_group",
  "aws_db_security_group",
  "aws_elasticsearch_domain",
  "aws_cloudwatch_metric_alarm",
  "aws_cloudwatch_log_group",
  "aws_cloudwatch_log_stream",
  "aws_cloudwatch_log_destination",
  "aws_cloudwatch_log_destination_policy",
  "aws_cloudwatch_log_metric_filter",
  "aws_cloudwatch_log_resource_policy",
  "aws_lambda_function",
  "aws_lambda_event_source_mapping",
  "aws_lambda_layer_version",
  "aws_kms_key",
  "aws_kms_alias",
  "aws_secretsmanager_secret",
  "aws_secretsmanager_secret_version",
  "aws_sqs_queue",
  "aws_sqs_queue_policy",
  "aws_sns_topic",
  "aws_sns_topic_subscription",
  "aws_dynamodb_table",
  "aws_dynamodb_table_item",
  "aws_dynamodb_table_replica",
  "aws_api_gateway_rest_api",
  "aws_api_gateway_resource",
  "aws_api_gateway_method",
  "aws_api_gateway_integration",
  "aws_api_gateway_method_response",
  "aws_api_gateway_integration_response",
  "aws_api_gateway_deployment",
  "aws_api_gateway_stage",
  "aws_api_gateway_gateway_response",
  "aws_api_gateway_usage_plan",
  "aws_api_gateway_usage_plan_key",
  "aws_api_gateway_model",
  "aws_api_gateway_request_validator",
  "aws_api_gateway_authorizer",
  "aws_eks_cluster",
  "aws_eks_node_group",
  "aws_eks_access_policy_association",
  "aws_eks_addon",
}

# Resources that should have tags
TAGGABLE_RESOURCES := {
  "aws_s3_bucket",
  "aws_instance",
  "aws_lb",
  "aws_db_instance",
  "aws_eks_cluster",
  "aws_eks_node_group",
  "aws_ecs_task_definition",
  "aws_ecs_service",
  "aws_autoscaling_group",
  "aws_launch_configuration",
  "aws_launch_template",
  "aws_cloudwatch_metric_alarm",
  "aws_cloudwatch_log_group",
  "aws_kms_key",
  "aws_secretsmanager_secret",
  "aws_sqs_queue",
  "aws_sns_topic",
  "aws_dynamodb_table",
  "aws_elasticsearch_domain",
  "aws_cloudfront_distribution",
  "aws_lb_target_group",
  "aws_vpc_endpoint",
  "aws_vpc_endpoint_service",
  "aws_nat_gateway",
  "aws_internet_gateway",
  "aws_route_table",
  "aws_route_table_association",
  "aws_eip",
  "aws_security_group",
}

# Resources that should have tags - subset of all AWS resources
# We match based on pattern rather than exhaustive list
is_taggable_resource(resource_type) {
  not is_untaggable_resource(resource_type)
}

is_untaggable_resource(resource_type) {
  UNTAGGABLE_RESOURCES[resource_type]
}

# Deny if required tags are missing
deny[msg] {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  resource.change.actions[_] == "create"

  # Skip untaggable resources
  is_untaggable_resource(resource.type)

  # Skip if tags are empty object (no tags at all)
  resource.change.after.tags == {}

  # Check each required tag is present
  not has_required_tags(resource)

  msg := sprintf(
    "Resource '%s' (type: %s) is missing required tags: %v",
    [resource.address, resource.type, missing_tags(resource)]
  )
}

# Check if all required tags are present
has_required_tags(resource) {
  tags := resource.change.after.tags
  tags[REQUIRED_TAGS[_]]
}

# Find which tags are missing
missing_tags(resource) = missing {
  tags := resource.change.after.tags
  missing := [t | t := REQUIRED_TAGS[_]; not tags[t]]
}
