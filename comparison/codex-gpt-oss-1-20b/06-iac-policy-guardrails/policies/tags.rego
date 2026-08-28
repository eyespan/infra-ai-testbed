package terraform.tags

import rego.v1

required := {"Environment", "Owner", "CostCenter"}

# An allowlist avoids falsely requiring tags on AWS helper, association, and
# policy resources that do not expose tags. Extend only after provider review.
taggable := {"aws_s3_bucket", "aws_security_group", "aws_vpc", "aws_subnet", "aws_instance", "aws_launch_template", "aws_eks_cluster", "aws_db_instance", "aws_rds_cluster", "aws_lambda_function", "aws_dynamodb_table", "aws_ecr_repository", "aws_lb", "aws_cloudwatch_log_group", "aws_kms_key", "aws_sns_topic", "aws_sqs_queue"}

in_scope(rc) if {
  rc.mode == "managed"
  rc.type in taggable
  some action in rc.change.actions
  action in {"create", "update"}
}

tag_keys(after) := keys if {
  tags := object.get(after, "tags", {})
  is_object(tags)
  keys := {key | tags[key]; key != ""}
}
tag_keys(after) := set() if {
  not is_object(object.get(after, "tags", {}))
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  missing := required - tag_keys(rc.change.after)
  count(missing) > 0
  msg := sprintf("Tagged resource %q (%s) is missing: %s.", [rc.address, rc.type, concat(", ", missing)])
}

deny contains msg if {
  rc := input.resource_changes[_]
  in_scope(rc)
  object.get(rc.change.after_unknown, "tags", false) == true
  msg := sprintf("Tags for resource %q are unknown in this plan; required tags cannot be verified.", [rc.address])
}
